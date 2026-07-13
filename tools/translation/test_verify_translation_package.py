import hashlib
import json
import tempfile
import unittest
from pathlib import Path

from tools.translation.verify_translation_package import PackageError, verify_package


def _sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


class TranslationPackageTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.stage = self.root / "stage"
        self.stage.mkdir()
        (self.stage / "translation-models.tar.xz").write_bytes(b"archive")
        (self.stage / "tokenizer.model").write_bytes(b"tokenizer")
        self.manifest_path = self.root / "package.json"

    def tearDown(self):
        self.temp.cleanup()

    def _manifest(self, *, mode="prototype", allowance=5):
        assets = []
        for path in sorted(self.stage.iterdir()):
            assets.append({
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

    def test_verifier_hashes_every_staged_asset_and_counts_prototype_allowance(self):
        self._manifest()
        result = verify_package(self.manifest_path, self.stage)
        self.assertEqual(result["assetBytes"], len(b"archive") + len(b"tokenizer"))
        self.assertEqual(result["allowanceBytes"], 5)
        self.assertEqual(result["totalBytes"], len(b"archive") + len(b"tokenizer") + 5)

    def test_verifier_rejects_hash_mutation_extra_missing_and_limit_overflow(self):
        self._manifest()
        (self.stage / "tokenizer.model").write_bytes(b"mutated")
        with self.assertRaisesRegex(PackageError, "hash|size"):
            verify_package(self.manifest_path, self.stage)

        (self.stage / "tokenizer.model").write_bytes(b"tokenizer")
        (self.stage / "extra.bin").write_bytes(b"extra")
        with self.assertRaisesRegex(PackageError, "unexpected"):
            verify_package(self.manifest_path, self.stage)

        (self.stage / "extra.bin").unlink()
        (self.stage / "tokenizer.model").unlink()
        with self.assertRaisesRegex(PackageError, "missing"):
            verify_package(self.manifest_path, self.stage)

        (self.stage / "tokenizer.model").write_bytes(b"tokenizer")
        self._manifest(allowance=36_700_160)
        with self.assertRaisesRegex(PackageError, "36700160|limit|bytes"):
            verify_package(self.manifest_path, self.stage)

    def test_final_mode_rejects_allowances_and_requires_complete_real_files(self):
        self._manifest(mode="final", allowance=5)
        with self.assertRaisesRegex(PackageError, "allowance"):
            verify_package(self.manifest_path, self.stage)

        self._manifest(mode="final", allowance=0)
        result = verify_package(self.manifest_path, self.stage)
        self.assertEqual(result["allowanceBytes"], 0)

    def test_manifest_schema_is_strict(self):
        manifest = self._manifest()
        manifest["unknown"] = True
        self.manifest_path.write_text(json.dumps(manifest), encoding="utf-8")
        with self.assertRaisesRegex(PackageError, "unknown"):
            verify_package(self.manifest_path, self.stage)


if __name__ == "__main__":
    unittest.main()
