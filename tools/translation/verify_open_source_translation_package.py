#!/usr/bin/env python3
"""Verify the shipped schema-v2 dual-direction translation package."""

from __future__ import annotations

import argparse
import json
import lzma
import sys
import tarfile
from pathlib import Path

if __package__ in (None, ""):
    sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from tools.translation.build_open_source_translation_package import (
    _artifact,
    validate_package_lock,
    validate_runtime_manifest,
    validate_tokenizer_runtime_bytes,
)
from tools.translation.build_translation_archive import CANONICAL_MEMBERS, _sha256, verify_archive


class PackageVerificationError(RuntimeError):
    pass


DEFAULT_PACKAGE_LOCK = (
    Path(__file__).resolve().parent / "manifests" / "open-source-edge-package-lock-v2.json"
)
EN_ZH_SOURCE_PREFIX = ">>cmn_Hans<<"


def _tokenizer_payloads(archive_path: Path) -> dict:
    wanted = {
        "zh-en/tokenizer.ttok", "en-zh/source.ttok", "en-zh/target.ttok",
    }
    result = {}
    try:
        with lzma.open(archive_path, "rb") as stream, tarfile.open(fileobj=stream, mode="r|") as archive:
            for member in archive:
                if member.name in wanted:
                    payload = archive.extractfile(member)
                    if payload is None:
                        raise PackageVerificationError(f"unreadable TTOK2 member: {member.name}")
                    result[member.name] = payload.read()
    except (lzma.LZMAError, tarfile.TarError, EOFError) as error:
        raise PackageVerificationError(f"cannot inspect TTOK2 members: {error}") from error
    if set(result) != wanted:
        raise PackageVerificationError("archive TTOK2 member set differs")
    return result


def validate_prefix_contract(parsed_tokenizers: dict) -> None:
    target_vocabulary = parsed_tokenizers["en-zh/target.ttok"]["vocabulary"]
    if len(target_vocabulary) <= 5 or target_vocabulary[5] != EN_ZH_SOURCE_PREFIX:
        raise PackageVerificationError("en-zh target tokenizer ID 5 is not the exact source prefix")
    source_pieces = parsed_tokenizers["en-zh/source.ttok"]["pieceTexts"]
    if any(EN_ZH_SOURCE_PREFIX in piece for piece in source_pieces):
        raise PackageVerificationError("en-zh source tokenizer P table contains the complete prefix")


def verify_package(root: Path, package_lock_path: Path = DEFAULT_PACKAGE_LOCK) -> dict:
    root = Path(root)
    manifest_path = root / "manifest.json"
    archive_path = root / "translation-models.tar.xz"
    licenses_path = root / "LICENSES.md"
    sums_path = root / "SHA256SUMS"
    for path in (manifest_path, archive_path, licenses_path, sums_path):
        if not path.is_file() or path.is_symlink():
            raise PackageVerificationError(f"missing regular package asset: {path.name}")
    try:
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError) as error:
        raise PackageVerificationError("runtime manifest is invalid") from error
    validate_runtime_manifest(manifest)
    try:
        package_lock = json.loads(Path(package_lock_path).read_text(encoding="utf-8"))
    except (OSError, UnicodeDecodeError, json.JSONDecodeError) as error:
        raise PackageVerificationError("external package lock is invalid") from error
    directions = manifest["directions"]
    descriptors = {
        "zh-en/encoder.ms": directions["en"]["graphs"]["encoder"],
        "zh-en/decoder_full.ms": directions["en"]["graphs"]["decoderFull"],
        "zh-en/tokenizer.ttok": directions["en"]["tokenizers"]["source"],
        "en-zh/encoder.ms": directions["zh"]["graphs"]["encoder"],
        "en-zh/decoder_full.ms": directions["zh"]["graphs"]["decoderFull"],
        "en-zh/source.ttok": directions["zh"]["tokenizers"]["source"],
        "en-zh/target.ttok": directions["zh"]["tokenizers"]["target"],
    }
    archive_contract = {
        "schemaVersion": 2,
        "members": package_lock.get("members"),
        "tar": {
            "size": package_lock.get("tar", {}).get("size"),
            "sha256": package_lock.get("tar", {}).get("sha256"),
        },
        "archive": {
            "size": package_lock.get("archive", {}).get("size"),
            "sha256": package_lock.get("archive", {}).get("sha256"),
        },
    }
    try:
        validate_package_lock(package_lock, manifest, archive_contract, _artifact(manifest_path))
        verify_archive(archive_path, archive_contract)
    except Exception as error:
        raise PackageVerificationError(f"package differs from external lock: {error}") from error
    payloads = _tokenizer_payloads(archive_path)
    tokenizer_descriptors = {
        "zh-en/tokenizer.ttok": directions["en"]["tokenizers"]["source"],
        "en-zh/source.ttok": directions["zh"]["tokenizers"]["source"],
        "en-zh/target.ttok": directions["zh"]["tokenizers"]["target"],
    }
    parsed_tokenizers = {}
    for name, descriptor in tokenizer_descriptors.items():
        try:
            parsed_tokenizers[name] = validate_tokenizer_runtime_bytes(payloads[name], descriptor)
        except Exception as error:
            raise PackageVerificationError(f"invalid {name}: {error}") from error
    validate_prefix_contract(parsed_tokenizers)
    expected_sums = "".join(
        f"{_sha256(root / name).upper()}  {name}\n"
        for name in ("LICENSES.md", "manifest.json", "translation-models.tar.xz")
    )
    if sums_path.read_text(encoding="ascii") != expected_sums:
        raise PackageVerificationError("SHA256SUMS differs from the exact package assets")
    licenses = licenses_path.read_text(encoding="utf-8")
    for required in (
        "Helsinki-NLP/opus-mt-en-zh",
        "Helsinki-NLP/opus-mt_tiny_zho-eng",
        "Apache-2.0",
        "XZ Utils 5.8.3",
    ):
        if required not in licenses:
            raise PackageVerificationError(f"LICENSES.md lacks {required}")
    forbidden = {"tokenizer.model", "tokenizer_runtime.json", "vocab.json"}
    retained_forbidden = sorted(path.name for path in root.iterdir() if path.name in forbidden)
    if retained_forbidden:
        raise PackageVerificationError(f"duplicate legacy tokenizer assets remain: {retained_forbidden}")
    return {
        "schemaVersion": 2,
        "archiveBytes": archive_path.stat().st_size,
        "archiveSha256": _sha256(archive_path),
        "members": list(CANONICAL_MEMBERS),
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", required=True, type=Path)
    parser.add_argument("--package-lock", type=Path, default=DEFAULT_PACKAGE_LOCK)
    args = parser.parse_args()
    print(json.dumps(verify_package(args.root, args.package_lock), sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
