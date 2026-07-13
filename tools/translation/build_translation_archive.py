#!/usr/bin/env python3
"""Build and verify the deterministic translation model TAR/XZ archive."""

from __future__ import annotations

import argparse
import hashlib
import json
import lzma
import os
import re
import subprocess
import tarfile
import tempfile
from pathlib import Path
from typing import Callable, Dict, Iterable, Mapping, Optional, Sequence


CANONICAL_MEMBERS = ("encoder.ms", "decoder_prefill.ms", "decoder_step.ms")
XZ_VERSION = "5.8.3"
MAX_TAR_BYTES = 60 * 1024 * 1024


class ArchiveError(RuntimeError):
    pass


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _source_map(sources: Path | Mapping[str, Path]) -> Dict[str, Path]:
    if isinstance(sources, Path):
        result = {name: sources / name for name in CANONICAL_MEMBERS}
    else:
        result = {name: Path(sources[name]) for name in CANONICAL_MEMBERS}
    for name, path in result.items():
        if not path.is_file() or path.is_symlink():
            raise ArchiveError(f"missing regular model file for {name}: {path}")
    return result


def build_tar(sources: Path | Mapping[str, Path], output: Path) -> dict:
    source_by_name = _source_map(sources)
    output = Path(output)
    output.parent.mkdir(parents=True, exist_ok=True)
    members = []
    with tarfile.open(output, "w:", format=tarfile.USTAR_FORMAT) as archive:
        for name in CANONICAL_MEMBERS:
            source = source_by_name[name]
            size = source.stat().st_size
            info = tarfile.TarInfo(name)
            info.size = size
            info.mtime = 0
            info.uid = 0
            info.gid = 0
            info.uname = ""
            info.gname = ""
            info.mode = 0o644
            info.type = tarfile.REGTYPE
            with source.open("rb") as stream:
                archive.addfile(info, stream)
            members.append({"name": name, "size": size, "sha256": _sha256(source)})
    return {"schemaVersion": 1, "members": members}


def _validate_manifest(manifest: dict) -> list:
    base_keys = {"schemaVersion", "members"}
    if set(manifest) not in (base_keys, base_keys | {"tar", "archive"}) or manifest["schemaVersion"] != 1:
        raise ArchiveError("invalid archive manifest schema")
    for artifact_name in ("tar", "archive"):
        if artifact_name in manifest:
            artifact = manifest[artifact_name]
            if (
                not isinstance(artifact, dict)
                or set(artifact) != {"size", "sha256"}
                or not isinstance(artifact["size"], int)
                or artifact["size"] < 0
                or not re.fullmatch(r"[0-9a-fA-F]{64}", artifact.get("sha256", ""))
            ):
                raise ArchiveError(f"invalid {artifact_name} manifest record")
    members = manifest["members"]
    if not isinstance(members, list) or [item.get("name") for item in members] != list(CANONICAL_MEMBERS):
        raise ArchiveError("archive manifest member allowlist/order mismatch")
    for item in members:
        if set(item) != {"name", "size", "sha256"}:
            raise ArchiveError("invalid archive member schema")
        if not isinstance(item["size"], int) or item["size"] < 0:
            raise ArchiveError("invalid archive member size")
        if not re.fullmatch(r"[0-9a-fA-F]{64}", item["sha256"]):
            raise ArchiveError("invalid archive member hash")
    return members


def verify_tar(path: Path, manifest: dict) -> dict:
    path = Path(path)
    expected = _validate_manifest(manifest)
    if "tar" in manifest:
        if path.stat().st_size != manifest["tar"]["size"] or _sha256(path).lower() != manifest["tar"]["sha256"].lower():
            raise ArchiveError("TAR size/hash mismatch")
    raw = path.read_bytes()
    if len(raw) > MAX_TAR_BYTES:
        raise ArchiveError("TAR exceeds 60 MiB")
    try:
        with tarfile.open(fileobj=__import__("io").BytesIO(raw), mode="r:") as archive:
            members = archive.getmembers()
            if [member.name for member in members] != list(CANONICAL_MEMBERS):
                raise ArchiveError("TAR member allowlist/order mismatch")
            data_end = 0
            for member, wanted in zip(members, expected):
                if not member.isfile() or member.issym() or member.islnk():
                    raise ArchiveError("TAR allows regular files only")
                if "/" in member.name or "\\" in member.name or member.name in (".", ".."):
                    raise ArchiveError("TAR paths are forbidden")
                if (
                    member.mtime != 0
                    or member.uid != 0
                    or member.gid != 0
                    or member.uname != ""
                    or member.gname != ""
                    or member.mode != 0o644
                ):
                    raise ArchiveError("TAR metadata is not canonical")
                if member.size != wanted["size"]:
                    raise ArchiveError(f"TAR size mismatch: {member.name}")
                payload = archive.extractfile(member)
                if payload is None:
                    raise ArchiveError(f"TAR member is unreadable: {member.name}")
                digest = hashlib.sha256(payload.read()).hexdigest()
                if digest.lower() != wanted["sha256"].lower():
                    raise ArchiveError(f"TAR hash mismatch: {member.name}")
                data_end = member.offset_data + ((member.size + 511) // 512) * 512
    except (tarfile.TarError, EOFError) as error:
        raise ArchiveError(f"invalid TAR: {error}") from error
    if len(raw) < data_end + 1024 or any(raw[data_end:]):
        raise ArchiveError("TAR has non-zero trailing data")
    return manifest


def _run_xz_version(xz_executable: Path | str, runner: Callable) -> None:
    command = [str(xz_executable), "--version"]
    try:
        result = runner(command, capture_output=True, text=True, check=False, env={})
    except OSError as error:
        raise ArchiveError(f"cannot execute xz: {error}") from error
    output = f"{result.stdout or ''}\n{result.stderr or ''}"
    if result.returncode != 0 or not re.search(rf"\bxz \(XZ Utils\) {re.escape(XZ_VERSION)}\b", output):
        raise ArchiveError(f"xz must be XZ Utils {XZ_VERSION}")


def _compress_tar(
    tar_path: Path,
    xz_path: Path,
    xz_executable: Path | str,
    runner: Callable = subprocess.run,
) -> None:
    _run_xz_version(xz_executable, runner)
    command = [
        str(xz_executable),
        "--threads=1",
        "--check=crc64",
        "--lzma2=preset=9e",
        "--stdout",
        str(tar_path),
    ]
    environment = os.environ.copy()
    environment["XZ_DEFAULTS"] = ""
    environment["XZ_OPT"] = ""
    try:
        with xz_path.open("wb") as output:
            result = runner(command, stdout=output, stderr=subprocess.PIPE, text=False, check=False, env=environment)
    except OSError as error:
        xz_path.unlink(missing_ok=True)
        raise ArchiveError(f"xz failed: {error}") from error
    if result.returncode != 0:
        xz_path.unlink(missing_ok=True)
        stderr = result.stderr.decode("utf-8", "replace") if isinstance(result.stderr, bytes) else result.stderr
        raise ArchiveError(f"xz failed: {stderr or result.returncode}")


def _decompress_one_xz(path: Path) -> bytes:
    payload = path.read_bytes()
    decoder = lzma.LZMADecompressor(format=lzma.FORMAT_XZ)
    try:
        raw = decoder.decompress(payload, max_length=MAX_TAR_BYTES + 1)
    except lzma.LZMAError as error:
        raise ArchiveError(f"invalid XZ stream: {error}") from error
    if len(raw) > MAX_TAR_BYTES:
        raise ArchiveError("XZ output exceeds 60 MiB")
    if not decoder.eof or decoder.unused_data:
        raise ArchiveError("XZ has trailing or concatenated stream data")
    if decoder.check != lzma.CHECK_CRC64:
        raise ArchiveError("XZ stream must use CRC64")
    return raw


def verify_archive(path: Path, manifest: dict) -> dict:
    path = Path(path)
    _validate_manifest(manifest)
    if "archive" in manifest:
        if path.stat().st_size != manifest["archive"]["size"] or _sha256(path).lower() != manifest["archive"]["sha256"].lower():
            raise ArchiveError("XZ archive size/hash mismatch")
    raw = _decompress_one_xz(path)
    with tempfile.NamedTemporaryFile(suffix=".tar", delete=False) as stream:
        stream.write(raw)
        temporary = Path(stream.name)
    try:
        return verify_tar(temporary, manifest)
    finally:
        temporary.unlink(missing_ok=True)


def build_archive(
    sources: Path | Mapping[str, Path],
    tar_path: Path,
    xz_path: Path,
    xz_executable: Path | str,
    *,
    runner: Callable = subprocess.run,
) -> dict:
    tar_path = Path(tar_path)
    xz_path = Path(xz_path)
    manifest = build_tar(sources, tar_path)
    verify_tar(tar_path, manifest)
    xz_path.parent.mkdir(parents=True, exist_ok=True)
    _compress_tar(tar_path, xz_path, xz_executable, runner)
    verify_archive(xz_path, manifest)
    return manifest


def _arguments(argv: Optional[Sequence[str]] = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--encoder", required=True, type=Path)
    parser.add_argument("--decoder-prefill", required=True, type=Path)
    parser.add_argument("--decoder-step", required=True, type=Path)
    parser.add_argument("--tar", required=True, type=Path)
    parser.add_argument("--archive", required=True, type=Path)
    parser.add_argument("--xz", required=True, type=Path)
    parser.add_argument("--manifest-out", required=True, type=Path)
    return parser.parse_args(argv)


def main(argv: Optional[Sequence[str]] = None) -> int:
    args = _arguments(argv)
    sources = {
        "encoder.ms": args.encoder,
        "decoder_prefill.ms": args.decoder_prefill,
        "decoder_step.ms": args.decoder_step,
    }
    manifest = build_archive(sources, args.tar, args.archive, args.xz)
    manifest["tar"] = {"size": args.tar.stat().st_size, "sha256": _sha256(args.tar)}
    manifest["archive"] = {"size": args.archive.stat().st_size, "sha256": _sha256(args.archive)}
    args.manifest_out.parent.mkdir(parents=True, exist_ok=True)
    args.manifest_out.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
