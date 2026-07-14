#!/usr/bin/env python3
"""Verify the complete staged HAP translation asset size and integrity gate."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import struct
import sys
from pathlib import Path, PurePosixPath
from typing import Optional, Sequence

if __package__ in {None, ""}:
    sys.path.insert(0, str(Path(__file__).resolve().parents[2]))


PACKAGE_LIMIT_BYTES = 35 * 1024 * 1024
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
PROTOTYPE_REQUIRED_ROLES = set(REQUIRED_ASSETS) - {"decompressor"}
DECOMPRESSOR_ALLOWANCE = "ohos-liblzma-decompressor"
REPOSITORY_ROOT = Path(__file__).resolve().parents[2]
TRUSTED_XZ_BUILD_MANIFEST = (
    REPOSITORY_ROOT
    / "Mindspore_inhand_HarmonyOS/entry/src/main/cpp/translation_xz/XZ_BUILD_MANIFEST.json"
)
TRUSTED_XZ_BUILD_MANIFEST_SHA256 = "43a92bed61c6a690fe4441a26ef76dc34d6c9a642c9a39fbc315e537a325ba0b"


class PackageError(RuntimeError):
    pass


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _canonical_json_bytes(value: object) -> bytes:
    return (json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":")) + "\n").encode("utf-8")


def _verify_trusted_native(path: Path) -> None:
    header = path.read_bytes()[:64]
    if len(header) < 64 or header[:7] != b"\x7fELF\x02\x01\x01":
        raise PackageError("decompressor must be a little-endian ELF64 artifact")
    elf_type, machine, version = struct.unpack_from("<HHI", header, 16)
    if machine != 183:
        raise PackageError("decompressor ELF machine must be AArch64")
    if elf_type != 3 or version != 1:
        raise PackageError("decompressor ELF must be an ET_DYN shared object")

    manifest_path = TRUSTED_XZ_BUILD_MANIFEST
    if not manifest_path.is_file() or manifest_path.is_symlink():
        raise PackageError("trusted XZ build manifest is missing")
    try:
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise PackageError("trusted XZ build manifest is invalid") from error
    manifest_digest = hashlib.sha256(_canonical_json_bytes(manifest)).hexdigest()
    artifact = manifest.get("artifacts", {}).get("napi") if isinstance(manifest, dict) else None
    if (
        manifest_digest != TRUSTED_XZ_BUILD_MANIFEST_SHA256
        or manifest.get("schemaVersion") != 1
        or manifest.get("upstream", {}).get("version") != "5.8.3"
        or manifest.get("upstream", {}).get("tagCommit") != "4b73f2ec19a99ef465282fbce633e8deb33691b3"
        or manifest.get("upstream", {}).get("sourceSha256")
        != "FFF1FFCF2B0DA84D308A14DE513A1AA23D4E9AA3464D17E64B9714BFDD0BBFB6"
        or manifest.get("toolchain", {}).get("abi") != "arm64-v8a"
        or manifest.get("toolchain", {}).get("apiLevel") != 24
        or manifest.get("build", {}).get("target") != "liblzma"
        or manifest.get("build", {}).get("wrapperTarget") != "translation_archive"
        or not isinstance(artifact, dict)
        or artifact.get("path") != "entry/libs/arm64-v8a/libtranslation_archive.so"
        or artifact.get("size") != path.stat().st_size
        or str(artifact.get("sha256", "")).lower() != _sha256(path)
    ):
        raise PackageError("decompressor differs from the trusted XZ build manifest/hash")


def _verify_final_authenticity(manifest: dict, stage_root: Path, decompressor_path: Path) -> None:
    from tools.translation.build_translation_archive import verify_archive
    from tools.translation.generate_final_translation_package import (
        MODEL_SHA256,
        TRUSTED_LICENSES_SHA256,
        TRUSTED_LICENSES_SOURCE,
        _canonical_license_bytes,
        _json_bytes,
        _tokenizer_assets,
    )

    tokenizer = stage_root / REQUIRED_ASSETS["tokenizer"]
    try:
        expected_runtime, expected_vocabulary = _tokenizer_assets(tokenizer)
    except Exception as error:
        raise PackageError("tokenizer.model is not the pinned production tokenizer") from error
    if (stage_root / REQUIRED_ASSETS["tokenizer-runtime"]).read_bytes() != expected_runtime:
        raise PackageError("tokenizer runtime differs from the complete rebuilt TTOK1 table")
    if (stage_root / REQUIRED_ASSETS["vocabulary"]).read_bytes() != _json_bytes(expected_vocabulary):
        raise PackageError("vocabulary differs from the rebuilt 32003-entry vocabulary")

    trusted_licenses = _canonical_license_bytes(TRUSTED_LICENSES_SOURCE)
    if hashlib.sha256(trusted_licenses).hexdigest() != TRUSTED_LICENSES_SHA256:
        raise PackageError("trusted translation license source digest differs")
    if (stage_root / REQUIRED_ASSETS["licenses"]).read_bytes() != trusted_licenses:
        raise PackageError("license notices differ from the trusted fixed content")

    checksum_names = sorted(
        set(REQUIRED_ASSETS.values())
        - {REQUIRED_ASSETS["checksums"], REQUIRED_ASSETS["decompressor"]}
    )
    expected_checksums = "".join(
        "%s  %s\n" % (_sha256(stage_root / name).upper(), name)
        for name in checksum_names
    ).encode("ascii")
    if (stage_root / REQUIRED_ASSETS["checksums"]).read_bytes() != expected_checksums:
        raise PackageError("SHA256SUMS checksum file does not exactly cover the six non-self raw assets")

    evidence = manifest["evidence"]
    if evidence["approval"]["candidate"]["tokenizer_sha256"] != MODEL_SHA256:
        raise PackageError("approval provenance does not bind the pinned production tokenizer")
    if evidence["sourceEvidence"] != evidence["canonicalRebuild"]:
        raise PackageError("source evidence and canonical rebuild differ")
    retained = evidence["canonicalRebuild"]
    try:
        runtime = json.loads((stage_root / REQUIRED_ASSETS["manifest"]).read_text(encoding="utf-8"))
        archive_record = runtime["archive"]
        graphs = runtime["graphs"]
        if (
            archive_record.get("file") != REQUIRED_ASSETS["archive"]
            or {"size": archive_record.get("size"), "sha256": archive_record.get("sha256")} != retained["archive"]
        ):
            raise PackageError("runtime archive record differs from retained final evidence")
        archive_contract = {
            "schemaVersion": 1,
            "members": [
                {"name": graph["file"], "size": graph["size"], "sha256": graph["sha256"]}
                for graph in graphs
            ],
            "tar": retained["tar"],
            "archive": retained["archive"],
        }
        verify_archive(stage_root / REQUIRED_ASSETS["archive"], archive_contract)
    except PackageError:
        raise
    except Exception as error:
        raise PackageError("final archive/TAR authenticity verification failed: %s" % error) from error
    _verify_trusted_native(decompressor_path)


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
    expected_evidence = {"sourceEvidence", "canonicalRebuild"}
    if manifest["mode"] == "final":
        approval = evidence.get("approval") if isinstance(evidence, dict) else None
        if isinstance(approval, dict) and approval.get("releaseChannel") == "local-learning":
            expected_evidence |= {
                "authorizationReport", "v5Terminal", "evaluationReport",
                "evaluationManifest", "budgetReceipt", "conversionReport", "approval",
            }
        else:
            expected_evidence |= {"qualityGateReport", "conversionReport", "approval"}
    if not isinstance(evidence, dict) or set(evidence) != expected_evidence:
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
    if manifest["mode"] == "final":
        local_learning = isinstance(evidence["approval"], dict) and evidence["approval"].get(
            "releaseChannel"
        ) == "local-learning"
        artifact_names = (
            "authorizationReport", "v5Terminal", "evaluationReport", "evaluationManifest",
            "budgetReceipt", "conversionReport"
        ) if local_learning else ("qualityGateReport", "conversionReport")
        for artifact_name in artifact_names:
            artifact = evidence[artifact_name]
            if (
                not isinstance(artifact, dict)
                or set(artifact) != {"path", "bytes", "sha256"}
                or not isinstance(artifact.get("path"), str)
                or artifact["path"] != Path(artifact["path"]).name
                or not artifact["path"]
                or type(artifact.get("bytes")) is not int
                or artifact["bytes"] <= 0
                or not isinstance(artifact.get("sha256"), str)
                or re.fullmatch(r"[0-9a-f]{64}", artifact["sha256"]) is None
            ):
                raise PackageError(f"invalid final provenance artifact: {artifact_name}")
        approval = evidence["approval"]
        if local_learning:
            from tools.translation.export_marian_smoke import _validate_local_learning_approval_record

            if (
                not _validate_local_learning_approval_record(approval)
                or approval["authorizationReport"] != evidence["authorizationReport"]
                or approval["v5Terminal"] != evidence["v5Terminal"]
                or approval["evaluationReport"] != evidence["evaluationReport"]
                or approval["evaluationManifest"] != evidence["evaluationManifest"]
                or approval["budgetReceipt"] != evidence["budgetReceipt"]
            ):
                raise PackageError("invalid local-learning non-production approval provenance")
        else:
            candidate = approval.get("candidate") if isinstance(approval, dict) else None
            objective = approval.get("objectiveHashes") if isinstance(approval, dict) else None
            if (
                not isinstance(approval, dict)
                or set(approval) != {"candidate", "candidateEpoch", "objectiveHashes"}
                or not isinstance(candidate, dict)
                or set(candidate) != {"model_sha256", "tokenizer_sha256"}
                or not all(isinstance(value, str) and re.fullmatch(r"[0-9a-f]{64}", value) for value in candidate.values())
                or type(approval.get("candidateEpoch")) is not int
                or approval["candidateEpoch"] not in (1, 2)
                or not isinstance(objective, dict)
                or not objective
                or not all(
                    isinstance(name, str)
                    and name
                    and isinstance(value, str)
                    and re.fullmatch(r"[0-9a-f]{64}", value)
                    for name, value in objective.items()
                )
            ):
                raise PackageError("invalid final approval provenance")
    return manifest


def verify_package(
    manifest_path: Path,
    stage_root: Path,
    decompressor_path: Optional[Path] = None,
) -> dict:
    manifest = _load_manifest(Path(manifest_path))
    stage_root = Path(stage_root)
    if not stage_root.is_dir() or stage_root.is_symlink():
        raise PackageError("staging root must be a regular directory")

    expected_paths = []
    asset_roles = set()
    for asset in manifest["assets"]:
        if not isinstance(asset, dict) or set(asset) != {"role", "path", "size", "sha256"}:
            raise PackageError("invalid asset schema")
        role = asset["role"]
        if not isinstance(role, str) or role not in REQUIRED_ASSETS:
            raise PackageError(f"unknown asset role: {role!r}")
        relative = _safe_path(asset["path"])
        relative_text = relative.as_posix()
        if relative_text != REQUIRED_ASSETS[role]:
            raise PackageError(f"asset role {role!r} requires path {REQUIRED_ASSETS[role]!r}")
        if role in asset_roles:
            raise PackageError(f"duplicate asset role: {role}")
        if relative_text in expected_paths:
            raise PackageError(f"duplicate asset: {relative_text}")
        asset_roles.add(role)
        expected_paths.append(relative_text)
        if not isinstance(asset["size"], int) or asset["size"] < 0:
            raise PackageError(f"invalid asset size: {relative_text}")
        if not isinstance(asset["sha256"], str) or not re.fullmatch(r"[0-9a-fA-F]{64}", asset["sha256"]):
            raise PackageError(f"invalid asset hash: {relative_text}")

    required_roles = set(REQUIRED_ASSETS) if manifest["mode"] == "final" else PROTOTYPE_REQUIRED_ROLES
    missing_roles = sorted(required_roles - asset_roles)
    if missing_roles:
        raise PackageError(f"missing required asset roles: {missing_roles}")

    allowance_bytes = 0
    allowance_names = set()
    for allowance in manifest["allowances"]:
        if not isinstance(allowance, dict) or set(allowance) != {"name", "bytes", "prototypeOnly"}:
            raise PackageError("invalid allowance schema")
        if manifest["mode"] != "prototype" or allowance["prototypeOnly"] is not True:
            raise PackageError("allowances are prototype-only")
        if allowance["name"] != DECOMPRESSOR_ALLOWANCE:
            raise PackageError(f"unknown allowance: {allowance['name']!r}")
        if allowance["name"] in allowance_names:
            raise PackageError("duplicate allowance")
        allowance_names.add(allowance["name"])
        if not isinstance(allowance["bytes"], int) or allowance["bytes"] < 0:
            raise PackageError("invalid allowance bytes")
        allowance_bytes += allowance["bytes"]
    if manifest["mode"] == "final" and manifest["allowances"]:
        raise PackageError("final package rejects allowances")
    if manifest["mode"] == "prototype":
        has_decompressor = "decompressor" in asset_roles
        if has_decompressor == bool(manifest["allowances"]):
            raise PackageError("prototype package requires either the decompressor asset or exactly one allowance")

    if expected_paths != sorted(expected_paths):
        raise PackageError("asset paths must be sorted")
    staged_expected_paths = sorted(
        asset["path"] for asset in manifest["assets"] if asset["role"] != "decompressor"
    )
    actual_paths = sorted(path.relative_to(stage_root).as_posix() for path in stage_root.rglob("*"))
    if actual_paths != staged_expected_paths:
        unexpected = sorted(set(actual_paths) - set(staged_expected_paths))
        missing = sorted(set(staged_expected_paths) - set(actual_paths))
        if unexpected:
            raise PackageError(f"unexpected staged assets: {unexpected}")
        raise PackageError(f"missing staged assets: {missing}")

    if "decompressor" in asset_roles:
        if decompressor_path is None:
            raise PackageError("decompressor asset requires an external path")
        decompressor_path = Path(decompressor_path)
        if decompressor_path.name != REQUIRED_ASSETS["decompressor"]:
            raise PackageError("external decompressor path has the wrong file name")
    elif decompressor_path is not None:
        raise PackageError("external decompressor is not declared by the package manifest")

    asset_bytes = 0
    for asset in manifest["assets"]:
        relative = PurePosixPath(asset["path"])
        relative_text = relative.as_posix()
        path = decompressor_path if asset["role"] == "decompressor" else stage_root.joinpath(*relative.parts)
        if path is None:
            raise PackageError("decompressor asset requires an external path")
        if path.is_symlink():
            raise PackageError(f"asset is not a regular file: {relative_text}")
        if not path.exists():
            raise PackageError(f"missing asset: {relative_text}")
        if not path.is_file():
            raise PackageError(f"asset is not a regular file: {relative_text}")
        size = path.stat().st_size
        if size != asset["size"]:
            raise PackageError(f"asset size mismatch: {relative_text}")
        if _sha256(path).lower() != asset["sha256"].lower():
            raise PackageError(f"asset hash mismatch: {relative_text}")
        asset_bytes += size

    if manifest["mode"] == "final":
        if decompressor_path is None:
            raise PackageError("final package requires the external decompressor")
        _verify_final_authenticity(manifest, stage_root, decompressor_path)

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
    parser.add_argument("--decompressor", type=Path)
    args = parser.parse_args(argv)
    print(json.dumps(verify_package(args.manifest, args.stage, args.decompressor), sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
