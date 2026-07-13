import json
import tempfile
import unittest
from pathlib import Path

from tools.translation.export_marian_smoke import ContractError, load_profile, validate_graph_contract


CONTRACT = Path(__file__).with_name("contracts") / "translation-v1.json"
ROOT = Path(__file__).parent


class ExportContractTest(unittest.TestCase):
    def test_prototype_and_final_profiles_are_separate_and_use_inspected_cache_shapes(self):
        prototype = load_profile(CONTRACT, "prototype")
        final = load_profile(CONTRACT, "final")
        self.assertEqual(prototype["vocabSize"], 32001)
        self.assertEqual(prototype["maxTokens"], 256)
        self.assertEqual(final["vocabSize"], 32003)
        self.assertEqual(final["maxTokens"], 128)
        self.assertEqual(prototype["onnxFloatingDtype"], "FLOAT16")
        self.assertEqual(prototype["mindsporeFloatingDtype"], "FLOAT32")
        self.assertEqual(prototype["graphs"]["decoder_step"]["inputs"]["past_key_0"]["shape"], [1, 8, 255, 32])
        self.assertEqual(final["graphs"]["decoder_step"]["inputs"]["past_key_0"]["shape"], [1, 8, 127, 32])
        self.assertEqual(final["graphs"]["decoder_step"]["outputs"]["new_key_0"]["shape"], [1, 8, 1, 32])
        self.assertEqual(final["graphs"]["encoder"]["inputs"]["attention_mask"]["dtype"], "INT32")

    def test_mindspore_smoke_scatter_updates_head_strided_cache_slots(self):
        source = (ROOT / "mindspore_translation_smoke.cpp").read_text(encoding="utf-8")
        self.assertIn("static void ScatterCacheSlot", source)
        self.assertIn("ScatterCacheSlot(self_key, past_key, 0);", source)
        self.assertIn("ScatterCacheSlot(new_key, past_key, position);", source)

    def test_mindspore_smoke_rejects_unknown_tensor_name_sets(self):
        source = (ROOT / "mindspore_translation_smoke.cpp").read_text(encoding="utf-8")
        self.assertIn("static void RequireNames", source)
        for label in (
            '"encoder inputs"', '"encoder outputs"',
            '"prefill inputs"', '"prefill outputs"',
            '"step inputs"', '"step outputs"',
        ):
            self.assertIn(f"RequireNames({label}", source)

    def test_converter_enforces_pinned_prototype_token_fixture(self):
        source = (ROOT / "convert_mindspore.ps1").read_text(encoding="utf-8")
        self.assertIn("@(422, 21, 23, 22, 80, 5)", source)
        self.assertIn("prototype cache fixture drift", source)

    def test_contract_comparison_fails_closed_on_name_dtype_or_shape_change(self):
        expected = {
            "inputs": {"mask": {"dtype": "INT32", "shape": [1, 128]}},
            "outputs": {"value": {"dtype": "FLOAT16", "shape": [1, 2]}},
        }
        validate_graph_contract(expected, json.loads(json.dumps(expected)), "graph")
        for field, value in (("dtype", "FLOAT32"), ("shape", [1, 3])):
            actual = json.loads(json.dumps(expected))
            actual["inputs"]["mask"][field] = value
            with self.subTest(field=field), self.assertRaisesRegex(ContractError, "graph contract mismatch"):
                validate_graph_contract(expected, actual, "graph")
        actual = json.loads(json.dumps(expected))
        actual["inputs"]["extra"] = {"dtype": "INT32", "shape": [1]}
        with self.assertRaisesRegex(ContractError, "graph contract mismatch"):
            validate_graph_contract(expected, actual, "graph")

    def test_unknown_profile_is_rejected(self):
        with self.assertRaisesRegex(ContractError, "profile"):
            load_profile(CONTRACT, "missing")


if __name__ == "__main__":
    unittest.main()
