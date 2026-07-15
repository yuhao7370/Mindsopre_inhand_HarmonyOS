import unittest

from tools.translation.runtime_input_policy import (
    RuntimeInputPolicyError,
    TranslationSegment,
    normalize_ocr_letter_spacing,
    prepare_translation_segments,
    translate_with_policy,
)


class RuntimeInputPolicyTest(unittest.TestCase):
    def test_collapses_only_three_or_more_single_ascii_letters(self):
        self.assertEqual(
            normalize_ocr_letter_spacing("P L E A S E   K E E P   C L E A R"),
            "PLEASE KEEP CLEAR",
        )
        self.assertEqual(normalize_ocr_letter_spacing("A B test"), "A B test")
        self.assertEqual(normalize_ocr_letter_spacing("中文 A B C"), "中文 ABC")

    def test_preserves_newlines_and_wide_word_boundaries(self):
        self.assertEqual(
            normalize_ocr_letter_spacing("I N V O I C E\r\nN O.  B-3017"),
            "INVOICE\r\nN O.  B-3017",
        )

    def test_rejects_non_string_ocr_input(self):
        with self.assertRaises(TypeError):
            normalize_ocr_letter_spacing(None)

    def test_protects_only_exact_data_spans(self):
        segments = prepare_translation_segments(
            "Open https://example.com/help, mail a.b+1@example.org, "
            "then use report_v5 or B-3017."
        )
        self.assertEqual(
            segments,
            [
                TranslationSegment("model", "Open "),
                TranslationSegment("protected", "https://example.com/help"),
                TranslationSegment("model", ", mail "),
                TranslationSegment("protected", "a.b+1@example.org"),
                TranslationSegment("model", ", then use "),
                TranslationSegment("protected", "report_v5"),
                TranslationSegment("model", " or "),
                TranslationSegment("protected", "B-3017"),
                TranslationSegment("model", "."),
            ],
        )

    def test_does_not_protect_dates_names_or_hyphenated_words(self):
        text = "OpenAI met Alice on 2025-12-09 for state-of-the-art work."
        self.assertEqual(
            prepare_translation_segments(text),
            [TranslationSegment("model", text)],
        )

    def test_normalizes_model_text_before_segmentation(self):
        self.assertEqual(
            prepare_translation_segments("O P E N   report_v5"),
            [
                TranslationSegment("model", "OPEN "),
                TranslationSegment("protected", "report_v5"),
            ],
        )

    def test_translates_model_spans_and_copies_protected_spans(self):
        calls = []

        def translate(values):
            calls.append(values)
            return [value.upper() for value in values]

        self.assertEqual(
            translate_with_policy(
                "open report_v5 at https://example.com/help", translate
            ),
            "OPEN report_v5 AT https://example.com/help",
        )
        self.assertEqual(calls, [["open ", " at "]])

    def test_protected_only_input_does_not_call_model(self):
        def fail_if_called(_):
            self.fail("model translator was called")

        self.assertEqual(
            translate_with_policy("https://example.com/help", fail_if_called),
            "https://example.com/help",
        )

    def test_rejects_missing_or_empty_model_outputs(self):
        with self.assertRaises(RuntimeInputPolicyError):
            translate_with_policy("translate report_v5", lambda _: [])
        with self.assertRaises(RuntimeInputPolicyError):
            translate_with_policy("translate report_v5", lambda _: [""])


if __name__ == "__main__":
    unittest.main()
