import hashlib
import json
import tempfile
import unittest
from pathlib import Path
from unittest import mock

from tools.translation.evaluate_v5_candidate import (
    CandidateEvaluationError,
    EVALUATION_IDENTITY,
    EVALUATION_STAGE,
    build_budget_receipt,
    build_budget_overrun_terminal,
    build_complete_manifest,
    build_manual_results,
    evaluation_budget_guard,
    validate_evaluator_trust_anchor,
    validate_complete_manifest,
    validate_v5_binding,
)


def _canonical(value):
    return (json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":")) + "\n").encode("utf-8")


class V5CandidateEvaluationTest(unittest.TestCase):
    def _write(self, path, value):
        path.write_bytes(_canonical(value))
        return {
            "path": path.name,
            "bytes": path.stat().st_size,
            "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
        }

    def _fixture(self, root):
        checkpoint = root / "candidate-step-18284" / "checkpoint"
        checkpoint.mkdir(parents=True)
        files = {}
        for name in (
            "base_revision.txt", "config.json", "generation_config.json",
            "model.safetensors", "selection.json", "tokenizer.model",
        ):
            path = checkpoint / name
            if name == "selection.json":
                path.write_bytes(_canonical({
                    "schema_version": 1,
                    "optimizer_step": 18284,
                    "adamw_step": 18279,
                    "skipped_optimizer_updates": 2,
                    "optimizer_independent": True,
                    "vocab_size": 32003,
                }))
            else:
                path.write_bytes((name + "\n").encode())
            files[name] = {
                "path": name,
                "bytes": path.stat().st_size,
                "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
            }
        budget = {
            "schema_version": 1,
            "stage": "translation_v5_original_bist_continuation",
            "status": "completed",
            "priorEvidence": {"path": "prior.json", "bytes": 1, "sha256": "1" * 64},
            "rootEvidence": {"path": "root.json", "bytes": 1, "sha256": "2" * 64},
            "priorCumulativeSeconds": 27948.77908489965,
            "evaluationActualSeconds": 975.25,
            "cumulativeActualSeconds": 28924.02908489965,
            "totalBudgetSeconds": 43200.0,
            "remainingSeconds": 14275.970915100352,
            "error": None,
        }
        budget_artifact = self._write(root / "budget-terminal-v1.json", budget)
        terminal = {
            "schema_version": 1,
            "stage": "translation_v5_original_bist_continuation",
            "status": "completed",
            "error": None,
            "finalGlobalStep": 18284,
            "adamWStep": 18279,
            "skippedOptimizerUpdates": 2,
            "budgetReceipt": budget_artifact,
            "candidate": {
                "globalStep": 18284,
                "adamWStep": 18279,
                "skippedUpdates": 2,
                "checkpoint": {"path": "checkpoint", "files": files},
            },
        }
        terminal_artifact = self._write(root / "v5-terminal-v1.json", terminal)
        return terminal_artifact, budget_artifact, checkpoint

    def test_identity_is_never_baseline_or_diagnostic(self):
        self.assertEqual("v5-final-candidate", EVALUATION_IDENTITY)
        self.assertEqual("translation_v5_candidate_quality_evaluation", EVALUATION_STAGE)
        self.assertNotIn("baseline", EVALUATION_IDENTITY)
        self.assertNotIn("diagnostic", EVALUATION_IDENTITY)

    def test_v5_binding_requires_exact_terminal_budget_and_candidate_inventory(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            terminal_artifact, budget_artifact, checkpoint = self._fixture(root)
            with mock.patch(
                "tools.translation.evaluate_v5_candidate.EXPECTED_V5_TERMINAL",
                terminal_artifact,
            ), mock.patch(
                "tools.translation.evaluate_v5_candidate.EXPECTED_V5_BUDGET",
                budget_artifact,
            ):
                binding = validate_v5_binding(
                    root / "v5-terminal-v1.json", root / "budget-terminal-v1.json"
                )
                self.assertEqual(checkpoint.resolve(), binding["checkpoint"])
                (checkpoint / "config.json").write_text("tampered\n", encoding="utf-8")
                with self.assertRaisesRegex(CandidateEvaluationError, "checkpoint"):
                    validate_v5_binding(
                        root / "v5-terminal-v1.json", root / "budget-terminal-v1.json"
                    )

    def test_v5_binding_rejects_mutated_terminal_even_if_semantics_look_similar(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            terminal_artifact, budget_artifact, _ = self._fixture(root)
            terminal_path = root / "v5-terminal-v1.json"
            value = json.loads(terminal_path.read_text(encoding="utf-8"))
            value["candidate"]["globalStep"] = 18283
            terminal_path.write_bytes(_canonical(value))
            with mock.patch(
                "tools.translation.evaluate_v5_candidate.EXPECTED_V5_TERMINAL",
                terminal_artifact,
            ), mock.patch(
                "tools.translation.evaluate_v5_candidate.EXPECTED_V5_BUDGET",
                budget_artifact,
            ):
                with self.assertRaisesRegex(CandidateEvaluationError, "terminal"):
                    validate_v5_binding(terminal_path, root / "budget-terminal-v1.json")

    def test_manual_results_are_raw_and_have_no_subjective_audit_fields(self):
        manual = [
            {"id": 1, "direction": "zh-en", "source": "会议在 2026 年。", "reference": "The meeting is in 2026.", "categories": ["number"]},
            {"id": 2, "direction": "en-zh", "source": "Open https://example.com", "reference": "打开 https://example.com", "categories": ["url"]},
        ]
        rows = build_manual_results(manual, ["The meeting is in 2026.", "打开网站"])
        self.assertEqual([1, 2], [row["id"] for row in rows])
        self.assertEqual([], rows[0]["automatic_corruption_flags"])
        self.assertEqual(["url"], rows[1]["automatic_corruption_flags"])
        forbidden = {"pass", "reason", "score", "audit", "audit_complete"}
        self.assertTrue(all(not forbidden.intersection(row) for row in rows))

    def test_complete_manifest_hashes_every_input_and_output_and_detects_tamper(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            input_path = root / "input.json"
            output_path = root / "output.jsonl"
            input_path.write_bytes(b"{}\n")
            output_path.write_bytes(b"{\"id\":1}\n")
            manifest = build_complete_manifest(
                EVALUATION_IDENTITY,
                {"terminal": input_path},
                {"bist_test_outputs": (output_path, 1)},
            )
            validate_complete_manifest(manifest, root)
            self.assertEqual({"terminal"}, set(manifest["inputs"]))
            self.assertEqual({"bist_test_outputs"}, set(manifest["outputs"]))
            output_path.write_bytes(b"tampered\n")
            with self.assertRaisesRegex(CandidateEvaluationError, "manifest"):
                validate_complete_manifest(manifest, root)

    def test_complete_manifest_verifies_cross_root_inputs_by_explicit_label(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            output_root = root / "output"
            first_root = root / "first"
            second_root = root / "second"
            output_root.mkdir()
            first_root.mkdir()
            second_root.mkdir()
            first = first_root / "budget-terminal-v1.json"
            second = second_root / "budget-terminal-v1.json"
            output = output_root / "report.json"
            first.write_bytes(b"first\n")
            second.write_bytes(b"second\n")
            output.write_bytes(b"{}\n")
            inputs = {"prior_budget": first, "v5_budget": second}
            manifest = build_complete_manifest(
                EVALUATION_IDENTITY, inputs, {"quality_report": (output, None)}
            )
            validate_complete_manifest(manifest, output_root, inputs)
            with self.assertRaisesRegex(CandidateEvaluationError, "inventory"):
                validate_complete_manifest(
                    manifest, output_root, {"prior_budget": second, "v5_budget": first}
                )

    def test_external_evaluator_trust_anchor_is_required_and_exact(self):
        authorized = "a" * 64
        report = {
            "identity": EVALUATION_IDENTITY,
            "stage": EVALUATION_STAGE,
            "status": "completed",
            "execution": {"evaluatorCodeSha256": authorized},
        }
        manifest = {
            "identity": EVALUATION_IDENTITY,
            "stage": EVALUATION_STAGE,
            "inputs": {
                "evaluator_code": {"path": "evaluate.py", "bytes": 1, "sha256": authorized}
            },
        }
        validate_evaluator_trust_anchor(report, manifest, authorized)
        with self.assertRaisesRegex(CandidateEvaluationError, "authorized"):
            validate_evaluator_trust_anchor(report, manifest, "b" * 64)
        with self.assertRaisesRegex(CandidateEvaluationError, "authorized"):
            validate_evaluator_trust_anchor(report, manifest, "")

    def test_budget_receipt_extends_prior_recursively_without_changing_root(self):
        prior = {
            "artifact": {"path": "budget-terminal-v1.json", "bytes": 578, "sha256": "a" * 64},
            "rootEvidence": {"path": "diagnostic-provenance-v1.json", "bytes": 2382, "sha256": "b" * 64},
            "cumulativeActualSeconds": 28924.0,
            "totalBudgetSeconds": 43200.0,
        }
        receipt = build_budget_receipt(prior, 12.5, "completed", None)
        self.assertEqual(EVALUATION_STAGE, receipt["stage"])
        self.assertEqual(prior["artifact"], receipt["priorEvidence"])
        self.assertEqual(prior["rootEvidence"], receipt["rootEvidence"])
        self.assertEqual(28936.5, receipt["cumulativeActualSeconds"])
        self.assertEqual(14263.5, receipt["remainingSeconds"])
        with self.assertRaises(CandidateEvaluationError):
            build_budget_receipt(prior, 14277.0, "completed", None)

    def test_periodic_budget_guard_and_overrun_terminal_fail_closed(self):
        prior = {
            "artifact": {"path": "budget-terminal-v1.json", "bytes": 578, "sha256": "a" * 64},
            "rootEvidence": {"path": "diagnostic-provenance-v1.json", "bytes": 2382, "sha256": "b" * 64},
            "cumulativeActualSeconds": 43190.0,
            "totalBudgetSeconds": 43200.0,
        }
        self.assertEqual(9.0, evaluation_budget_guard(prior, 100.0, now=lambda: 109.0))
        with self.assertRaisesRegex(CandidateEvaluationError, "budget"):
            evaluation_budget_guard(prior, 100.0, now=lambda: 110.001)
        terminal = build_budget_overrun_terminal(prior, 11.5, "decode exceeded budget")
        self.assertEqual("failed", terminal["status"])
        self.assertIs(terminal["admissibleForContinuation"], False)
        self.assertEqual(-1.5, terminal["remainingSeconds"])
        self.assertEqual(43201.5, terminal["cumulativeActualSeconds"])


if __name__ == "__main__":
    unittest.main()
