import hashlib
import json
import tempfile
import unittest
from pathlib import Path

from tools.translation.distill_en_zh import (
    DistillationError,
    build_output_row,
    build_training_view_manifest,
    canonical_json_bytes,
    generation_budget_snapshot,
    load_distillation_config,
    materialize_training_view,
)
from tools.translation.train_rescue import (
    CANDIDATE_DIR,
    build_rescue_objective_hashes,
    checked_rescue_budget_snapshot,
    cumulative_rescue_elapsed,
    evaluate_rescue_gates,
    rescue_elapsed_floor,
    rescue_budget_snapshot,
    summarize_audited_manual_results,
    validate_rescue_resume_state,
    verify_epoch2_authorization,
    verify_rescue_bundle,
)


ROOT = Path(__file__).parent
CONFIG = ROOT / "config" / "distillation-run-v4.json"


class FakeStudentProcessor:
    def encode(self, text, out_type=int):
        del out_type
        return list(range(len(text)))


class RescueContractTest(unittest.TestCase):
    def _bundle(self, root):
        config = load_distillation_config(CONFIG)
        processor = FakeStudentProcessor()
        audit = root / "en-zh.distilled.train.jsonl"
        audit.write_bytes(b"".join(canonical_json_bytes(row) for row in (
            build_output_row(0, "one", "一", processor),
            build_output_row(1, "two 2", "错 3", processor, original_target="二 2"),
        )))
        view = root / "en-zh.rescue.train.jsonl"
        view_result = materialize_training_view(audit, view, expected_rows=2)
        view_manifest = build_training_view_manifest(audit, view, view_result)
        view_manifest_path = root / "training-view-manifest-v1.json"
        view_manifest_path.write_bytes(canonical_json_bytes(view_manifest))
        generation_seconds = 100.0
        budget = generation_budget_snapshot(config, generation_seconds)
        sidecar_path = root / "fallback-preservation-warnings-v1.jsonl"
        sidecar_path.write_bytes(canonical_json_bytes({
            "id": 1,
            "source_sha256": json.loads(audit.read_text(encoding="utf-8").splitlines()[1])["source_sha256"],
            "originalPreservationWarnings": [],
        }))
        sidecar_bytes = sidecar_path.stat().st_size
        sidecar_sha256 = hashlib.sha256(sidecar_path.read_bytes()).hexdigest()
        distillation_manifest = {
            "schema_version": 1,
            "teacher": {
                "repo": config["teacher"]["repo"],
                "revision": config["teacher"]["revision"],
                "prefix": config["teacher"]["prefix"],
            },
            "source": {
                "path": config["data"]["source_file"],
                "rows": config["data"]["source_rows"],
                "bytes": config["data"]["source_bytes"],
                "sha256": config["data"]["source_sha256"],
            },
            "output": view_manifest["audit"],
            "fullAudit": view_manifest["audit"],
            "chunks": [{"path": "00000000.jsonl", "rows": 2, "bytes": audit.stat().st_size, "sha256": view_manifest["audit"]["sha256"]}],
            "latin_residue_rows": 0,
            "target_origins": {
                "teacher": view_result["teacher"],
                "original_fallback": view_result["original_fallback"],
                "hard_fail": 0,
            },
            "validationPolicy": config["validationPolicy"],
            "generation": {
                "precision": "fp16", "num_beams": 4, "do_sample": False,
                "renormalize_logits": True, "max_tokens": 128, "batch_size": 64,
            },
            "generation_gpu_seconds": generation_seconds,
            "gpuLedger": {"probeAndLoad": config["gpuLedger"], "budget": budget},
            "cumulative_gpu_seconds": budget["cumulativeActualSeconds"],
            "cumulative_with_reserve_seconds": budget["cumulativeWithReserveSeconds"],
            "fallbackPreservationWarnings": {
                "path": sidecar_path.name,
                "rows": 1,
                "bytes": sidecar_bytes,
                "sha256": sidecar_sha256,
                "fallbackWithPreservationWarnings": 0,
                "number": 0,
                "url": 0,
            },
        }
        distillation_manifest_path = root / "distillation-manifest-v1.json"
        distillation_manifest_path.write_bytes(canonical_json_bytes(distillation_manifest))
        manifest_sha256 = hashlib.sha256(distillation_manifest_path.read_bytes()).hexdigest()
        verification = {
            "schema_version": 1,
            "verified": True,
            "rows": 2,
            "output_bytes": audit.stat().st_size,
            "output_sha256": view_manifest["audit"]["sha256"],
            "network_calls": 0,
            "gpuLedger": budget,
            "manifest_sha256": manifest_sha256,
            "student_tokenizer_sha256": config["student"]["tokenizer_sha256"],
        }
        verification_one = root / "offline-verification-1.json"
        verification_two = root / "offline-verification-2.json"
        verification_one.write_bytes(canonical_json_bytes(verification))
        verification_two.write_bytes(canonical_json_bytes(verification))
        return (
            config, audit, view, view_manifest_path, distillation_manifest_path,
            verification_one, verification_two,
        )

    def test_rescue_view_is_bound_to_training_view_audit_and_teacher_ledger(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (
                config, unused_audit, view, view_manifest, distillation_manifest,
                verification_one, verification_two,
            ) = self._bundle(root)
            bundle = verify_rescue_bundle(
                config, view, view_manifest, distillation_manifest,
                verification_one, verification_two, expected_rows=2
            )
            self.assertEqual(bundle["view_artifact"]["count"], 2)
            self.assertEqual(bundle["teacher_generation_gpu_seconds"], 100.0)

            original = view.read_bytes()
            view.write_bytes(original + original.splitlines(keepends=True)[0])
            with self.assertRaises(DistillationError):
                verify_rescue_bundle(
                    config, view, view_manifest, distillation_manifest,
                    verification_one, verification_two, expected_rows=2
                )
            view.write_bytes(original)
            original_view_manifest = view_manifest.read_bytes()
            view.write_bytes(b"".join(reversed(original.splitlines(keepends=True))))
            rebound = json.loads(original_view_manifest.decode("utf-8"))
            rebound["output"]["bytes"] = view.stat().st_size
            rebound["output"]["sha256"] = hashlib.sha256(view.read_bytes()).hexdigest()
            view_manifest.write_bytes(canonical_json_bytes(rebound))
            with self.assertRaises(DistillationError):
                verify_rescue_bundle(
                    config, view, view_manifest, distillation_manifest,
                    verification_one, verification_two, expected_rows=2
                )
            view.write_bytes(original)
            view_manifest.write_bytes(original_view_manifest)
            manifest = json.loads(distillation_manifest.read_text(encoding="utf-8"))
            manifest["generation_gpu_seconds"] = 99.0
            distillation_manifest.write_bytes(canonical_json_bytes(manifest))
            with self.assertRaises(DistillationError):
                verify_rescue_bundle(
                    config, view, view_manifest, distillation_manifest,
                    verification_one, verification_two, expected_rows=2
                )

    def test_bundle_rejects_partial_manifest_and_noncanonical_verification_receipt(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (
                config, unused_audit, view, view_manifest, distillation_manifest,
                verification_one, verification_two,
            ) = self._bundle(root)
            manifest_bytes = distillation_manifest.read_bytes()
            manifest = json.loads(manifest_bytes.decode("utf-8"))
            del manifest["chunks"]
            distillation_manifest.write_bytes(canonical_json_bytes(manifest))
            with self.assertRaises(DistillationError):
                verify_rescue_bundle(
                    config, view, view_manifest, distillation_manifest,
                    verification_one, verification_two, expected_rows=2
                )
            with self.assertRaises(DistillationError):
                verify_rescue_bundle(
                    config, view, view_manifest, distillation_manifest,
                    verification_one, verification_one, expected_rows=2
                )
            distillation_manifest.write_bytes(manifest_bytes)
            verification_two.write_bytes(b"  " + verification_two.read_bytes())
            with self.assertRaises(DistillationError):
                verify_rescue_bundle(
                    config, view, view_manifest, distillation_manifest,
                    verification_one, verification_two, expected_rows=2
                )

    def test_resume_state_restores_exact_cursor_elapsed_history_and_best(self):
        state = {
            "schema_version": 1,
            "model": {},
            "optimizer": {},
            "scaler": {},
            "rescue_step": 500,
            "epoch": 0,
            "next_group": 500,
            "elapsed_seconds": 321.5,
            "python_random_state": (3, (), None),
            "torch_random_state": "torch",
            "cuda_random_state": ["cuda"],
            "validation_history": [{"rescue_step": 500, "loss": 3.6}],
            "best_loss": 3.6,
            "best_step": 500,
            "objective_hashes": {"contract": "a" * 64},
        }
        restored = validate_rescue_resume_state(
            state, total_groups=1406, expected_objective_hashes={"contract": "a" * 64}
        )
        self.assertEqual(restored, (500, 321.5, [{"rescue_step": 500, "loss": 3.6}], 3.6, 500))
        for mutation in (
            {**state, "next_group": 499},
            {**state, "elapsed_seconds": -1},
            {**state, "validation_history": [{"rescue_step": 501, "loss": 3.6}]},
            {**state, "best_step": None},
            {**state, "objective_hashes": {"contract": "b" * 64}},
        ):
            with self.assertRaises(DistillationError):
                validate_rescue_resume_state(
                    mutation, total_groups=1406, expected_objective_hashes={"contract": "a" * 64}
                )
        self.assertEqual(
            rescue_elapsed_floor(
                321.5,
                {"rescue_step": 700, "rescue_gpu_seconds": 500.0, "objective_hashes": {"contract": "a" * 64}},
                {"contract": "a" * 64},
            ),
            500.0,
        )
        with self.assertRaises(DistillationError):
            rescue_elapsed_floor(
                321.5,
                {"rescue_step": 700, "rescue_gpu_seconds": 500.0, "objective_hashes": {"contract": "b" * 64}},
                {"contract": "a" * 64},
            )
        self.assertEqual(cumulative_rescue_elapsed(500.0, 100.0, 125.0), 525.0)
        epoch2_state = {**state, "epoch": 1, "best_loss": 3.4}
        epoch2_state["validation_history"] = [{"rescue_step": 500, "loss": 3.4}]
        self.assertEqual(
            validate_rescue_resume_state(
                epoch2_state,
                total_groups=1406,
                expected_objective_hashes={"contract": "a" * 64},
                expected_epoch=1,
                expected_baseline_loss=3.5,
            )[0],
            500,
        )

    def test_manual_results_are_bound_rowwise_to_manual_asset(self):
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "manual-results-v1.jsonl"
            manual_rows = []
            result_rows = []
            for row_id in range(1, 101):
                direction = "zh-en" if row_id <= 50 else "en-zh"
                manual = {
                    "id": row_id,
                    "direction": direction,
                    "source": "source-%d" % row_id,
                    "reference": "reference-%d" % row_id,
                    "categories": ["general"],
                }
                manual_rows.append(manual)
                result_rows.append({
                    **manual,
                    "output": "output-%d" % row_id,
                    "fatal_corruptions": [],
                    "pass": True,
                    "reason": "audited",
                })
            path.write_bytes(b"".join(canonical_json_bytes(row) for row in result_rows))
            summary, artifact = summarize_audited_manual_results(path, manual_rows)
            self.assertEqual(summary["zh-en"]["passed"], 50)
            self.assertEqual(summary["en-zh"]["passed"], 50)
            self.assertEqual(artifact["rows"], 100)
            result_rows[0]["source"] = "different"
            path.write_bytes(b"".join(canonical_json_bytes(row) for row in result_rows))
            with self.assertRaises(DistillationError):
                summarize_audited_manual_results(path, manual_rows)
            result_rows[0]["source"] = manual_rows[0]["source"]
            result_rows[0]["output"] = None
            path.write_bytes(b"".join(canonical_json_bytes(row) for row in result_rows))
            with self.assertRaises(DistillationError):
                summarize_audited_manual_results(path, manual_rows)

    def test_epoch2_and_promotion_gates_execute_fail_closed(self):
        config = load_distillation_config(CONFIG)
        candidate = {"model_sha256": "a" * 64, "tokenizer_sha256": config["student"]["tokenizer_sha256"]}
        manual_asset = {"path": "manual-eval-v1.jsonl", "rows": 100, "bytes": 123, "sha256": "b" * 64}
        manual_results = {"path": "manual-results-v1.jsonl", "rows": 100, "bytes": 456, "sha256": "e" * 64}
        training_artifact = {"path": "training-v1.json", "bytes": 789, "sha256": "f" * 64}
        epoch1_objective_hashes = {"contract": "1" * 64}
        epoch2_manual = {
            "zh-en": {"total": 50, "passed": 32, "fatal_corruptions": 5},
            "en-zh": {"total": 50, "passed": 33, "fatal_corruptions": 2},
        }
        epoch2 = evaluate_rescue_gates(config, {
            "schema_version": 1,
            "candidate": candidate,
            "manualAsset": manual_asset,
            "manualResults": manual_results,
            "manual": epoch2_manual,
            "flores": None,
        }, candidate, manual_asset, manual_results, epoch2_manual,
            training_artifact, epoch1_objective_hashes, 1)
        self.assertTrue(epoch2["epoch2_allowed"])
        self.assertTrue(epoch2["epoch2_launch_allowed"])
        self.assertFalse(epoch2["promotion_allowed"])
        promotion_manual = {
            "zh-en": {"total": 50, "passed": 45, "fatal_corruptions": 0},
            "en-zh": {"total": 50, "passed": 45, "fatal_corruptions": 0},
        }
        flores_files = [
            {"language": "cmn_Hans", "path": "devtest/cmn_Hans.jsonl", "bytes": 1, "sha256": "c" * 64},
            {"language": "eng_Latn", "path": "devtest/eng_Latn.jsonl", "bytes": 1, "sha256": "d" * 64},
        ]
        promoted = evaluate_rescue_gates(config, {
            "schema_version": 1,
            "candidate": candidate,
            "manualAsset": manual_asset,
            "manualResults": manual_results,
            "manual": promotion_manual,
            "flores": {
                "repo": "openlanguagedata/flores_plus",
                "revision": "b3a5298db5721c8a682e7ef00a37fcc9ab522757",
                "files": flores_files,
                "metrics": {
                    "zh-en": {"bleu": 19.0, "chrf2": 49.0},
                    "en-zh": {"bleu": 17.0, "chrf2": 40.0},
                },
            },
        }, candidate, manual_asset, manual_results, promotion_manual,
            training_artifact, epoch1_objective_hashes, 1, flores_files)
        self.assertTrue(promoted["epoch2_allowed"])
        self.assertTrue(promoted["promotion_allowed"])
        epoch2_final_gate = evaluate_rescue_gates(config, {
            "schema_version": 1,
            "candidate": candidate,
            "manualAsset": manual_asset,
            "manualResults": manual_results,
            "manual": promotion_manual,
            "flores": promoted["flores"],
        }, candidate, manual_asset, manual_results, promotion_manual,
            training_artifact, epoch1_objective_hashes, 2, flores_files)
        self.assertFalse(epoch2_final_gate["epoch2_launch_allowed"])
        self.assertEqual(epoch2_final_gate["epoch2_status"], "max_epochs_reached")
        self.assertTrue(epoch2_final_gate["promotion_allowed"])
        invalid = json.loads(json.dumps({
            "schema_version": 1, "candidate": candidate, "manualAsset": manual_asset,
            "manualResults": manual_results,
            "manual": {
                "zh-en": {"total": 49, "passed": 49, "fatal_corruptions": 0},
                "en-zh": {"total": 50, "passed": 50, "fatal_corruptions": 0},
            },
            "flores": None,
        }))
        with self.assertRaises(DistillationError):
            evaluate_rescue_gates(
                config, invalid, candidate, manual_asset, manual_results, invalid["manual"],
                training_artifact, epoch1_objective_hashes, 1,
            )
        infinite = json.loads(json.dumps({
            "schema_version": 1, "candidate": candidate, "manualAsset": manual_asset,
            "manualResults": manual_results,
            "manual": promoted["manual"],
            "flores": promoted["flores"],
        }))
        infinite["flores"]["metrics"]["zh-en"]["bleu"] = float("inf")
        self.assertFalse(
            evaluate_rescue_gates(
                config, infinite, candidate, manual_asset, manual_results,
                infinite["manual"], training_artifact, epoch1_objective_hashes,
                1, flores_files,
            )["promotion_allowed"]
        )
        numeric_string = json.loads(json.dumps(promoted["flores"]))
        numeric_string["metrics"]["zh-en"]["bleu"] = "19.0"
        numeric_string_evaluation = {
            "schema_version": 1,
            "candidate": candidate,
            "manualAsset": manual_asset,
            "manualResults": manual_results,
            "manual": promotion_manual,
            "flores": numeric_string,
        }
        self.assertFalse(
            evaluate_rescue_gates(
                config, numeric_string_evaluation, candidate, manual_asset,
                manual_results, promotion_manual, training_artifact,
                epoch1_objective_hashes, 1, flores_files,
            )["promotion_allowed"]
        )
        self.assertEqual(CANDIDATE_DIR, "candidate-epoch1")

    def test_epoch2_authorization_binds_gate_candidate_training_report_and_objective(self):
        config = load_distillation_config(CONFIG)
        candidate = {"model_sha256": "a" * 64, "tokenizer_sha256": "b" * 64}
        objective_hashes = {
            "distillation_config": "1" * 64,
            "training_config": "2" * 64,
            "dataset_manifest": "3" * 64,
            "rescue_view": "4" * 64,
            "training_view_manifest": "d" * 64,
            "distillation_manifest": "e" * 64,
            "offline_verification_one": "5" * 64,
            "offline_verification_two": "6" * 64,
            "baseline_model": "7" * 64,
            "baseline_tokenizer": "8" * 64,
            "rescue_epoch": hashlib.sha256(b"1").hexdigest(),
        }
        ledger = rescue_budget_snapshot(config, 100.0, 500.0)
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            training_path = root / "training-v1.json"
            training = {
                "schema_version": 1,
                "epoch": 1,
                "seed": config["seed"],
                "plan_epoch_index": 0,
                "optimizer_reset": True,
                "rescue_steps": 1406,
                "logical_batches": 5624,
                "dropped_partial_logical_batches": 2,
                "validation_history": [
                    {"rescue_step": 500, "loss": 3.6},
                    {"rescue_step": 1000, "loss": 3.55},
                    {"rescue_step": 1406, "loss": 3.5},
                ],
                "baseline_validation_loss": 3.7039039318084717,
                "best_rescue_step": 1406,
                "objective_hashes": objective_hashes,
                "candidate": candidate,
                "candidate_checkpoint": "candidate-epoch1/selected",
                "promotion_allowed": False,
                "promotion_status": "pending_manual_and_flores_gate",
                "resumed": False,
                "rescue_gpu_seconds": 500.0,
                "epoch_gpu_seconds": 500.0,
                "best_validation_loss": 3.5,
                "teacher_generation_gpu_seconds": 100.0,
                "probe_gpu_seconds": config["gpuLedger"]["probeActualSeconds"],
                "gpuLedger": ledger,
                "cumulative_gpu_seconds": ledger["cumulativeActualSeconds"],
                "training_view_manifest_sha256": "d" * 64,
                "distillation_manifest_sha256": "e" * 64,
                "peak_cuda_bytes": 123,
                "last_progress": {
                    "schema_version": 1,
                    "rescue_step": 1406,
                    "loss": 3.5,
                    "learning_rate": 0.00001,
                    "rescue_gpu_seconds": 500.0,
                    "cumulative_gpu_seconds": ledger["cumulativeActualSeconds"],
                    "objective_hashes": objective_hashes,
                },
            }
            training_path.write_bytes(canonical_json_bytes(training))
            training_bytes = training_path.read_bytes()
            training_artifact = {
                "path": training_path.name,
                "bytes": training_path.stat().st_size,
                "sha256": hashlib.sha256(training_path.read_bytes()).hexdigest(),
            }
            gate_path = root / "gate-v1.json"
            gate = {
                "schema_version": 1,
                "epoch2_allowed": True,
                "epoch2_launch_allowed": True,
                "epoch2_status": "authorized",
                "promotion_allowed": False,
                "candidate": candidate,
                "candidateEpoch": 1,
                "trainingReport": training_artifact,
                "objectiveHashes": objective_hashes,
                "manualAsset": {
                    "path": "manual-eval-v1.jsonl", "rows": 100,
                    "bytes": 123, "sha256": "f" * 64,
                },
                "manualResults": {
                    "path": "manual-results-v1.jsonl", "rows": 100,
                    "bytes": 456, "sha256": "1" * 64,
                },
                "manual": {
                    "zh-en": {"total": 50, "passed": 32, "fatal_corruptions": 0},
                    "en-zh": {"total": 50, "passed": 33, "fatal_corruptions": 2},
                },
                "flores": None,
            }
            gate_path.write_bytes(canonical_json_bytes(gate))
            authorization = verify_epoch2_authorization(
                gate_path, training_path, candidate, config, 100.0,
                objective_hashes,
            )
            self.assertEqual(authorization["prior_rescue_gpu_seconds"], 500.0)
            self.assertEqual(authorization["baseline_validation_loss"], 3.5)
            rejected = dict(gate, epoch2_launch_allowed=False)
            gate_path.write_bytes(canonical_json_bytes(rejected))
            with self.assertRaises(DistillationError):
                verify_epoch2_authorization(
                    gate_path, training_path, candidate, config, 100.0,
                    objective_hashes,
                )
            gate_path.write_bytes(canonical_json_bytes(gate))
            training_path.write_bytes(canonical_json_bytes({
                "schema_version": 1,
                "epoch": 1,
                "candidate": candidate,
                "objective_hashes": objective_hashes,
                "rescue_gpu_seconds": 500.0,
                "best_validation_loss": 3.5,
            }))
            with self.assertRaises(DistillationError):
                verify_epoch2_authorization(
                    gate_path, training_path, candidate, config, 100.0,
                    objective_hashes,
                )
            training_path.write_bytes(training_bytes)
            forged = dict(gate, manual={})
            gate_path.write_bytes(canonical_json_bytes(forged))
            with self.assertRaises(DistillationError):
                verify_epoch2_authorization(
                    gate_path, training_path, candidate, config, 100.0,
                    objective_hashes,
                )
            training_path.write_bytes(training_bytes)
            gate_path.write_bytes(canonical_json_bytes(gate))
            with self.assertRaises(DistillationError):
                verify_epoch2_authorization(
                    gate_path,
                    training_path,
                    candidate,
                    config,
                    100.0,
                    {**objective_hashes, "dataset_manifest": "0" * 64},
                )

    def test_rescue_objective_hashes_are_computed_from_every_real_input(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            paths = {}
            for name in (
                "rescue-view.jsonl", "training-view.json", "distillation.json",
                "receipt-one.json", "receipt-two.json",
            ):
                path = root / name
                path.write_bytes((name + "\n").encode("utf-8"))
                paths[name] = path
            baseline = root / "baseline"
            baseline.mkdir()
            (baseline / "model.safetensors").write_bytes(b"model")
            (baseline / "tokenizer.model").write_bytes(b"tokenizer")
            config = {"schema_version": 4, "value": "config"}
            training_config = {"schema_version": 3, "value": "training"}
            dataset_manifest = {"schema_version": 1, "value": "dataset"}
            objective = build_rescue_objective_hashes(
                config,
                training_config,
                dataset_manifest,
                paths["rescue-view.jsonl"],
                paths["training-view.json"],
                paths["distillation.json"],
                paths["receipt-one.json"],
                paths["receipt-two.json"],
                baseline,
                1,
            )
            self.assertEqual(set(objective), {
                "distillation_config", "training_config", "dataset_manifest",
                "rescue_view", "training_view_manifest", "distillation_manifest",
                "offline_verification_one", "offline_verification_two",
                "baseline_model", "baseline_tokenizer", "rescue_epoch",
            })
            changed_inputs = [
                ({**config, "value": "changed"}, training_config, dataset_manifest),
                (config, {**training_config, "value": "changed"}, dataset_manifest),
                (config, training_config, {**dataset_manifest, "value": "changed"}),
            ]
            for changed_config, changed_training, changed_dataset in changed_inputs:
                changed = build_rescue_objective_hashes(
                    changed_config,
                    changed_training,
                    changed_dataset,
                    paths["rescue-view.jsonl"],
                    paths["training-view.json"],
                    paths["distillation.json"],
                    paths["receipt-one.json"],
                    paths["receipt-two.json"],
                    baseline,
                    1,
                )
                self.assertNotEqual(changed, objective)
            for name in (
                "rescue-view.jsonl", "training-view.json", "distillation.json",
                "receipt-one.json", "receipt-two.json",
            ):
                original = paths[name].read_bytes()
                paths[name].write_bytes(original + b"changed\n")
                changed = build_rescue_objective_hashes(
                    config,
                    training_config,
                    dataset_manifest,
                    paths["rescue-view.jsonl"],
                    paths["training-view.json"],
                    paths["distillation.json"],
                    paths["receipt-one.json"],
                    paths["receipt-two.json"],
                    baseline,
                    1,
                )
                self.assertNotEqual(changed, objective)
                paths[name].write_bytes(original)

    def test_final_validation_elapsed_is_in_rescue_budget(self):
        config = load_distillation_config(CONFIG)
        snapshot = rescue_budget_snapshot(config, teacher_generation_seconds=1000.0, rescue_elapsed_seconds=500.0)
        self.assertEqual(snapshot["probeAndLoadActualSeconds"], 677.9)
        self.assertEqual(snapshot["teacherGenerationActualSeconds"], 1000.0)
        self.assertEqual(snapshot["rescueActualSeconds"], 500.0)
        with self.assertRaises(DistillationError):
            rescue_budget_snapshot(config, teacher_generation_seconds=26000.0, rescue_elapsed_seconds=3000.0)

    def test_rescue_budget_overrun_is_journaled_with_unadvanced_model_cursor(self):
        config = load_distillation_config(CONFIG)
        objective_hashes = {"contract": "a" * 64}
        cursor = {
            "stage": "optimizer_step",
            "resumable_model_step": 500,
            "attempted_rescue_step": 501,
        }
        with tempfile.TemporaryDirectory() as temporary:
            terminal = Path(temporary) / "budget-terminal-v1.json"
            with self.assertRaises(DistillationError):
                checked_rescue_budget_snapshot(
                    config,
                    teacher_generation_seconds=26000.0,
                    rescue_elapsed_seconds=3000.0,
                    terminal_path=terminal,
                    objective_hashes=objective_hashes,
                    cursor=cursor,
                )
            payload = json.loads(terminal.read_text(encoding="utf-8"))
            self.assertEqual(payload["measured_gpu_seconds"], 3000.0)
            self.assertEqual(payload["cursor"], cursor)


if __name__ == "__main__":
    unittest.main()
