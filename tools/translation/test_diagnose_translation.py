import hashlib
import json
import tempfile
import unittest
from pathlib import Path
from unittest import mock

from tools.translation.diagnose_translation import (
    DiagnosticEvaluationError,
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
                "totalBudgetSeconds": 1000.0,
                "remainingSeconds": 960.0,
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
            "gpuLedger": evaluation_budget_snapshot(prior, elapsed, 1000.0),
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
                1000.0,
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
            provenance_path = root / "diagnostic-provenance-v1.json"
            provenance_artifact = self._write(
                provenance_path, self._diagnostic_provenance()
            )
            prior_path = root / "prior-budget-v1.json"
            prior = build_budget_terminal(
                "translation_diagnostic_reconciliation", "completed",
                provenance_artifact, 40.0, 1.0, 1000.0, None,
            )
            prior_artifact = self._write(prior_path, prior)
            baseline_receipt_path = root / "baseline-budget-v1.json"
            baseline_receipt = build_budget_terminal(
                "translation_diagnostic_evaluation", "completed",
                prior_artifact, 41.0, 1.0, 1000.0, None, provenance_artifact,
            )
            baseline_receipt_artifact = self._write(
                baseline_receipt_path, baseline_receipt
            )
            baseline_path = root / "baseline.json"
            baseline = self._evaluation_report(
                "baseline", STUDENT_SHA256, "4" * 64, prior_artifact,
                baseline_receipt_artifact, 41.0, 1.0, None,
            )
            baseline["budgetRootProvenance"] = provenance_artifact
            self._write(baseline_path, baseline)
            diagnostic_receipt_path = root / "diagnostic-budget-v1.json"
            diagnostic_receipt = build_budget_terminal(
                "translation_diagnostic_evaluation", "completed",
                baseline_receipt_artifact, 42.0, 2.0, 1000.0, None,
                provenance_artifact,
            )
            diagnostic_receipt_artifact = self._write(
                diagnostic_receipt_path, diagnostic_receipt
            )
            diagnostic_path = root / "diagnostic.json"
            diagnostic = self._evaluation_report(
                "diagnostic", "d" * 64, "4" * 64,
                baseline_receipt_artifact, diagnostic_receipt_artifact,
                42.0, 2.0, provenance_artifact,
            )
            diagnostic["budgetRootProvenance"] = provenance_artifact
            self._write(diagnostic_path, diagnostic)
            report = build_checkpoint_comparison(
                baseline_path, diagnostic_path, provenance_path, prior_path
            )
            self.assertTrue(report["sequence_metrics_improved"])
            self.assertTrue(report["validation_nll_regressed"])
            self.assertEqual(report["directions"]["en-zh"]["bleu_delta"], 1.0)

            forged = {"label": "diagnostic", "bist_test": diagnostic["bist_test"], "directional_validation_loss": diagnostic["directional_validation_loss"]}
            diagnostic_path.write_bytes(canonical_json_bytes(forged))
            with self.assertRaises(DiagnosticEvaluationError):
                build_checkpoint_comparison(
                    baseline_path, diagnostic_path, provenance_path, prior_path
                )


if __name__ == "__main__":
    unittest.main()
