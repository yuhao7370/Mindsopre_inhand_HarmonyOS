import copy
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

from tools.translation import build_translation_archive as archive
from tools.translation import build_open_source_translation_package as package
from tools.translation import verify_open_source_translation_package as verifier


ROOT = Path(__file__).resolve().parents[2]
OFFICIAL = ROOT / "tools" / "translation" / "manifests" / "open-source-edge-models-v1.json"
EVIDENCE = ROOT / "tools" / "translation" / "manifests" / "open-source-edge-conversion-evidence-v1.json"
PACKAGE_LOCK = ROOT / "tools" / "translation" / "manifests" / "open-source-edge-package-lock-v2.json"
RAW_PACKAGE = ROOT / "Mindspore_inhand_HarmonyOS" / "entry" / "src" / "main" / "resources" / "rawfile" / "models" / "translation"


def runtime_manifest_fixture():
    official = json.loads(OFFICIAL.read_text(encoding="utf-8"))
    evidence = json.loads(EVIDENCE.read_text(encoding="utf-8"))
    tokenizer_records = {
        "zh-en/shared": {
            "file": "", "size": 6254032,
            "sha256": "272dd9a4dee268f578865af6f51534a60e900170872b09f13b5c76e3687fcc61",
            "modelSha256": "e5528a5c3685d08f8868902d31febeb763eea8519f9997f43b05964b02554640",
            "vocabularySha256": "13690d04e27310a43f0d879dfd38823c317e9ac69f436754baffbb0da6fc9dbe",
            "pieceCount": 32000,
            "decodeVocabularySize": 32001,
            "specialTokens": {"eos": "</s>", "unk": "<unk>", "pad": "<pad>"},
        },
        "en-zh/source": {
            "file": "", "size": 6505149,
            "sha256": "65f8d80b682fcf6a6920103bc11d72bf7c1b7fde9d6c470f7a32146afec6cb1a",
            "modelSha256": "5775ddc9e3ff2fae91554da56468ad35ff56edaba870fea74447bc7234bfdaa8",
            "vocabularySha256": "f1832ca38f7aa158b9a944ff583e4901e6b37d9d4ad9241f03838e636e9cfb03",
            "pieceCount": 32000,
            "decodeVocabularySize": 0,
            "specialTokens": {"eos": "</s>", "unk": "<unk>", "pad": "<pad>"},
        },
        "en-zh/target": {
            "file": "", "size": 6235904,
            "sha256": "0dbe12b8a22483d82fc56d464969de7d6c874465d9e20fa28f22b7e6c2714643",
            "modelSha256": "81dc94efa84e4025ef38d25d5d07429fe41e3eb29d44003f1db6fe98487b0052",
            "vocabularySha256": "f1832ca38f7aa158b9a944ff583e4901e6b37d9d4ad9241f03838e636e9cfb03",
            "pieceCount": 0,
            "decodeVocabularySize": 65001,
            "specialTokens": {"eos": "</s>", "unk": "<unk>", "pad": "<pad>"},
        },
    }
    members = []
    for name in archive.CANONICAL_MEMBERS:
        if name.endswith(".ms"):
            direction, file_name = name.split("/")
            graph = "encoder" if file_name == "encoder.ms" else "decoder_full"
            record = evidence["directions"][direction]["graphs"][graph]["mindSporeLite"]
        elif name == "zh-en/tokenizer.ttok":
            record = tokenizer_records["zh-en/shared"]
        elif name == "en-zh/source.ttok":
            record = tokenizer_records["en-zh/source"]
        else:
            record = tokenizer_records["en-zh/target"]
        members.append({"name": name, "size": record["size"], "sha256": record["sha256"]})
    archive_manifest = {
        "schemaVersion": 2,
        "members": members,
        "tar": {"size": 208732160, "sha256": "a" * 64},
        "archive": {"size": 100000000, "sha256": "b" * 64},
    }
    return package.build_runtime_manifest(
        official, evidence, archive_manifest, tokenizer_records
    )


class TranslationPackageV2Test(unittest.TestCase):
    def test_package_metadata_serializers_use_canonical_lf_bytes(self):
        json_serializer = getattr(package, "_canonical_json_bytes", None)
        checksum_serializer = getattr(package, "_canonical_checksum_bytes", None)
        self.assertTrue(callable(json_serializer))
        self.assertTrue(callable(checksum_serializer))
        json_payload = json_serializer({"values": [1, 2]})
        checksum_payload = checksum_serializer(["A  one", "B  two"])
        self.assertNotIn(b"\r\n", json_payload)
        self.assertNotIn(b"\r\n", checksum_payload)
        self.assertTrue(json_payload.endswith(b"\n"))
        self.assertEqual(checksum_payload, b"A  one\nB  two\n")

    def test_ttok2_has_complete_unique_decode_vocab_and_allows_repeated_unk_encode_ids(self):
        runtime = "\n".join((
            "TTOK2\t" + "a" * 64 + "\t" + "b" * 64 + "\t4\t3\t4\t1\t-9.0\t1\t1\t1",
            "P\t0\t0.0\t3\t3C,2F,73,3E",
            "P\t1\t-1.0\t1\t61",
            "P\t1\t-2.0\t1\t62",
            "V\t0\t3C,2F,73,3E",
            "V\t1\t3C,75,6E,6B,3E",
            "V\t2\t78",
            "V\t3\t3C,70,61,64,3E",
            "",
        )).encode("ascii")
        descriptor = {
            "modelSha256": "a" * 64,
            "vocabularySha256": "b" * 64,
            "pieceCount": 3,
            "decodeVocabularySize": 4,
            "specialTokens": {"eos": "</s>", "unk": "<unk>", "pad": "<pad>"},
        }
        parsed = package.validate_tokenizer_runtime_bytes(runtime, descriptor)
        self.assertEqual(parsed["pieceIds"], [0, 1, 1])
        self.assertEqual(parsed.get("pieceTexts"), ["</s>", "a", "b"])
        self.assertEqual(parsed["vocabulary"], ["</s>", "<unk>", "x", "<pad>"])

        for label, lines in (
            ("missing", runtime.decode("ascii").replace("V\t2\t78\n", "")),
            ("duplicate-id", runtime.decode("ascii").replace("V\t2\t78", "V\t1\t78")),
            ("duplicate-text", runtime.decode("ascii").replace("V\t2\t78", "V\t2\t3C,75,6E,6B,3E")),
            ("wrong-special", runtime.decode("ascii").replace("V\t3\t3C,70,61,64,3E", "V\t3\t78")),
        ):
            with self.subTest(label=label), self.assertRaises(package.PackageV2Error):
                package.validate_tokenizer_runtime_bytes(lines.encode("ascii"), descriptor)

    def test_en_zh_prefix_contract_binds_target_id_and_excludes_source_piece(self):
        validate_prefix_contract = getattr(verifier, "validate_prefix_contract", None)
        self.assertTrue(callable(validate_prefix_contract))
        valid = {
            "en-zh/source.ttok": {
                "pieceTexts": ["▁hello", ">>cmn", "_Hans<<"],
                "vocabulary": [],
            },
            "en-zh/target.ttok": {
                "pieceTexts": [],
                "vocabulary": ["</s>", "<unk>", "a", "b", "c", ">>cmn_Hans<<", "<pad>"],
            },
        }
        validate_prefix_contract(valid)

        wrong_target = copy.deepcopy(valid)
        wrong_target["en-zh/target.ttok"]["vocabulary"][5] = ">>cmn_Hant<<"
        with self.assertRaisesRegex(verifier.PackageVerificationError, "target.*ID 5"):
            validate_prefix_contract(wrong_target)

        embedded_source = copy.deepcopy(valid)
        embedded_source["en-zh/source.ttok"]["pieceTexts"].append(
            "▁>>cmn_Hans<<"
        )
        with self.assertRaisesRegex(verifier.PackageVerificationError, "source.*prefix"):
            validate_prefix_contract(embedded_source)

    def test_package_clis_run_directly_without_pythonpath(self):
        for script in (
            ROOT / "tools" / "translation" / "build_open_source_translation_package.py",
            ROOT / "tools" / "translation" / "verify_open_source_translation_package.py",
        ):
            completed = subprocess.run(
                [sys.executable, str(script), "--help"],
                cwd=Path(script).parent,
                text=True,
                capture_output=True,
                check=False,
            )
            self.assertEqual(completed.returncode, 0, completed.stderr)

    def test_archive_has_exact_direction_scoped_members_and_measured_limits(self):
        self.assertEqual(
            archive.CANONICAL_MEMBERS,
            (
                "zh-en/encoder.ms",
                "zh-en/decoder_full.ms",
                "zh-en/tokenizer.ttok",
                "en-zh/encoder.ms",
                "en-zh/decoder_full.ms",
                "en-zh/source.ttok",
                "en-zh/target.ttok",
            ),
        )
        self.assertEqual(archive.MAX_TAR_BYTES, 208 * 1024 * 1024)
        self.assertEqual(archive.MAX_ARCHIVE_BYTES, 152 * 1024 * 1024)

    def test_tar_is_deterministic_and_rejects_swapped_or_missing_members(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            sources = {}
            for index, name in enumerate(archive.CANONICAL_MEMBERS):
                source = root / "inputs" / name
                source.parent.mkdir(parents=True, exist_ok=True)
                source.write_bytes((name + str(index)).encode("ascii"))
                sources[name] = source
            first = root / "first.tar"
            second = root / "second.tar"
            manifest = archive.build_tar(sources, first)
            archive.build_tar(sources, second)
            self.assertEqual(first.read_bytes(), second.read_bytes())
            archive.verify_tar(first, manifest)

            swapped = copy.deepcopy(manifest)
            swapped["members"][0], swapped["members"][1] = (
                swapped["members"][1], swapped["members"][0]
            )
            with self.assertRaisesRegex(archive.ArchiveError, "allowlist/order"):
                archive.verify_tar(first, swapped)

            missing = dict(sources)
            missing.pop("en-zh/target.ttok")
            with self.assertRaises((archive.ArchiveError, KeyError)):
                archive.build_tar(missing, root / "missing.tar")

    def test_manifest_rejects_traversal_duplicate_and_oversize_records(self):
        members = [
            {"name": name, "size": 1, "sha256": "a" * 64}
            for name in archive.CANONICAL_MEMBERS
        ]
        manifest = {"schemaVersion": 2, "members": members}
        archive._validate_manifest(manifest)
        for label, replacement in (
            ("traversal", "../encoder.ms"),
            ("duplicate", archive.CANONICAL_MEMBERS[0]),
        ):
            with self.subTest(label=label):
                candidate = copy.deepcopy(manifest)
                candidate["members"][1]["name"] = replacement
                with self.assertRaisesRegex(archive.ArchiveError, "allowlist/order"):
                    archive._validate_manifest(candidate)
        candidate = copy.deepcopy(manifest)
        candidate["members"][0]["size"] = archive.MAX_TAR_BYTES + 1
        with self.assertRaisesRegex(archive.ArchiveError, "payload"):
            archive._validate_manifest(candidate)

    def test_runtime_manifest_binds_two_directions_and_reuses_identical_tokenizer(self):
        manifest = runtime_manifest_fixture()
        package.validate_runtime_manifest(manifest)
        self.assertEqual(set(manifest["directions"]), {"en", "zh"})
        self.assertEqual(
            manifest["directions"]["en"]["tokenizers"]["source"],
            manifest["directions"]["en"]["tokenizers"]["target"],
        )
        self.assertNotEqual(
            manifest["directions"]["zh"]["tokenizers"]["source"]["file"],
            manifest["directions"]["zh"]["tokenizers"]["target"]["file"],
        )
        self.assertEqual(manifest["directions"]["en"]["graphBytes"], 37363640)
        self.assertEqual(manifest["directions"]["zh"]["graphBytes"], 152333536)
        self.assertEqual(
            manifest["directions"]["en"]["generation"].get("sourcePrefixTokenId"), -1
        )
        self.assertEqual(
            manifest["directions"]["zh"]["generation"].get("sourcePrefixTokenId"), 5
        )

    def test_runtime_manifest_rejects_swapped_direction_vocab_layer_and_tokenizer(self):
        manifest = runtime_manifest_fixture()
        mutations = (
            (("directions", "en", "targetLanguage"), "zh"),
            (("directions", "zh", "vocabulary", "size"), 32001),
            (("directions", "zh", "generation", "numBeams"), 1),
            (("directions", "en", "generation", "sourcePrefixTokenId"), 5),
            (("directions", "zh", "generation", "sourcePrefixTokenId"), -1),
            (("directions", "zh", "generation", "extra"), 1),
            (("directions", "en", "graphs", "decoderFull", "outputs", 0, "shape"), [1, 32, 65001]),
            (("directions", "en", "tokenizers", "target", "file"), "en-zh/target.ttok"),
            (("directions", "en", "repository"), "other/repository"),
            (("directions", "zh", "revision"), "0" * 40),
            (("directions", "en", "graphBytes"), 37363641),
            (("directions", "zh", "graphs", "encoder", "sha256"), "f" * 64),
            (("directions", "zh", "tokenizers", "source", "modelSha256"), "f" * 64),
            (("directions", "zh", "tokenizers", "target", "vocabularySha256"), "f" * 64),
            (("directions", "zh", "tokenizers", "target", "decodeVocabularySize"), 32001),
            (("directions", "en", "vocabulary", "extra"), 1),
            (("archive", "maxTarBytes"), 60 * 1024 * 1024),
        )
        for path, replacement in mutations:
            with self.subTest(path=path):
                candidate = copy.deepcopy(manifest)
                target = candidate
                for key in path[:-1]:
                    target = target[key]
                target[path[-1]] = replacement
                with self.assertRaises(package.PackageV2Error):
                    package.validate_runtime_manifest(candidate)

        missing_prefix = copy.deepcopy(manifest)
        del missing_prefix["directions"]["zh"]["generation"]["sourcePrefixTokenId"]
        with self.assertRaises(package.PackageV2Error):
            package.validate_runtime_manifest(missing_prefix)

    def test_external_package_lock_rejects_consistent_manifest_and_archive_tampering(self):
        manifest = runtime_manifest_fixture()
        archive_contract = package.archive_contract_from_manifest(manifest)
        manifest_artifact = {"size": 1234, "sha256": "c" * 64}
        lock = package.build_package_lock(manifest, archive_contract, manifest_artifact)
        package.validate_package_lock(lock, manifest, archive_contract, manifest_artifact)

        tampered_manifest = copy.deepcopy(manifest)
        tampered_manifest["archive"]["size"] += 1
        tampered_manifest["archive"]["sha256"] = "d" * 64
        tampered_contract = package.archive_contract_from_manifest(tampered_manifest)
        with self.assertRaises(package.PackageV2Error):
            package.validate_package_lock(
                lock, tampered_manifest, tampered_contract,
                {"size": 1235, "sha256": "e" * 64},
            )

        for label, path, replacement in (
            ("wrong-prefix-id", ("directions", "zh", "generation", "sourcePrefixTokenId"), -1),
            ("extra-generation-key", ("directions", "zh", "generation", "extra"), 1),
        ):
            with self.subTest(label=label):
                candidate = copy.deepcopy(manifest)
                target = candidate
                for key in path[:-1]:
                    target = target[key]
                target[path[-1]] = replacement
                with self.assertRaises(package.PackageV2Error):
                    package.validate_package_lock(
                        lock, candidate, archive_contract, manifest_artifact
                    )

        missing_prefix = copy.deepcopy(manifest)
        del missing_prefix["directions"]["zh"]["generation"]["sourcePrefixTokenId"]
        with self.assertRaises(package.PackageV2Error):
            package.validate_package_lock(
                lock, missing_prefix, archive_contract, manifest_artifact
            )

    def test_actual_verifier_rejects_manifest_and_archive_tampered_together(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            manifest = json.loads((RAW_PACKAGE / "manifest.json").read_text(encoding="utf-8"))
            (root / "translation-models.tar.xz").write_bytes(b"tampered archive")
            manifest["archive"]["size"] = (root / "translation-models.tar.xz").stat().st_size
            manifest["archive"]["sha256"] = archive._sha256(root / "translation-models.tar.xz")
            (root / "manifest.json").write_text(
                json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8"
            )
            (root / "LICENSES.md").write_bytes((RAW_PACKAGE / "LICENSES.md").read_bytes())
            (root / "SHA256SUMS").write_text(
                "".join(
                    f"{archive._sha256(root / name).upper()}  {name}\n"
                    for name in ("LICENSES.md", "manifest.json", "translation-models.tar.xz")
                ),
                encoding="ascii",
            )
            with self.assertRaisesRegex(verifier.PackageVerificationError, "external lock"):
                verifier.verify_package(root, PACKAGE_LOCK)


if __name__ == "__main__":
    unittest.main()
