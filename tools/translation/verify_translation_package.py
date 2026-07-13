#!/usr/bin/env python3
"""Verify the complete staged HAP translation asset size and integrity gate."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
from pathlib import Path, PurePosixPath
from typing import Optional, Sequence


PACKAGE_LIMIT_BYTES = 35 * 1024 * 1024


class PackageError(RuntimeError):
    pass


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _safe_path(value: object) -> PurePosixPath:
    if not isinstance(value, str) or not value or "\\" in value:
        raise PackageError("invalid asset path")
    path = PurePosixPath(value)
    if path.is_absolute() or any(part in ("", ".", "..") for part in path.parts):
        raise PackageError("invalid asset path")
    return path


def _load_manifest(path: Path) -> dict:
    try:
        manifest = json.loads(Path(path).read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise PackageError(f"invalid package manifest: {error}") from error
    expected_keys = {"schemaVersion", "mode", "limitBytes", "assets", "allowances", "evidence"}
    unknown = set(manifest) - expected_keys if isinstance(manifest, dict) else {"root"}
    if not isinstance(manifest, dict) or set(manifest) != expected_keys:
        raise PackageError(f"unknown or missing manifest fields: {sorted(unknown)}")
    if manifest["schemaVersion"] != 1:
        raise PackageError("unsupported package schema")
    if manifest["mode"] not in ("prototype", "final"):
        raise PackageError("package mode must be prototype or final")
    if manifest["limitBytes"] != PACKAGE_LIMIT_BYTES:
        raise PackageError(f"package limit must be exactly {PACKAGE_LIMIT_BYTES} bytes")
    if not isinstance(manifest["assets"], list) or not manifest["assets"]:
        raise PackageError("package assets must be a non-empty list")
    if not isinstance(manifest["allowances"], list):
        raise PackageError("package allowances must be a list")
    evidence = manifest["evidence"]
    if not isinstance(evidence, dict) or set(evidence) != {"sourceEvidence", "canonicalRebuild"}:
        raise PackageError("invalid evidence schema")
    for evidence_name in ("sourceEvidence", "canonicalRebuild"):
        record = evidence[evidence_name]
        if not isinstance(record, dict) or set(record) != {"tar", "archive"}:
            raise PackageError(f"invalid {evidence_name} schema")
        for artifact_name in ("tar", "archive"):
            artifact = record[artifact_name]
            if not isinstance(artifact, dict) or set(artifact) != {"size", "sha256"}:
                raise PackageError(f"invalid {evidence_name} {artifact_name} schema")
            if not isinstance(artifact["size"], int) or artifact["size"] < 0:
                raise PackageError(f"invalid {evidence_name} {artifact_name} size")
            if not isinstance(artifact["sha256"], str) or not re.fullmatch(r"[0-9a-fA-F]{64}", artifact["sha256"]):
                raise PackageError(f"invalid {evidence_name} {artifact_name} hash")
    return manifest


def verify_package(manifest_path: Path, stage_root: Path) -> dict:
    manifest = _load_manifest(Path(manifest_path))
    stage_root = Path(stage_root)
    if not stage_root.is_dir() or stage_root.is_symlink():
        raise PackageError("staging root must be a regular directory")

    expected_paths = []
    asset_bytes = 0
    for asset in manifest["assets"]:
        if not isinstance(asset, dict) or set(asset) != {"path", "size", "sha256"}:
            raise PackageError("invalid asset schema")
        relative = _safe_path(asset["path"])
        relative_text = relative.as_posix()
        if relative_text in expected_paths:
            raise PackageError(f"duplicate asset: {relative_text}")
        expected_paths.append(relative_text)
        if not isinstance(asset["size"], int) or asset["size"] < 0:
            raise PackageError(f"invalid asset size: {relative_text}")
        if not isinstance(asset["sha256"], str) or not re.fullmatch(r"[0-9a-fA-F]{64}", asset["sha256"]):
            raise PackageError(f"invalid asset hash: {relative_text}")
        path = stage_root.joinpath(*relative.parts)
        if not path.exists():
            raise PackageError(f"missing asset: {relative_text}")
        if not path.is_file() or path.is_symlink():
            raise PackageError(f"asset is not a regular file: {relative_text}")
        size = path.stat().st_size
        if size != asset["size"]:
            raise PackageError(f"asset size mismatch: {relative_text}")
        if _sha256(path).lower() != asset["sha256"].lower():
            raise PackageError(f"asset hash mismatch: {relative_text}")
        asset_bytes += size

    if expected_paths != sorted(expected_paths):
        raise PackageError("asset paths must be sorted")
    actual_paths = sorted(
        path.relative_to(stage_root).as_posix()
        for path in stage_root.rglob("*")
        if path.is_file() or path.is_symlink()
    )
    if actual_paths != sorted(expected_paths):
        unexpected = sorted(set(actual_paths) - set(expected_paths))
        missing = sorted(set(expected_paths) - set(actual_paths))
        if unexpected:
            raise PackageError(f"unexpected staged assets: {unexpected}")
        raise PackageError(f"missing staged assets: {missing}")

    allowance_bytes = 0
    allowance_names = set()
    for allowance in manifest["allowances"]:
        if not isinstance(allowance, dict) or set(allowance) != {"name", "bytes", "prototypeOnly"}:
            raise PackageError("invalid allowance schema")
        if manifest["mode"] != "prototype" or allowance["prototypeOnly"] is not True:
            raise PackageError("allowances are prototype-only")
        if allowance["name"] in allowance_names:
            raise PackageError("duplicate allowance")
        allowance_names.add(allowance["name"])
        if not isinstance(allowance["bytes"], int) or allowance["bytes"] < 0:
            raise PackageError("invalid allowance bytes")
        allowance_bytes += allowance["bytes"]
    if manifest["mode"] == "final" and manifest["allowances"]:
        raise PackageError("final package rejects allowances")

    total = asset_bytes + allowance_bytes
    if total > PACKAGE_LIMIT_BYTES:
        raise PackageError(f"package uses {total} bytes; limit is {PACKAGE_LIMIT_BYTES} bytes")
    return {
        "mode": manifest["mode"],
        "assetBytes": asset_bytes,
        "allowanceBytes": allowance_bytes,
        "totalBytes": total,
        "limitBytes": PACKAGE_LIMIT_BYTES,
    }


def main(argv: Optional[Sequence[str]] = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", required=True, type=Path)
    parser.add_argument("--stage", required=True, type=Path)
    args = parser.parse_args(argv)
    print(json.dumps(verify_package(args.manifest, args.stage), sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
