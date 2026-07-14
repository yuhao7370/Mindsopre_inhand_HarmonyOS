import copy
import hashlib
import json
import math
import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace

from tools.translation.train_bidirectional import (
    BASE_REVISION,
    TrainingContractError,
    BestCheckpointTracker,
    alternating_batch_plan,
    build_checkpoint_manifest,
    build_model_fields,
    canonical_json_bytes,
    decoder_input_ids,
    expand_shared_embeddings,
    final_validation_required,
    load_training_config,
    restore_resume_state,
    resume_elapsed_floor,
    run_logical_batches,
    _save_selected_checkpoint,
    should_save_periodic_resume,
    smoke_loss_gate,
    stop_reason,
    validate_quality_result,
    validate_resume_state,
    verify_dataset_inputs,
)


ROOT = Path(__file__).parent
CONFIG = ROOT / "config" / "training-run-v1.json"
CONFIG_V2 = ROOT / "config" / "training-run-v2.json"
CONFIG_V3 = ROOT / "config" / "training-run-v3.json"
DATASET_MANIFEST = ROOT / "manifests" / "bist-v1.json"


class FakeSentencePiece:
    def encode(self, text, out_type=int):
        del out_type
        return [int(value) for value in text.split()] if text else []


class TrainContractTest(unittest.TestCase):
    def test_selected_checkpoint_records_pinned_base_revision_for_export(self):
        class FakeModel:
            def save_pretrained(self, selected_root, **kwargs):
                self.kwargs = kwargs
                (Path(selected_root) / "config.json").write_text("{}", encoding="utf-8")
                (Path(selected_root) / "model.safetensors").write_bytes(b"weights")

        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            tokenizer = root / "tokenizer.model"
            tokenizer.write_bytes(b"tokenizer")
            selected = root / "selected"

            model = FakeModel()
            _save_selected_checkpoint(model, tokenizer, selected, 12, 1.25)

            provenance = selected / "base_revision.txt"
            self.assertTrue(provenance.is_file())
            self.assertEqual(provenance.read_bytes(), (BASE_REVISION + "\n").encode("ascii"))
            self.assertEqual(model.kwargs, {"safe_serialization": True, "max_shard_size": "1GB"})

    def test_checked_in_config_pins_complete_training_and_model_contract(self):
        config = load_training_config(CONFIG)
        self.assertEqual(config["seed"], 20260713)
        self.assertEqual(
            config["base_checkpoint"],
            {
                "repo": "Helsinki-NLP/opus-mt_tiny_zho-eng",
                "revision": BASE_REVISION,
            },
        )
        self.assertEqual(
            config["tokens"],
            {
                "eos": 0,
                "unk": 1,
                "pad": 32000,
                "decoder_start": 32000,
                "to_en": 32001,
                "to_zh": 32002,
            },
        )
        self.assertEqual(
            config["model"],
            {
                "vocab_size": 32003,
                "max_tokens": 128,
                "encoder_layers": 6,
                "decoder_layers": 2,
                "d_model": 256,
                "ffn_dim": 1536,
                "attention_heads": 8,
                "shared_embeddings": True,
            },
        )
        self.assertEqual(
            config["training"],
            {
                "precision": "fp16",
                "device": "cuda",
                "microbatch_per_direction": 32,
                "gradient_accumulation": 4,
                "learning_rate": 3e-5,
                "weight_decay": 0.01,
                "label_smoothing": 0.1,
                "warmup_optimizer_steps": 1000,
                "evaluate_every_optimizer_steps": 1000,
                "early_stop_non_improving_evaluations": 2,
                "max_epochs": 4,
                "max_gpu_hours": 12,
                "embedding_init_std": 0.02,
            },
        )

    def test_v2_amendment_only_extends_the_epoch_ceiling(self):
        original = load_training_config(CONFIG)
        amended = load_training_config(CONFIG_V2)
        amended_v3 = load_training_config(CONFIG_V3)
        self.assertEqual(original["schema_version"], 1)
        self.assertEqual(amended["schema_version"], 2)
        self.assertEqual(original["training"]["max_epochs"], 4)
        self.assertEqual(amended["training"]["max_epochs"], 8)
        comparable = copy.deepcopy(amended)
        comparable["schema_version"] = 1
        comparable["training"]["max_epochs"] = 4
        self.assertEqual(comparable, original)
        self.assertEqual(amended_v3["schema_version"], 3)
        self.assertEqual(amended_v3["training"]["max_epochs"], 12)
        comparable = copy.deepcopy(amended_v3)
        comparable["schema_version"] = 1
        comparable["training"]["max_epochs"] = 4
        self.assertEqual(comparable, original)

    def test_config_rejects_unknown_missing_boolean_numbers_paths_and_pin_drift(self):
        original = json.loads(CONFIG.read_text(encoding="utf-8"))
        mutations = []
        value = copy.deepcopy(original)
        value["unexpected"] = 1
        mutations.append(value)
        value = copy.deepcopy(original)
        del value["training"]["learning_rate"]
        mutations.append(value)
        value = copy.deepcopy(original)
        value["training"]["max_epochs"] = True
        mutations.append(value)
        value = copy.deepcopy(original)
        value["base_checkpoint"]["revision"] = "0" * 40
        mutations.append(value)
        value = copy.deepcopy(original)
        value["tokens"]["to_en"] = 7
        mutations.append(value)
        value = copy.deepcopy(original)
        value["model"]["decoder_layers"] = 6
        mutations.append(value)
        value = copy.deepcopy(original)
        value["tokenizer"]["file"] = "../source.spm"
        mutations.append(value)
        value = copy.deepcopy(original)
        value["tokenizer"]["file"] = "C:/temp/source.spm"
        mutations.append(value)
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "config.json"
            for index, mutation in enumerate(mutations):
                with self.subTest(index=index):
                    path.write_text(json.dumps(mutation), encoding="utf-8")
                    with self.assertRaises(TrainingContractError):
                        load_training_config(path)

    def test_direction_prefix_eos_padding_masks_and_label_ignore_are_exact(self):
        row = {"source": "10 11", "target": "20 21 22", "direction_id": 32001}
        fields = build_model_fields(row, "zh-en", FakeSentencePiece(), max_tokens=8)
        self.assertEqual(fields["input_ids"], [32001, 10, 11, 0, 32000, 32000, 32000, 32000])
        self.assertEqual(fields["attention_mask"], [1, 1, 1, 1, 0, 0, 0, 0])
        self.assertEqual(fields["labels"], [20, 21, 22, 0, -100, -100, -100, -100])
        reverse = build_model_fields(
            {"source": "30", "target": "40", "direction_id": 32002},
            "en-zh",
            FakeSentencePiece(),
            max_tokens=4,
        )
        self.assertEqual(reverse["input_ids"], [32002, 30, 0, 32000])
        self.assertEqual(reverse["labels"], [40, 0, -100, -100])

    def test_encoding_accepts_exact_boundary_and_rejects_overflow_or_wrong_direction(self):
        exact = build_model_fields(
            {"source": "2 3 4 5 6 7", "target": "8 9 10 11 12 13 14", "direction_id": 32001},
            "zh-en",
            FakeSentencePiece(),
            max_tokens=8,
        )
        self.assertEqual(len(exact["input_ids"]), 8)
        self.assertEqual(len(exact["labels"]), 8)
        invalid = (
            ({"source": "2 3 4 5 6 7 8", "target": "9", "direction_id": 32001}, "zh-en"),
            ({"source": "2", "target": "3 4 5 6 7 8 9 10", "direction_id": 32001}, "zh-en"),
            ({"source": "2", "target": "3", "direction_id": 32002}, "zh-en"),
        )
        for row, direction in invalid:
            with self.subTest(row=row), self.assertRaises(TrainingContractError):
                build_model_fields(row, direction, FakeSentencePiece(), max_tokens=8)

    def test_batch_plan_is_deterministic_seeded_and_strictly_alternating(self):
        first = alternating_batch_plan({"zh-en": 9, "en-zh": 9}, batch_size=4, seed=20260713, epoch=0)
        second = alternating_batch_plan({"zh-en": 9, "en-zh": 9}, batch_size=4, seed=20260713, epoch=0)
        next_epoch = alternating_batch_plan({"zh-en": 9, "en-zh": 9}, batch_size=4, seed=20260713, epoch=1)
        self.assertEqual(first, second)
        self.assertNotEqual(first, next_epoch)
        self.assertEqual([direction for direction, _ in first], ["zh-en", "en-zh"] * 3)
        for direction in ("zh-en", "en-zh"):
            flattened = [index for item_direction, indices in first if item_direction == direction for index in indices]
            self.assertEqual(sorted(flattened), list(range(9)))
            self.assertEqual([len(indices) for item_direction, indices in first if item_direction == direction], [4, 4, 1])
        with self.assertRaises(TrainingContractError):
            alternating_batch_plan({"zh-en": 9, "en-zh": 8}, 4, 20260713, 0)

    def test_gradient_accumulation_counts_logical_batches_not_memory_subdivisions(self):
        subbatch_calls = []
        optimizer_calls = []
        plan = [("zh-en" if index % 2 == 0 else "en-zh", list(range(32))) for index in range(8)]

        def train_subbatch(direction, indices, loss_scale):
            subbatch_calls.append((direction, len(indices), loss_scale))
            return 1.0

        result = run_logical_batches(
            plan,
            gradient_accumulation=4,
            physical_microbatch=8,
            train_subbatch=train_subbatch,
            optimizer_step=lambda: optimizer_calls.append("step"),
        )
        self.assertEqual(len(subbatch_calls), 32)
        self.assertTrue(all(size == 8 for _, size, _ in subbatch_calls))
        self.assertTrue(all(math.isclose(scale, 1 / 16) for _, _, scale in subbatch_calls))
        self.assertEqual(len(optimizer_calls), 2)
        self.assertEqual(result, {"logical_batches": 8, "optimizer_steps": 2})

    def test_validation_tracker_saves_only_strict_best_and_stops_after_two_non_improvements(self):
        saved = []
        tracker = BestCheckpointTracker(patience=2, save=lambda step, loss: saved.append((step, loss)))
        self.assertFalse(tracker.observe(1000, 2.0))
        self.assertFalse(tracker.observe(2000, 2.0))
        self.assertFalse(tracker.observe(3000, 1.9))
        self.assertFalse(tracker.observe(4000, 2.1))
        self.assertTrue(tracker.observe(5000, 2.2))
        self.assertEqual(saved, [(1000, 2.0), (3000, 1.9)])
        self.assertEqual(tracker.best_step, 3000)
        self.assertEqual(tracker.best_loss, 1.9)

    def test_final_checkpoint_is_validated_when_not_on_the_regular_cadence(self):
        history = [{"optimizer_step": 5000, "loss": 4.2}]
        self.assertTrue(final_validation_required(history, 5626))
        self.assertFalse(final_validation_required(history, 5000))
        self.assertTrue(final_validation_required([], 26))

    def test_stop_reason_uses_time_then_epoch_then_early_stop_priority(self):
        self.assertEqual(stop_reason(12, 4, True), "gpu_time_limit")
        self.assertEqual(stop_reason(1, 4, True), "epoch_limit")
        self.assertEqual(stop_reason(1, 3, True), "early_stop")
        self.assertIsNone(stop_reason(1, 3, False))

    def test_embedding_expansion_copies_old_rows_adds_seeded_normal_rows_and_keeps_ties(self):
        try:
            import torch
        except ImportError:
            self.skipTest("torch is not installed in the host test interpreter")

        class TinySharedModel(torch.nn.Module):
            def __init__(self):
                super().__init__()
                self.shared = torch.nn.Embedding(5, 3)
                self.lm_head = torch.nn.Linear(3, 5, bias=False)
                self.lm_head.weight = self.shared.weight

            def get_input_embeddings(self):
                return self.shared

            def get_output_embeddings(self):
                return self.lm_head

            def resize_token_embeddings(self, size):
                replacement = torch.nn.Embedding(size, 3)
                replacement.weight.data[:5].copy_(self.shared.weight.data)
                self.shared = replacement
                self.lm_head = torch.nn.Linear(3, size, bias=False)
                self.lm_head.weight = self.shared.weight
                return replacement

            def tie_weights(self):
                self.lm_head.weight = self.shared.weight

        torch.manual_seed(7)
        model = TinySharedModel()
        old = model.shared.weight.detach().clone()
        expand_shared_embeddings(model, old_vocab=5, final_vocab=7, seed=20260713, std=0.02)
        self.assertTrue(torch.equal(model.shared.weight[:5], old))
        self.assertIs(model.get_input_embeddings().weight, model.get_output_embeddings().weight)
        clone = TinySharedModel()
        clone.shared.weight.data[:5].copy_(old)
        expand_shared_embeddings(clone, old_vocab=5, final_vocab=7, seed=20260713, std=0.02)
        self.assertTrue(torch.equal(model.shared.weight[5:], clone.shared.weight[5:]))
        self.assertFalse(torch.equal(model.shared.weight[5:], torch.zeros_like(model.shared.weight[5:])))

    def test_embedding_expansion_bypasses_upstream_mean_resize_and_updates_marian_bias(self):
        try:
            import torch
        except ImportError:
            self.skipTest("torch is not installed in the host test interpreter")

        class DirectSharedModel(torch.nn.Module):
            def __init__(self):
                super().__init__()
                self.shared = torch.nn.Embedding(5, 3, padding_idx=4)
                self.lm_head = torch.nn.Linear(3, 5, bias=False)
                self.lm_head.weight = self.shared.weight
                self.register_buffer("final_logits_bias", torch.zeros((1, 5)))
                self.config = SimpleNamespace(vocab_size=5, decoder_vocab_size=5)

            def get_input_embeddings(self):
                return self.shared

            def get_output_embeddings(self):
                return self.lm_head

            def set_input_embeddings(self, value):
                self.shared = value

            def set_output_embeddings(self, value):
                self.lm_head = value

            def resize_token_embeddings(self, *args, **kwargs):
                raise AssertionError("upstream mean-resizing path must not run")

            def tie_weights(self):
                self.lm_head.weight = self.shared.weight

        model = DirectSharedModel()
        old = model.shared.weight.detach().clone()
        expand_shared_embeddings(model, old_vocab=5, final_vocab=7, seed=20260713, std=0.02)
        self.assertTrue(torch.equal(model.shared.weight[:5], old))
        self.assertEqual(tuple(model.final_logits_bias.shape), (1, 7))
        self.assertEqual(model.config.vocab_size, 7)
        self.assertEqual(model.config.decoder_vocab_size, 7)
        self.assertIs(model.shared.weight, model.lm_head.weight)

    def test_dataset_verification_reads_exact_six_hashes_and_rejects_tampering(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            outputs = {}
            for direction in ("zh-en", "en-zh"):
                for split in ("train", "validation", "test"):
                    name = f"{direction}.{split}.jsonl"
                    payload = (json.dumps({"source": "a", "target": "b", "direction_id": 32001}) + "\n").encode()
                    (root / name).write_bytes(payload)
                    outputs[name] = {
                        "path": name,
                        "count": 1,
                        "bytes": len(payload),
                        "sha256": hashlib.sha256(payload).hexdigest(),
                    }
            manifest = {"schema_version": 1, "outputs": outputs}
            self.assertEqual(len(verify_dataset_inputs(root, manifest)), 6)
            (root / "zh-en.train.jsonl").write_bytes(b"tampered")
            with self.assertRaises(TrainingContractError):
                verify_dataset_inputs(root, manifest)

    def test_checkpoint_manifest_is_canonical_portable_and_hashes_exact_files(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            checkpoint = root / "selected"
            checkpoint.mkdir()
            (checkpoint / "model.safetensors").write_bytes(b"weights")
            manifest = build_checkpoint_manifest(
                checkpoint,
                [checkpoint / "model.safetensors"],
                optimizer_steps=12,
                validation_loss=1.25,
                stop="epoch_limit",
            )
            self.assertEqual(manifest["files"][0]["path"], "model.safetensors")
            self.assertEqual(manifest["files"][0]["sha256"], hashlib.sha256(b"weights").hexdigest())
            encoded = canonical_json_bytes(manifest)
            self.assertTrue(encoded.endswith(b"\n"))
            self.assertNotIn(str(root).encode(), encoded)
            self.assertNotIn(b"timestamp", encoded)
            outside = root.parent / "outside.safetensors"
            outside.write_bytes(b"outside")
            try:
                with self.assertRaises(TrainingContractError):
                    build_checkpoint_manifest(checkpoint, [outside], 1, 1.0, "epoch_limit")
            finally:
                outside.unlink()

    def test_quality_gate_fails_closed_and_enforces_all_immutable_thresholds(self):
        passing = {
            "flores": {
                "zh-en": {"bleu": 19.0, "chrf2": 49.0},
                "en-zh": {"bleu": 17.0, "chrf2": 40.0},
            },
            "manual": {
                "zh-en": {"passed": 45, "total": 50, "fatal_corruptions": 0},
                "en-zh": {"passed": 45, "total": 50, "fatal_corruptions": 0},
            },
        }
        self.assertTrue(validate_quality_result(passing))
        mutations = []
        value = copy.deepcopy(passing)
        value["flores"]["zh-en"]["bleu"] = 18.999
        mutations.append(value)
        value = copy.deepcopy(passing)
        value["manual"]["en-zh"]["passed"] = 44
        mutations.append(value)
        value = copy.deepcopy(passing)
        value["manual"]["zh-en"]["fatal_corruptions"] = 1
        mutations.append(value)
        value = copy.deepcopy(passing)
        value["flores"]["en-zh"]["bleu"] = float("nan")
        mutations.append(value)
        value = copy.deepcopy(passing)
        del value["flores"]["zh-en"]["chrf2"]
        mutations.append(value)
        value = copy.deepcopy(passing)
        value["flores"]["zh-en"]["bleu"] = True
        mutations.append(value)
        for index, result in enumerate(mutations):
            with self.subTest(index=index):
                self.assertFalse(validate_quality_result(result))

    def test_t3_cuda_dependencies_are_separate_fully_hashed_and_platform_pinned(self):
        requirements = (ROOT / "requirements-t3.in").read_text(encoding="utf-8")
        lock = (ROOT / "requirements-t3.lock.txt").read_text(encoding="utf-8")
        bootstrap = (ROOT / "bootstrap_training.ps1").read_text(encoding="utf-8")
        self.assertIn("torch==2.5.1+cu121", requirements)
        self.assertIn("transformers==4.46.3", requirements)
        self.assertIn("sacrebleu==2.4.3", requirements)
        self.assertIn("--require-hashes", lock)
        self.assertIn("--hash=sha256:", lock)
        self.assertIn("t3-lock-python: 3.9.7", lock)
        self.assertIn("t3-lock-platform: win32", lock)
        self.assertIn("t3-lock-machine: AMD64", lock)
        self.assertIn("t3-lock-cuda: 12.1", lock)
        self.assertIn("--require-hashes", bootstrap)
        self.assertIn(
            "DC4249C520A6E9B1555E46BD70586A7CF33012800A51ACB58A0C51464E3A786A",
            bootstrap,
        )
        self.assertIn("torch-2.5.1%2Bcu121-cp39-cp39-win_amd64.whl", bootstrap)
        self.assertIn("--no-deps", bootstrap)
        self.assertNotIn("requirements.lock.txt", bootstrap)

    def test_smoke_gate_requires_finite_twenty_steps_and_material_window_drop(self):
        passing = [10.0, 9.9, 9.8, 9.7, 9.6] + [9.4] * 10 + [9.2, 9.1, 9.0, 8.9, 8.8]
        result = smoke_loss_gate(passing)
        self.assertTrue(result["passed"])
        self.assertLess(result["final_window_loss"], result["initial_window_loss"] * 0.98)
        self.assertFalse(smoke_loss_gate(passing[:-1])["passed"])
        nonfinite = list(passing)
        nonfinite[7] = float("nan")
        self.assertFalse(smoke_loss_gate(nonfinite)["passed"])
        flat = [10.0] * 20
        self.assertFalse(smoke_loss_gate(flat)["passed"])

    def test_decoder_inputs_shift_labels_and_replace_ignore_with_pad(self):
        self.assertEqual(
            decoder_input_ids([[20, 21, 0, -100], [30, 0, -100, -100]]),
            [[32000, 20, 21, 0], [32000, 30, 0, 32000]],
        )

    def test_resume_state_cursor_is_strict_and_matches_accumulation_boundary(self):
        python_rng = __import__("random").getstate()
        state = {
            "schema_version": 1,
            "model": {},
            "optimizer": {},
            "scaler": {},
            "optimizer_step": 4400,
            "epoch": 3,
            "plan_index": 722,
            "elapsed_seconds": 60.5,
            "python_random_state": python_rng,
            "torch_random_state": "cpu-rng",
            "cuda_random_state": ["cuda-rng"],
        }
        self.assertEqual(validate_resume_state(state), (4400, 3, 722, 60.5))
        for mutation in (
            {**state, "unexpected": 1},
            {**state, "optimizer_step": True},
            {**state, "plan_index": 723},
            {**state, "elapsed_seconds": float("nan")},
        ):
            with self.assertRaises(TrainingContractError):
                validate_resume_state(mutation)

    def test_resume_restores_exact_model_optimizer_scaler_and_rng_objects(self):
        python_rng = __import__("random").getstate()
        state = {
            "schema_version": 1,
            "model": {"weight": "model-state"},
            "optimizer": {"state": "optimizer-state"},
            "scaler": {"scale": "scaler-state"},
            "optimizer_step": 5626,
            "epoch": 3,
            "plan_index": 5626,
            "elapsed_seconds": 4566.844,
            "python_random_state": python_rng,
            "torch_random_state": "cpu-rng",
            "cuda_random_state": ["cuda-rng"],
        }

        class Loader:
            def __init__(self):
                self.calls = []

            def load_state_dict(self, value, **kwargs):
                self.calls.append((value, kwargs))

        class Cuda:
            def __init__(self):
                self.value = None

            def set_rng_state_all(self, value):
                self.value = value

        class Torch:
            def __init__(self):
                self.value = None
                self.cuda = Cuda()

            def set_rng_state(self, value):
                self.value = value

        torch = Torch()
        model, optimizer, scaler = Loader(), Loader(), Loader()
        cursor = restore_resume_state(torch, state, model, optimizer, scaler, max_epochs=8)
        self.assertEqual(cursor, (5626, 3, 5626, 4566.844))
        self.assertEqual(model.calls, [({"weight": "model-state"}, {"strict": True})])
        self.assertEqual(optimizer.calls, [({"state": "optimizer-state"}, {})])
        self.assertEqual(scaler.calls, [({"scale": "scaler-state"}, {})])
        self.assertEqual(torch.value, "cpu-rng")
        self.assertEqual(torch.cuda.value, ["cuda-rng"])

    def test_resume_elapsed_uses_existing_report_as_a_no_rollback_floor(self):
        self.assertEqual(resume_elapsed_floor(4560.954, {"elapsed_seconds": 4566.844}), 4566.844)
        self.assertEqual(resume_elapsed_floor(4583.095, {"elapsed_seconds": 4566.844}), 4583.095)
        with self.assertRaises(TrainingContractError):
            resume_elapsed_floor(1.0, {"elapsed_seconds": True})

    def test_periodic_resume_is_saved_every_five_hundred_optimizer_steps(self):
        self.assertFalse(should_save_periodic_resume(11300))
        self.assertFalse(should_save_periodic_resume(11499))
        self.assertTrue(should_save_periodic_resume(11500))
        self.assertTrue(should_save_periodic_resume(12000))
        for invalid in (True, 0, -500, 11500.0):
            with self.assertRaises(TrainingContractError):
                should_save_periodic_resume(invalid)


if __name__ == "__main__":
    unittest.main()
