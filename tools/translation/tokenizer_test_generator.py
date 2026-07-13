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
        self.assertEqual(ARKTS_FIXTURE.read_text(encoding="utf-8"), render_arkts_fixture(fixture))

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
