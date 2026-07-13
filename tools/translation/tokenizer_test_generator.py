import hashlib
import os
import tempfile
import unittest
from pathlib import Path

from tools.translation.tokenizer_generate_fixture import (
    CASE_NAMES,
    MODEL_SHA256,
    build_fixture,
    render_arkts_fixture,
)


MODEL = Path(os.environ["LOCALAPPDATA"]) / "MindsporeInhand/tokenizer-task5/source.spm"
ARKTS_FIXTURE = (
    Path(__file__).resolve().parents[2]
    / "Mindspore_inhand_HarmonyOS/entry/src/test/TranslationTokenizerFixture.ets"
)


class TokenizerFixtureGeneratorTest(unittest.TestCase):
    def test_pinned_model_generates_exact_normalization_and_required_goldens(self):
        fixture = build_fixture(MODEL)
        self.assertEqual(hashlib.sha256(MODEL.read_bytes()).hexdigest(), MODEL_SHA256)
        self.assertEqual({case["name"] for case in fixture["cases"]}, set(CASE_NAMES))
        self.assertEqual(fixture["normalizationExamples"]["e\u0301"], "\u00e9")
        self.assertEqual(
            fixture["normalizationExamples"]["\uff21\uff22\uff23\u3000\uff11\uff12\uff13"],
            "ABC 123",
        )
        self.assertEqual(fixture["directions"], {"toEnglish": 32001, "toChinese": 32002})
        self.assertLess(len(fixture["runtime"]["pieces"]), 32000)
        self.assertGreater(len(fixture["runtime"]["normalizationRules"]), 0)
        self.assertTrue(fixture["runtimeTable"].startswith("TTOK1_TEST\t"))
        self.assertEqual(ARKTS_FIXTURE.read_text(encoding="utf-8"), render_arkts_fixture(fixture))

    def test_unknown_runs_and_priority_chunks_match_pinned_sentencepiece(self):
        fixture = build_fixture(MODEL)
        cases = {case["name"]: case for case in fixture["cases"]}
        self.assertTrue(
            {
                "unknown_run",
                "unknown_bmp_run",
                "unknown_adjacency",
                "unknown_boundary_128",
                "priority_mixed",
                "priority_english",
                "priority_space",
            }
            <= cases.keys()
        )

        unknown_run = cases["unknown_run"]["chunks"][0]
        self.assertEqual(unknown_run["pieceIds"], [71, 1, 256])
        self.assertEqual(unknown_run["pieces"], ["\u2581A", "\U0001f9ea\U0001f9ec", "B"])
        self.assertEqual(unknown_run["decoded"], "A \u2047 B")

        bmp_run = cases["unknown_bmp_run"]["chunks"][0]
        self.assertEqual(bmp_run["pieceIds"], [71, 1, 256])
        self.assertEqual(bmp_run["pieces"], ["\u2581A", "\ue000\ue001", "B"])
        self.assertEqual(bmp_run["decoded"], "A \u2047 B")

        adjacency = cases["unknown_adjacency"]["chunks"][0]
        self.assertEqual(adjacency["pieceIds"].count(1), 2)
        self.assertIn("\u2047", adjacency["decoded"])

        unknown_boundary = cases["unknown_boundary_128"]
        self.assertEqual(len(unknown_boundary["chunks"]), 1)
        self.assertEqual(len(unknown_boundary["chunks"][0]["pieceIds"]), 126)
        self.assertEqual(unknown_boundary["chunks"][0]["pieceIds"].count(1), 1)

        for name in ("priority_mixed", "priority_english", "priority_space"):
            case = cases[name]
            reconstructed = "".join(
                chunk["separatorBefore"] + chunk["sourceText"] + chunk["separatorAfter"]
                for chunk in case["chunks"]
            )
            self.assertEqual(reconstructed, case["text"])
            self.assertTrue(all(len(chunk["pieceIds"]) <= 126 for chunk in case["chunks"]))

        self.assertTrue(cases["priority_mixed"]["chunks"][0]["sourceText"].endswith("\u3002"))
        self.assertTrue(cases["priority_english"]["chunks"][0]["sourceText"].endswith("."))
        self.assertTrue(cases["priority_space"]["chunks"][0]["sourceText"].endswith(" "))

    def test_output_is_deterministic_and_rejects_wrong_model_bytes(self):
        fixture = build_fixture(MODEL)
        self.assertEqual(render_arkts_fixture(fixture), render_arkts_fixture(build_fixture(MODEL)))
        with tempfile.TemporaryDirectory() as folder:
            altered = Path(folder) / "source.spm"
            altered.write_bytes(MODEL.read_bytes() + b"x")
            with self.assertRaisesRegex(ValueError, "pinned source.spm"):
                build_fixture(altered)


if __name__ == "__main__":
    unittest.main()
