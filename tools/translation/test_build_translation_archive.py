import hashlib
import io
import lzma
import os
import subprocess
import tarfile
import tempfile
import unittest
from pathlib import Path

from tools.translation.build_translation_archive import (
    ArchiveError,
    CANONICAL_MEMBERS,
    build_archive,
    build_tar,
    verify_archive,
    verify_tar,
)


class _PythonXzRunner:
    def __init__(self, version="5.8.3"):
        self.version = version
        self.commands = []

    def __call__(self, command, **kwargs):
        self.commands.append(tuple(str(part) for part in command))
        if "--version" in command:
            return subprocess.CompletedProcess(command, 0, f"xz (XZ Utils) {self.version}\n", "")
        source = Path(command[-1])
        payload = lzma.compress(
            source.read_bytes(),
            format=lzma.FORMAT_XZ,
            check=lzma.CHECK_CRC64,
            filters=[{"id": lzma.FILTER_LZMA2, "preset": 9 | lzma.PRESET_EXTREME}],
        )
        kwargs["stdout"].write(payload)
        return subprocess.CompletedProcess(command, 0, "", "")


class TranslationArchiveTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.models = self.root / "models"
        self.models.mkdir()
        for index, name in enumerate(CANONICAL_MEMBERS):
            path = self.models / name
            path.write_bytes((name.encode("ascii") + b"\0") * (index + 1))
            os.utime(path, (1_700_000_000 + index, 1_700_000_000 + index))

    def tearDown(self):
        self.temp.cleanup()

    def test_tar_and_xz_are_byte_identical_across_output_directories(self):
        first = self.root / "first"
        second = self.root / "second"
        first.mkdir()
        second.mkdir()
        runner = _PythonXzRunner()

        one = build_archive(self.models, first / "models.tar", first / "models.tar.xz", "xz", runner=runner)
        two = build_archive(self.models, second / "models.tar", second / "models.tar.xz", "xz", runner=runner)

        self.assertEqual((first / "models.tar").read_bytes(), (second / "models.tar").read_bytes())
        self.assertEqual((first / "models.tar.xz").read_bytes(), (second / "models.tar.xz").read_bytes())
        self.assertEqual(one, two)
        self.assertTrue(any("--check=crc64" in command for command in runner.commands))
        self.assertTrue(any("--threads=1" in command for command in runner.commands))
        persisted = dict(one)
        persisted["tar"] = {"size": (first / "models.tar").stat().st_size, "sha256": hashlib.sha256((first / "models.tar").read_bytes()).hexdigest()}
        persisted["archive"] = {"size": (first / "models.tar.xz").stat().st_size, "sha256": hashlib.sha256((first / "models.tar.xz").read_bytes()).hexdigest()}
        self.assertEqual(verify_archive(first / "models.tar.xz", persisted), persisted)

    def test_tar_metadata_and_member_order_are_canonical(self):
        tar_path = self.root / "models.tar"
        manifest = build_tar(self.models, tar_path)

        with tarfile.open(tar_path, "r:") as archive:
            members = archive.getmembers()
        self.assertEqual([member.name for member in members], list(CANONICAL_MEMBERS))
        for member in members:
            self.assertTrue(member.isfile())
            self.assertEqual(member.mtime, 0)
            self.assertEqual(member.uid, 0)
            self.assertEqual(member.gid, 0)
            self.assertEqual(member.uname, "")
            self.assertEqual(member.gname, "")
            self.assertEqual(member.mode, 0o644)
        self.assertEqual(verify_tar(tar_path, manifest), manifest)

    def test_verifier_rejects_extra_link_path_duplicate_and_trailing_xz_data(self):
        tar_path = self.root / "bad.tar"
        with tarfile.open(tar_path, "w", format=tarfile.USTAR_FORMAT) as archive:
            for name in CANONICAL_MEMBERS:
                payload = b"x"
                info = tarfile.TarInfo(name)
                info.size = len(payload)
                archive.addfile(info, io.BytesIO(payload))
            info = tarfile.TarInfo("extra.ms")
            info.size = 1
            archive.addfile(info, io.BytesIO(b"x"))
        manifest = {
            "schemaVersion": 1,
            "members": [
                {"name": name, "size": 1, "sha256": hashlib.sha256(b"x").hexdigest()}
                for name in CANONICAL_MEMBERS
            ]
        }
        with self.assertRaisesRegex(ArchiveError, "allowlist"):
            verify_tar(tar_path, manifest)

        good_tar = self.root / "good.tar"
        good_xz = self.root / "good.tar.xz"
        good_manifest = build_tar(self.models, good_tar)
        runner = _PythonXzRunner()
        build_archive(self.models, good_tar, good_xz, "xz", runner=runner)
        good_xz.write_bytes(good_xz.read_bytes() + b"trailing")
        with self.assertRaisesRegex(ArchiveError, "trailing|concatenated"):
            verify_archive(good_xz, good_manifest)

    def test_builder_rejects_wrong_or_compromised_xz_version(self):
        for version in ("5.6.0", "5.6.1", "5.8.2"):
            with self.subTest(version=version):
                with self.assertRaisesRegex(ArchiveError, "5.8.3"):
                    build_archive(
                        self.models,
                        self.root / f"{version}.tar",
                        self.root / f"{version}.tar.xz",
                        "xz",
                        runner=_PythonXzRunner(version),
                    )


if __name__ == "__main__":
    unittest.main()
