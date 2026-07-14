import hashlib
import inspect
import json
import tempfile
import unittest
from pathlib import Path
from unittest import mock

from tools.translation.final_package_test_fixture import build_final_package_fixture
from tools.translation.verify_translation_package import PackageError, verify_package


REQUIRED_ASSETS = {
    "archive": "translation-models.tar.xz",
    "tokenizer": "tokenizer.model",
    "vocabulary": "vocab.json",
    "tokenizer-runtime": "tokenizer_runtime.json",
    "manifest": "manifest.json",
    "licenses": "LICENSES.md",
    "checksums": "SHA256SUMS",
    "decompressor": "libtranslation_archive.so",
}
PROTOTYPE_ASSETS = {role: name for role, name in REQUIRED_ASSETS.items() if role != "decompressor"}


def _sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


class TranslationPackageTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.stage = self.root / "stage"
        self.stage.mkdir()
        for role, name in PROTOTYPE_ASSETS.items():
            (self.stage / name).write_bytes(role.encode("ascii"))
        self.decompressor = self.root / REQUIRED_ASSETS["decompressor"]
        self.manifest_path = self.root / "package.json"

    def tearDown(self):
        self.temp.cleanup()

    def _manifest(self, *, mode="prototype", allowance=5, include_decompressor=False):
        roles_by_name = {name: role for role, name in REQUIRED_ASSETS.items()}
        assets = []
        for path in sorted(self.stage.iterdir(), key=lambda item: item.name):
            assets.append({
                "role": roles_by_name[path.name],
                "path": path.name,
                "size": path.stat().st_size,
                "sha256": _sha256(path),
            })
        if include_decompressor:
            assets.append({
                "role": "decompressor",
                "path": self.decompressor.name,
                "size": self.decompressor.stat().st_size,
                "sha256": _sha256(self.decompressor),
            })
            assets.sort(key=lambda asset: asset["path"])
        manifest = {
            "schemaVersion": 1,
            "mode": mode,
            "limitBytes": 36_700_160,
            "assets": assets,
            "allowances": [],
            "evidence": {
                "sourceEvidence": {
                    "tar": {"size": 1, "sha256": "0" * 64},
                    "archive": {"size": 1, "sha256": "1" * 64},
                },
                "canonicalRebuild": {
                    "tar": {"size": 1, "sha256": "2" * 64},
                    "archive": {"size": 1, "sha256": "3" * 64},
                },
            },
        }
        if mode == "final":
            manifest["evidence"].update({
                "qualityGateReport": {"path": "gate-v1.json", "bytes": 1, "sha256": "4" * 64},
                "conversionReport": {"path": "conversion-report.json", "bytes": 1, "sha256": "5" * 64},
                "approval": {
                    "candidate": {
                        "model_sha256": "6" * 64,
                        "tokenizer_sha256": "e5528e885e876c18a3c0beef124842798138b688da3ca0e64425047c8c574190",
                    },
                    "candidateEpoch": 1,
                    "objectiveHashes": {"contract": "7" * 64},
                },
            })
        if allowance:
            manifest["allowances"].append({
                "name": "ohos-liblzma-decompressor",
                "bytes": allowance,
                "prototypeOnly": True,
            })
        self.manifest_path.write_text(json.dumps(manifest), encoding="utf-8")
        return manifest

    def _write_manifest(self, manifest):
        self.manifest_path.write_text(json.dumps(manifest), encoding="utf-8")

    def _make_decompressor(self):
        self.decompressor.write_bytes(b"decompressor")

    def _authentic_final(self, suffix):
        root = self.root / suffix
        root.mkdir()
        return build_final_package_fixture(root)

    def test_verifier_hashes_every_staged_asset_and_counts_prototype_allowance(self):
        self._manifest()
        result = verify_package(self.manifest_path, self.stage)
        self.assertEqual(result["assetBytes"], sum(path.stat().st_size for path in self.stage.iterdir()))
        self.assertEqual(result["allowanceBytes"], 5)
        self.assertEqual(result["totalBytes"], result["assetBytes"] + 5)

    def test_verifier_rejects_hash_mutation_extra_missing_and_limit_overflow(self):
        self._manifest()
        tokenizer = self.stage / "tokenizer.model"
        tokenizer.write_bytes(b"mutated")
        with self.assertRaisesRegex(PackageError, "hash|size"):
            verify_package(self.manifest_path, self.stage)

        tokenizer.write_bytes(b"tokenizer")
        self._manifest()
        (self.stage / "extra.bin").write_bytes(b"extra")
        with self.assertRaisesRegex(PackageError, "unexpected"):
            verify_package(self.manifest_path, self.stage)

        (self.stage / "extra.bin").unlink()
        tokenizer.unlink()
        with self.assertRaisesRegex(PackageError, "missing"):
            verify_package(self.manifest_path, self.stage)

        tokenizer.write_bytes(b"tokenizer")
        self._manifest(allowance=36_700_160)
        with self.assertRaisesRegex(PackageError, "36700160|limit|bytes"):
            verify_package(self.manifest_path, self.stage)

    def test_final_mode_rejects_allowances_and_accepts_complete_real_files(self):
        fixture = self._authentic_final("final-allowance")
        manifest_path = fixture["packageManifest"]
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        manifest["allowances"] = [{
            "name": "ohos-liblzma-decompressor", "bytes": 5, "prototypeOnly": True,
        }]
        manifest_path.write_text(json.dumps(manifest), encoding="utf-8")
        with self.assertRaisesRegex(PackageError, "allowance"):
            verify_package(
                manifest_path, fixture["stage"], fixture["decompressor"], fixture["releaseEvidence"]
            )

        manifest["allowances"] = []
        manifest_path.write_text(json.dumps(manifest), encoding="utf-8")
        result = verify_package(
            manifest_path, fixture["stage"], fixture["decompressor"], fixture["releaseEvidence"]
        )
        self.assertEqual(result["allowanceBytes"], 0)

    def test_final_mode_verifies_external_decompressor_and_rejects_rawfile_duplicate(self):
        self.assertIn("decompressor_path", inspect.signature(verify_package).parameters)
        fixture = self._authentic_final("final-native")
        result = verify_package(
            fixture["packageManifest"], fixture["stage"], fixture["decompressor"],
            fixture["releaseEvidence"],
        )
        self.assertEqual(
            result["assetBytes"],
            sum(path.stat().st_size for path in fixture["stage"].iterdir())
            + fixture["decompressor"].stat().st_size,
        )

        duplicate = fixture["stage"] / fixture["decompressor"].name
        duplicate.write_bytes(fixture["decompressor"].read_bytes())
        with self.assertRaisesRegex(PackageError, "unexpected|duplicate"):
            verify_package(
                fixture["packageManifest"], fixture["stage"], fixture["decompressor"],
                fixture["releaseEvidence"],
            )

    def test_final_release_evidence_is_external_and_binds_the_production_candidate(self):
        self.assertIn("release_evidence_path", inspect.signature(verify_package).parameters)
        fixture = self._authentic_final("final-release-evidence")
        with self.assertRaisesRegex(PackageError, "external release evidence"):
            verify_package(fixture["packageManifest"], fixture["stage"], fixture["decompressor"])
        manifest = json.loads(fixture["packageManifest"].read_text(encoding="utf-8"))
        manifest["evidence"]["approval"]["candidate"]["model_sha256"] = "f" * 64
        fixture["packageManifest"].write_text(json.dumps(manifest), encoding="utf-8")
        with self.assertRaisesRegex(PackageError, "release|approval|candidate|gate"):
            verify_package(
                fixture["packageManifest"], fixture["stage"], fixture["decompressor"],
                fixture["releaseEvidence"],
            )

    def test_final_mode_rejects_removal_of_every_required_asset(self):
        for role, name in REQUIRED_ASSETS.items():
            with self.subTest(role=role):
                self._make_decompressor()
                manifest = self._manifest(mode="final", allowance=0, include_decompressor=True)
                path = self.decompressor if role == "decompressor" else self.stage / name
                path.unlink()
                try:
                    manifest["assets"] = [asset for asset in manifest["assets"] if asset["role"] != role]
                    self._write_manifest(manifest)
                    with self.assertRaisesRegex(PackageError, "required|missing"):
                        verify_package(self.manifest_path, self.stage, self.decompressor)
                finally:
                    path.write_bytes(role.encode("ascii"))

    def test_prototype_mode_rejects_removal_of_every_non_decompressor_asset(self):
        for role, name in PROTOTYPE_ASSETS.items():
            with self.subTest(role=role):
                manifest = self._manifest()
                (self.stage / name).unlink()
                try:
                    manifest["assets"] = [asset for asset in manifest["assets"] if asset["role"] != role]
                    self._write_manifest(manifest)
                    with self.assertRaisesRegex(PackageError, "required|missing"):
                        verify_package(self.manifest_path, self.stage)
                finally:
                    (self.stage / name).write_bytes(role.encode("ascii"))

    def test_prototype_may_ship_real_decompressor_instead_of_allowance(self):
        self._make_decompressor()
        self._manifest(allowance=0, include_decompressor=True)
        result = verify_package(self.manifest_path, self.stage, self.decompressor)
        self.assertEqual(result["allowanceBytes"], 0)

    def test_prototype_requires_exactly_one_decompressor_source(self):
        self._manifest(allowance=0)
        with self.assertRaisesRegex(PackageError, "decompressor|allowance"):
            verify_package(self.manifest_path, self.stage)

        self._make_decompressor()
        self._manifest(allowance=5, include_decompressor=True)
        with self.assertRaisesRegex(PackageError, "decompressor|allowance"):
            verify_package(self.manifest_path, self.stage, self.decompressor)

    def test_prototype_rejects_unknown_or_multiple_allowance_names(self):
        manifest = self._manifest()
        manifest["allowances"][0]["name"] = "unknown-decompressor"
        self._write_manifest(manifest)
        with self.assertRaisesRegex(PackageError, "allowance"):
            verify_package(self.manifest_path, self.stage)

        manifest = self._manifest()
        manifest["allowances"].append(dict(manifest["allowances"][0]))
        self._write_manifest(manifest)
        with self.assertRaisesRegex(PackageError, "allowance"):
            verify_package(self.manifest_path, self.stage)

    def test_manifest_rejects_unknown_duplicate_or_mismatched_asset_roles_and_names(self):
        manifest = self._manifest()
        manifest["assets"][0]["role"] = "unknown"
        self._write_manifest(manifest)
        with self.assertRaisesRegex(PackageError, "role|asset"):
            verify_package(self.manifest_path, self.stage)

        manifest = self._manifest()
        manifest["assets"].append(dict(manifest["assets"][0]))
        self._write_manifest(manifest)
        with self.assertRaisesRegex(PackageError, "duplicate.*role"):
            verify_package(self.manifest_path, self.stage)

        manifest = self._manifest()
        manifest["assets"][0]["path"] = manifest["assets"][1]["path"]
        self._write_manifest(manifest)
        with self.assertRaisesRegex(PackageError, "duplicate|role|asset"):
            verify_package(self.manifest_path, self.stage)

        manifest = self._manifest()
        manifest["assets"][0]["path"] = "../LICENSES.md"
        self._write_manifest(manifest)
        with self.assertRaisesRegex(PackageError, "path"):
            verify_package(self.manifest_path, self.stage)

    def test_verifier_rejects_symlinked_required_asset(self):
        tokenizer = self.stage / "tokenizer.model"
        outside = self.root / "outside.model"
        outside.write_bytes(tokenizer.read_bytes())
        tokenizer.unlink()
        try:
            tokenizer.symlink_to(outside)
        except OSError:
            tokenizer.write_bytes(outside.read_bytes())
            self._manifest()
            with mock.patch.object(
                type(tokenizer),
                "is_symlink",
                autospec=True,
                side_effect=lambda candidate: candidate == tokenizer,
            ):
                with self.assertRaisesRegex(PackageError, "regular file|symlink"):
                    verify_package(self.manifest_path, self.stage)
            return
        self._manifest()
        with self.assertRaisesRegex(PackageError, "regular file|symlink"):
            verify_package(self.manifest_path, self.stage)

    def test_manifest_schema_is_strict(self):
        manifest = self._manifest()
        manifest["unknown"] = True
        self._write_manifest(manifest)
        with self.assertRaisesRegex(PackageError, "unknown"):
            verify_package(self.manifest_path, self.stage)


if __name__ == "__main__":
    unittest.main()
