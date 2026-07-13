import hashlib
import json
import tempfile
import unittest
from pathlib import Path
from unittest import mock

from tools.translation.export_marian_smoke import (
    ContractError,
    PINNED_REVISION,
    _inspect_onnx,
    _validate_checkpoint,
    _validate_stable_softmax,
    load_profile,
    validate_graph_contract,
    verify_export_report,
)
from tools.translation.generate_mindspore_contract import DescriptorError, generate_header


CONTRACT = Path(__file__).with_name("contracts") / "translation-v1.json"
ROOT = Path(__file__).parent


class ExportContractTest(unittest.TestCase):
    def test_final_checkpoint_revision_provenance_is_required_and_pinned(self):
        profile = load_profile(CONTRACT, "prototype")
        config = {
            "vocab_size": 32001,
            "decoder_vocab_size": 32001,
            "d_model": 256,
            "encoder_layers": 6,
            "decoder_layers": 2,
            "encoder_attention_heads": 8,
            "decoder_attention_heads": 8,
        }
        with tempfile.TemporaryDirectory() as directory:
            checkpoint = Path(directory)
            (checkpoint / "config.json").write_text(json.dumps(config), encoding="utf-8")
            (checkpoint / "model.safetensors").write_bytes(b"weights")
            provenance = checkpoint / "base_revision.txt"

            provenance.write_text(PINNED_REVISION + "\n", encoding="utf-8")
            _validate_checkpoint(checkpoint, profile, "prototype")

            provenance.unlink()
            with self.assertRaisesRegex(ContractError, "got None"):
                _validate_checkpoint(checkpoint, profile, "prototype")

            provenance.write_text("0" * 40 + "\n", encoding="utf-8")
            with self.assertRaisesRegex(ContractError, "revision mismatch"):
                _validate_checkpoint(checkpoint, profile, "prototype")

    def test_final_checkpoint_is_bound_to_canonical_training_and_quality_gate_reports(self):
        profile = load_profile(CONTRACT, "final")
        config = {
            "vocab_size": 32003,
            "decoder_vocab_size": 32003,
            "d_model": 256,
            "encoder_layers": 6,
            "decoder_layers": 2,
            "encoder_attention_heads": 8,
            "decoder_attention_heads": 8,
        }

        def canonical(value):
            return (json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":")) + "\n").encode("utf-8")

        def artifact(path):
            payload = path.read_bytes()
            return {"path": path.name, "bytes": len(payload), "sha256": hashlib.sha256(payload).hexdigest()}

        with tempfile.TemporaryDirectory() as directory:
            checkpoint = Path(directory) / "candidate-epoch1" / "selected"
            checkpoint.mkdir(parents=True)
            (checkpoint / "config.json").write_text(json.dumps(config), encoding="utf-8")
            (checkpoint / "model.safetensors").write_bytes(b"approved-weights")
            (checkpoint / "tokenizer.model").write_bytes(b"approved-tokenizer")
            (checkpoint / "base_revision.txt").write_text(PINNED_REVISION + "\n", encoding="ascii")
            candidate = {
                "model_sha256": hashlib.sha256(b"approved-weights").hexdigest(),
                "tokenizer_sha256": hashlib.sha256(b"approved-tokenizer").hexdigest(),
            }
            objective = {"contract": "c" * 64}
            training = {
                "schema_version": 1, "epoch": 1, "seed": 20260713, "plan_epoch_index": 0,
                "optimizer_reset": True, "rescue_steps": 1406, "logical_batches": 5624,
                "dropped_partial_logical_batches": 2, "validation_history": [],
                "baseline_validation_loss": 3.7, "best_rescue_step": 1406,
                "best_validation_loss": 3.6, "candidate_checkpoint": "candidate-epoch1/selected",
                "candidate": candidate, "promotion_allowed": False,
                "promotion_status": "pending_manual_and_flores_gate", "resumed": False,
                "teacher_generation_gpu_seconds": 1.0, "probe_gpu_seconds": 1.0,
                "rescue_gpu_seconds": 1.0, "epoch_gpu_seconds": 1.0,
                "cumulative_gpu_seconds": 3.0, "gpuLedger": {},
                "training_view_manifest_sha256": "a" * 64,
                "distillation_manifest_sha256": "b" * 64, "peak_cuda_bytes": 1,
                "last_progress": {}, "objective_hashes": objective,
                "replayed_from_baseline": False, "replayed_optimizer_steps": 0,
                "baseline_replay_receipt": None,
            }
            training_path = Path(directory) / "training-v1.json"
            training_path.write_bytes(canonical(training))
            gate = {
                "schema_version": 1, "epoch2_allowed": True, "epoch2_launch_allowed": True,
                "epoch2_status": "authorized", "promotion_allowed": True,
                "candidate": candidate, "candidateEpoch": 1,
                "trainingReport": artifact(training_path), "objectiveHashes": objective,
                "manualAsset": {"path": "manual.jsonl", "bytes": 1, "sha256": "d" * 64},
                "manualResults": {"path": "manual-results.jsonl", "bytes": 1, "sha256": "e" * 64},
                "manual": {
                    "zh-en": {"total": 50, "passed": 45, "fatal_corruptions": 0},
                    "en-zh": {"total": 50, "passed": 45, "fatal_corruptions": 0},
                },
                "flores": {
                    "repo": "openlanguagedata/flores_plus",
                    "revision": "b3a5298db5721c8a682e7ef00a37fcc9ab522757",
                    "files": [
                        {"language": "zh", "path": "devtest/cmn_Hans.jsonl", "bytes": 1, "sha256": "f" * 64},
                        {"language": "en", "path": "devtest/eng_Latn.jsonl", "bytes": 1, "sha256": "0" * 64},
                    ],
                    "metrics": {
                        "zh-en": {"bleu": 19.0, "chrf2": 49.0},
                        "en-zh": {"bleu": 17.0, "chrf2": 40.0},
                    },
                },
            }
            gate_path = Path(directory) / "gate-v1.json"
            gate_path.write_bytes(canonical(gate))

            approval = _validate_checkpoint(
                checkpoint, profile, "final", training_path, gate_path
            )
            self.assertEqual(approval["candidate"], candidate)
            with self.assertRaisesRegex(ContractError, "requires canonical"):
                _validate_checkpoint(checkpoint, profile, "final")

            (checkpoint / "model.safetensors").write_bytes(b"different")
            with self.assertRaisesRegex(ContractError, "candidate differs"):
                _validate_checkpoint(checkpoint, profile, "final", training_path, gate_path)

    def test_prototype_and_final_profiles_are_separate_and_use_inspected_cache_shapes(self):
        prototype = load_profile(CONTRACT, "prototype")
        final = load_profile(CONTRACT, "final")
        self.assertEqual(prototype["vocabSize"], 32001)
        self.assertEqual(prototype["maxTokens"], 256)
        self.assertEqual(final["vocabSize"], 32003)
        self.assertEqual(final["maxTokens"], 128)
        self.assertEqual(prototype["onnxFloatingDtype"], "FLOAT16")
        self.assertEqual(prototype["mindsporeFloatingDtype"], "FLOAT32")
        self.assertEqual(prototype["graphs"]["decoder_step"]["inputs"]["past_key_0"]["shape"], [1, 8, 255, 32])
        self.assertEqual(final["graphs"]["decoder_step"]["inputs"]["past_key_0"]["shape"], [1, 8, 127, 32])
        self.assertEqual(final["graphs"]["decoder_step"]["outputs"]["new_key_0"]["shape"], [1, 8, 1, 32])
        self.assertEqual(final["graphs"]["encoder"]["inputs"]["attention_mask"]["dtype"], "INT32")

    def test_mindspore_smoke_scatter_updates_head_strided_cache_slots(self):
        source = (ROOT / "mindspore_translation_smoke.cpp").read_text(encoding="utf-8")
        self.assertIn("static void ScatterCacheSlot", source)
        self.assertIn("ScatterCacheSlot(self_key, past_key, 0);", source)
        self.assertIn("ScatterCacheSlot(new_key, past_key, position);", source)

    def test_mindspore_smoke_uses_generated_runtime_descriptors(self):
        source = (ROOT / "mindspore_translation_smoke.cpp").read_text(encoding="utf-8")
        self.assertIn('#include "translation_runtime_contract.h"', source)
        self.assertIn("RequireDescriptors", source)

    def test_runtime_descriptor_header_is_contract_driven_and_strict(self):
        contract = json.loads(CONTRACT.read_text(encoding="utf-8"))
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            generated = root / "translation_runtime_contract.h"
            generate_header(CONTRACT, "prototype", generated)
            header = generated.read_text(encoding="utf-8")
            self.assertIn('{"attention_mask", mindspore::DataType::kNumberTypeInt32, {1, 256}}', header)
            self.assertIn('{"last_hidden_state", mindspore::DataType::kNumberTypeFloat32, {1, 256, 256}}', header)

            contract["profiles"]["prototype"]["graphs"]["encoder"]["inputs"]["attention_mask"]["shape"] = [1, 255]
            mutated_contract = root / "mutated.json"
            mutated_contract.write_text(json.dumps(contract), encoding="utf-8")
            generate_header(mutated_contract, "prototype", generated)
            self.assertIn('{"attention_mask", mindspore::DataType::kNumberTypeInt32, {1, 255}}', generated.read_text(encoding="utf-8"))

            contract["profiles"]["prototype"]["mindsporeFloatingDtype"] = "FLOAT16"
            mutated_contract.write_text(json.dumps(contract), encoding="utf-8")
            with self.assertRaisesRegex(DescriptorError, "FLOAT32"):
                generate_header(mutated_contract, "prototype", generated)

    def test_converter_enforces_pinned_prototype_token_fixture(self):
        source = (ROOT / "convert_mindspore.ps1").read_text(encoding="utf-8")
        self.assertIn("@(422, 22, 7, 4, 422, 22)", source)
        self.assertIn("prototype cache fixture drift", source)

    def test_final_converter_measures_float_parity_and_one_hundred_step_w8_agreement(self):
        converter = (ROOT / "convert_mindspore.ps1").read_text(encoding="utf-8")
        smoke = (ROOT / "mindspore_translation_smoke.cpp").read_text(encoding="utf-8")
        exporter = (ROOT / "export_marian_smoke.py").read_text(encoding="utf-8")
        self.assertIn("$requiredCacheSteps = if ($Profile -eq 'final') { 100 } else { 5 }", converter)
        self.assertIn("if ($argmaxAgreement -lt 0.99)", converter)
        self.assertNotIn("argmaxAgreement = 1.0", converter)
        self.assertIn("encoderParity", converter)
        self.assertIn("maxAbs", converter)
        self.assertIn("meanAbs", converter)
        self.assertIn("--steps=", converter)
        self.assertIn("--encoder-output=", converter)
        self.assertIn("--valid-tokens=", converter)
        self.assertIn("position <= steps", smoke)
        self.assertIn("encoder_mindspore_parity", exporter)
        self.assertIn("--encoder-mindspore-output", exporter)
        self.assertIn("--encoder-valid-tokens", exporter)
        self.assertIn("$resolvedOutput.Equals($repoRoot", converter)
        self.assertIn("--verify-export-report", converter)
        self.assertIn("consumed != value.size()", smoke)

    def test_export_report_binds_exact_onnx_files_and_rejects_tampering(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            artifacts = {}
            for name in ("encoder", "decoder_prefill", "decoder_step"):
                path = root / (name + ".onnx")
                path.write_bytes(name.encode("ascii"))
                artifacts[path.name] = {
                    "path": path.name,
                    "bytes": path.stat().st_size,
                    "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
                }
            graphs = {"encoder": {}, "decoder_prefill": {}, "decoder_step": {}}
            report = {
                "schemaVersion": 1, "profile": "prototype",
                "checkpointRevision": PINNED_REVISION, "approval": None,
                "vocabSize": 32001, "maxTokens": 256, "graphs": graphs,
                "pytorchOnnxMaxAbsLimit": 0.03,
                "decoderPytorchOnnxMaxAbsLimit": 0.03,
                "stableSoftmax": ["ReduceMax", "Sub", "Exp", "ReduceSum", "Div"],
                "onnxArtifacts": artifacts,
            }
            (root / "export-report.json").write_bytes(
                (json.dumps(report, sort_keys=True, separators=(",", ":")) + "\n").encode("utf-8")
            )
            with mock.patch(
                "tools.translation.export_marian_smoke.inspect_exports",
                return_value={"profile": "prototype", "graphs": graphs},
            ):
                self.assertEqual(verify_export_report(root, CONTRACT, "prototype"), report)
                (root / "encoder.onnx").write_bytes(b"tampered")
                with self.assertRaisesRegex(ContractError, "does not bind"):
                    verify_export_report(root, CONTRACT, "prototype")

    def test_contract_comparison_fails_closed_on_name_dtype_or_shape_change(self):
        expected = {
            "inputs": {"mask": {"dtype": "INT32", "shape": [1, 128]}},
            "outputs": {"value": {"dtype": "FLOAT16", "shape": [1, 2]}},
        }
        validate_graph_contract(expected, json.loads(json.dumps(expected)), "graph")
        for field, value in (("dtype", "FLOAT32"), ("shape", [1, 3])):
            actual = json.loads(json.dumps(expected))
            actual["inputs"]["mask"][field] = value
            with self.subTest(field=field), self.assertRaisesRegex(ContractError, "graph contract mismatch"):
                validate_graph_contract(expected, actual, "graph")
        actual = json.loads(json.dumps(expected))
        actual["inputs"]["extra"] = {"dtype": "INT32", "shape": [1]}
        with self.assertRaisesRegex(ContractError, "graph contract mismatch"):
            validate_graph_contract(expected, actual, "graph")

    def test_stable_softmax_rejects_mutated_onnx_edge(self):
        import onnx
        from onnx import TensorProto, helper

        nodes = [
            helper.make_node("ReduceMax", ["scores"], ["maximum"]),
            helper.make_node("Sub", ["scores", "maximum"], ["shifted"]),
            helper.make_node("Exp", ["shifted"], ["numerator"]),
            helper.make_node("ReduceSum", ["numerator"], ["denominator"]),
            helper.make_node("Div", ["numerator", "denominator"], ["probabilities"]),
        ]
        graph = helper.make_graph(
            nodes,
            "stable-softmax",
            [helper.make_tensor_value_info("scores", TensorProto.FLOAT, [1, 2])],
            [helper.make_tensor_value_info("probabilities", TensorProto.FLOAT, [1, 2])],
        )
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "softmax.onnx"
            onnx.save(helper.make_model(graph), path)
            _, inspected_nodes = _inspect_onnx(path)
            _validate_stable_softmax(inspected_nodes, "valid", 1)

            graph.node[-1].input[1] = "wrong_denominator"
            onnx.save(helper.make_model(graph), path)
            _, inspected_nodes = _inspect_onnx(path)
            with self.assertRaisesRegex(ContractError, "dataflow"):
                _validate_stable_softmax(inspected_nodes, "mutated", 1)

    def test_unknown_profile_is_rejected(self):
        with self.assertRaisesRegex(ContractError, "profile"):
            load_profile(CONTRACT, "missing")


if __name__ == "__main__":
    unittest.main()
