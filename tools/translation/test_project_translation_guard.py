import hashlib
import json
import lzma
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

from tools.translation.build_translation_archive import build_tar


ROOT = Path(__file__).resolve().parents[2]
GUARD = ROOT / "Mindspore_inhand_HarmonyOS" / "scripts" / "verify-translation-model.ps1"
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


def _tensor(name, dtype, shape):
    return {"name": name, "dtype": dtype, "shape": shape}


def _graphs(member_manifest):
    members = {item["name"]: item for item in member_manifest["members"]}
    float32 = "FLOAT32"
    cache_one = [1, 8, 1, 32]
    cache_cross = [1, 8, 128, 32]
    cache_past = [1, 8, 127, 32]
    return [
        {
            "file": "encoder.ms", "size": members["encoder.ms"]["size"], "sha256": members["encoder.ms"]["sha256"],
            "inputs": [_tensor("input_ids", "INT32", [1, 128]), _tensor("attention_mask", "INT32", [1, 128])],
            "outputs": [_tensor("last_hidden_state", float32, [1, 128, 256])],
        },
        {
            "file": "decoder_prefill.ms", "size": members["decoder_prefill.ms"]["size"], "sha256": members["decoder_prefill.ms"]["sha256"],
            "inputs": [
                _tensor("decoder_input_ids", "INT32", [1, 1]),
                _tensor("encoder_hidden_states", float32, [1, 128, 256]),
                _tensor("encoder_attention_mask", "INT32", [1, 128]),
            ],
            "outputs": [_tensor("logits", float32, [1, 32003])] + [
                _tensor(f"{kind}_{layer}", float32, cache_one if kind.startswith("self") else cache_cross)
                for layer in range(2) for kind in ("self_key", "self_value", "cross_key", "cross_value")
            ],
        },
        {
            "file": "decoder_step.ms", "size": members["decoder_step.ms"]["size"], "sha256": members["decoder_step.ms"]["sha256"],
            "inputs": [
                _tensor("decoder_input_ids", "INT32", [1, 1]),
                _tensor("position_id", "INT32", [1]),
                _tensor("self_attention_mask", "INT32", [1, 128]),
                _tensor("cross_attention_mask", "INT32", [1, 128]),
            ] + [
                _tensor(f"{kind}_{layer}", float32, cache_past if kind.startswith("past") else cache_cross)
                for layer in range(2) for kind in ("past_key", "past_value", "cross_key", "cross_value")
            ],
            "outputs": [_tensor("logits", float32, [1, 32003])] + [
                _tensor(f"new_{kind}_{layer}", float32, cache_one)
                for layer in range(2) for kind in ("key", "value")
            ],
        },
    ]


class ProjectTranslationGuardTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.stage = self.root / "stage"
        self.models = self.root / "models"
        self.stage.mkdir()
        self.models.mkdir()
        for index, name in enumerate(("encoder.ms", "decoder_prefill.ms", "decoder_step.ms"), 1):
            (self.models / name).write_bytes((name.encode("ascii") + b"\0") * index)
        tar_path = self.root / "models.tar"
        member_manifest = build_tar(self.models, tar_path)
        archive = self.stage / "translation-models.tar.xz"
        archive.write_bytes(lzma.compress(tar_path.read_bytes(), format=lzma.FORMAT_XZ, check=lzma.CHECK_CRC64, preset=9))
        runtime_manifest = {
            "schemaVersion": 1,
            "vocabulary": {"size": 32003, "eos": 0, "unk": 1, "pad": 32000, "decoderStart": 32000, "toEnglish": 32001, "toChinese": 32002},
            "archive": {"file": archive.name, "size": archive.stat().st_size, "sha256": _sha(archive), "cacheKey": "ARCHIVE_SHA256"},
            "graphs": _graphs(member_manifest),
        }
        (self.stage / "manifest.json").write_text(json.dumps(runtime_manifest, separators=(",", ":")), encoding="utf-8")
        for name, payload in {
            "tokenizer.model": b"tokenizer", "vocab.json": b"{}", "tokenizer_runtime.json": b"{}",
            "LICENSES.md": b"fixture", "SHA256SUMS": b"fixture", "libtranslation_archive.so": b"fixture",
        }.items():
            (self.stage / name).write_bytes(payload)
        self.package_manifest = self.root / "package.json"
        self._refresh_package_manifest()

    def tearDown(self):
        self.temp.cleanup()

    def _refresh_package_manifest(self):
        role_by_name = {name: role for role, name in FILES_BY_ROLE.items()}
        assets = [{"role": role_by_name[path.name], "path": path.name, "size": path.stat().st_size, "sha256": _sha(path)}
                  for path in sorted(self.stage.iterdir(), key=lambda item: item.name)]
        package = {
            "schemaVersion": 1, "mode": "final", "limitBytes": 35 * 1024 * 1024,
            "assets": assets, "allowances": [],
            "evidence": {
                "sourceEvidence": {"tar": {"size": 1, "sha256": "0" * 64}, "archive": {"size": 1, "sha256": "1" * 64}},
                "canonicalRebuild": {"tar": {"size": 1, "sha256": "2" * 64}, "archive": {"size": 1, "sha256": "3" * 64}},
            },
        }
        self.package_manifest.write_text(json.dumps(package), encoding="utf-8")

    def _run(self):
        return subprocess.run([
            str(POWERSHELL), "-NoLogo", "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass",
            "-File", str(GUARD), "-StageRoot", str(self.stage), "-PackageManifestPath", str(self.package_manifest),
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


if __name__ == "__main__":
    unittest.main()
