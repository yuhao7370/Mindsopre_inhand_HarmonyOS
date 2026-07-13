#!/usr/bin/env python3
"""Export fixed Marian encoder/prefill/step ONNX graphs and verify their contract."""

from __future__ import annotations

import argparse
import json
import math
import os
from pathlib import Path
from typing import Dict, Optional, Sequence


PINNED_REPOSITORY = "Helsinki-NLP/opus-mt_tiny_zho-eng"
PINNED_REVISION = "4ee3a9342aae4ca6fbae82c930b5dccff5dd68dd"
PYTORCH_ONNX_MAX_ABS = 0.03
DECODER_PYTORCH_ONNX_MAX_ABS = 0.03


class ContractError(RuntimeError):
    pass


def load_profile(contract_path: Path, profile_name: str) -> dict:
    try:
        contract = json.loads(Path(contract_path).read_text(encoding="utf-8"))
        profile = contract["profiles"][profile_name]
    except (OSError, json.JSONDecodeError, KeyError, TypeError) as error:
        raise ContractError(f"unknown or invalid contract profile: {profile_name}") from error
    if contract.get("schemaVersion") != 1:
        raise ContractError("unsupported contract schema")
    return profile


def validate_graph_contract(expected: dict, actual: dict, graph_name: str) -> None:
    if expected != actual:
        raise ContractError(
            f"{graph_name} graph contract mismatch\n"
            f"expected={json.dumps(expected, sort_keys=True)}\n"
            f"actual={json.dumps(actual, sort_keys=True)}"
        )


def _inspect_onnx(path: Path) -> tuple[dict, list[dict]]:
    import onnx

    model = onnx.load(str(path))
    initializer_names = {item.name for item in model.graph.initializer}

    def tensor_map(values) -> dict:
        result = {}
        for value in values:
            tensor = value.type.tensor_type
            shape = []
            for dimension in tensor.shape.dim:
                if not dimension.HasField("dim_value"):
                    raise ContractError(f"dynamic dimension in {path.name}: {value.name}")
                shape.append(dimension.dim_value)
            result[value.name] = {
                "dtype": onnx.TensorProto.DataType.Name(tensor.elem_type),
                "shape": shape,
            }
        return result

    inputs = [value for value in model.graph.input if value.name not in initializer_names]
    contract = {"inputs": tensor_map(inputs), "outputs": tensor_map(model.graph.output)}
    nodes = [
        {"opType": node.op_type, "inputs": list(node.input), "outputs": list(node.output)}
        for node in model.graph.node
    ]
    return contract, nodes


def _validate_stable_softmax(nodes: list[dict], graph_name: str, expected_chains: int) -> None:
    operators = [node["opType"] for node in nodes]
    if "Softmax" in operators:
        raise ContractError(f"{graph_name} contains forbidden native Softmax")
    for operator in ("ReduceMax", "Exp", "ReduceSum", "Div"):
        if operators.count(operator) != expected_chains:
            raise ContractError(
                f"{graph_name} stable softmax dataflow expected {expected_chains} {operator} nodes, "
                f"got {operators.count(operator)}"
            )

    producers = {}
    for node in nodes:
        for output in node["outputs"]:
            if output in producers:
                raise ContractError(f"{graph_name} stable softmax dataflow has duplicate producer: {output}")
            producers[output] = node

    chains = 0
    for divide in (node for node in nodes if node["opType"] == "Div"):
        if len(divide["inputs"]) != 2:
            continue
        exponent = producers.get(divide["inputs"][0])
        denominator = producers.get(divide["inputs"][1])
        if not exponent or exponent["opType"] != "Exp" or not denominator or denominator["opType"] != "ReduceSum":
            continue
        if len(exponent["inputs"]) != 1 or len(exponent["outputs"]) != 1:
            continue
        if not denominator["inputs"] or denominator["inputs"][0] != exponent["outputs"][0]:
            continue
        subtract = producers.get(exponent["inputs"][0])
        if not subtract or subtract["opType"] != "Sub" or len(subtract["inputs"]) != 2:
            continue
        maximum = producers.get(subtract["inputs"][1])
        if not maximum or maximum["opType"] != "ReduceMax" or len(maximum["inputs"]) != 1:
            continue
        if subtract["inputs"][0] != maximum["inputs"][0]:
            continue
        chains += 1
    if chains != expected_chains:
        raise ContractError(
            f"{graph_name} stable softmax dataflow expected {expected_chains} complete chains, got {chains}"
        )


def _checkpoint_revision(checkpoint: Path) -> Optional[str]:
    metadata = checkpoint / ".cache" / "huggingface" / "download" / "config.json.metadata"
    if metadata.is_file():
        return metadata.read_text(encoding="utf-8").splitlines()[0].strip()
    provenance = checkpoint / "base_revision.txt"
    if provenance.is_file():
        return provenance.read_text(encoding="utf-8").strip()
    return None


def _validate_checkpoint(checkpoint: Path, profile: dict, profile_name: str) -> None:
    config_path = checkpoint / "config.json"
    if not config_path.is_file() or not (checkpoint / "model.safetensors").is_file():
        raise ContractError("checkpoint must contain config.json and model.safetensors")
    config = json.loads(config_path.read_text(encoding="utf-8"))
    expected = {
        "vocab_size": profile["vocabSize"],
        "decoder_vocab_size": profile["vocabSize"],
        "d_model": 256,
        "encoder_layers": 6,
        "decoder_layers": 2,
        "encoder_attention_heads": 8,
        "decoder_attention_heads": 8,
    }
    wrong = {name: (config.get(name), value) for name, value in expected.items() if config.get(name) != value}
    if wrong:
        raise ContractError(f"checkpoint config mismatch for {profile_name}: {wrong}")
    revision = _checkpoint_revision(checkpoint)
    if revision != PINNED_REVISION:
        raise ContractError(f"checkpoint revision mismatch: expected {PINNED_REVISION}, got {revision}")


def download_pinned_checkpoint(download_root: Path) -> Path:
    from huggingface_hub import snapshot_download

    download_root = Path(download_root).resolve()
    repository_root = Path(__file__).resolve().parents[2]
    if download_root == repository_root or repository_root in download_root.parents:
        raise ContractError("checkpoint/cache downloads must stay outside the repository")
    download_root.mkdir(parents=True, exist_ok=True)
    snapshot_download(
        repo_id=PINNED_REPOSITORY,
        revision=PINNED_REVISION,
        local_dir=str(download_root),
        cache_dir=str(download_root / ".hf-cache"),
        allow_patterns=("config.json", "model.safetensors"),
    )
    return download_root


def _wrappers(torch):
    nn = torch.nn

    def stable_softmax(value):
        maximum = torch.amax(value, dim=-1, keepdim=True)
        numerator = torch.exp(value - maximum)
        return numerator / torch.sum(numerator, dim=-1, keepdim=True)

    def additive_mask(mask, dtype):
        return (1.0 - mask[:, None, None, :].to(dtype)) * torch.finfo(dtype).min

    def project(module, hidden, projection):
        value = projection(hidden)
        return value.view(value.shape[0], value.shape[1], module.num_heads, module.head_dim).transpose(1, 2)

    def attention(module, query_hidden, key_hidden, mask, past_key=None, past_value=None, cached=None):
        query = project(module, query_hidden, module.q_proj)
        if cached is None:
            new_key = project(module, key_hidden, module.k_proj)
            new_value = project(module, key_hidden, module.v_proj)
            key = torch.cat((past_key, new_key), dim=2) if past_key is not None else new_key
            value = torch.cat((past_value, new_value), dim=2) if past_value is not None else new_value
        else:
            key, value = cached
            new_key, new_value = key, value
        scores = torch.matmul(query, key.transpose(2, 3)) * module.scaling
        if mask is not None:
            scores = scores + mask
        output = torch.matmul(stable_softmax(scores), value)
        output = output.transpose(1, 2).contiguous().reshape(query_hidden.shape[0], query_hidden.shape[1], -1)
        return module.out_proj(output), new_key, new_value

    def feed_forward(layer, hidden):
        residual = hidden
        hidden = layer.activation_fn(layer.fc1(hidden))
        hidden = layer.fc2(hidden)
        return layer.final_layer_norm(residual + hidden)

    class Encoder(nn.Module):
        def __init__(self, model):
            super().__init__()
            self.encoder = model.model.encoder

        def forward(self, input_ids, attention_mask):
            hidden = self.encoder.embed_tokens(input_ids.to(torch.int64)) * self.encoder.embed_scale
            hidden = hidden + self.encoder.embed_positions(hidden.shape[:-1])
            mask = additive_mask(attention_mask, hidden.dtype)
            for layer in self.encoder.layers:
                residual = hidden
                attended, _, _ = attention(layer.self_attn, hidden, hidden, mask)
                hidden = layer.self_attn_layer_norm(residual + attended)
                hidden = feed_forward(layer, hidden)
            return hidden

    class DecoderBase(nn.Module):
        def __init__(self, model):
            super().__init__()
            self.decoder = model.model.decoder
            self.lm_head = model.lm_head
            self.register_buffer("final_logits_bias", model.final_logits_bias)

        def embed(self, input_ids, position_id):
            hidden = self.decoder.embed_tokens(input_ids.to(torch.int64)) * self.decoder.embed_scale
            positions = self.decoder.embed_positions(hidden.shape[:-1], position_ids=position_id.to(torch.int64))
            return hidden + positions

        def finish(self, hidden):
            return self.lm_head(hidden)[:, -1, :] + self.final_logits_bias

    class Prefill(DecoderBase):
        def forward(self, decoder_input_ids, encoder_hidden_states, encoder_attention_mask):
            position = torch.zeros((1,), dtype=torch.int64, device=decoder_input_ids.device)
            hidden = self.embed(decoder_input_ids, position)
            cross_mask = additive_mask(encoder_attention_mask, hidden.dtype)
            caches = []
            for layer in self.decoder.layers:
                residual = hidden
                attended, self_key, self_value = attention(layer.self_attn, hidden, hidden, None)
                hidden = layer.self_attn_layer_norm(residual + attended)
                residual = hidden
                attended, cross_key, cross_value = attention(
                    layer.encoder_attn, hidden, encoder_hidden_states, cross_mask
                )
                hidden = layer.encoder_attn_layer_norm(residual + attended)
                hidden = feed_forward(layer, hidden)
                caches.extend((self_key, self_value, cross_key, cross_value))
            return (self.finish(hidden), *caches)

    class Step(DecoderBase):
        def forward(self, decoder_input_ids, position_id, self_attention_mask, cross_attention_mask, *caches):
            hidden = self.embed(decoder_input_ids, position_id)
            self_mask = additive_mask(self_attention_mask, hidden.dtype)
            cross_mask = additive_mask(cross_attention_mask, hidden.dtype)
            outputs = []
            for index, layer in enumerate(self.decoder.layers):
                past_key, past_value, cross_key, cross_value = caches[index * 4 : index * 4 + 4]
                residual = hidden
                attended, new_key, new_value = attention(
                    layer.self_attn, hidden, hidden, self_mask, past_key, past_value
                )
                hidden = layer.self_attn_layer_norm(residual + attended)
                residual = hidden
                attended, _, _ = attention(
                    layer.encoder_attn, hidden, hidden, cross_mask, cached=(cross_key, cross_value)
                )
                hidden = layer.encoder_attn_layer_norm(residual + attended)
                hidden = feed_forward(layer, hidden)
                outputs.extend((new_key, new_value))
            return (self.finish(hidden), *outputs)

    return Encoder, Prefill, Step


def _numpy_outputs(values) -> list:
    import numpy as np

    if not isinstance(values, tuple):
        values = (values,)
    outputs = [value.detach().cpu().numpy() for value in values]
    if not all(np.isfinite(value).all() for value in outputs):
        raise ContractError("PyTorch produced non-finite tensors")
    return outputs


def _export_one(torch, wrapper, inputs, names, output_names, path: Path, max_abs: float) -> list:
    wrapper.eval()
    with torch.no_grad():
        expected = _numpy_outputs(wrapper(*inputs))
    torch.onnx.export(
        wrapper,
        inputs,
        str(path),
        input_names=names,
        output_names=output_names,
        opset_version=17,
        do_constant_folding=True,
        dynamo=False,
    )
    import numpy as np
    import onnxruntime as ort

    session_options = ort.SessionOptions()
    session_options.graph_optimization_level = ort.GraphOptimizationLevel.ORT_DISABLE_ALL
    session_options.execution_mode = ort.ExecutionMode.ORT_SEQUENTIAL
    session_options.intra_op_num_threads = 1
    session_options.inter_op_num_threads = 1
    session = ort.InferenceSession(str(path), sess_options=session_options, providers=["CPUExecutionProvider"])
    actual = session.run(None, {name: value.detach().cpu().numpy() for name, value in zip(names, inputs)})
    for name, reference, candidate in zip(output_names, expected, actual):
        if not np.isfinite(candidate).all():
            raise ContractError(f"{path.name}:{name} produced non-finite ONNX output")
        error = float(np.max(np.abs(reference.astype(np.float32) - candidate.astype(np.float32))))
        if error > max_abs:
            raise ContractError(
                f"{path.name}:{name} PyTorch/ONNX max_abs {error} > {max_abs}"
            )
    return actual


def export_graphs(checkpoint: Path, output_root: Path, contract_path: Path, profile_name: str) -> dict:
    import numpy as np
    import torch
    from transformers import MarianMTModel

    profile = load_profile(contract_path, profile_name)
    _validate_checkpoint(checkpoint, profile, profile_name)
    output_root = output_root.resolve()
    repository_root = Path(__file__).resolve().parents[2]
    if output_root == repository_root or repository_root in output_root.parents:
        raise ContractError("large generated artifacts must be outside the repository")
    output_root.mkdir(parents=True, exist_ok=True)

    model = MarianMTModel.from_pretrained(
        str(checkpoint), local_files_only=True, dtype=torch.float16, attn_implementation="eager"
    ).eval()
    Encoder, Prefill, Step = _wrappers(torch)
    encoder, prefill, step = Encoder(model), Prefill(model), Step(model)
    length = profile["maxTokens"]
    vocab = profile["vocabSize"]
    generator = torch.Generator().manual_seed(20260713)
    input_ids = torch.randint(2, min(vocab - 1, 1000), (1, length), dtype=torch.int32, generator=generator)
    input_ids[:, -1] = 0
    encoder_mask = torch.ones((1, length), dtype=torch.int32)
    decoder_ids = torch.tensor([[model.config.decoder_start_token_id]], dtype=torch.int32)

    graph_inputs = {}
    encoder_outputs = _export_one(
        torch, encoder, (input_ids, encoder_mask), ["input_ids", "attention_mask"],
        ["last_hidden_state"], output_root / "encoder.onnx", PYTORCH_ONNX_MAX_ABS
    )
    hidden = torch.from_numpy(encoder_outputs[0])
    prefill_names = ["logits"]
    for layer in range(2):
        prefill_names.extend((f"self_key_{layer}", f"self_value_{layer}", f"cross_key_{layer}", f"cross_value_{layer}"))
    prefill_outputs = _export_one(
        torch, prefill, (decoder_ids, hidden, encoder_mask),
        ["decoder_input_ids", "encoder_hidden_states", "encoder_attention_mask"], prefill_names,
        output_root / "decoder_prefill.onnx", DECODER_PYTORCH_ONNX_MAX_ABS
    )
    history = []
    for layer in range(2):
        past_key = torch.zeros((1, 8, length - 1, 32), dtype=torch.float16)
        past_value = torch.zeros_like(past_key)
        past_key[:, :, 0:1, :] = torch.from_numpy(prefill_outputs[1 + layer * 4])
        past_value[:, :, 0:1, :] = torch.from_numpy(prefill_outputs[2 + layer * 4])
        history.extend((past_key, past_value, torch.from_numpy(prefill_outputs[3 + layer * 4]), torch.from_numpy(prefill_outputs[4 + layer * 4])))
    self_mask = torch.zeros((1, length), dtype=torch.int32)
    self_mask[:, 0] = 1
    self_mask[:, -1] = 1
    position = torch.tensor([1], dtype=torch.int32)
    next_ids = torch.from_numpy(np.argmax(prefill_outputs[0], axis=-1).astype(np.int32)).reshape(1, 1)
    step_input_names = ["decoder_input_ids", "position_id", "self_attention_mask", "cross_attention_mask"]
    for layer in range(2):
        step_input_names.extend((f"past_key_{layer}", f"past_value_{layer}", f"cross_key_{layer}", f"cross_value_{layer}"))
    step_output_names = ["logits", "new_key_0", "new_value_0", "new_key_1", "new_value_1"]
    step_inputs = (next_ids, position, self_mask, encoder_mask, *history)
    _export_one(
        torch, step, step_inputs, step_input_names, step_output_names,
        output_root / "decoder_step.onnx", DECODER_PYTORCH_ONNX_MAX_ABS
    )

    for graph_name in ("encoder", "decoder_prefill", "decoder_step"):
        actual, nodes = _inspect_onnx(output_root / f"{graph_name}.onnx")
        validate_graph_contract(profile["graphs"][graph_name], actual, graph_name)
        _validate_stable_softmax(nodes, graph_name, profile["stableSoftmaxChains"][graph_name])
        graph_inputs[graph_name] = actual
    report = {
        "profile": profile_name,
        "checkpointRevision": PINNED_REVISION,
        "vocabSize": vocab,
        "maxTokens": length,
        "graphs": graph_inputs,
        "pytorchOnnxMaxAbsLimit": PYTORCH_ONNX_MAX_ABS,
        "decoderPytorchOnnxMaxAbsLimit": DECODER_PYTORCH_ONNX_MAX_ABS,
        "stableSoftmax": ["ReduceMax", "Sub", "Exp", "ReduceSum", "Div"],
    }
    (output_root / "export-report.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    return report


def inspect_exports(output_root: Path, contract_path: Path, profile_name: str) -> dict:
    profile = load_profile(contract_path, profile_name)
    inspected = {}
    for graph_name in ("encoder", "decoder_prefill", "decoder_step"):
        actual, nodes = _inspect_onnx(Path(output_root) / f"{graph_name}.onnx")
        validate_graph_contract(profile["graphs"][graph_name], actual, graph_name)
        _validate_stable_softmax(nodes, graph_name, profile["stableSoftmaxChains"][graph_name])
        inspected[graph_name] = actual
    return {"profile": profile_name, "graphs": inspected}


def onnx_cache_loop(
    output_root: Path,
    contract_path: Path,
    profile_name: str,
    steps: int = 5,
    binary_fixture_root: Optional[Path] = None,
) -> dict:
    import numpy as np
    import onnxruntime as ort

    profile = load_profile(contract_path, profile_name)
    length = profile["maxTokens"]
    sessions = {
        name: ort.InferenceSession(str(Path(output_root) / f"{name}.onnx"), providers=["CPUExecutionProvider"])
        for name in ("encoder", "decoder_prefill", "decoder_step")
    }
    input_ids = np.arange(length, dtype=np.int32).reshape(1, length)
    encoder_mask = np.zeros((1, length), dtype=np.int32)
    encoder_mask[:, : length // 2] = 1
    cross_mask = encoder_mask.copy()
    hidden = sessions["encoder"].run(None, {"input_ids": input_ids, "attention_mask": encoder_mask})[0]
    if binary_fixture_root is not None:
        fixture = Path(binary_fixture_root)
        hidden = np.fromfile(fixture / "pre_01_encoder.bin", dtype=np.float32).reshape(1, length, 256).astype(np.float16)
        cross_mask = np.fromfile(fixture / "pre_02_mask.bin", dtype=np.int32).reshape(1, length)
    prefill = sessions["decoder_prefill"].run(None, {
        "decoder_input_ids": np.array([[32000]], dtype=np.int32),
        "encoder_hidden_states": hidden,
        "encoder_attention_mask": cross_mask,
    })
    if not all(np.isfinite(value).all() for value in (hidden, *prefill)):
        raise ContractError("ONNX cache loop produced non-finite tensors")
    token = int(np.argmax(prefill[0], axis=-1)[0])
    tokens = [token]
    history = []
    for layer in range(2):
        past_key = np.zeros((1, 8, length - 1, 32), dtype=prefill[1 + layer * 4].dtype)
        past_value = np.zeros_like(past_key)
        past_key[:, :, 0:1, :] = prefill[1 + layer * 4]
        past_value[:, :, 0:1, :] = prefill[2 + layer * 4]
        history.extend((past_key, past_value, prefill[3 + layer * 4], prefill[4 + layer * 4]))
    if binary_fixture_root is not None:
        fixture = Path(binary_fixture_root)
        token = int(np.fromfile(fixture / "step_00_ids.bin", dtype=np.int32)[0])
        tokens = [token]
        history = []
        for layer in range(2):
            history.extend((
                np.fromfile(fixture / f"step_{4 + layer * 4:02d}_past_key_{layer}.bin", dtype=np.float32)
                .reshape(1, 8, length - 1, 32).astype(np.float16),
                np.fromfile(fixture / f"step_{5 + layer * 4:02d}_past_value_{layer}.bin", dtype=np.float32)
                .reshape(1, 8, length - 1, 32).astype(np.float16),
                np.fromfile(fixture / f"step_{6 + layer * 4:02d}_cross_key_{layer}.bin", dtype=np.float32)
                .reshape(1, 8, length, 32).astype(np.float16),
                np.fromfile(fixture / f"step_{7 + layer * 4:02d}_cross_value_{layer}.bin", dtype=np.float32)
                .reshape(1, 8, length, 32).astype(np.float16),
            ))
    for position in range(1, steps + 1):
        self_mask = np.zeros((1, length), dtype=np.int32)
        self_mask[:, :position] = 1
        self_mask[:, -1] = 1
        feed = {
            "decoder_input_ids": np.array([[token]], dtype=np.int32),
            "position_id": np.array([position], dtype=np.int32),
            "self_attention_mask": self_mask,
            "cross_attention_mask": cross_mask,
        }
        for layer in range(2):
            offset = layer * 4
            feed[f"past_key_{layer}"] = history[offset]
            feed[f"past_value_{layer}"] = history[offset + 1]
            feed[f"cross_key_{layer}"] = history[offset + 2]
            feed[f"cross_value_{layer}"] = history[offset + 3]
        outputs = sessions["decoder_step"].run(None, feed)
        if not all(np.isfinite(value).all() for value in outputs):
            raise ContractError("ONNX decoder step produced non-finite tensors")
        token = int(np.argmax(outputs[0], axis=-1)[0])
        tokens.append(token)
        if position < length - 1:
            for layer in range(2):
                history[layer * 4][:, :, position : position + 1, :] = outputs[1 + layer * 2]
                history[layer * 4 + 1][:, :, position : position + 1, :] = outputs[2 + layer * 2]
    return {"profile": profile_name, "steps": steps, "tokens": tokens}


def _parse(argv: Optional[Sequence[str]] = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--checkpoint", type=Path)
    parser.add_argument("--download-root", type=Path)
    parser.add_argument("--output-root", required=True, type=Path)
    parser.add_argument("--contract", required=True, type=Path)
    parser.add_argument("--profile", choices=("prototype", "final"), required=True)
    parser.add_argument("--inspect-only", action="store_true")
    parser.add_argument("--cache-loop-only", action="store_true")
    parser.add_argument("--binary-fixture-root", type=Path)
    return parser.parse_args(argv)


def main(argv: Optional[Sequence[str]] = None) -> int:
    args = _parse(argv)
    if args.cache_loop_only:
        result = onnx_cache_loop(
            args.output_root, args.contract, args.profile, binary_fixture_root=args.binary_fixture_root
        )
    elif args.inspect_only:
        result = inspect_exports(args.output_root, args.contract, args.profile)
    else:
        checkpoint = args.checkpoint
        if checkpoint is None:
            if args.download_root is None:
                raise ContractError("provide --checkpoint or an explicit --download-root")
            checkpoint = download_pinned_checkpoint(args.download_root)
        result = export_graphs(checkpoint, args.output_root, args.contract, args.profile)
    print(json.dumps(result, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
