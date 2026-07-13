import json
import tempfile
import unittest
from pathlib import Path

from tools.translation.evaluate_translation import (
    EvaluationError,
    FLORES_REVISION,
    corruption_reasons,
    corpus_metrics,
    load_manual_set,
    stable_argmax,
    translate_preserving_boundaries,
    write_canonical_json,
)


ROOT = Path(__file__).parent
MANUAL = ROOT / "manual-eval-v1.jsonl"


class EvaluateTranslationTest(unittest.TestCase):
    def test_canonical_json_writer_supports_python39_and_uses_lf(self):
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "report.json"
            write_canonical_json(path, {"text": "\u4e2d\u6587", "value": 1})
            payload = path.read_bytes()
            self.assertEqual(payload[-1:], b"\n")
            self.assertNotIn(b"\r", payload)
            self.assertEqual(json.loads(payload), {"text": "\u4e2d\u6587", "value": 1})

    def test_manual_set_is_exactly_fifty_per_direction_and_covers_required_categories(self):
        rows = load_manual_set(MANUAL)
        self.assertEqual(FLORES_REVISION, "b3a5298db5721c8a682e7ef00a37fcc9ab522757")
        self.assertEqual(len(rows), 100)
        self.assertEqual([row["id"] for row in rows], list(range(1, 101)))
        for direction in ("zh-en", "en-zh"):
            selected = [row for row in rows if row["direction"] == direction]
            self.assertEqual(len(selected), 50)
            categories = {category for row in selected for category in row["categories"]}
            self.assertTrue(
                {
                    "short-common",
                    "mixed-punctuation",
                    "numbers",
                    "dates",
                    "urls",
                    "names",
                    "negation",
                    "ocr-spacing",
                    "multiline",
                }.issubset(categories)
            )

    def test_manual_set_rejects_unknown_fields_bad_ids_machine_paths_and_empty_text(self):
        valid = {
            "id": 1,
            "direction": "zh-en",
            "source": "你好",
            "reference": "Hello.",
            "categories": ["short-common"],
        }
        mutations = []
        value = dict(valid, unexpected=True)
        mutations.append(value)
        value = dict(valid, id=True)
        mutations.append(value)
        value = dict(valid, source="")
        mutations.append(value)
        value = dict(valid, reference="C:\\temp\\answer")
        mutations.append(value)
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "manual.jsonl"
            for row in mutations:
                path.write_text(json.dumps(row, ensure_ascii=False) + "\n", encoding="utf-8")
                with self.assertRaises(EvaluationError):
                    load_manual_set(path, expected_total=1)

    def test_stable_argmax_chooses_smallest_token_id_on_tie_and_rejects_nonfinite(self):
        self.assertEqual(stable_argmax([1.0, 4.0, 4.0, 3.0]), 1)
        for values in ([], [1.0, float("nan")], [float("inf")]):
            with self.assertRaises(EvaluationError):
                stable_argmax(values)

    def test_corruption_detection_is_exact_for_numbers_urls_and_proper_names(self):
        source = "Alice paid 12.50 USD at https://example.com/a?x=1"
        self.assertEqual(corruption_reasons(source, source), [])
        self.assertIn("number", corruption_reasons(source, "Alice paid 15.20 USD at https://example.com/a?x=1"))
        self.assertIn("url", corruption_reasons(source, "Alice paid 12.50 USD at https://example.org/a?x=1"))
        self.assertIn("proper-name", corruption_reasons(source, "Alicia paid 12.50 USD at https://example.com/a?x=1"))

    def test_corruption_detection_uses_reference_format_and_only_named_manual_cases(self):
        source = "会议安排在2026年7月18日。"
        reference = "The meeting is scheduled for July 18, 2026."
        self.assertEqual(
            corruption_reasons(source, reference, reference=reference, check_proper_names=False),
            [],
        )
        named_source = "Alice will meet David in Shenzhen."
        named_reference = "Alice将在深圳见David。"
        self.assertEqual(
            corruption_reasons(
                named_source,
                named_reference,
                reference=named_reference,
                check_proper_names=True,
            ),
            [],
        )
        self.assertIn(
            "proper-name",
            corruption_reasons(
                named_source,
                "Alicia将在深圳见David。",
                reference=named_reference,
                check_proper_names=True,
            ),
        )

    def test_corruption_detection_ignores_sentence_punctuation_after_urls(self):
        source = "Visit https://example.com/a?x=1."
        reference = "\u8bf7\u8bbf\u95ee https://example.com/a?x=1\u3002"
        output = "\u8bf7\u8bbf\u95ee https://example.com/a?x=1."
        self.assertEqual(
            corruption_reasons(source, output, reference=reference, check_proper_names=False),
            [],
        )

    def test_multiline_translation_preserves_every_original_newline_boundary(self):
        calls = []

        def translate(chunks):
            calls.append(chunks)
            return [chunk.upper() for chunk in chunks]

        self.assertEqual(
            translate_preserving_boundaries("first\n\nsecond\r\nthird\n", translate),
            "FIRST\n\nSECOND\r\nTHIRD\n",
        )
        self.assertEqual(calls, [["first", "second", "third"]])

    def test_corpus_metrics_pin_sacrebleu_signature_and_chrf2(self):
        metrics = corpus_metrics(
            ["hello wonderful world today", "have a very good night"],
            ["hello wonderful world today", "have a very good night"],
            tokenizer="13a",
        )
        self.assertAlmostEqual(metrics["bleu"], 100.0)
        self.assertAlmostEqual(metrics["chrf2"], 100.0)
        self.assertIn("version:2.4.3", metrics["bleu_signature"])
        self.assertIn("version:2.4.3", metrics["chrf2_signature"])


if __name__ == "__main__":
    unittest.main()
