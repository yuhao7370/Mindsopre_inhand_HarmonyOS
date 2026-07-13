import json
import tempfile
import unittest
from pathlib import Path

from tools.translation.export_marian_smoke import (
    ContractError,
    _inspect_onnx,
    _validate_stable_softmax,
    load_profile,
    validate_graph_contract,
)
from tools.translation.generate_mindspore_contract import DescriptorError, generate_header


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

    def test_mindspore_smoke_uses_generated_runtime_descriptors(self):
        source = (ROOT / "mindspore_translation_smoke.cpp").read_text(encoding="utf-8")
        self.assertIn('#include "translation_runtime_contract.h"', source)
        self.assertIn("RequireDescriptors", source)

    def test_runtime_descriptor_header_is_contract_driven_and_strict(self):
        contract = json.loads(CONTRACT.read_text(encoding="utf-8"))
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            generated = root / "translation_runtime_contract.h"
            generate_header(CONTRACT, "prototype", generated)
            header = generated.read_text(encoding="utf-8")
            self.assertIn('{"attention_mask", mindspore::DataType::kNumberTypeInt32, {1, 256}}', header)
            self.assertIn('{"last_hidden_state", mindspore::DataType::kNumberTypeFloat32, {1, 256, 256}}', header)

            contract["profiles"]["prototype"]["graphs"]["encoder"]["inputs"]["attention_mask"]["shape"] = [1, 255]
            mutated_contract = root / "mutated.json"
            mutated_contract.write_text(json.dumps(contract), encoding="utf-8")
            generate_header(mutated_contract, "prototype", generated)
            self.assertIn('{"attention_mask", mindspore::DataType::kNumberTypeInt32, {1, 255}}', generated.read_text(encoding="utf-8"))

            contract["profiles"]["prototype"]["mindsporeFloatingDtype"] = "FLOAT16"
            mutated_contract.write_text(json.dumps(contract), encoding="utf-8")
            with self.assertRaisesRegex(DescriptorError, "FLOAT32"):
                generate_header(mutated_contract, "prototype", generated)

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

    def test_stable_softmax_rejects_mutated_onnx_edge(self):
        import onnx
        from onnx import TensorProto, helper

        nodes = [
            helper.make_node("ReduceMax", ["scores"], ["maximum"]),
            helper.make_node("Sub", ["scores", "maximum"], ["shifted"]),
            helper.make_node("Exp", ["shifted"], ["numerator"]),
            helper.make_node("ReduceSum", ["numerator"], ["denominator"]),
            helper.make_node("Div", ["numerator", "denominator"], ["probabilities"]),
        ]
        graph = helper.make_graph(
            nodes,
            "stable-softmax",
            [helper.make_tensor_value_info("scores", TensorProto.FLOAT, [1, 2])],
            [helper.make_tensor_value_info("probabilities", TensorProto.FLOAT, [1, 2])],
        )
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "softmax.onnx"
            onnx.save(helper.make_model(graph), path)
            _, inspected_nodes = _inspect_onnx(path)
            _validate_stable_softmax(inspected_nodes, "valid", 1)

            graph.node[-1].input[1] = "wrong_denominator"
            onnx.save(helper.make_model(graph), path)
            _, inspected_nodes = _inspect_onnx(path)
            with self.assertRaisesRegex(ContractError, "dataflow"):
                _validate_stable_softmax(inspected_nodes, "mutated", 1)

    def test_unknown_profile_is_rejected(self):
        with self.assertRaisesRegex(ContractError, "profile"):
            load_profile(CONTRACT, "missing")


if __name__ == "__main__":
    unittest.main()
