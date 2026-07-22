import copy
import hashlib
import importlib
import json
import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest import mock

from tools.translation import export_marian_smoke as exporter


ROOT = Path(__file__).resolve().parents[2]
MANIFEST = ROOT / "tools" / "translation" / "manifests" / "open-source-edge-models-v1.json"
REFERENCE = ROOT / "tools" / "translation" / "manifests" / "open-source-edge-reference-v1.json"
EVIDENCE = ROOT / "tools" / "translation" / "manifests" / "open-source-edge-conversion-evidence-v1.json"
QUANT_CONFIG = ROOT / "tools" / "translation" / "config" / "open-source-edge-w8.ini"


class OpenSourceEdgeModelTest(unittest.TestCase):
    def test_converter_and_static_w8_policy_are_pinned(self):
        converter = importlib.import_module("tools.translation.convert_open_source_edge_models")
        self.assertEqual(converter.CONVERTER_VERSION, "2.8.0")
        self.assertEqual(
            converter.CONVERTER_ARCHIVE_SHA256,
            "657579ba8ad27f0116e32ed49fc12e9b8409b614defa712de1e7e63c4c06336d",
        )
        self.assertEqual(converter.GRAPH_NAMES, ("encoder", "decoder_full"))
        self.assertEqual(
            converter.QUANTIZATION,
            {
                "type": "WEIGHT_QUANT", "bitNum": 8,
                "minWeightSize": 0, "minWeightChannel": 0,
            },
        )
        self.assertEqual(
            converter.CONVERSION_POLICY,
            {
                "selectedDecoder": "static-full-decoder",
                "cachedStep": {
                    "status": "rejected",
                    "reason": "cached-step-semantics-diverged",
                },
            },
        )
        config = QUANT_CONFIG.read_text(encoding="utf-8")
        for expected in (
            "quant_type=WEIGHT_QUANT", "bit_num=8",
            "min_quant_weight_size=0", "min_quant_weight_channel=0",
        ):
            self.assertIn(expected, config)

    def test_full_decoder_lite_runner_is_bounded_and_supports_manifest_beams(self):
        source_path = ROOT / "tools" / "translation" / "mindspore_lite_full_decoder_loop.cc"
        source = source_path.read_text(encoding="utf-8")
        for expected in (
            "MSModelBuildFromFile", "MSModelPredict", "decoder_input_ids",
            "decoder_attention_mask", "encoder_hidden_states", "numBeams",
            "beam_count != 1 && beam_count != 4", "target_length != 32",
            "encoder_inputs.handle_num != 2", "decoder_inputs.handle_num != 4",
            "outputs.handle_num != 1", "RequireTensor", "token != pad_token",
            "KeepGlobalTop(candidates, beam_count * 2)", "beam_count == 1",
            "KeepGlobalTop", "GreedyToken", "--self-test", "self-test passed",
        ):
            self.assertIn(expected, source)
        self.assertNotIn("past_key_", source)
        self.assertNotIn("cross_key_", source)

    def test_real_w8_evidence_binds_graph_bytes_and_all_sentence_outputs(self):
        evidence = json.loads(EVIDENCE.read_text(encoding="utf-8"))
        self.assertEqual(
            set(evidence),
            {
                "schemaVersion", "converter", "policy", "mindSporeLiteContracts",
                "runner", "directions", "mindSporeLiteTotalBytes",
            },
        )
        self.assertEqual(evidence["schemaVersion"], 1)
        self.assertEqual(
            evidence["converter"],
            {
                "version": "2.8.0",
                "archiveSha256": "657579ba8ad27f0116e32ed49fc12e9b8409b614defa712de1e7e63c4c06336d",
                "binarySha256": "2e21f91190de81d8fb60514390094afb21282e2060ff24da08f59e2df9125ee5",
                "quantConfigSha256": "742d8be0f75ac1739ce2edbd985789eee335628e5578b0adb81474619818b2d9",
            },
        )
        self.assertEqual(
            evidence["policy"],
            {
                "onnxDtype": "FLOAT32", "mindSporeLiteQuantization": "WEIGHT_QUANT_W8",
                "selectedDecoder": "static-full-decoder", "targetMaxTokens": 32,
            },
        )
        self.assertEqual(
            evidence["runner"],
            {
                "source": {
                    "path": "tools/translation/mindspore_lite_full_decoder_loop.cc",
                    "size": 19129,
                    "sha256": "945add25a32f59a04a4b226142a4053054ce7b02c978a02c893e4358d0c66046",
                },
                "build": {
                    "platform": "linux-x86_64",
                    "compiler": "g++ (Ubuntu 13.3.0-6ubuntu2~24.04.1) 13.3.0",
                    "flags": ["-std=c++17", "-O2", "-Wall", "-Wextra", "-Werror"],
                    "binarySize": 87400,
                    "binarySha256": "6960ea49a08db4f460674290026ddf36b9a034a4ab833a7a344064b2cddd8ef4",
                },
                "selfTest": {
                    "exitCode": 0,
                    "receiptEncoding": "UTF-8",
                    "stdout": "self-test passed\n",
                    "receiptSha256": "d557c5b8a87676e45bca4cbaecde8ab1c77d74f125850c78d9f1a25ceb5dfcc4",
                },
            },
        )
        runner_source = ROOT / evidence["runner"]["source"]["path"]
        self.assertEqual(runner_source.stat().st_size, evidence["runner"]["source"]["size"])
        self.assertEqual(exporter._sha256_file(runner_source), evidence["runner"]["source"]["sha256"])
        self.assertEqual(
            hashlib.sha256(evidence["runner"]["selfTest"]["stdout"].encode("utf-8")).hexdigest(),
            evidence["runner"]["selfTest"]["receiptSha256"],
        )
        def contract(hidden_size, vocab_size):
            return {
                "encoder": {
                    "inputs": {
                        "input_ids": ["INT32", [1, 128]],
                        "attention_mask": ["INT32", [1, 128]],
                    },
                    "outputs": {"last_hidden_state": ["FLOAT32", [1, 128, hidden_size]]},
                },
                "decoder_full": {
                    "inputs": {
                        "decoder_input_ids": ["INT32", [1, 32]],
                        "decoder_attention_mask": ["INT32", [1, 32]],
                        "encoder_hidden_states": ["FLOAT32", [1, 128, hidden_size]],
                        "encoder_attention_mask": ["INT32", [1, 128]],
                    },
                    "outputs": {"logits": ["FLOAT32", [1, 32, vocab_size]]},
                },
            }
        self.assertEqual(
            evidence["mindSporeLiteContracts"],
            {"zh-en": contract(256, 32001), "en-zh": contract(512, 65001)},
        )
        self.assertEqual(evidence["mindSporeLiteTotalBytes"], 189697176)
        expected_graphs = {
            "zh-en": {
                "encoder": (
                    (58188119, "1597ae69c8841baf57ce5c99c4f6a562341566baf7bf6665f7458f9260bc12c0"),
                    (16115736, "86a9272199af2b3699a3d873b69e5741de3e26da545de06180902df071ff91bb"),
                ),
                "decoder_full": (
                    (76251021, "449c32eb8c8f81d80ea78a742470d458caf0c89315f5255f48f8ccef311e7c95"),
                    (21247904, "8dc03af96ac9f7bf9efb37ffcc42a0034f5305810a0059cd7c3cb66e48a3550d"),
                ),
            },
            "en-zh": {
                "encoder": (
                    (209072207, "5dc3c72ac20ff29a5e4f60a8c648a616365c9c8c4947a9fd678cb37615f9549e"),
                    (55211640, "4a1eae7e4b3600801b88df822bd42f786e9e34f715d12d0bac6454683599c5ee"),
                ),
                "decoder_full": (
                    (367525327, "ea89d16bd01ca3297698f5afd3c9d9e8d5dfee78375844bab25df8721d424c26"),
                    (97121896, "5046af7b4311c14676d099e6cd01839f9c3b910d437184017797e972e559e66e"),
                ),
            },
        }
        expected_gates = {
            "zh-en": {
                "strategy": "greedy", "numBeams": 1,
                "rows": [
                    {"tokens": [12249, 2, 5, 192, 4, 0], "output": "Hello, the world."},
                    {"tokens": [130, 446, 14, 21784, 10, 349, 31, 3852, 28, 6629, 4, 0], "output": "This report is confidential and must be submitted on Monday."},
                    {"tokens": [1344, 1525, 5, 3304, 10, 899, 5, 5681, 4, 0], "output": "Please close the door and open the window."},
                    {"tokens": [25, 5751, 53, 31, 1480, 5463, 4, 0], "output": "The weather will be clear tomorrow."},
                ],
            },
            "en-zh": {
                "strategy": "beam", "numBeams": 4,
                "rows": [
                    {"tokens": [7999, 2273, 955, 0], "output": "哈罗世界"},
                    {"tokens": [4683, 72, 8143, 12, 2, 6440, 16723, 693, 10, 0], "output": "报告是保密的,必须在星期一提交。"},
                    {"tokens": [8, 4614, 158, 3019, 10958, 33216, 0], "output": "关上门打开窗户"},
                    {"tokens": [12516, 17546, 384, 1002, 51988, 9483, 0], "output": "明天天气会很晴朗"},
                ],
            },
        }
        expected_conversion_reports = {
            "zh-en": "80411326fbb0ef844501d5518f577a7c52c326a38eaf37a133f59fe4e0840064",
            "en-zh": "0b77050018fbc2e10aa053871dfe577fbd8243cfb6b3979c85feb829869023b2",
        }
        expected_runner_reports = {
            "zh-en": [
                "2b7a192191d88bb7cdeb4c4b693764cf3cbb6dba011bbd6f13ee1cebdbe96248",
                "b53feae7007e9e9e637072890ca5a7d276a1560615ea8ac9e279b11fd16170a2",
                "4ee4f08b7a57df6d6172567f65d5db7cbea97a1462949fe4bf1f8383c56f0f9b",
                "0d4d022e539c32b2c26202dd7c12b131c87a0edc432cd3bd1009f0748f324529",
            ],
            "en-zh": [
                "98c4211bd21d8cc1342d987ecb170601ab77f531efa257e57e59567a39dfc0d7",
                "354e95075aace90b910813febde17c7c02b8b8d021d0ca2fb42720f2d482d4fb",
                "e608fd2c330974caf9d8d4b4601d0c9de233042549684c4bff12fff0f4975bd0",
                "b85a404fc710d8c82d07729b7640998645f01c890a6ef51118dc7d6b946dbe17",
            ],
        }
        expected_input_receipts = {
            "zh-en": [
                ("18fa4067aee90b3e6cad1b16869572e96969b5df60c1277e43f9c7fd9b6c8782", "cf2c087882a24a288be5d997e75691586f414041345c725dd4b6abc6a9c5708f"),
                ("46c9ba125d064483757cf8b9b26ec69331c688fa4925d0b355ac88b6a05b4b65", "643b4e2fa4fddee0635d92f9ce36f6cf350503ba84554110c449313b524ff136"),
                ("cd088e05909cfd74eb9ef12cd20914399e5002ee7fd880493dbc22dffd3344b9", "508bcba349d4ba2f39c23ec8e1aeed8a5f4fc700ecb2959296bc8ee46bda01dd"),
                ("a32c02c178ea01435b3cdd5c40836a966a470f1a2b623078e712695f7f1394fb", "83c47f75a359b2820927861139b06a42a89d4073ea58bbae29e091454cb7878f"),
            ],
            "en-zh": [
                ("505567124ff08643386f919db0ef0cc49a7a06d0b1eb24dce625e0f7c109473e", "cf2c087882a24a288be5d997e75691586f414041345c725dd4b6abc6a9c5708f"),
                ("84c57557cb8130b0bd87b983bfe8fd66ac8dc21147d96ef84b24c5d80b02fc87", "96856cff6bf890671a8c4737475232ba3de0ad797d92cb876670f03b447874a1"),
                ("d2448e4881f4612820bc7e2896ccb6fcfeefb3f3b688de08b03854e7669dcf5f", "9f30fb90e46df18bfe8fa76cfa66368a719848e4b88606365fdf3c8617413f8b"),
                ("7d326a39f4900d506377a876258ddb92fe6fced7322c54ae11baa5f7a243d722", "63a08dbbdf5c4768b61c8c44cb9b7b86b35104c12f73cfbf534bed5305a3038a"),
            ],
        }
        self.assertEqual(set(evidence["directions"]), set(expected_graphs))
        total = 0
        for direction, graphs in expected_graphs.items():
            actual = evidence["directions"][direction]
            self.assertEqual(
                set(actual), {"conversionReport", "graphs", "sentenceGate"}
            )
            self.assertEqual(
                actual["conversionReport"],
                {"schemaVersion": 1, "sha256": expected_conversion_reports[direction]},
            )
            for graph_name, (onnx, mindspore) in graphs.items():
                self.assertEqual(
                    actual["graphs"][graph_name],
                    {
                        "onnx": {"size": onnx[0], "sha256": onnx[1]},
                        "mindSporeLite": {"size": mindspore[0], "sha256": mindspore[1]},
                    },
                )
                total += mindspore[0]
            self.assertEqual(
                set(actual["sentenceGate"]),
                {"strategy", "numBeams", "runnerBinarySha256", "modelGraphSha256", "rows"},
            )
            self.assertEqual(actual["sentenceGate"]["strategy"], expected_gates[direction]["strategy"])
            self.assertEqual(actual["sentenceGate"]["numBeams"], expected_gates[direction]["numBeams"])
            self.assertEqual(
                actual["sentenceGate"]["runnerBinarySha256"],
                evidence["runner"]["build"]["binarySha256"],
            )
            self.assertEqual(
                actual["sentenceGate"]["modelGraphSha256"],
                {
                    "encoder": actual["graphs"]["encoder"]["mindSporeLite"]["sha256"],
                    "decoderFull": actual["graphs"]["decoder_full"]["mindSporeLite"]["sha256"],
                },
            )
            self.assertEqual(len(actual["sentenceGate"]["rows"]), 4)
            for index, row in enumerate(actual["sentenceGate"]["rows"]):
                self.assertEqual(
                    set(row),
                    {
                        "tokens", "output", "inputIdsSha256", "attentionMaskSha256",
                        "runnerReportSha256",
                    },
                )
                expected_row = expected_gates[direction]["rows"][index]
                self.assertEqual(row["tokens"], expected_row["tokens"])
                self.assertEqual(row["output"], expected_row["output"])
                self.assertEqual(
                    (row["inputIdsSha256"], row["attentionMaskSha256"]),
                    expected_input_receipts[direction][index],
                )
                self.assertEqual(row["runnerReportSha256"], expected_runner_reports[direction][index])
                self.assertEqual(row["tokens"][-1], 0)
                has_cjk = any("\u3400" <= character <= "\u9fff" for character in row["output"])
                self.assertEqual(has_cjk, direction == "en-zh")
        self.assertEqual(total, evidence["mindSporeLiteTotalBytes"])

    def test_converter_preserves_failure_log_and_rejects_missing_output(self):
        converter = importlib.import_module("tools.translation.convert_open_source_edge_models")
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            onnx_root = root / "onnx"
            onnx_root.mkdir()
            for graph in converter.GRAPH_NAMES:
                (onnx_root / f"{graph}.onnx").write_bytes(graph.encode("ascii"))
            config = root / "quant.ini"
            config.write_text(QUANT_CONFIG.read_text(encoding="utf-8"), encoding="utf-8")
            converter_path = root / "converter"
            archive_path = root / "converter.tar.gz"
            converter_path.write_bytes(b"test-converter")
            archive_path.write_bytes(b"test-archive")
            receipt = {
                "converterBinarySha256": converter.CONVERTER_BINARY_SHA256,
                "converterArchiveSha256": converter.CONVERTER_ARCHIVE_SHA256,
                "quantConfigSha256": converter.QUANT_CONFIG_SHA256,
            }
            failed = SimpleNamespace(returncode=9, stdout="raw stdout\n", stderr="raw stderr\n")
            output = root / "failed"
            with mock.patch.object(converter, "_validate_toolchain", return_value=receipt), \
                    mock.patch.object(converter.subprocess, "run", return_value=failed):
                with self.assertRaisesRegex(RuntimeError, "exit 9"):
                    converter.convert_direction(
                        converter_path, archive_path, onnx_root, output, config, "zh-en"
                    )
            self.assertEqual(
                (output / "encoder.converter.log").read_text(encoding="utf-8"),
                "raw stdout\nraw stderr\n",
            )
            succeeded = SimpleNamespace(returncode=0, stdout="ok\n", stderr="")
            with mock.patch.object(converter, "_validate_toolchain", return_value=receipt), \
                    mock.patch.object(converter.subprocess, "run", return_value=succeeded):
                with self.assertRaisesRegex(RuntimeError, "did not create"):
                    converter.convert_direction(
                        converter_path, archive_path, onnx_root,
                        root / "missing", config, "zh-en"
                    )

    def test_converter_rejects_an_unpinned_binary_or_archive(self):
        converter = importlib.import_module("tools.translation.convert_open_source_edge_models")
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            binary = root / "converter"
            archive = root / "converter.tar.gz"
            config = root / "quant.ini"
            binary.write_bytes(b"arbitrary executable")
            archive.write_bytes(b"arbitrary archive")
            config.write_text(QUANT_CONFIG.read_text(encoding="utf-8"), encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "toolchain receipt differs"):
                converter._validate_toolchain(binary, archive, config)

    def test_conversion_report_binds_actual_graph_bytes_and_policy(self):
        converter = importlib.import_module("tools.translation.convert_open_source_edge_models")
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            onnx_root = root / "onnx"
            onnx_root.mkdir()
            for graph in converter.GRAPH_NAMES:
                (onnx_root / f"{graph}.onnx").write_bytes((graph + "-onnx").encode("ascii"))
            config = root / "quant.ini"
            config.write_text(QUANT_CONFIG.read_text(encoding="utf-8"), encoding="utf-8")
            converter_path = root / "converter"
            archive_path = root / "converter.tar.gz"
            converter_path.write_bytes(b"test-converter")
            archive_path.write_bytes(b"test-archive")
            receipt = {
                "converterBinarySha256": converter.CONVERTER_BINARY_SHA256,
                "converterArchiveSha256": converter.CONVERTER_ARCHIVE_SHA256,
                "quantConfigSha256": converter.QUANT_CONFIG_SHA256,
            }

            def fake_run(command, **_kwargs):
                self.assertTrue(any(item.startswith("--configFile=") for item in command))
                output_arg = next(item for item in command if item.startswith("--outputFile="))
                Path(output_arg.split("=", 1)[1]).with_suffix(".ms").write_bytes(b"w8-model")
                return SimpleNamespace(returncode=0, stdout="ok\n", stderr="")

            output = root / "output"
            with mock.patch.object(converter, "_validate_toolchain", return_value=receipt), \
                    mock.patch.object(converter.subprocess, "run", side_effect=fake_run):
                report = converter.convert_direction(
                    converter_path, archive_path, onnx_root, output, config, "zh-en"
                )
            self.assertEqual(report["conversionPolicy"], converter.CONVERSION_POLICY)
            self.assertEqual(report["converter"]["binarySha256"], converter.CONVERTER_BINARY_SHA256)
            self.assertEqual(report["quantization"]["configSha256"], converter.QUANT_CONFIG_SHA256)
            self.assertEqual(set(report["graphs"]), {"encoder", "decoder_full"})
            for graph in converter.GRAPH_NAMES:
                self.assertEqual(report["graphs"][graph]["mindSporeLite"]["size"], 8)
                self.assertEqual(
                    report["graphs"][graph]["mindSporeLite"]["sha256"],
                    converter._sha256(output / f"{graph}.ms"),
                )

    def test_official_manifest_rejects_provenance_and_export_mutations(self):
        manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
        exporter.validate_official_models_manifest(manifest)
        notice = manifest["directions"]["en-zh"]["notice"]
        notice_path = ROOT / notice["path"]
        self.assertEqual(notice_path.stat().st_size, notice["size"])
        self.assertEqual(exporter._sha256_file(notice_path), notice["sha256"])
        license_text = manifest["licenseText"]
        license_path = ROOT / license_text["path"]
        self.assertEqual(license_path.stat().st_size, license_text["size"])
        self.assertEqual(exporter._sha256_file(license_path), license_text["sha256"])
        mutations = (
            (("directions", "en-zh", "revision"), "main"),
            (("directions", "en-zh", "files", "README.md", "sha256"), "f" * 64),
            (("directions", "en-zh", "files", "config.json", "sha256"), "f" * 64),
            (("directions", "zh-en", "files", "vocab.json", "sha256"), "f" * 64),
            (("directions", "en-zh", "files", "pytorch_model.bin", "sha256"), "f" * 64),
            (("directions", "zh-en", "files", "source.spm", "sha256"), "f" * 64),
            (("directions", "en-zh", "notice"), None),
            (("directions", "zh-en"), None),
            (("directions", "en-zh", "onnxDtype"), "FLOAT16"),
            (("directions", "en-zh", "sourceLanguage"), "zh"),
            (("directions", "en-zh", "targetLanguage"), "en"),
            (("directions", "zh-en", "sourceLanguage"), "en"),
            (("directions", "zh-en", "targetLanguage"), "zh"),
            (("directions", "en-zh", "weightFile"), "model.safetensors"),
            (("directions", "zh-en", "weightFile"), "pytorch_model.bin"),
            (("directions", "en-zh", "upstreamBenchmark", "bleu"), 0.0),
            (("directions", "zh-en", "upstreamBenchmark", "testSet"), "unknown"),
            (("directions", "en-zh", "architecture", "hiddenSize"), 256),
            (("directions", "en-zh", "architecture", "decoderLayers"), 2),
            (("directions", "en-zh", "architecture", "padTokenId"), 0),
            (("directions", "zh-en", "architecture", "vocabSize"), 65001),
            (("directions", "zh-en", "architecture", "attentionHeads"), 4),
            (("directions", "zh-en", "architecture", "targetMaxTokens"), 128),
            (("directions", "en-zh", "generation", "strategy"), "greedy"),
            (("directions", "en-zh", "generation", "numBeams"), 1),
            (("directions", "en-zh", "generation", "sourcePrefix"), ""),
            (("directions", "zh-en", "generation", "strategy"), "beam"),
            (("directions", "zh-en", "generation", "numBeams"), 4),
            (("directions", "zh-en", "generation", "sourcePrefix"), ">>cmn_Hans<< "),
            (("licenseText", "sha256"), "f" * 64),
            (("productionApproval",), {"releaseChannel": "local-learning"}),
        )
        for path, replacement in mutations:
            with self.subTest(path=path):
                candidate = copy.deepcopy(manifest)
                target = candidate
                for key in path[:-1]:
                    target = target[key]
                if replacement is None:
                    target.pop(path[-1])
                else:
                    target[path[-1]] = replacement
                with self.assertRaises(exporter.ContractError):
                    exporter.validate_official_models_manifest(candidate)

    def test_official_profiles_have_exact_two_graph_float32_contract(self):
        profiles = exporter.load_official_models_manifest(MANIFEST)
        for direction, decoder_layers in (("zh-en", 2), ("en-zh", 6)):
            with self.subTest(direction=direction):
                profile = profiles[direction]
                self.assertEqual(profile.decoder_layers, decoder_layers)
                self.assertEqual(profile.onnx_dtype, "FLOAT32")
                self.assertEqual(profile.target_max_tokens, 32)
                self.assertEqual(exporter._graph_names(profile), ("encoder", "decoder_full"))
                contract = exporter.build_graph_contract(profile)
                self.assertEqual(set(contract), {"encoder", "decoder_full"})
                decoder = contract["decoder_full"]
                self.assertEqual(
                    list(decoder["inputs"]),
                    [
                        "decoder_input_ids", "decoder_attention_mask",
                        "encoder_hidden_states", "encoder_attention_mask",
                    ],
                )
                self.assertEqual(decoder["inputs"]["decoder_input_ids"]["shape"], [1, 32])
                self.assertEqual(decoder["inputs"]["decoder_attention_mask"]["shape"], [1, 32])
                self.assertEqual(
                    decoder["inputs"]["encoder_hidden_states"]["shape"],
                    [1, profile.max_tokens, profile.hidden_size],
                )
                self.assertEqual(
                    decoder["outputs"]["logits"],
                    {"dtype": "FLOAT", "shape": [1, 32, profile.vocab_size]},
                )
                with self.assertRaises(exporter.ContractError):
                    exporter.build_graph_contract(profile, floating="FLOAT16")

    def test_schema_v1_local_learning_keeps_three_graph_layout(self):
        legacy = {"graphs": {}, "stableSoftmaxChains": {}}
        self.assertEqual(
            exporter._graph_names(legacy),
            ("encoder", "decoder_prefill", "decoder_step"),
        )

    def test_profile_values_are_validated_and_immutable(self):
        profile = exporter.load_profile(MANIFEST, "zh-en")
        self.assertFalse(isinstance(profile, dict))
        self.assertEqual(profile.decoder_layers, 2)
        with self.assertRaises((AttributeError, TypeError)):
            profile.decoder_layers = 6

    def test_reference_fixture_is_complete_and_language_pure(self):
        fixture = json.loads(REFERENCE.read_text(encoding="utf-8"))
        exporter.validate_reference_fixture(fixture)
        self.assertEqual({row["direction"] for row in fixture["rows"]}, {"en-zh", "zh-en"})
        self.assertEqual(len(fixture["rows"]), 8)

    def test_hugging_face_snapshot_path_preserves_pinned_revision(self):
        revision = "408d9bc410a388e1d9aef112a2daba955b945255"
        with tempfile.TemporaryDirectory() as directory:
            checkpoint = Path(directory) / "snapshots" / revision
            checkpoint.mkdir(parents=True)
            self.assertEqual(exporter._checkpoint_revision(checkpoint), revision)


if __name__ == "__main__":
    unittest.main()
