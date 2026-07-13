import copy
import hashlib
import inspect
import itertools
import json
import tempfile
import unittest
from pathlib import Path
from unittest import mock

import tools.translation.train_v5_continuation as v5
from tools.translation.distill_en_zh import canonical_json_bytes
from tools.translation.train_v5_continuation import (
    V5_BASELINE_LOSSES,
    V5_BUDGET_RECEIPT_SHA256,
    V5_PRIOR_CUMULATIVE_SECONDS,
    V5_RESUME_BYTES,
    V5_RESUME_SHA256,
    V5_SELECTED_FILES,
    V5_START_GLOBAL_STEP,
    V5_TRAINING_CONFIG,
    V5_VALIDATION_STEPS,
    V5ContractError,
    _execute_v5_training_plan,
    _build_fresh_token_caches,
    _canonical_supporting_evidence,
    _configure_determinism,
    _run_production_v5,
    _verify_output_resume,
    evaluate_v5_validation_history,
    validate_v5_launch_bundle,
    validate_v5_budget_root,
    validate_v5_resume_state,
    verify_v5_dataset_bundle,
    run_v5_continuation,
)


class V5ContinuationContractTest(unittest.TestCase):
    def _supporting_evidence(self):
        return [
            {"path": "baseline-budget-terminal-v1.json", "bytes": 596,
             "sha256": "4dc8803c2f81855224883627dc06f734ed6b48a31c99fe21aa2bc525a0d33bc3"},
            {"path": "failed-budget-terminal-v1.json", "bytes": 668,
             "sha256": "edda591abc9943f0f0b65eda34487ec6e8abd5a7310a29a5b694da6c38dd639f"},
            {"path": "diagnostic-provenance-v1.json", "bytes": 2382,
             "sha256": "5ab469aca6d5f147e3dcdc1dc3a0ddbe198ed00b128b62aacdcaf34415e591c5"},
        ]

    def _resume_fixture(self):
        model = {"tensor-%03d" % index: bytes([index % 251]) for index in range(155)}
        state = {
            "schema_version": 1,
            "model": model,
            "optimizer": {
                "state": {index: {"step": 16875} for index in range(149)},
                "param_groups": [{"params": list(range(151))}],
            },
            "scaler": {
                "scale": 2097152.0,
                "growth_factor": 2.0,
                "backoff_factor": 0.5,
                "growth_interval": 2000,
                "_growth_tracker": 57,
            },
            "optimizer_step": 16878,
            "epoch": 11,
            "plan_index": 5626,
            "elapsed_seconds": 13924.157000000065,
            "python_random_state": (3, (), None),
            "torch_random_state": b"torch-rng",
            "cuda_random_state": [b"cuda-rng"],
        }
        artifact = {
            "path": "resume.pt",
            "bytes": V5_RESUME_BYTES,
            "sha256": V5_RESUME_SHA256,
        }
        return state, copy.deepcopy(model), artifact

    def _launch_fixture(self):
        state, baseline, artifact = self._resume_fixture()
        resume = validate_v5_resume_state(
            state, artifact, baseline, tensor_equal=lambda left, right: left == right
        )
        dataset_artifacts = {
            "%s.%s.jsonl" % (direction, split): {
                "path": "%s.%s.jsonl" % (direction, split),
                "count": 1,
                "bytes": 1,
                "sha256": "%x" % (index + 1) * 64,
            }
            for index, (direction, split) in enumerate(
                (direction, split)
                for direction in ("zh-en", "en-zh")
                for split in ("train", "validation", "test")
            )
        }
        evidence = validate_v5_budget_root({
            "artifact": {
                "path": "budget-terminal-v1.json",
                "bytes": 584,
                "sha256": V5_BUDGET_RECEIPT_SHA256,
            },
            "rootEvidence": {
                "path": "diagnostic-provenance-v1.json",
                "bytes": 2382,
                "sha256": "5ab469aca6d5f147e3dcdc1dc3a0ddbe198ed00b128b62aacdcaf34415e591c5",
            },
            "cumulativeActualSeconds": V5_PRIOR_CUMULATIVE_SECONDS,
            "totalBudgetSeconds": 43200.0,
            "supportingEvidence": self._supporting_evidence(),
        })
        launch = {
            "schema_version": 1,
            "contract": "original-bist-v5-continuation",
            "resume": resume,
            "selectedCheckpoint": copy.deepcopy(V5_SELECTED_FILES),
            "trainingConfig": dict(V5_TRAINING_CONFIG),
            "dataset": {
                "manifest": {
                    "path": "run1-manifest.json", "bytes": 6565,
                    "sha256": "6776016325cc0a42653aa964acb30d577c9aa05fe08bfc695d691ccfb1a738a6",
                },
                "repo": "Mxode/BiST",
                "revision": "aca6be897afc319f779009379c8b849c1eb8d63e",
                "artifacts": dataset_artifacts,
                "trainingObjectives": ["zh-en.train.jsonl", "en-zh.train.jsonl"],
                "alternation": "strict-1-to-1",
            },
            "budget": evidence,
            "limits": {
                "startGlobalStep": 16878,
                "finalGlobalStep": 18284,
                "epochs": 1,
                "maxV5ActualSeconds": 2400.0,
                "validationSteps": [17000, 18000, 18284],
                "physicalMicrobatch": 32,
            },
            "execution": {
                "code": v5._artifact(v5.__file__),
                "trainingCore": dict(v5.V5_TRAINING_CORE),
                "diagnosticCore": dict(v5.V5_DIAGNOSTIC_CORE),
                "distillationCore": dict(v5.V5_DISTILLATION_CORE),
                "requirementsLock": dict(v5.V5_REQUIREMENTS_LOCK),
                "runtimeVersions": dict(v5.V5_RUNTIME_VERSIONS),
                "device": dict(v5.V5_DEVICE),
                "determinism": dict(v5.V5_DETERMINISM),
            },
            "teacherView": None,
        }
        return validate_v5_launch_bundle(launch)

    def test_resume_binds_exact_cursor_optimizer_scaler_rng_and_155_tensors(self):
        state, baseline, artifact = self._resume_fixture()
        result = validate_v5_resume_state(
            state, artifact, baseline, tensor_equal=lambda left, right: left == right
        )
        self.assertEqual(result["optimizerStep"], 16878)
        self.assertEqual(result["planIndex"], 5626)
        self.assertEqual(result["optimizerStateEntries"], 149)
        self.assertEqual(result["modelTensors"], 155)
        reordered_baseline = dict(reversed(list(baseline.items())))
        validate_v5_resume_state(
            state, artifact, reordered_baseline,
            tensor_equal=lambda left, right: left == right,
        )

        mutations = []
        for field, value in (
            ("optimizer_step", 16877),
            ("epoch", 10),
            ("plan_index", 0),
            ("elapsed_seconds", 13924.0),
        ):
            mutated = copy.deepcopy(state)
            mutated[field] = value
            mutations.append(mutated)
        mutated = copy.deepcopy(state)
        mutated["optimizer"]["state"].pop(0)
        mutations.append(mutated)
        mutated = copy.deepcopy(state)
        mutated["model"].pop("tensor-000")
        mutations.append(mutated)
        mutated = copy.deepcopy(state)
        mutated["model"]["tensor-000"] = b"changed"
        mutations.append(mutated)
        mutated = copy.deepcopy(state)
        mutated["scaler"]["scale"] = 1.0
        mutations.append(mutated)
        mutated = copy.deepcopy(state)
        mutated["cuda_random_state"] = []
        mutations.append(mutated)
        for mutated in mutations:
            with self.subTest(field=next(
                (key for key in state if mutated.get(key) != state.get(key)), "nested"
            )), self.assertRaises(V5ContractError):
                validate_v5_resume_state(
                    mutated, artifact, baseline,
                    tensor_equal=lambda left, right: left == right,
                )

    def test_dataset_binds_six_original_bist_assets_and_rejects_teacher_view(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            outputs = {}
            for direction, direction_id in (("zh-en", 32001), ("en-zh", 32002)):
                for split in ("train", "validation", "test"):
                    name = "%s.%s.jsonl" % (direction, split)
                    path = root / name
                    path.write_bytes(canonical_json_bytes({
                        "source": "source", "target": "target",
                        "direction_id": direction_id,
                    }))
                    outputs[name] = {
                        "path": name,
                        "count": 1,
                        "bytes": path.stat().st_size,
                        "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
                    }
            manifest = {
                "dataset": {
                    "repo": "Mxode/BiST",
                    "revision": "aca6be897afc319f779009379c8b849c1eb8d63e",
                },
                "outputs": outputs,
            }
            manifest_path = root / "run1-manifest.json"

            def publish(value):
                payload = (
                    json.dumps(value, ensure_ascii=False, indent=2) + "\n"
                ).encode("utf-8")
                manifest_path.write_bytes(payload)
                return hashlib.sha256(payload).hexdigest()

            manifest_sha256 = publish(manifest)
            result = verify_v5_dataset_bundle(
                root, manifest_path, expected_manifest_sha256=manifest_sha256
            )
            self.assertEqual(len(result["artifacts"]), 6)
            self.assertEqual(
                result["trainingObjectives"],
                ["zh-en.train.jsonl", "en-zh.train.jsonl"],
            )

            teacher = copy.deepcopy(manifest)
            teacher["teacher_view"] = {"path": "distilled.jsonl"}
            teacher_sha256 = publish(teacher)
            with self.assertRaises(V5ContractError):
                verify_v5_dataset_bundle(
                    root, manifest_path,
                    expected_manifest_sha256=teacher_sha256,
                )

            publish(manifest)
            (root / "en-zh.train.jsonl").write_bytes(b"tampered\n")
            with self.assertRaises(V5ContractError):
                verify_v5_dataset_bundle(
                    root, manifest_path,
                    expected_manifest_sha256=manifest_sha256,
                )

    def test_budget_and_validation_are_fixed_to_one_epoch_and_joint_improvement(self):
        evidence = {
            "artifact": {
                "path": "budget-terminal-v1.json",
                "bytes": 584,
                "sha256": V5_BUDGET_RECEIPT_SHA256,
            },
            "rootEvidence": {
                "path": "diagnostic-provenance-v1.json",
                "bytes": 2382,
                "sha256": "5ab469aca6d5f147e3dcdc1dc3a0ddbe198ed00b128b62aacdcaf34415e591c5",
            },
            "cumulativeActualSeconds": V5_PRIOR_CUMULATIVE_SECONDS,
            "totalBudgetSeconds": 43200.0,
            "supportingEvidence": self._supporting_evidence(),
        }
        self.assertEqual(
            validate_v5_budget_root(evidence)["maxV5ActualSeconds"], 2400.0
        )
        for field, value in (
            ("cumulativeActualSeconds", V5_PRIOR_CUMULATIVE_SECONDS - 1),
            ("totalBudgetSeconds", 43199.0),
        ):
            forged = copy.deepcopy(evidence)
            forged[field] = value
            with self.assertRaises(V5ContractError):
                validate_v5_budget_root(forged)
        forged = copy.deepcopy(evidence)
        forged["artifact"]["sha256"] = "0" * 64
        with self.assertRaises(V5ContractError):
            validate_v5_budget_root(forged)

        history = [
            {"global_step": 17000, "losses": {"zh-en": 3.20, "en-zh": 4.10}},
            {"global_step": 18000, "losses": {"zh-en": 3.10, "en-zh": 4.00}},
            {"global_step": 18284, "losses": {"zh-en": 3.00, "en-zh": 3.90}},
        ]
        gate = evaluate_v5_validation_history(history, require_final=True)
        self.assertEqual(gate["candidate"]["global_step"], 18284)
        self.assertEqual(tuple(V5_VALIDATION_STEPS), (17000, 18000, 18284))
        self.assertEqual(
            V5_BASELINE_LOSSES,
            {"zh-en": 3.2650395484924317, "en-zh": 4.142768315124512},
        )
        one_direction_only = copy.deepcopy(history)
        one_direction_only[0]["losses"]["en-zh"] = 4.20
        gate = evaluate_v5_validation_history(one_direction_only[:1])
        self.assertIsNone(gate["candidate"])
        for invalid in (
            history[1:],
            history + [{"global_step": 18285, "losses": history[-1]["losses"]}],
        ):
            with self.assertRaises(V5ContractError):
                evaluate_v5_validation_history(invalid, require_final=True)

    def test_public_runner_does_not_accept_an_injected_runtime(self):
        self.assertNotIn("runtime", inspect.signature(run_v5_continuation).parameters)
        launch = self._launch_fixture()
        self.assertEqual(launch["execution"]["runtimeVersions"]["python"], "3.9.7")
        self.assertEqual(launch["execution"]["runtimeVersions"]["cuda"], "12.1")
        self.assertEqual(
            launch["execution"]["device"],
            {"type": "cuda", "name": "NVIDIA GeForce RTX 2070",
             "totalMemoryBytes": 8589475840},
        )
        forged = copy.deepcopy(launch)
        forged["execution"]["runtimeVersions"]["python"] = "3.9.8"
        with self.assertRaises(V5ContractError):
            validate_v5_launch_bundle(forged)

    def test_supporting_budget_evidence_has_one_canonical_order(self):
        expected = None
        for permutation in itertools.permutations(self._supporting_evidence()):
            actual = _canonical_supporting_evidence(list(permutation))
            if expected is None:
                expected = actual
            self.assertEqual(actual, expected)
        self.assertEqual(
            [row["sha256"] for row in expected],
            sorted(row["sha256"] for row in expected),
        )

    def test_determinism_is_set_and_verified_before_runtime_construction(self):
        class Cudnn:
            benchmark = True

        class Backends:
            cudnn = Cudnn()

        class Torch:
            backends = Backends()

            def __init__(self):
                self.enabled = False

            def use_deterministic_algorithms(self, enabled):
                self.enabled = enabled

            def are_deterministic_algorithms_enabled(self):
                return self.enabled

        torch = Torch()
        with mock.patch.dict("os.environ", {}, clear=True):
            self.assertEqual(_configure_determinism(torch), v5.V5_DETERMINISM)
        self.assertTrue(torch.enabled)
        self.assertFalse(torch.backends.cudnn.benchmark)
        with mock.patch.dict(
            "os.environ", {"CUBLAS_WORKSPACE_CONFIG": ":16:8"}, clear=True
        ), self.assertRaises(V5ContractError):
            _configure_determinism(Torch())

    def test_cache_root_must_be_new_and_rehashes_sources_after_six_rebuilds(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            dataset = root / "dataset"
            dataset.mkdir()
            outputs = {}
            for direction in ("zh-en", "en-zh"):
                for split in ("train", "validation", "test"):
                    name = "%s.%s.jsonl" % (direction, split)
                    payload = (name + "\n").encode("ascii")
                    (dataset / name).write_bytes(payload)
                    outputs[name] = {
                        "path": name, "count": 1, "bytes": len(payload),
                        "sha256": hashlib.sha256(payload).hexdigest(),
                    }
            manifest = {"outputs": outputs}
            config = {"tokenizer": {}, "model": {"max_tokens": 128}}

            def fake_build(cache_root, unused_source, unused_artifact,
                           unused_tokenizer, unused_processor, direction, split,
                           unused_max_tokens):
                destination = Path(cache_root) / (direction + "." + split)
                destination.mkdir(parents=True)
                for name in ("manifest.json", "input_ids.npy",
                             "attention_mask.npy", "labels.npy"):
                    (destination / name).write_bytes(name.encode("ascii"))
                return object()

            cache = root / "fresh-cache"
            with mock.patch.object(v5, "build_token_cache", side_effect=fake_build):
                datasets, inventory = _build_fresh_token_caches(
                    config, dataset, manifest, object(), cache
                )
            self.assertEqual(sum(len(rows) for rows in datasets.values()), 6)
            self.assertEqual(len(inventory), 24)
            with self.assertRaises(V5ContractError):
                _build_fresh_token_caches(config, dataset, manifest, object(), cache)

            mutated_cache = root / "mutated-cache"
            calls = {"count": 0}

            def mutating_build(*args):
                calls["count"] += 1
                result = fake_build(*args)
                if calls["count"] == 1:
                    (dataset / "zh-en.train.jsonl").write_bytes(b"tampered\n")
                return result

            with mock.patch.object(v5, "build_token_cache", side_effect=mutating_build), \
                    self.assertRaises(V5ContractError):
                _build_fresh_token_caches(
                    config, dataset, manifest, object(), mutated_cache
                )

    def test_saved_resume_is_independently_reloaded_with_exact_adam_cursor(self):
        state, unused_baseline, unused_artifact = self._resume_fixture()
        state["optimizer_step"] = 17000
        state["epoch"] = 12
        state["plan_index"] = 488
        v5_elapsed = 1.25
        state["elapsed_seconds"] = 13924.157000000065 + v5_elapsed
        for item in state["optimizer"]["state"].values():
            item["step"] = 16997

        class Torch:
            def load(self, unused_path, map_location, weights_only):
                self.arguments = (map_location, weights_only)
                return state

        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "resume.pt"
            path.write_bytes(b"serialized independently")
            torch = Torch()
            verified = _verify_output_resume(torch, path, 17000, 488, v5_elapsed)
            self.assertEqual(torch.arguments, ("cpu", False))
            self.assertEqual(verified["adamWStep"], 16997)
            state["optimizer"]["state"][0]["step"] = 16996
            with self.assertRaises(V5ContractError):
                _verify_output_resume(torch, path, 17000, 488, v5_elapsed)

    def test_internal_plan_executes_tail_batches_and_owns_cursor_and_losses(self):
        launch = self._launch_fixture()

        class FakeRuntime:
            def __init__(self, losses, fail_at=None, advance=True):
                self.step = V5_START_GLOBAL_STEP
                self.losses = iter(losses)
                self.fail_at = fail_at
                self.advance = advance
                self.saved = {}
                self.plan_index = 0
                self.tail_calls = []

            def current_optimizer_step(self):
                return self.step

            def train_optimizer_step(self, expected_step, unused_plan_index, budget_guard):
                budget_guard()
                if expected_step == self.fail_at:
                    raise RuntimeError("synthetic optimizer failure")
                if self.advance:
                    self.step = expected_step
                    self.plan_index += 4

            def directional_validation(self, budget_guard):
                budget_guard()
                return next(self.losses)

            def discard_partial_gradients(self):
                pass

            def current_plan_index(self):
                return self.plan_index

            def consume_partial_logical_batches(self, expected_plan_index, budget_guard):
                budget_guard()
                self.tail_calls.append(expected_plan_index)
                self.plan_index += 2

            def save_resume(self, path, step, plan_index, unused_elapsed):
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(b"resume state")
                self.saved[Path(path).resolve()] = (step, plan_index)

            def inspect_resume(self, path):
                step, plan_index = self.saved[Path(path).resolve()]
                return {
                    "optimizerStep": step,
                    "epoch": 12,
                    "planIndex": plan_index,
                    "optimizerStateEntries": 149,
                    "modelTensors": 155,
                    "scaler": True,
                    "rng": {"python": True, "torch": True, "cudaStates": 1},
                }

            def save_candidate(self, root, unused_step, unused_losses):
                root.mkdir()
                for name in (
                    "config.json", "generation_config.json", "model.safetensors",
                    "selection.json", "tokenizer.model",
                ):
                    (root / name).write_bytes(
                        b"tokenizer" if name == "tokenizer.model" else name.encode("ascii")
                    )

        class Clock:
            def __init__(self):
                self.value = 0.0

            def __call__(self):
                self.value += 0.001
                return self.value

        improving = [
            {"zh-en": 3.2, "en-zh": 4.1},
            {"zh-en": 3.1, "en-zh": 4.0},
            {"zh-en": 3.0, "en-zh": 3.9},
        ]
        runtime = FakeRuntime(improving)
        terminal = _execute_v5_training_plan(runtime, lambda: None)
        self.assertEqual(terminal["status"], "completed")
        self.assertEqual(terminal["currentStep"], 18284)
        self.assertEqual(terminal["planIndex"], 5626)
        self.assertEqual(runtime.tail_calls, [5624])

        losses = [
            {"zh-en": 3.3, "en-zh": 4.1},
            {"zh-en": 3.2, "en-zh": 4.2},
        ]
        early = _execute_v5_training_plan(FakeRuntime(losses), lambda: None)
        self.assertEqual(early["status"], "early_stopped")
        self.assertEqual(early["currentStep"], 18000)

        with self.assertRaisesRegex(RuntimeError, "synthetic optimizer failure"):
            _execute_v5_training_plan(
                FakeRuntime(improving, fail_at=16900), lambda: None
            )
        with self.assertRaises(V5ContractError):
            _execute_v5_training_plan(
                FakeRuntime(improving, advance=False), lambda: None
            )

    def test_production_failure_terminal_survives_discard_and_resume_errors(self):
        launch = self._launch_fixture()

        class BrokenRuntime:
            def discard_partial_gradients(self):
                raise RuntimeError("discard broke")

            def current_optimizer_step(self):
                return 16899

            def current_plan_index(self):
                return 84

            def save_resume(self, *unused):
                raise RuntimeError("save broke")

        class Clock:
            def __init__(self):
                self.value = 0.0

            def __call__(self):
                self.value += 0.01
                return self.value

        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary) / "failed"
            with mock.patch.object(v5, "_TorchV5Runtime", return_value=BrokenRuntime()), \
                    mock.patch.object(
                        v5, "_execute_v5_training_plan",
                        side_effect=RuntimeError("primary failure"),
                    ):
                with self.assertRaisesRegex(RuntimeError, "primary failure"):
                    _run_production_v5(
                        object(), launch, {}, Path("dataset"), {}, Path("selected"),
                        Path("resume.pt"), Path("cache"), root, clock=Clock(),
                    )
            terminal = json.loads(
                (root / "v5-terminal-v1.json").read_text(encoding="utf-8")
            )
            self.assertEqual(terminal["status"], "failed")
            self.assertEqual(terminal["finalGlobalStep"], 16899)
            self.assertEqual(terminal["planIndex"], 84)
            self.assertTrue(any("discard broke" in row for row in terminal["secondaryErrors"]))
            self.assertTrue(any("save broke" in row for row in terminal["secondaryErrors"]))
            budget = json.loads(
                (root / "budget-terminal-v1.json").read_text(encoding="utf-8")
            )
            self.assertEqual(budget["status"], "failed")


if __name__ == "__main__":
    unittest.main()
