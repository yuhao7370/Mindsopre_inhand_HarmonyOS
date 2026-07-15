import json
import tempfile
import unittest
from pathlib import Path

from tools.translation.evaluate_runtime_input_policy import (
    EXPECTED_CHECKPOINT_SHA256,
    EXPECTED_TOKENIZER_SHA256,
    RuntimeInputPolicyEvaluationError,
    build_policy_results,
    evaluate_gate,
    evaluate_inputs,
    validate_bound_hashes,
    write_evaluation_outputs,
)


def result_row(row_id, direction, flags):
    return {
        "id": row_id,
        "direction": direction,
        "automatic_corruption_flags": list(flags),
    }


class RuntimeInputPolicyEvaluationTest(unittest.TestCase):
    def test_gate_requires_strict_total_improvement_without_direction_regression(self):
        baseline = [
            result_row(1, "zh-en", ["url"]),
            result_row(2, "en-zh", ["proper-name"]),
        ]
        improved = [
            result_row(1, "zh-en", []),
            result_row(2, "en-zh", ["proper-name"]),
        ]
        gate = evaluate_gate(baseline, improved)
        self.assertTrue(gate["passed"])
        self.assertEqual(gate["baseline"], {"zh-en": 1, "en-zh": 1})
        self.assertEqual(gate["policy"], {"zh-en": 0, "en-zh": 1})
        self.assertEqual(gate["totalDecrease"], 1)

    def test_gate_rejects_a_direction_regression_despite_total_improvement(self):
        baseline = [
            result_row(1, "zh-en", ["url", "number", "proper-name"]),
            result_row(2, "en-zh", []),
        ]
        regressed = [
            result_row(1, "zh-en", []),
            result_row(2, "en-zh", ["url"]),
        ]
        gate = evaluate_gate(baseline, regressed)
        self.assertFalse(gate["passed"])
        self.assertEqual(gate["regressedDirections"], ["en-zh"])

    def test_gate_rejects_misaligned_or_invalid_rows(self):
        with self.assertRaises(RuntimeInputPolicyEvaluationError):
            evaluate_gate(
                [result_row(1, "zh-en", [])],
                [result_row(2, "zh-en", [])],
            )
        invalid = result_row(1, "fr-en", [])
        with self.assertRaises(RuntimeInputPolicyEvaluationError):
            evaluate_gate([invalid], [invalid])

    def test_hash_binding_accepts_only_packaged_v5_identity(self):
        validate_bound_hashes(
            EXPECTED_CHECKPOINT_SHA256, EXPECTED_TOKENIZER_SHA256
        )
        with self.assertRaises(RuntimeInputPolicyEvaluationError):
            validate_bound_hashes("0" * 64, EXPECTED_TOKENIZER_SHA256)
        with self.assertRaises(RuntimeInputPolicyEvaluationError):
            validate_bound_hashes(EXPECTED_CHECKPOINT_SHA256, "0" * 64)

    def test_build_policy_results_translates_model_spans_per_direction(self):
        manual = [
            {
                "id": 1,
                "direction": "en-zh",
                "source": "Open report_v5 at https://example.com/help",
                "reference": "打开 report_v5，网址是 https://example.com/help",
                "categories": ["urls", "names"],
            }
        ]
        calls = []

        def translate(texts, direction):
            calls.append((list(texts), direction))
            return ["打开 " if text == "Open " else "，网址是 " for text in texts]

        results = build_policy_results(manual, translate)
        self.assertEqual(calls, [(["Open ", " at "], "en-zh")])
        self.assertEqual(
            results[0]["output"],
            "打开 report_v5，网址是 https://example.com/help",
        )
        self.assertEqual(results[0]["automatic_corruption_flags"], [])

    def test_build_policy_results_rejects_empty_translation(self):
        manual = [
            {
                "id": 1,
                "direction": "zh-en",
                "source": "翻译 report_v5",
                "reference": "Translate report_v5",
                "categories": ["names"],
            }
        ]
        with self.assertRaises(RuntimeInputPolicyEvaluationError):
            build_policy_results(manual, lambda texts, direction: [""])

    def test_evaluate_inputs_binds_identity_and_reports_a_passing_delta(self):
        manual = [
            {
                "id": 1,
                "direction": "zh-en",
                "source": "访问 https://example.com/help",
                "reference": "Visit https://example.com/help",
                "categories": ["urls"],
            }
        ]
        baseline = [
            {
                **manual[0],
                "output": "Visit https://example.com/helps",
                "automatic_corruption_flags": ["url"],
            }
        ]

        def translate(texts, direction):
            self.assertEqual(direction, "zh-en")
            self.assertEqual(texts, ["访问 "])
            return ["Visit "]

        report, policy = evaluate_inputs(
            manual,
            baseline,
            translate,
            EXPECTED_CHECKPOINT_SHA256,
            EXPECTED_TOKENIZER_SHA256,
        )
        self.assertTrue(report["gate"]["passed"])
        self.assertEqual(report["model"]["checkpointSha256"], EXPECTED_CHECKPOINT_SHA256)
        self.assertEqual(report["model"]["tokenizerSha256"], EXPECTED_TOKENIZER_SHA256)
        self.assertEqual(policy[0]["output"], "Visit https://example.com/help")

    def test_write_evaluation_outputs_is_canonical_and_new_only(self):
        report = {"schemaVersion": 1, "gate": {"passed": True}}
        rows = [result_row(1, "zh-en", [])]
        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary) / "evaluation"
            artifacts = write_evaluation_outputs(output, report, rows)
            report_bytes = (output / "runtime-input-policy-evaluation-v1.json").read_bytes()
            self.assertEqual(
                report_bytes,
                (json.dumps(report, sort_keys=True, separators=(",", ":")) + "\n").encode(),
            )
            self.assertEqual(artifacts["report"]["bytes"], len(report_bytes))
            with self.assertRaises(RuntimeInputPolicyEvaluationError):
                write_evaluation_outputs(output, report, rows)


if __name__ == "__main__":
    unittest.main()
