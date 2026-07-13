import hashlib
import json
import tempfile
import unittest
from pathlib import Path
from unittest import mock

from tools.translation.diagnose_translation import (
    DiagnosticEvaluationError,
    _published_dataset_manifest_load,
    build_budget_terminal,
    build_checkpoint_comparison,
    evaluate_checkpoint,
    evaluation_budget_snapshot,
    load_bist_rows,
    load_budget_evidence,
)
from tools.translation.distill_en_zh import STUDENT_SHA256, canonical_json_bytes


class DiagnosticTranslationTest(unittest.TestCase):
    def _write(self, path, value):
        path.write_bytes(canonical_json_bytes(value))
        return {
            "path": path.name,
            "bytes": path.stat().st_size,
            "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
        }

    def _diagnostic_provenance(self):
        return {
            "schema_version": 1,
            "status": "REJECTED_NOT_PROMOTABLE",
            "gate_eligible": False,
            "reason": "rejected",
            "final_rescue_step": 1406,
            "resume_epoch_index": 0,
            "baseline_validation_loss": 3.7,
            "validation_history": [{"rescue_step": 1406, "loss": 3.8}],
            "checkpoint": {
                "model": {"path": "model.safetensors", "bytes": 1, "sha256": "d" * 64},
                "tokenizer": {"path": "tokenizer.model", "bytes": 1, "sha256": "4" * 64},
            },
            "gpuLedger": {
                "baselineGpuSeconds": 10.0,
                "probeAndLoadActualSeconds": 2.0,
                "teacherGenerationActualSeconds": 20.0,
                "rescueActualSeconds": 8.0,
                "cumulativeActualSeconds": 40.0,
                "totalBudgetSeconds": 43200.0,
                "remainingSeconds": 43160.0,
            },
            "objectiveHashes": {"fixture": "a" * 64},
            "sourceArtifacts": {
                "progress": {"path": "progress-v1.json", "bytes": 1, "sha256": "b" * 64},
                "trainingReport": {"path": "training-v1.json", "bytes": 1, "sha256": "c" * 64},
                "baselineReplayReceipt": {"path": "baseline-replay-v1.json", "bytes": 1, "sha256": "e" * 64},
            },
        }

    def _evaluation_report(
        self, label, model_sha, tokenizer_sha, prior_artifact, receipt_artifact,
        prior, elapsed, diagnostic_provenance,
    ):
        return {
            "schema_version": 1,
            "label": label,
            "checkpoint": {
                "model": {"path": "model.safetensors", "bytes": 1, "sha256": model_sha},
                "tokenizer": {"path": "tokenizer.model", "bytes": 1, "sha256": tokenizer_sha},
            },
            "dataset": {
                "manifest": {"path": "run1-manifest.json", "bytes": 1, "sha256": "f" * 64},
                "repo": "Mxode/BiST",
                "revision": "aca6be897afc319f779009379c8b849c1eb8d63e",
                "rows_per_direction": {"validation": 5000, "test": 5000},
            },
            "directional_validation_loss": {"zh-en": 3.5 + elapsed / 100, "en-zh": 3.9 + elapsed / 100},
            "bist_test": {
                "zh-en": {"bleu": 20.0 + elapsed, "chrf2": 45.0 + elapsed, "bleu_signature": "b", "chrf2_signature": "c"},
                "en-zh": {"bleu": 15.0 + elapsed, "chrf2": 35.0 + elapsed, "bleu_signature": "b", "chrf2_signature": "c"},
            },
            "bistOutputs": {"path": "bist.jsonl", "bytes": 1, "sha256": "1" * 64, "rows": 10000},
            "manual": {
                "asset": {"path": "manual.jsonl", "bytes": 1, "sha256": "2" * 64, "rows": 100},
                "results": {"path": "results.jsonl", "bytes": 1, "sha256": "3" * 64, "rows": 100},
                "audit_complete": False,
            },
            "decode": {"strategy": "greedy", "max_tokens": 128, "tie": "smallest-token-id"},
            "diagnosticProvenance": diagnostic_provenance,
            "budgetRootProvenance": None,
            "priorEvidence": prior_artifact,
            "budgetReceipt": receipt_artifact,
            "gpuLedger": evaluation_budget_snapshot(prior, elapsed, 43200.0),
            "peak_cuda_bytes": 1,
        }

    def test_bist_rows_are_canonical_exact_and_direction_bound(self):
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "test.jsonl"
            rows = [
                {"source": "甲", "target": "A", "direction_id": 32001},
                {"source": "乙", "target": "B", "direction_id": 32001},
            ]
            path.write_bytes(
                "".join(
                    json.dumps(row, ensure_ascii=False, separators=(",", ":")) + "\n"
                    for row in rows
                ).encode("utf-8")
            )
            self.assertEqual(load_bist_rows(path, "zh-en", 2), rows)
            with self.assertRaises(DiagnosticEvaluationError):
                load_bist_rows(path, "en-zh", 2)
            with self.assertRaises(DiagnosticEvaluationError):
                load_bist_rows(path, "zh-en", 3)
            path.write_bytes(path.read_bytes().replace(b"\n", b"\r\n"))
            with self.assertRaises(DiagnosticEvaluationError):
                load_bist_rows(path, "zh-en", 2)

    def test_prepare_bist_manifest_publication_format_is_exact(self):
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "run1-manifest.json"
            manifest = {
                "schema_version": 1,
                "dataset": {
                    "repo": "Mxode/BiST",
                    "revision": "aca6be897afc319f779009379c8b849c1eb8d63e",
                },
                "outputs": {},
            }
            published = (
                json.dumps(manifest, ensure_ascii=False, indent=2) + "\n"
            ).encode("utf-8")
            path.write_bytes(published)
            published_sha256 = hashlib.sha256(published).hexdigest()
            self.assertEqual(
                _published_dataset_manifest_load(path, published_sha256), manifest
            )
            path.write_bytes(canonical_json_bytes(manifest))
            with self.assertRaises(DiagnosticEvaluationError):
                _published_dataset_manifest_load(path, published_sha256)

    def test_prepare_bist_manifest_rejects_reordered_keys(self):
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "run1-manifest.json"
            original = {
                "schema_version": 1,
                "dataset": {
                    "repo": "Mxode/BiST",
                    "revision": "aca6be897afc319f779009379c8b849c1eb8d63e",
                },
                "outputs": {},
            }
            published = (
                json.dumps(original, ensure_ascii=False, indent=2) + "\n"
            ).encode("utf-8")
            published_sha256 = hashlib.sha256(published).hexdigest()
            for reordered in (
                {
                    "dataset": original["dataset"],
                    "schema_version": 1,
                    "outputs": {},
                },
                {
                    "schema_version": 1,
                    "dataset": {
                        "revision": original["dataset"]["revision"],
                        "repo": original["dataset"]["repo"],
                    },
                    "outputs": {},
                },
            ):
                path.write_bytes(
                    (json.dumps(reordered, ensure_ascii=False, indent=2) + "\n")
                    .encode("utf-8")
                )
                with self.assertRaises(DiagnosticEvaluationError):
                    _published_dataset_manifest_load(path, published_sha256)

    def test_evaluation_budget_is_monotonic_finite_and_bounded(self):
        budget = evaluation_budget_snapshot(27338.577, 100.5, 43200.0)
        self.assertEqual(budget["cumulativeActualSeconds"], 27439.077)
        self.assertAlmostEqual(budget["remainingSeconds"], 15760.923)
        for prior, elapsed, total in ((True, 1, 10), (0, -1, 10), (9, 2, 10)):
            with self.assertRaises(DiagnosticEvaluationError):
                evaluation_budget_snapshot(prior, elapsed, total)

        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            provenance_path = root / "diagnostic-provenance-v1.json"
            provenance_artifact = self._write(
                provenance_path, self._diagnostic_provenance()
            )
            evidence = load_budget_evidence(provenance_path)
            self.assertEqual(evidence["cumulativeActualSeconds"], 40.0)
            terminal = build_budget_terminal(
                "translation_diagnostic_evaluation",
                "failed",
                provenance_artifact,
                40.0,
                5.0,
                43200.0,
                "synthetic failure",
            )
            terminal_path = root / "budget-terminal-v1.json"
            self._write(terminal_path, terminal)
            self.assertEqual(
                load_budget_evidence(terminal_path)["cumulativeActualSeconds"], 45.0
            )
            terminal["cumulativeActualSeconds"] += 1
            self._write(terminal_path, terminal)
            with self.assertRaises(DiagnosticEvaluationError):
                load_budget_evidence(terminal_path)

            forged = build_budget_terminal(
                "translation_diagnostic_evaluation", "completed",
                provenance_artifact, 0.0, 5.0, 43200.0, None,
                provenance_artifact,
            )
            self._write(terminal_path, forged)
            with self.assertRaises(DiagnosticEvaluationError):
                load_budget_evidence(terminal_path)

            forged = build_budget_terminal(
                "translation_diagnostic_evaluation", "completed",
                provenance_artifact, 40.0, 5.0, 43199.0, None,
                provenance_artifact,
            )
            self._write(terminal_path, forged)
            with self.assertRaises(DiagnosticEvaluationError):
                load_budget_evidence(terminal_path)

            missing = build_budget_terminal(
                "translation_diagnostic_evaluation", "completed",
                {"path": "missing.json", "bytes": 1, "sha256": "9" * 64},
                40.0, 5.0, 43200.0, None, provenance_artifact,
            )
            self._write(terminal_path, missing)
            with self.assertRaises(DiagnosticEvaluationError):
                load_budget_evidence(terminal_path)

            cycle = build_budget_terminal(
                "translation_diagnostic_evaluation", "completed",
                {"path": terminal_path.name, "bytes": 1, "sha256": "8" * 64},
                40.0, 5.0, 43200.0, None, provenance_artifact,
            )
            self._write(terminal_path, cycle)
            with self.assertRaises(DiagnosticEvaluationError):
                load_budget_evidence(terminal_path)

    def test_failed_evaluation_persists_actual_terminal_budget_receipt(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            checkpoint = root / "diagnostic"
            checkpoint.mkdir()
            model_path = checkpoint / "model.safetensors"
            tokenizer_path = checkpoint / "tokenizer.model"
            model_path.write_bytes(b"model")
            tokenizer_path.write_bytes(b"tokenizer")
            provenance = self._diagnostic_provenance()
            provenance["checkpoint"] = {
                "model": {
                    "path": model_path.name,
                    "bytes": model_path.stat().st_size,
                    "sha256": hashlib.sha256(model_path.read_bytes()).hexdigest(),
                },
                "tokenizer": {
                    "path": tokenizer_path.name,
                    "bytes": tokenizer_path.stat().st_size,
                    "sha256": hashlib.sha256(tokenizer_path.read_bytes()).hexdigest(),
                },
            }
            provenance_path = checkpoint / "diagnostic-provenance-v1.json"
            self._write(provenance_path, provenance)
            output = root / "failed-output"
            with mock.patch(
                "tools.translation.diagnose_translation._load_json", return_value={}
            ), mock.patch(
                "tools.translation.diagnose_translation.load_training_config", return_value={}
            ), mock.patch(
                "tools.translation.diagnose_translation.verify_dataset_inputs"
            ), mock.patch(
                "tools.translation.diagnose_translation.load_runtime",
                side_effect=RuntimeError("synthetic GPU load failure"),
            ):
                with self.assertRaisesRegex(RuntimeError, "synthetic GPU"):
                    evaluate_checkpoint(
                        checkpoint,
                        tokenizer_path,
                        "diagnostic",
                        root,
                        root / "manifest.json",
                        root / "config.json",
                        root / "manual.jsonl",
                        output,
                        provenance_path,
                        provenance_path,
                        provenance_path,
                    )
            terminal_path = output / "budget-terminal-v1.json"
            terminal = json.loads(terminal_path.read_text(encoding="utf-8"))
            self.assertEqual(terminal["status"], "failed")
            self.assertIn("synthetic GPU load failure", terminal["error"])
            self.assertGreaterEqual(terminal["cumulativeActualSeconds"], 40.0)

    def test_comparison_marks_sequence_gain_and_nll_regression_per_direction(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)

            def artifact(path, rows=None):
                value = {
                    "path": path.name,
                    "bytes": path.stat().st_size,
                    "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
                }
                if rows is not None:
                    value["rows"] = rows
                return value

            baseline_checkpoint = root / "baseline-checkpoint"
            diagnostic_checkpoint = root / "diagnostic-checkpoint"
            baseline_checkpoint.mkdir()
            diagnostic_checkpoint.mkdir()
            baseline_model = baseline_checkpoint / "model.safetensors"
            diagnostic_model = diagnostic_checkpoint / "model.safetensors"
            tokenizer_path = root / "tokenizer.model"
            baseline_model.write_bytes(b"baseline model fixture")
            diagnostic_model.write_bytes(b"diagnostic model fixture")
            tokenizer_path.write_bytes(b"tokenizer fixture")

            dataset_root = root / "dataset"
            dataset_root.mkdir()
            dataset_outputs = {}
            test_rows = {}
            for direction, direction_id in (("zh-en", 32001), ("en-zh", 32002)):
                for split in ("train", "validation", "test"):
                    count = 5000 if split == "test" else 1
                    rows = [
                        {
                            "source": "%s source %d" % (direction, index),
                            "target": "%s target %d" % (direction, index),
                            "direction_id": direction_id,
                        }
                        for index in range(1, count + 1)
                    ]
                    name = "%s.%s.jsonl" % (direction, split)
                    path = dataset_root / name
                    path.write_bytes(b"".join(
                        json.dumps(
                            row, ensure_ascii=False, separators=(",", ":")
                        ).encode("utf-8") + b"\n"
                        for row in rows
                    ))
                    dataset_outputs[name] = {
                        **artifact(path), "count": count,
                    }
                    if split == "test":
                        test_rows[direction] = rows
            dataset_manifest_path = root / "dataset-manifest-v1.json"
            dataset_manifest_value = {
                "schema_version": 1,
                "dataset": {
                    "repo": "Mxode/BiST",
                    "revision": "aca6be897afc319f779009379c8b849c1eb8d63e",
                },
                "outputs": dataset_outputs,
            }
            dataset_manifest_path.write_bytes(
                (json.dumps(dataset_manifest_value, ensure_ascii=False, indent=2) + "\n")
                .encode("utf-8")
            )
            dataset_manifest_artifact = artifact(dataset_manifest_path)
            manual_path = root / "manual.jsonl"
            manual_path.write_bytes(b"{}\n" * 100)
            manual_artifact = artifact(manual_path, rows=100)

            provenance = self._diagnostic_provenance()
            provenance["checkpoint"] = {
                "model": artifact(diagnostic_model),
                "tokenizer": artifact(tokenizer_path),
            }
            provenance_path = diagnostic_checkpoint / "diagnostic-provenance-v1.json"
            provenance_artifact = self._write(provenance_path, provenance)
            prior_path = root / "prior-budget-v1.json"
            prior = build_budget_terminal(
                "translation_diagnostic_reconciliation", "completed",
                provenance_artifact, 40.0, 1.0, 43200.0, None,
            )
            prior_artifact = self._write(prior_path, prior)

            baseline_root = root / "baseline-evaluation"
            diagnostic_root = root / "diagnostic-evaluation"
            baseline_root.mkdir()
            diagnostic_root.mkdir()
            baseline_receipt_path = baseline_root / "budget-terminal-v1.json"
            baseline_receipt = build_budget_terminal(
                "translation_diagnostic_evaluation", "completed",
                prior_artifact, 41.0, 1.0, 43200.0, None, provenance_artifact,
            )
            baseline_receipt_artifact = self._write(
                baseline_receipt_path, baseline_receipt
            )
            diagnostic_receipt_path = diagnostic_root / "budget-terminal-v1.json"
            diagnostic_receipt = build_budget_terminal(
                "translation_diagnostic_evaluation", "completed",
                baseline_receipt_artifact, 42.0, 2.0, 43200.0, None,
                provenance_artifact,
            )
            diagnostic_receipt_artifact = self._write(
                diagnostic_receipt_path, diagnostic_receipt
            )

            metric_values = {
                ("baseline", "13a"): {
                    "bleu": 21.0, "chrf2": 46.0,
                    "bleu_signature": "b", "chrf2_signature": "c",
                },
                ("baseline", "zh"): {
                    "bleu": 16.0, "chrf2": 36.0,
                    "bleu_signature": "b", "chrf2_signature": "c",
                },
                ("diagnostic", "13a"): {
                    "bleu": 22.0, "chrf2": 47.0,
                    "bleu_signature": "b", "chrf2_signature": "c",
                },
                ("diagnostic", "zh"): {
                    "bleu": 17.0, "chrf2": 37.0,
                    "bleu_signature": "b", "chrf2_signature": "c",
                },
            }

            def write_bist_outputs(label, output_root):
                path = output_root / "bist-test-outputs-v1.jsonl"
                with path.open("wb") as stream:
                    for direction in ("zh-en", "en-zh"):
                        for index, row in enumerate(test_rows[direction], 1):
                            stream.write(canonical_json_bytes({
                                "direction": direction,
                                "index": index,
                                "source": row["source"],
                                "reference": row["target"],
                                "output": "%s: %s" % (label, row["target"]),
                            }))
                return artifact(path, rows=10000)

            baseline_bist = write_bist_outputs("baseline", baseline_root)
            diagnostic_bist = write_bist_outputs("diagnostic", diagnostic_root)
            baseline_results_path = baseline_root / "manual-results-raw-v1.jsonl"
            diagnostic_results_path = diagnostic_root / "manual-results-raw-v1.jsonl"
            baseline_results_path.write_bytes(b"{}\n" * 100)
            diagnostic_results_path.write_bytes(b"{}\n" * 100)

            baseline_path = baseline_root / "diagnostic-evaluation-v1.json"
            baseline = self._evaluation_report(
                "baseline", STUDENT_SHA256, artifact(tokenizer_path)["sha256"], prior_artifact,
                baseline_receipt_artifact, 41.0, 1.0, None,
            )
            baseline["budgetRootProvenance"] = provenance_artifact
            baseline["checkpoint"]["model"]["bytes"] = baseline_model.stat().st_size
            baseline["checkpoint"]["tokenizer"] = artifact(tokenizer_path)
            baseline["dataset"]["manifest"] = dataset_manifest_artifact
            baseline["bistOutputs"] = baseline_bist
            baseline["manual"]["asset"] = manual_artifact
            baseline["manual"]["results"] = artifact(
                baseline_results_path, rows=100
            )
            self._write(baseline_path, baseline)
            diagnostic_path = diagnostic_root / "diagnostic-evaluation-v1.json"
            diagnostic = self._evaluation_report(
                "diagnostic", artifact(diagnostic_model)["sha256"],
                artifact(tokenizer_path)["sha256"],
                baseline_receipt_artifact, diagnostic_receipt_artifact,
                42.0, 2.0, provenance_artifact,
            )
            diagnostic["budgetRootProvenance"] = provenance_artifact
            diagnostic["checkpoint"] = {
                "model": artifact(diagnostic_model),
                "tokenizer": artifact(tokenizer_path),
            }
            diagnostic["dataset"]["manifest"] = dataset_manifest_artifact
            diagnostic["bistOutputs"] = diagnostic_bist
            diagnostic["manual"]["asset"] = manual_artifact
            diagnostic["manual"]["results"] = artifact(
                diagnostic_results_path, rows=100
            )
            self._write(diagnostic_path, diagnostic)

            real_artifact = __import__(
                "tools.translation.diagnose_translation", fromlist=["_artifact"]
            )._artifact

            def pinned_artifact(path):
                value = real_artifact(path)
                if Path(path).resolve() == baseline_model.resolve():
                    value["sha256"] = STUDENT_SHA256
                return value

            def recompute(outputs, unused_references, tokenizer):
                return metric_values[(outputs[0].split(":", 1)[0], tokenizer)]

            arguments = (
                baseline_path, diagnostic_path, provenance_path, prior_path,
                baseline_checkpoint, tokenizer_path, dataset_root,
                dataset_manifest_path, manual_path,
            )
            with mock.patch(
                "tools.translation.diagnose_translation._artifact",
                side_effect=pinned_artifact,
            ), mock.patch(
                "tools.translation.diagnose_translation.corpus_metrics",
                side_effect=recompute,
            ), mock.patch(
                "tools.translation.diagnose_translation.PINNED_BIST_MANIFEST_SHA256",
                dataset_manifest_artifact["sha256"],
            ):
                report = build_checkpoint_comparison(*arguments)
                self.assertTrue(report["sequence_metrics_improved"])
                self.assertTrue(report["validation_nll_regressed"])
                self.assertEqual(report["directions"]["en-zh"]["bleu_delta"], 1.0)

                diagnostic["bist_test"]["en-zh"]["bleu"] = 999.0
                diagnostic_path.write_bytes(canonical_json_bytes(diagnostic))
                with self.assertRaises(DiagnosticEvaluationError):
                    build_checkpoint_comparison(*arguments)

                diagnostic["bist_test"]["en-zh"]["bleu"] = 17.0
                diagnostic_path.write_bytes(canonical_json_bytes(diagnostic))
                (diagnostic_root / diagnostic_bist["path"]).unlink()
                with self.assertRaises(DiagnosticEvaluationError):
                    build_checkpoint_comparison(*arguments)

                diagnostic_path.write_bytes(canonical_json_bytes({
                    "label": "diagnostic",
                    "bist_test": diagnostic["bist_test"],
                    "directional_validation_loss": diagnostic["directional_validation_loss"],
                }))
                with self.assertRaises(DiagnosticEvaluationError):
                    build_checkpoint_comparison(*arguments)


if __name__ == "__main__":
    unittest.main()
