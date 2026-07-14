#!/usr/bin/env python3
"""Bounded deterministic training for the single bidirectional Marian checkpoint."""

import argparse
import hashlib
import json
import math
import os
import random
import shutil
import time
from pathlib import Path, PurePosixPath


BASE_REPO = "Helsinki-NLP/opus-mt_tiny_zho-eng"
BASE_REVISION = "4ee3a9342aae4ca6fbae82c930b5dccff5dd68dd"
DATASET_REPO = "Mxode/BiST"
DATASET_REVISION = "aca6be897afc319f779009379c8b849c1eb8d63e"
DIRECTIONS = {"zh-en": 32001, "en-zh": 32002}
EOS = 0
PAD = 32000


class TrainingContractError(RuntimeError):
    pass


def _exact_keys(value, expected, label):
    if not isinstance(value, dict) or set(value) != set(expected):
        raise TrainingContractError("%s must contain exactly: %s" % (label, ", ".join(expected)))


def _int(value, label, minimum=None):
    if isinstance(value, bool) or not isinstance(value, int):
        raise TrainingContractError("%s must be an integer" % label)
    if minimum is not None and value < minimum:
        raise TrainingContractError("%s is below its minimum" % label)


def _number(value, label, minimum=None):
    if isinstance(value, bool) or not isinstance(value, (int, float)) or not math.isfinite(value):
        raise TrainingContractError("%s must be a finite number" % label)
    if minimum is not None and value < minimum:
        raise TrainingContractError("%s is below its minimum" % label)


def _portable_relative_path(value, label):
    if not isinstance(value, str) or not value or "\\" in value:
        raise TrainingContractError("%s must be a portable relative path" % label)
    path = PurePosixPath(value)
    if path.is_absolute() or ".." in path.parts or ":" in value:
        raise TrainingContractError("%s must be a portable relative path" % label)


def load_training_config(path):
    try:
        config = json.loads(Path(path).read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise TrainingContractError("cannot read training config: %s" % error) from error
    _exact_keys(
        config,
        (
            "schema_version", "seed", "dataset", "tokenizer", "directions", "quotas",
            "token_bounds", "split", "base_checkpoint", "tokens", "model", "training",
        ),
        "training config",
    )
    _int(config["schema_version"], "schema_version")
    _int(config["seed"], "seed")
    epoch_ceilings = {1: 4, 2: 8, 3: 12}
    if config["schema_version"] not in epoch_ceilings or config["seed"] != 20260713:
        raise TrainingContractError("training config version or seed is unsupported")
    _exact_keys(config["dataset"], ("repo", "revision"), "dataset")
    if config["dataset"] != {"repo": DATASET_REPO, "revision": DATASET_REVISION}:
        raise TrainingContractError("dataset pin differs from v1")
    _exact_keys(config["tokenizer"], ("repo", "revision", "file", "size", "sha256"), "tokenizer")
    _portable_relative_path(config["tokenizer"]["file"], "tokenizer file")
    if config["tokenizer"] != {
        "repo": BASE_REPO,
        "revision": BASE_REVISION,
        "file": "source.spm",
        "size": 755175,
        "sha256": "e5528a5c3685d08f8868902d31febeb763eea8519f9997f43b05964b02554640",
    }:
        raise TrainingContractError("tokenizer pin differs from v1")
    _exact_keys(config["directions"], ("zh-en", "en-zh"), "directions")
    expected_directions = {
        "zh-en": {"direction_id": 32001, "subset": "zh-en"},
        "en-zh": {"direction_id": 32002, "subset": "en-zh"},
    }
    if config["directions"] != expected_directions:
        raise TrainingContractError("direction mapping differs from v1")
    if config["quotas"] != {"train": 90000, "validation": 5000, "test": 5000}:
        raise TrainingContractError("dataset quotas differ from v1")
    if config["token_bounds"] != {"min": 3, "max": 120}:
        raise TrainingContractError("token bounds differ from v1")
    if config["split"] != {"buckets": 20, "test": [0], "validation": [1], "train": [2, 19]}:
        raise TrainingContractError("split differs from v1")
    _exact_keys(config["base_checkpoint"], ("repo", "revision"), "base checkpoint")
    if config["base_checkpoint"] != {"repo": BASE_REPO, "revision": BASE_REVISION}:
        raise TrainingContractError("base checkpoint differs from immutable pin")
    expected_tokens = {
        "eos": 0, "unk": 1, "pad": 32000, "decoder_start": 32000,
        "to_en": 32001, "to_zh": 32002,
    }
    _exact_keys(config["tokens"], expected_tokens, "tokens")
    for name, value in config["tokens"].items():
        _int(value, "token %s" % name, 0)
    if config["tokens"] != expected_tokens:
        raise TrainingContractError("token IDs differ from v1")
    expected_model = {
        "vocab_size": 32003, "max_tokens": 128, "encoder_layers": 6,
        "decoder_layers": 2, "d_model": 256, "ffn_dim": 1536,
        "attention_heads": 8, "shared_embeddings": True,
    }
    _exact_keys(config["model"], expected_model, "model")
    for name in expected_model:
        if name == "shared_embeddings":
            if not isinstance(config["model"][name], bool):
                raise TrainingContractError("shared_embeddings must be boolean")
        else:
            _int(config["model"][name], "model %s" % name, 1)
    if config["model"] != expected_model:
        raise TrainingContractError("model architecture differs from export contract")
    expected_training = {
        "precision": "fp16", "device": "cuda", "microbatch_per_direction": 32,
        "gradient_accumulation": 4, "learning_rate": 3e-5, "weight_decay": 0.01,
        "label_smoothing": 0.1, "warmup_optimizer_steps": 1000,
        "evaluate_every_optimizer_steps": 1000,
        "early_stop_non_improving_evaluations": 2,
        "max_epochs": epoch_ceilings[config["schema_version"]],
        "max_gpu_hours": 12, "embedding_init_std": 0.02,
    }
    _exact_keys(config["training"], expected_training, "training")
    if config["training"].get("precision") != "fp16" or config["training"].get("device") != "cuda":
        raise TrainingContractError("training precision/device differs from v1")
    for name, expected in expected_training.items():
        if isinstance(expected, str):
            continue
        if isinstance(expected, int):
            _int(config["training"][name], "training %s" % name, 1)
        else:
            _number(config["training"][name], "training %s" % name, 0)
    if config["training"] != expected_training:
        raise TrainingContractError("training values differ from v1")
    return config


def build_model_fields(row, direction, processor, max_tokens=128):
    if direction not in DIRECTIONS or not isinstance(row, dict) or set(row) != {
        "source", "target", "direction_id"
    }:
        raise TrainingContractError("training row/direction schema is invalid")
    if row["direction_id"] != DIRECTIONS[direction]:
        raise TrainingContractError("row direction ID does not match its file")
    if not isinstance(row["source"], str) or not isinstance(row["target"], str):
        raise TrainingContractError("training source/target must be strings")
    _int(max_tokens, "max_tokens", 2)
    source = list(processor.encode(row["source"], out_type=int))
    target = list(processor.encode(row["target"], out_type=int))
    if len(source) > max_tokens - 2 or len(target) > max_tokens - 1:
        raise TrainingContractError("encoded row exceeds the fixed maximum")
    input_ids = [DIRECTIONS[direction]] + source + [EOS]
    attention_mask = [1] * len(input_ids)
    labels = target + [EOS]
    input_ids += [PAD] * (max_tokens - len(input_ids))
    attention_mask += [0] * (max_tokens - len(attention_mask))
    labels += [-100] * (max_tokens - len(labels))
    return {"input_ids": input_ids, "attention_mask": attention_mask, "labels": labels}


def alternating_batch_plan(lengths, batch_size, seed, epoch):
    if not isinstance(lengths, dict) or set(lengths) != set(DIRECTIONS):
        raise TrainingContractError("batch lengths must contain both directions")
    for name, value in (("batch_size", batch_size), ("seed", seed), ("epoch", epoch)):
        _int(value, name, 0 if name != "batch_size" else 1)
    if lengths["zh-en"] != lengths["en-zh"]:
        raise TrainingContractError("1:1 alternation requires equal direction counts")
    batches = {}
    for offset, direction in enumerate(DIRECTIONS):
        indices = list(range(lengths[direction]))
        random.Random(seed + epoch * 2 + offset).shuffle(indices)
        batches[direction] = [indices[index:index + batch_size] for index in range(0, len(indices), batch_size)]
    plan = []
    for index in range(len(batches["zh-en"])):
        plan.append(("zh-en", batches["zh-en"][index]))
        plan.append(("en-zh", batches["en-zh"][index]))
    return plan


def run_logical_batches(plan, gradient_accumulation, physical_microbatch, train_subbatch, optimizer_step):
    _int(gradient_accumulation, "gradient_accumulation", 1)
    _int(physical_microbatch, "physical_microbatch", 1)
    optimizer_steps = 0
    for logical_index, (direction, indices) in enumerate(plan, 1):
        if direction not in DIRECTIONS or not indices:
            raise TrainingContractError("logical batch is invalid")
        subdivisions = math.ceil(len(indices) / physical_microbatch)
        scale = 1.0 / (gradient_accumulation * subdivisions)
        for start in range(0, len(indices), physical_microbatch):
            loss = train_subbatch(direction, indices[start:start + physical_microbatch], scale)
            if isinstance(loss, bool) or not isinstance(loss, (int, float)) or not math.isfinite(loss):
                raise TrainingContractError("training produced a non-finite loss")
        if logical_index % gradient_accumulation == 0:
            optimizer_step()
            optimizer_steps += 1
    if len(plan) % gradient_accumulation:
        raise TrainingContractError("logical batch plan ends mid accumulation window")
    return {"logical_batches": len(plan), "optimizer_steps": optimizer_steps}


class BestCheckpointTracker:
    def __init__(self, patience, save):
        _int(patience, "patience", 1)
        self.patience = patience
        self.save = save
        self.best_loss = None
        self.best_step = None
        self.non_improving = 0

    def observe(self, step, loss):
        _int(step, "validation step", 1)
        _number(loss, "validation loss", 0)
        if self.best_loss is None or loss < self.best_loss:
            self.best_loss = float(loss)
            self.best_step = step
            self.non_improving = 0
            self.save(step, float(loss))
        else:
            self.non_improving += 1
        return self.non_improving >= self.patience


def stop_reason(elapsed_gpu_hours, completed_epochs, early_stop, max_gpu_hours=12, max_epochs=4):
    _number(elapsed_gpu_hours, "elapsed_gpu_hours", 0)
    _int(completed_epochs, "completed_epochs", 0)
    if elapsed_gpu_hours >= max_gpu_hours:
        return "gpu_time_limit"
    if completed_epochs >= max_epochs:
        return "epoch_limit"
    if early_stop:
        return "early_stop"
    return None


def expand_shared_embeddings(model, old_vocab=32001, final_vocab=32003, seed=20260713, std=0.02):
    try:
        import torch
    except ImportError as error:
        raise TrainingContractError("embedding expansion requires torch") from error
    _int(old_vocab, "old_vocab", 1)
    _int(final_vocab, "final_vocab", old_vocab + 1)
    _int(seed, "embedding seed", 0)
    _number(std, "embedding std", 0)
    old = model.get_input_embeddings().weight.detach().clone()
    if old.shape[0] != old_vocab:
        raise TrainingContractError("base embedding vocabulary is not %d" % old_vocab)
    input_embedding = model.get_input_embeddings()
    if all(
        hasattr(model, name)
        for name in ("set_input_embeddings", "set_output_embeddings", "get_output_embeddings")
    ):
        replacement = torch.nn.Embedding(
            final_vocab,
            old.shape[1],
            padding_idx=getattr(input_embedding, "padding_idx", None),
            device=old.device,
            dtype=old.dtype,
        )
        output = torch.nn.Linear(
            old.shape[1], final_vocab, bias=False, device=old.device, dtype=old.dtype
        )
        model.set_input_embeddings(replacement)
        model.set_output_embeddings(output)
        if hasattr(model, "_resize_final_logits_bias"):
            model._resize_final_logits_bias(final_vocab)
        elif hasattr(model, "final_logits_bias"):
            extra = model.final_logits_bias.new_zeros(
                (1, final_vocab - model.final_logits_bias.shape[-1])
            )
            model.register_buffer(
                "final_logits_bias", torch.cat([model.final_logits_bias, extra], dim=-1)
            )
        if hasattr(model, "config"):
            model.config.vocab_size = final_vocab
            model.config.decoder_vocab_size = final_vocab
    else:
        model.resize_token_embeddings(final_vocab)
    weight = model.get_input_embeddings().weight
    with torch.no_grad():
        weight[:old_vocab].copy_(old)
        generator = torch.Generator(device=weight.device).manual_seed(seed)
        added = torch.empty(
            (final_vocab - old_vocab, weight.shape[1]), dtype=weight.dtype, device=weight.device
        )
        added.normal_(mean=0.0, std=std, generator=generator)
        weight[old_vocab:].copy_(added)
    model.tie_weights()
    if model.get_input_embeddings().weight is not model.get_output_embeddings().weight:
        raise TrainingContractError("input and output embeddings are not tied")
    return model


def _sha256_file(path):
    digest = hashlib.sha256()
    size = 0
    with Path(path).open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
            size += len(chunk)
    return size, digest.hexdigest()


def verify_dataset_inputs(root, manifest):
    root = Path(root).resolve()
    expected_names = {
        "%s.%s.jsonl" % (direction, split)
        for direction in DIRECTIONS for split in ("train", "validation", "test")
    }
    outputs = manifest.get("outputs") if isinstance(manifest, dict) else None
    if not isinstance(outputs, dict) or set(outputs) != expected_names:
        raise TrainingContractError("dataset manifest must contain exactly six outputs")
    verified = []
    for name in sorted(outputs):
        artifact = outputs[name]
        if not isinstance(artifact, dict) or set(artifact) != {"path", "count", "bytes", "sha256"}:
            raise TrainingContractError("dataset artifact schema is invalid")
        _portable_relative_path(artifact["path"], "dataset artifact path")
        if artifact["path"] != name:
            raise TrainingContractError("dataset artifact name/path differs")
        path = (root / artifact["path"]).resolve()
        try:
            path.relative_to(root)
        except ValueError as error:
            raise TrainingContractError("dataset artifact leaves its root") from error
        _int(artifact["count"], "dataset artifact count", 1)
        _int(artifact["bytes"], "dataset artifact bytes", 1)
        size, digest = _sha256_file(path)
        if size != artifact["bytes"] or digest != artifact["sha256"]:
            raise TrainingContractError("dataset artifact integrity failure: %s" % name)
        verified.append(path)
    return verified


def canonical_json_bytes(value):
    return (json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":")) + "\n").encode("utf-8")


def build_checkpoint_manifest(root, files, optimizer_steps, validation_loss, stop):
    root = Path(root).resolve()
    _int(optimizer_steps, "optimizer_steps", 1)
    _number(validation_loss, "validation_loss", 0)
    if stop not in {"gpu_time_limit", "epoch_limit", "early_stop", "quality_blocked"}:
        raise TrainingContractError("checkpoint stop reason is invalid")
    artifacts = []
    for item in sorted((Path(value).resolve() for value in files), key=str):
        try:
            relative = item.relative_to(root).as_posix()
        except ValueError as error:
            raise TrainingContractError("checkpoint file is outside checkpoint root") from error
        _portable_relative_path(relative, "checkpoint file")
        size, digest = _sha256_file(item)
        artifacts.append({"path": relative, "bytes": size, "sha256": digest})
    return {
        "schema_version": 1,
        "base_checkpoint": {"repo": BASE_REPO, "revision": BASE_REVISION},
        "vocab_size": 32003,
        "optimizer_steps": optimizer_steps,
        "validation_loss": float(validation_loss),
        "stop_reason": stop,
        "files": artifacts,
    }


def _quality_number(value):
    return not isinstance(value, bool) and isinstance(value, (int, float)) and math.isfinite(value)


def validate_quality_result(result):
    try:
        if not isinstance(result, dict) or set(result) != {"flores", "manual"}:
            return False
        thresholds = {"zh-en": (19.0, 49.0), "en-zh": (17.0, 40.0)}
        if set(result["flores"]) != set(thresholds) or set(result["manual"]) != set(thresholds):
            return False
        for direction, (bleu, chrf2) in thresholds.items():
            metrics = result["flores"][direction]
            manual = result["manual"][direction]
            if set(metrics) != {"bleu", "chrf2"} or set(manual) != {
                "passed", "total", "fatal_corruptions"
            }:
                return False
            if not all(_quality_number(metrics[name]) for name in metrics):
                return False
            if metrics["bleu"] < bleu or metrics["chrf2"] < chrf2:
                return False
            for name in manual:
                if isinstance(manual[name], bool) or not isinstance(manual[name], int):
                    return False
            if manual != {"passed": manual["passed"], "total": 50, "fatal_corruptions": 0}:
                return False
            if manual["passed"] < 45:
                return False
        return True
    except (KeyError, TypeError):
        return False


def smoke_loss_gate(losses):
    if (
        not isinstance(losses, list)
        or len(losses) != 20
        or any(not _quality_number(value) for value in losses)
    ):
        return {"passed": False, "initial_window_loss": None, "final_window_loss": None}
    initial = sum(losses[:5]) / 5
    final = sum(losses[-5:]) / 5
    return {
        "passed": final < initial * 0.98,
        "initial_window_loss": initial,
        "final_window_loss": final,
    }


def final_validation_required(history, optimizer_steps):
    return not history or history[-1].get("optimizer_step") != optimizer_steps


def _load_json(path):
    try:
        return json.loads(Path(path).read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise TrainingContractError("cannot read JSON %s: %s" % (Path(path).name, error)) from error


def _read_rows(path, direction, limit=None, expected_count=None):
    if direction not in DIRECTIONS:
        raise TrainingContractError("unsupported direction")
    rows = []
    count = 0
    try:
        with Path(path).open("r", encoding="utf-8", newline="") as stream:
            for line_number, line in enumerate(stream, 1):
                if "\r" in line or not line.endswith("\n"):
                    raise TrainingContractError("dataset JSONL is not canonical LF at line %d" % line_number)
                try:
                    row = json.loads(line)
                except json.JSONDecodeError as error:
                    raise TrainingContractError("invalid dataset JSONL at line %d" % line_number) from error
                if not isinstance(row, dict) or set(row) != {"source", "target", "direction_id"}:
                    raise TrainingContractError("dataset row schema differs at line %d" % line_number)
                if row["direction_id"] != DIRECTIONS[direction]:
                    raise TrainingContractError("dataset direction differs at line %d" % line_number)
                if not isinstance(row["source"], str) or not isinstance(row["target"], str):
                    raise TrainingContractError("dataset text fields are not strings")
                count += 1
                if limit is None or len(rows) < limit:
                    rows.append(row)
    except OSError as error:
        raise TrainingContractError("cannot read dataset JSONL: %s" % error) from error
    if expected_count is not None and count != expected_count:
        raise TrainingContractError("dataset line count differs from manifest")
    if limit is not None and len(rows) != limit:
        raise TrainingContractError("dataset does not contain the requested deterministic prefix")
    return rows


def _outside_repository(path, label):
    repository = Path(__file__).resolve().parents[2]
    resolved = Path(path).resolve()
    if resolved == repository or repository in resolved.parents:
        raise TrainingContractError("%s must be outside the repository" % label)
    return resolved


def _verified_file_inventory(paths, root):
    root = Path(root).resolve()
    inventory = []
    for path in paths:
        item = Path(path).resolve()
        try:
            relative = item.relative_to(root).as_posix()
        except ValueError as error:
            raise TrainingContractError("inventory file is outside its root") from error
        size, digest = _sha256_file(item)
        inventory.append({"path": relative, "bytes": size, "sha256": digest})
    return sorted(inventory, key=lambda value: value["path"])


def _set_determinism(torch, seed):
    os.environ.setdefault("CUBLAS_WORKSPACE_CONFIG", ":4096:8")
    random.seed(seed)
    torch.manual_seed(seed)
    torch.cuda.manual_seed_all(seed)
    torch.use_deterministic_algorithms(True)
    torch.backends.cudnn.benchmark = False


def _load_runtime(config, base_model_dir, tokenizer_model):
    try:
        import sentencepiece
        import torch
        from transformers import MarianMTModel
    except ImportError as error:
        raise TrainingContractError("real training requires the pinned T3 dependencies") from error
    if not torch.cuda.is_available():
        raise TrainingContractError("the pinned CUDA runtime is unavailable")
    base_model_dir = Path(base_model_dir).resolve()
    tokenizer_model = Path(tokenizer_model).resolve()
    base_files = [base_model_dir / "config.json", base_model_dir / "model.safetensors"]
    for path in base_files:
        if not path.is_file():
            raise TrainingContractError("pinned base model file is missing: %s" % path.name)
    expected_tokenizer = config["tokenizer"]
    size, digest = _sha256_file(tokenizer_model)
    if size != expected_tokenizer["size"] or digest != expected_tokenizer["sha256"]:
        raise TrainingContractError("pinned SentencePiece model integrity failure")
    processor = sentencepiece.SentencePieceProcessor(model_file=str(tokenizer_model))
    if processor.get_piece_size() != 32000:
        raise TrainingContractError("SentencePiece vocabulary differs from the pinned 32000-piece model")
    model = MarianMTModel.from_pretrained(
        str(base_model_dir), local_files_only=True, torch_dtype=torch.float32
    )
    architecture = config["model"]
    checks = {
        "vocab_size": model.config.vocab_size,
        "max_tokens": 128,
        "encoder_layers": model.config.encoder_layers,
        "decoder_layers": model.config.decoder_layers,
        "d_model": model.config.d_model,
        "ffn_dim": model.config.encoder_ffn_dim,
        "attention_heads": model.config.encoder_attention_heads,
        "shared_embeddings": model.config.share_encoder_decoder_embeddings,
    }
    if checks != {**architecture, "vocab_size": 32001}:
        raise TrainingContractError("base model architecture differs from the approved export contract")
    expand_shared_embeddings(
        model,
        old_vocab=32001,
        final_vocab=architecture["vocab_size"],
        seed=config["seed"],
        std=config["training"]["embedding_init_std"],
    )
    model.config.decoder_vocab_size = architecture["vocab_size"]
    model.config.max_length = architecture["max_tokens"]
    model.config.forced_eos_token_id = EOS
    model.config.use_cache = False
    return torch, model, processor, _verified_file_inventory(base_files, base_model_dir)


def _encode_rows(rows, direction, processor, max_tokens):
    return [build_model_fields(row, direction, processor, max_tokens=max_tokens) for row in rows]


def _batch_tensors(torch, encoded, indices, device):
    return {
        name: torch.tensor([encoded[index][name] for index in indices], dtype=torch.long, device=device)
        for name in ("input_ids", "attention_mask", "labels")
    }


def decoder_input_ids(labels, decoder_start=PAD, pad=PAD):
    if hasattr(labels, "new_full"):
        shifted = labels.new_full(labels.shape, pad)
        shifted[:, 0] = decoder_start
        shifted[:, 1:] = labels[:, :-1]
        shifted.masked_fill_(shifted == -100, pad)
        return shifted
    if not isinstance(labels, list) or any(not isinstance(row, list) or not row for row in labels):
        raise TrainingContractError("decoder labels must be a non-empty rectangular matrix")
    width = len(labels[0])
    if any(len(row) != width for row in labels):
        raise TrainingContractError("decoder labels must be rectangular")
    return [
        [decoder_start] + [pad if value == -100 else value for value in row[:-1]]
        for row in labels
    ]


def _forward_loss(torch, model, batch, label_smoothing):
    import torch.nn.functional as functional

    with torch.amp.autocast(device_type="cuda", dtype=torch.float16):
        output = model(
            input_ids=batch["input_ids"],
            attention_mask=batch["attention_mask"],
            decoder_input_ids=decoder_input_ids(batch["labels"]),
            labels=None,
            use_cache=False,
            return_dict=True,
        )
        logits = output.logits
        loss = functional.cross_entropy(
            logits.float().reshape(-1, logits.shape[-1]),
            batch["labels"].reshape(-1),
            ignore_index=-100,
            label_smoothing=label_smoothing,
        )
    if not torch.isfinite(loss).item() or not torch.isfinite(logits).all().item():
        raise TrainingContractError("training produced non-finite loss/logits")
    return loss, logits


def run_overfit_smoke(
    config,
    dataset_root,
    dataset_manifest,
    base_model_dir,
    tokenizer_model,
    artifact_root,
    physical_microbatch,
):
    dataset_root = Path(dataset_root).resolve()
    artifact_root = _outside_repository(artifact_root, "training artifact root")
    artifact_root.mkdir(parents=True, exist_ok=True)
    verified = verify_dataset_inputs(dataset_root, dataset_manifest)
    del verified
    torch, model, processor, base_inventory = _load_runtime(
        config, base_model_dir, tokenizer_model
    )
    _set_determinism(torch, config["seed"])
    training = config["training"]
    logical_batch = training["microbatch_per_direction"]
    _int(physical_microbatch, "physical_microbatch", 1)
    if logical_batch % physical_microbatch:
        raise TrainingContractError("physical subdivision must divide logical batch 32")
    encoded = {}
    for direction in DIRECTIONS:
        name = "%s.train.jsonl" % direction
        artifact = dataset_manifest["outputs"][name]
        rows = _read_rows(
            dataset_root / artifact["path"],
            direction,
            limit=64,
            expected_count=artifact["count"],
        )
        encoded[direction] = _encode_rows(rows, direction, processor, config["model"]["max_tokens"])
    device = torch.device("cuda")
    model.to(device)
    model.train()
    model.gradient_checkpointing_enable()
    optimizer = torch.optim.AdamW(
        model.parameters(),
        lr=training["learning_rate"],
        weight_decay=training["weight_decay"],
    )
    scaler = torch.amp.GradScaler("cuda")
    torch.cuda.reset_peak_memory_stats()
    started = time.monotonic()
    losses = []
    directions_finite = {direction: False for direction in DIRECTIONS}
    for optimizer_step in range(20):
        plan = alternating_batch_plan(
            {"zh-en": 64, "en-zh": 64},
            logical_batch,
            config["seed"],
            optimizer_step,
        )
        optimizer.zero_grad(set_to_none=True)
        logical_losses = []
        for direction, indices in plan:
            weighted_loss = 0.0
            for start in range(0, len(indices), physical_microbatch):
                sub_indices = indices[start:start + physical_microbatch]
                batch = _batch_tensors(torch, encoded[direction], sub_indices, device)
                loss, logits = _forward_loss(torch, model, batch, training["label_smoothing"])
                directions_finite[direction] = directions_finite[direction] or bool(
                    torch.isfinite(logits).all().item()
                )
                weight = len(sub_indices) / len(indices)
                scaler.scale(loss * weight / training["gradient_accumulation"]).backward()
                weighted_loss += float(loss.detach().item()) * weight
            logical_losses.append(weighted_loss)
        scaler.unscale_(optimizer)
        torch.nn.utils.clip_grad_norm_(model.parameters(), 1.0)
        scaler.step(optimizer)
        scaler.update()
        losses.append(sum(logical_losses) / len(logical_losses))
        print(
            json.dumps(
                {"smoke_optimizer_step": optimizer_step + 1, "loss": losses[-1]},
                sort_keys=True,
            ),
            flush=True,
        )
    gate = smoke_loss_gate(losses)
    gate["directions_finite"] = directions_finite
    gate["passed"] = gate["passed"] and all(directions_finite.values())
    report = {
        "schema_version": 1,
        "seed": config["seed"],
        "examples_per_direction": 64,
        "logical_microbatch": logical_batch,
        "physical_microbatch": physical_microbatch,
        "gradient_accumulation": training["gradient_accumulation"],
        "optimizer_steps": 20,
        "losses": losses,
        "gate": gate,
        "elapsed_seconds": round(time.monotonic() - started, 3),
        "peak_cuda_bytes": torch.cuda.max_memory_allocated(),
        "gpu": {
            "name": torch.cuda.get_device_name(0),
            "total_memory_bytes": torch.cuda.get_device_properties(0).total_memory,
            "torch": torch.__version__,
            "cuda": torch.version.cuda,
        },
        "base_files": base_inventory,
        "dataset_manifest_sha256": _sha256_file(
            Path(__file__).parent / "manifests" / "bist-v1.json"
        )[1],
    }
    report_path = artifact_root / "smoke-v1.json"
    report_path.write_bytes(canonical_json_bytes(report))
    if not report["gate"]["passed"]:
        raise TrainingContractError("20-step smoke quality gate failed; report preserved at %s" % report_path)
    return report


class MemmapRows:
    def __init__(self, root):
        try:
            import numpy
        except ImportError as error:
            raise TrainingContractError("token cache requires pinned numpy") from error
        self.root = Path(root)
        self.input_ids = numpy.load(self.root / "input_ids.npy", mmap_mode="r")
        self.attention_mask = numpy.load(self.root / "attention_mask.npy", mmap_mode="r")
        self.labels = numpy.load(self.root / "labels.npy", mmap_mode="r")
        if not (
            self.input_ids.shape == self.attention_mask.shape == self.labels.shape
            and self.input_ids.dtype == self.attention_mask.dtype == self.labels.dtype == numpy.int32
        ):
            raise TrainingContractError("token cache tensor contract differs")

    def __len__(self):
        return self.input_ids.shape[0]


def _token_cache_metadata(source_artifact, tokenizer_config, direction, split, count, max_tokens):
    return {
        "schema_version": 1,
        "source": {
            "path": source_artifact["path"],
            "bytes": source_artifact["bytes"],
            "sha256": source_artifact["sha256"],
        },
        "tokenizer": {
            "bytes": tokenizer_config["size"],
            "sha256": tokenizer_config["sha256"],
        },
        "direction": direction,
        "split": split,
        "count": count,
        "max_tokens": max_tokens,
        "dtype": "int32",
        "fields": ["input_ids", "attention_mask", "labels"],
    }


def build_token_cache(
    cache_root,
    source_path,
    source_artifact,
    tokenizer_config,
    processor,
    direction,
    split,
    max_tokens,
):
    try:
        import numpy
    except ImportError as error:
        raise TrainingContractError("token cache requires pinned numpy") from error
    cache_root = _outside_repository(cache_root, "token cache root")
    destination = cache_root / ("%s.%s" % (direction, split))
    expected = _token_cache_metadata(
        source_artifact,
        tokenizer_config,
        direction,
        split,
        source_artifact["count"],
        max_tokens,
    )
    metadata_path = destination / "manifest.json"
    if metadata_path.is_file():
        existing = _load_json(metadata_path)
        if existing == expected:
            cached = MemmapRows(destination)
            if len(cached) == source_artifact["count"] and cached.input_ids.shape[1] == max_tokens:
                return cached
        if destination.parent != cache_root:
            raise TrainingContractError("unsafe token cache replacement")
        shutil.rmtree(destination)
    destination.mkdir(parents=True, exist_ok=True)
    count = source_artifact["count"]
    arrays = {
        name: numpy.lib.format.open_memmap(
            destination / (name + ".npy"), mode="w+", dtype=numpy.int32, shape=(count, max_tokens)
        )
        for name in ("input_ids", "attention_mask", "labels")
    }
    row_index = 0
    try:
        with Path(source_path).open("r", encoding="utf-8", newline="") as stream:
            for line_number, line in enumerate(stream, 1):
                if "\r" in line or not line.endswith("\n"):
                    raise TrainingContractError("dataset JSONL is not canonical LF at line %d" % line_number)
                try:
                    row = json.loads(line)
                except json.JSONDecodeError as error:
                    raise TrainingContractError("invalid dataset JSONL at line %d" % line_number) from error
                fields = build_model_fields(row, direction, processor, max_tokens=max_tokens)
                if row_index >= count:
                    raise TrainingContractError("dataset contains more rows than its manifest")
                for name, array in arrays.items():
                    array[row_index] = fields[name]
                row_index += 1
    except Exception:
        for array in arrays.values():
            del array
        if destination.parent == cache_root:
            shutil.rmtree(destination, ignore_errors=True)
        raise
    if row_index != count:
        raise TrainingContractError("dataset contains fewer rows than its manifest")
    for array in arrays.values():
        array.flush()
    metadata_path.write_bytes(canonical_json_bytes(expected))
    return MemmapRows(destination)


def _memmap_batch(torch, rows, indices, device):
    import numpy

    index_array = numpy.asarray(indices, dtype=numpy.int64)
    return {
        name: torch.from_numpy(numpy.asarray(getattr(rows, name)[index_array]).copy()).to(
            device=device, dtype=torch.long, non_blocking=True
        )
        for name in ("input_ids", "attention_mask", "labels")
    }


def _evaluate_validation(torch, model, validation, physical_microbatch, label_smoothing):
    model.eval()
    total_loss = 0.0
    total_examples = 0
    device = next(model.parameters()).device
    with torch.no_grad():
        for direction in DIRECTIONS:
            rows = validation[direction]
            for start in range(0, len(rows), physical_microbatch):
                indices = list(range(start, min(start + physical_microbatch, len(rows))))
                batch = _memmap_batch(torch, rows, indices, device)
                loss, unused_logits = _forward_loss(torch, model, batch, label_smoothing)
                del unused_logits
                total_loss += float(loss.item()) * len(indices)
                total_examples += len(indices)
    model.train()
    if not total_examples:
        raise TrainingContractError("validation set is empty")
    return total_loss / total_examples


def _save_selected_checkpoint(model, tokenizer_model, selected_root, step, validation_loss):
    selected_root = Path(selected_root).resolve()
    if selected_root.exists():
        if selected_root.name != "selected" or selected_root.parent == selected_root:
            raise TrainingContractError("unsafe selected checkpoint replacement")
        shutil.rmtree(selected_root)
    selected_root.mkdir(parents=True)
    model.save_pretrained(selected_root, safe_serialization=True, max_shard_size="1GB")
    shutil.copyfile(tokenizer_model, selected_root / "tokenizer.model")
    (selected_root / "base_revision.txt").write_bytes((BASE_REVISION + "\n").encode("ascii"))
    metadata = {
        "schema_version": 1,
        "optimizer_step": step,
        "validation_loss": validation_loss,
        "vocab_size": 32003,
        "optimizer_independent": True,
    }
    (selected_root / "selection.json").write_bytes(canonical_json_bytes(metadata))


def _save_resume_state(torch, path, model, optimizer, scaler, step, epoch, plan_index, elapsed_seconds):
    state = {
        "schema_version": 1,
        "model": model.state_dict(),
        "optimizer": optimizer.state_dict(),
        "scaler": scaler.state_dict(),
        "optimizer_step": step,
        "epoch": epoch,
        "plan_index": plan_index,
        "elapsed_seconds": elapsed_seconds,
        "python_random_state": random.getstate(),
        "torch_random_state": torch.get_rng_state(),
        "cuda_random_state": torch.cuda.get_rng_state_all(),
    }
    temporary = Path(str(path) + ".partial")
    torch.save(state, temporary)
    os.replace(temporary, path)


def validate_resume_state(state, max_epochs=4):
    expected = {
        "schema_version", "model", "optimizer", "scaler", "optimizer_step", "epoch",
        "plan_index", "elapsed_seconds", "python_random_state", "torch_random_state",
        "cuda_random_state",
    }
    if not isinstance(state, dict) or set(state) != expected or state.get("schema_version") != 1:
        raise TrainingContractError("resume state schema differs from v1")
    for name in ("optimizer_step", "epoch", "plan_index"):
        _int(state[name], "resume %s" % name, 0)
    _int(max_epochs, "resume max_epochs", 1)
    _number(state["elapsed_seconds"], "resume elapsed_seconds", 0)
    logical_batches_per_epoch = 2 * math.ceil(90000 / 32)
    global_logical_batches = state["epoch"] * logical_batches_per_epoch + state["plan_index"]
    if (
        state["optimizer_step"] < 1
        or state["epoch"] >= max_epochs
        or state["plan_index"] > logical_batches_per_epoch
        or global_logical_batches != state["optimizer_step"] * 4
    ):
        raise TrainingContractError("resume cursor is not an optimizer boundary")
    return (
        state["optimizer_step"],
        state["epoch"],
        state["plan_index"],
        float(state["elapsed_seconds"]),
    )


def restore_resume_state(torch, state, model, optimizer, scaler, max_epochs=4):
    cursor = validate_resume_state(state, max_epochs=max_epochs)
    model.load_state_dict(state["model"], strict=True)
    optimizer.load_state_dict(state["optimizer"])
    scaler.load_state_dict(state["scaler"])
    random.setstate(state["python_random_state"])
    torch.set_rng_state(state["torch_random_state"])
    torch.cuda.set_rng_state_all(state["cuda_random_state"])
    return cursor


def resume_elapsed_floor(state_elapsed, previous_report):
    _number(state_elapsed, "resume elapsed_seconds", 0)
    if not isinstance(previous_report, dict) or "elapsed_seconds" not in previous_report:
        raise TrainingContractError("previous training report lacks elapsed_seconds")
    _number(previous_report["elapsed_seconds"], "previous elapsed_seconds", 0)
    return max(float(state_elapsed), float(previous_report["elapsed_seconds"]))


def should_save_periodic_resume(optimizer_step):
    _int(optimizer_step, "optimizer step", 1)
    return optimizer_step % 500 == 0


def run_full_training(
    config,
    dataset_root,
    dataset_manifest,
    base_model_dir,
    tokenizer_model,
    artifact_root,
    physical_microbatch,
    resume=False,
):
    dataset_root = Path(dataset_root).resolve()
    artifact_root = _outside_repository(artifact_root, "training artifact root")
    artifact_root.mkdir(parents=True, exist_ok=True)
    verify_dataset_inputs(dataset_root, dataset_manifest)
    torch, model, processor, base_inventory = _load_runtime(config, base_model_dir, tokenizer_model)
    _set_determinism(torch, config["seed"])
    training = config["training"]
    logical_batch = training["microbatch_per_direction"]
    _int(physical_microbatch, "physical_microbatch", 1)
    if logical_batch % physical_microbatch:
        raise TrainingContractError("physical subdivision must divide logical batch 32")
    cache_root = artifact_root / "token-cache"
    datasets = {split: {} for split in ("train", "validation")}
    cache_started = time.monotonic()
    for split in datasets:
        for direction in DIRECTIONS:
            name = "%s.%s.jsonl" % (direction, split)
            artifact = dataset_manifest["outputs"][name]
            datasets[split][direction] = build_token_cache(
                cache_root,
                dataset_root / artifact["path"],
                artifact,
                config["tokenizer"],
                processor,
                direction,
                split,
                config["model"]["max_tokens"],
            )
    cache_seconds = time.monotonic() - cache_started
    if {direction: len(rows) for direction, rows in datasets["train"].items()} != {
        "zh-en": 90000,
        "en-zh": 90000,
    }:
        raise TrainingContractError("training cache counts differ from approved quotas")
    device = torch.device("cuda")
    model.to(device)
    model.train()
    model.gradient_checkpointing_enable()
    optimizer = torch.optim.AdamW(
        model.parameters(), lr=training["learning_rate"], weight_decay=training["weight_decay"]
    )
    scaler = torch.amp.GradScaler("cuda")

    def learning_rate_scale(step):
        return min(1.0, step / training["warmup_optimizer_steps"])

    selected_root = artifact_root / "selected"
    validation_history = []

    def save_best(step, loss):
        _save_selected_checkpoint(model, tokenizer_model, selected_root, step, loss)

    tracker = BestCheckpointTracker(
        training["early_stop_non_improving_evaluations"], save_best
    )
    optimizer_steps = 0
    logical_steps = 0
    start_epoch = 0
    start_plan_index = 0
    previous_elapsed = 0.0
    resume_path = artifact_root / "resume.pt"
    if resume:
        if not resume_path.is_file():
            raise TrainingContractError("--resume requested but resume.pt is missing")
        state = torch.load(resume_path, map_location="cpu", weights_only=False)
        optimizer_steps, start_epoch, start_plan_index, previous_elapsed = restore_resume_state(
            torch,
            state,
            model,
            optimizer,
            scaler,
            max_epochs=training["max_epochs"],
        )
        previous_report_path = artifact_root / "training-v1.json"
        if previous_report_path.is_file():
            previous_elapsed = resume_elapsed_floor(
                previous_elapsed, _load_json(previous_report_path)
            )
        logical_steps = optimizer_steps * training["gradient_accumulation"]
        history_path = artifact_root / "validation-history.json"
        if history_path.is_file():
            validation_history = _load_json(history_path)
            if not isinstance(validation_history, list):
                raise TrainingContractError("resume validation history is invalid")
            for item in validation_history:
                if not isinstance(item, dict) or set(item) != {"optimizer_step", "loss"}:
                    raise TrainingContractError("resume validation history entry is invalid")
                _int(item["optimizer_step"], "validation optimizer_step", 1)
                _number(item["loss"], "validation loss", 0)
            if validation_history:
                best = min(validation_history, key=lambda item: item["loss"])
                tracker.best_step = best["optimizer_step"]
                tracker.best_loss = float(best["loss"])
                best_index = validation_history.index(best)
                tracker.non_improving = len(validation_history) - best_index - 1
    started = time.monotonic() - previous_elapsed
    budget_seconds = training["max_gpu_hours"] * 3600
    torch.cuda.reset_peak_memory_stats()
    stop = None
    last_progress = None
    for epoch in range(start_epoch, training["max_epochs"]):
        plan = alternating_batch_plan(
            {direction: len(datasets["train"][direction]) for direction in DIRECTIONS},
            logical_batch,
            config["seed"],
            epoch,
        )
        for plan_index, (direction, indices) in enumerate(plan):
            if epoch == start_epoch and plan_index < start_plan_index:
                continue
            if logical_steps % training["gradient_accumulation"] == 0:
                optimizer.zero_grad(set_to_none=True)
            logical_loss = 0.0
            for start in range(0, len(indices), physical_microbatch):
                sub_indices = indices[start:start + physical_microbatch]
                batch = _memmap_batch(torch, datasets["train"][direction], sub_indices, device)
                loss, unused_logits = _forward_loss(
                    torch, model, batch, training["label_smoothing"]
                )
                del unused_logits
                weight = len(sub_indices) / len(indices)
                scaler.scale(loss * weight / training["gradient_accumulation"]).backward()
                logical_loss += float(loss.detach().item()) * weight
            logical_steps += 1
            if logical_steps % training["gradient_accumulation"]:
                continue
            optimizer_steps += 1
            for group in optimizer.param_groups:
                group["lr"] = training["learning_rate"] * learning_rate_scale(optimizer_steps)
            scaler.unscale_(optimizer)
            torch.nn.utils.clip_grad_norm_(model.parameters(), 1.0)
            scaler.step(optimizer)
            scaler.update()
            elapsed = time.monotonic() - started
            last_progress = {
                "schema_version": 1,
                "optimizer_step": optimizer_steps,
                "completed_epochs": epoch,
                "next_plan_index": plan_index + 1,
                "last_logical_loss": logical_loss,
                "learning_rate": optimizer.param_groups[0]["lr"],
                "elapsed_seconds": round(elapsed, 3),
                "peak_cuda_bytes": torch.cuda.max_memory_allocated(),
            }
            if optimizer_steps % 20 == 0:
                (artifact_root / "training-progress.json").write_bytes(
                    canonical_json_bytes(last_progress)
                )
                print(json.dumps(last_progress, sort_keys=True), flush=True)
            if should_save_periodic_resume(optimizer_steps):
                _save_resume_state(
                    torch,
                    artifact_root / "resume.pt",
                    model,
                    optimizer,
                    scaler,
                    optimizer_steps,
                    epoch,
                    plan_index + 1,
                    elapsed,
                )
            if optimizer_steps % training["evaluate_every_optimizer_steps"] == 0:
                validation_loss = _evaluate_validation(
                    torch,
                    model,
                    datasets["validation"],
                    physical_microbatch,
                    training["label_smoothing"],
                )
                validation_history.append(
                    {"optimizer_step": optimizer_steps, "loss": validation_loss}
                )
                (artifact_root / "validation-history.json").write_bytes(
                    canonical_json_bytes(validation_history)
                )
                if tracker.observe(optimizer_steps, validation_loss):
                    stop = "early_stop"
            if elapsed >= budget_seconds:
                stop = "gpu_time_limit"
            if stop:
                break
        if stop:
            break
    if stop is None:
        stop = "epoch_limit"
    if logical_steps % training["gradient_accumulation"]:
        optimizer.zero_grad(set_to_none=True)
    elapsed = time.monotonic() - started
    if final_validation_required(validation_history, optimizer_steps):
        validation_loss = _evaluate_validation(
            torch,
            model,
            datasets["validation"],
            physical_microbatch,
            training["label_smoothing"],
        )
        validation_history.append({"optimizer_step": optimizer_steps, "loss": validation_loss})
        (artifact_root / "validation-history.json").write_bytes(
            canonical_json_bytes(validation_history)
        )
        tracker.observe(optimizer_steps, validation_loss)
    elapsed = time.monotonic() - started
    if optimizer_steps:
        _save_resume_state(
            torch,
            resume_path,
            model,
            optimizer,
            scaler,
            optimizer_steps,
            epoch,
            plan_index + 1,
            elapsed,
        )
    checkpoint_files = [path for path in selected_root.rglob("*") if path.is_file()]
    checkpoint_manifest = build_checkpoint_manifest(
        selected_root,
        checkpoint_files,
        tracker.best_step,
        tracker.best_loss,
        stop,
    )
    (artifact_root / "checkpoint-manifest.json").write_bytes(
        canonical_json_bytes(checkpoint_manifest)
    )
    report = {
        "schema_version": 1,
        "seed": config["seed"],
        "optimizer_steps": optimizer_steps,
        "logical_batches": logical_steps,
        "completed_epochs": logical_steps / (2 * math.ceil(90000 / logical_batch)),
        "stop_reason": stop,
        "elapsed_seconds": round(elapsed, 3),
        "cache_build_seconds": round(cache_seconds, 3),
        "peak_cuda_bytes": torch.cuda.max_memory_allocated(),
        "physical_microbatch": physical_microbatch,
        "best_step": tracker.best_step,
        "best_validation_loss": tracker.best_loss,
        "validation_history": validation_history,
        "base_files": base_inventory,
        "gpu": {
            "name": torch.cuda.get_device_name(0),
            "total_memory_bytes": torch.cuda.get_device_properties(0).total_memory,
            "torch": torch.__version__,
            "cuda": torch.version.cuda,
        },
        "nondeterministic_exceptions": [],
        "last_progress": last_progress,
    }
    (artifact_root / "training-v1.json").write_bytes(canonical_json_bytes(report))
    return report


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)
    smoke = subparsers.add_parser("smoke", help="run the required real 20-step overfit smoke")
    train = subparsers.add_parser("train", help="run the bounded real training job")
    for command in (smoke, train):
        command.add_argument("--config", required=True, type=Path)
        command.add_argument("--dataset-manifest", required=True, type=Path)
        command.add_argument("--dataset-root", required=True, type=Path)
        command.add_argument("--base-model-dir", required=True, type=Path)
        command.add_argument("--tokenizer-model", required=True, type=Path)
        command.add_argument("--artifact-root", required=True, type=Path)
        command.add_argument("--physical-microbatch", type=int, default=32)
        command.add_argument("--resume", action="store_true")
    args = parser.parse_args(argv)
    config = load_training_config(args.config)
    dataset_manifest = _load_json(args.dataset_manifest)
    if args.command == "smoke":
        report = run_overfit_smoke(
            config,
            args.dataset_root,
            dataset_manifest,
            args.base_model_dir,
            args.tokenizer_model,
            args.artifact_root,
            args.physical_microbatch,
        )
        print(json.dumps(report["gate"], sort_keys=True), flush=True)
    elif args.command == "train":
        report = run_full_training(
            config,
            args.dataset_root,
            dataset_manifest,
            args.base_model_dir,
            args.tokenizer_model,
            args.artifact_root,
            args.physical_microbatch,
            resume=args.resume,
        )
        print(json.dumps(report, sort_keys=True), flush=True)


if __name__ == "__main__":
    try:
        main()
    except TrainingContractError as error:
        raise SystemExit("error: %s" % error)
