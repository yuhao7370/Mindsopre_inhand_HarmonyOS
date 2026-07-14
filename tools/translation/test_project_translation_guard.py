import hashlib
import json
import lzma
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

from tools.translation.final_package_test_fixture import build_final_package_fixture


ROOT = Path(__file__).resolve().parents[2]
GUARD = ROOT / "Mindspore_inhand_HarmonyOS" / "scripts" / "verify-translation-model.ps1"
BUILD_HAP = ROOT / "Mindspore_inhand_HarmonyOS" / "scripts" / "build-hap.ps1"
POWERSHELL = Path(os.environ.get("SystemRoot", r"C:\Windows")) / "System32" / "WindowsPowerShell" / "v1.0" / "powershell.exe"
FILES_BY_ROLE = {
    "archive": "translation-models.tar.xz",
    "tokenizer": "tokenizer.model",
    "vocabulary": "vocab.json",
    "tokenizer-runtime": "tokenizer_runtime.json",
    "manifest": "manifest.json",
    "licenses": "LICENSES.md",
    "checksums": "SHA256SUMS",
    "decompressor": "libtranslation_archive.so",
}


def _sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


class ProjectTranslationGuardTest(unittest.TestCase):
    def test_external_native_guard_contract_and_build_hap_activation_order(self):
        guard_source = GUARD.read_text(encoding="utf-8")
        self.assertIn("[string]$NativeDecompressorPath", guard_source)
        self.assertIn("'--decompressor'", guard_source)
        self.assertIn("[string]$ReleaseEvidencePath", guard_source)
        self.assertIn("'--release-evidence'", guard_source)

        build_source = BUILD_HAP.read_text(encoding="utf-8")
        self.assertIn("verify-translation-model.ps1", build_source)
        self.assertIn("local-learning-authorization-v1.json", build_source)
        self.assertIn("-ReleaseEvidencePath", build_source)
        ensure_index = build_source.index("ensure-mindspore-models.ps1")
        guard_index = build_source.index("verify-translation-model.ps1")
        hvigor_index = build_source.index("$hvigor =")
        self.assertLess(ensure_index, guard_index)
        self.assertLess(guard_index, hvigor_index)
        self.assertLess(ensure_index, hvigor_index)

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        fixture = build_final_package_fixture(self.root)
        self.stage = fixture["stage"]
        self.decompressor = fixture["decompressor"]
        self.package_manifest = fixture["packageManifest"]
        self.release_evidence = fixture["releaseEvidence"]
        self.tar_record = fixture["archiveManifest"]["tar"]

    def tearDown(self):
        self.temp.cleanup()

    def _refresh_package_manifest(self):
        checksum_names = sorted(set(FILES_BY_ROLE.values()) - {"SHA256SUMS", "libtranslation_archive.so"})
        (self.stage / "SHA256SUMS").write_bytes("".join(
            "%s  %s\n" % (_sha(self.stage / name).upper(), name) for name in checksum_names
        ).encode("ascii"))
        package = json.loads(self.package_manifest.read_text(encoding="utf-8"))
        for asset in package["assets"]:
            path = self.decompressor if asset["role"] == "decompressor" else self.stage / asset["path"]
            asset.update({"size": path.stat().st_size, "sha256": _sha(path)})
        archive = self.stage / "translation-models.tar.xz"
        evidence = {
            "tar": self.tar_record,
            "archive": {"size": archive.stat().st_size, "sha256": _sha(archive)},
        }
        package["evidence"] = {"sourceEvidence": evidence, "canonicalRebuild": json.loads(json.dumps(evidence))}
        self.package_manifest.write_text(json.dumps(package), encoding="utf-8")

    def _run(self):
        return subprocess.run([
            str(POWERSHELL), "-NoLogo", "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass",
            "-File", str(GUARD), "-StageRoot", str(self.stage), "-PackageManifestPath", str(self.package_manifest),
            "-NativeDecompressorPath", str(self.decompressor),
            "-ReleaseEvidencePath", str(self.release_evidence),
            "-Python", sys.executable,
        ], cwd=ROOT, text=True, capture_output=True)

    def _write_runtime(self, mutate):
        path = self.stage / "manifest.json"
        manifest = json.loads(path.read_text(encoding="utf-8"))
        mutate(manifest)
        path.write_text(json.dumps(manifest, separators=(",", ":")), encoding="utf-8")
        self._refresh_package_manifest()

    def test_valid_fixture_passes_and_default_missing_production_assets_fail(self):
        valid = self._run()
        self.assertEqual(valid.returncode, 0, valid.stdout + valid.stderr)
        missing = subprocess.run([
            str(POWERSHELL), "-NoLogo", "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-File", str(GUARD)
        ], cwd=ROOT, text=True, capture_output=True)
        self.assertNotEqual(missing.returncode, 0)
        self.assertRegex(missing.stdout + missing.stderr, "missing|Missing")

    def test_rejects_wrong_token_id_tensor_name_and_shape(self):
        mutations = (
            lambda value: value["vocabulary"].update({"toChinese": "32002"}),
            lambda value: value["graphs"][0]["inputs"][0].update({"name": "wrong"}),
            lambda value: value["graphs"][2]["inputs"][4].update({"shape": [1, 8, 128, 32]}),
        )
        original = (self.stage / "manifest.json").read_bytes()
        for mutate in mutations:
            with self.subTest(mutation=mutate):
                (self.stage / "manifest.json").write_bytes(original)
                self._write_runtime(mutate)
                result = self._run()
                self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_reuses_task1_archive_verifier_for_crc64_and_single_stream(self):
        archive = self.stage / "translation-models.tar.xz"
        original = archive.read_bytes()
        tar_bytes = lzma.decompress(original)
        for bad in (
            lzma.compress(tar_bytes, format=lzma.FORMAT_XZ, check=lzma.CHECK_CRC32),
            original + original,
            original + b"trailing",
        ):
            with self.subTest(size=len(bad)):
                archive.write_bytes(bad)
                self._write_runtime(lambda value: value["archive"].update({"size": len(bad), "sha256": _sha(archive)}))
                result = self._run()
                self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
                archive.write_bytes(original)

    def test_rejects_external_native_mutation_and_rawfile_duplicate(self):
        original = self.decompressor.read_bytes()
        self.decompressor.write_bytes(b"mutated native")
        mutated = self._run()
        self.assertNotEqual(mutated.returncode, 0, mutated.stdout + mutated.stderr)

        self.decompressor.write_bytes(original)
        duplicate = self.stage / self.decompressor.name
        duplicate.write_bytes(original)
        duplicated = self._run()
        self.assertNotEqual(duplicated.returncode, 0, duplicated.stdout + duplicated.stderr)


if __name__ == "__main__":
    unittest.main()
