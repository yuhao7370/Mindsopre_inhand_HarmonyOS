import hashlib
import json
import tempfile
import unittest
from pathlib import Path
from unittest import mock

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
        self.manifest_path = self.root / "package.json"

    def tearDown(self):
        self.temp.cleanup()

    def _manifest(self, *, mode="prototype", allowance=5):
        roles_by_name = {name: role for role, name in REQUIRED_ASSETS.items()}
        assets = []
        for path in sorted(self.stage.iterdir(), key=lambda item: item.name):
            assets.append({
                "role": roles_by_name[path.name],
                "path": path.name,
                "size": path.stat().st_size,
                "sha256": _sha256(path),
            })
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

    def _make_final_stage(self):
        (self.stage / REQUIRED_ASSETS["decompressor"]).write_bytes(b"decompressor")

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
        self._make_final_stage()
        self._manifest(mode="final", allowance=5)
        with self.assertRaisesRegex(PackageError, "allowance"):
            verify_package(self.manifest_path, self.stage)

        self._manifest(mode="final", allowance=0)
        result = verify_package(self.manifest_path, self.stage)
        self.assertEqual(result["allowanceBytes"], 0)

    def test_final_mode_rejects_removal_of_every_required_asset(self):
        for role, name in REQUIRED_ASSETS.items():
            with self.subTest(role=role):
                self._make_final_stage()
                manifest = self._manifest(mode="final", allowance=0)
                (self.stage / name).unlink()
                try:
                    manifest["assets"] = [asset for asset in manifest["assets"] if asset["role"] != role]
                    self._write_manifest(manifest)
                    with self.assertRaisesRegex(PackageError, "required|missing"):
                        verify_package(self.manifest_path, self.stage)
                finally:
                    (self.stage / name).write_bytes(role.encode("ascii"))

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
        self._make_final_stage()
        self._manifest(allowance=0)
        result = verify_package(self.manifest_path, self.stage)
        self.assertEqual(result["allowanceBytes"], 0)

    def test_prototype_requires_exactly_one_decompressor_source(self):
        self._manifest(allowance=0)
        with self.assertRaisesRegex(PackageError, "decompressor|allowance"):
            verify_package(self.manifest_path, self.stage)

        self._make_final_stage()
        self._manifest(allowance=5)
        with self.assertRaisesRegex(PackageError, "decompressor|allowance"):
            verify_package(self.manifest_path, self.stage)

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
