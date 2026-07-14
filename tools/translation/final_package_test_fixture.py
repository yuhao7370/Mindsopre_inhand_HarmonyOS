"""Build a minimal but authentic final translation package for tests."""

import hashlib
import json
import lzma
import os
import shutil
from pathlib import Path

from tools.translation.build_translation_archive import build_tar
from tools.translation.generate_final_translation_package import (
    TRUSTED_LICENSES_SOURCE,
    generate_final_package,
)


REPOSITORY_ROOT = Path(__file__).resolve().parents[2]
TOKENIZER = Path(os.environ["LOCALAPPDATA"]) / "MindsporeInhand/tokenizer-task5/source.spm"
TRUSTED_NATIVE = (
    REPOSITORY_ROOT / "Mindspore_inhand_HarmonyOS/entry/libs/arm64-v8a/libtranslation_archive.so"
)


def _sha256(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def _artifact(path):
    path = Path(path)
    return {"path": path.name, "bytes": path.stat().st_size, "sha256": _sha256(path)}


def _canonical_json_bytes(value):
    return (json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":")) + "\n").encode("utf-8")


def build_final_package_fixture(root):
    root = Path(root)
    models = root / "models"
    models.mkdir()
    for index, name in enumerate(("encoder.ms", "decoder_prefill.ms", "decoder_step.ms"), 1):
        (models / name).write_bytes((name.encode("ascii") + b"\0") * index)
    tar_path = root / "translation-models.tar"
    member_manifest = build_tar(models, tar_path)
    archive = root / "translation-models.tar.xz"
    archive.write_bytes(lzma.compress(tar_path.read_bytes(), format=lzma.FORMAT_XZ, check=lzma.CHECK_CRC64, preset=9))
    archive_manifest = {
        **member_manifest,
        "tar": {"size": tar_path.stat().st_size, "sha256": _sha256(tar_path)},
        "archive": {"size": archive.stat().st_size, "sha256": _sha256(archive)},
    }
    evidence_a = root / "archive-a.json"
    evidence_b = root / "archive-b.json"
    evidence = json.dumps(archive_manifest, sort_keys=True)
    evidence_a.write_text(evidence, encoding="utf-8")
    evidence_b.write_text(evidence, encoding="utf-8")

    training_report = root / "training-v1.json"
    training_report.write_bytes(b"{}\n")
    candidate = {
        "model_sha256": hashlib.sha256(b"approved student checkpoint").hexdigest(),
        "tokenizer_sha256": _sha256(TOKENIZER),
    }
    objective = {"distillation": "a" * 64, "training": "b" * 64}
    gate = {
        "schema_version": 1,
        "epoch2_allowed": True,
        "epoch2_launch_allowed": True,
        "epoch2_status": "authorized",
        "promotion_allowed": True,
        "candidate": candidate,
        "candidateEpoch": 1,
        "trainingReport": _artifact(training_report),
        "objectiveHashes": objective,
        "manualAsset": {"path": "manual-eval-v1.jsonl", "rows": 100, "bytes": 1, "sha256": "c" * 64},
        "manualResults": {"path": "manual-results-v1.json", "rows": 100, "bytes": 1, "sha256": "d" * 64},
        "manual": {},
        "flores": {},
    }
    quality_gate = root / "gate-v1.json"
    quality_gate.write_bytes(_canonical_json_bytes(gate))
    export_report = root / "export-report.json"
    export_report.write_bytes(b"{}\n")
    onnx_artifacts = {}
    for name in ("encoder.onnx", "decoder_prefill.onnx", "decoder_step.onnx"):
        path = root / name
        path.write_bytes(name.encode("ascii"))
        onnx_artifacts[name] = _artifact(path)
    conversion = {
        "schemaVersion": 1,
        "profile": "final",
        "approval": {
            "candidate": candidate,
            "candidateEpoch": 1,
            "objectiveHashes": objective,
            "trainingReport": _artifact(training_report),
            "qualityGateReport": _artifact(quality_gate),
        },
        "exportReport": _artifact(export_report),
        "onnxArtifacts": onnx_artifacts,
        "quantization": {"type": "WEIGHT_QUANT", "bitNum": 8, "minWeightSize": 0, "minWeightChannel": 0},
        "encoderParity": [
            {"name": "all-valid", "validTokens": 128, "elements": 32768, "maxAbs": 0.01, "meanAbs": 0.001},
            {"name": "half-padding", "validTokens": 64, "elements": 32768, "maxAbs": 0.01, "meanAbs": 0.001},
        ],
        "cacheLoopSteps": 100,
        "cacheLoopTokens": [0] * 101,
        "referenceCacheLoopTokens": [0] * 101,
        "expectedCacheLoopTokens": None,
        "argmaxAgreement": 1.0,
        "matchingTokens": 101,
        "models": member_manifest["members"],
    }
    conversion_report = root / "conversion-report.json"
    conversion_report.write_text(json.dumps(conversion), encoding="utf-8")
    decompressor = root / "libtranslation_archive.so"
    shutil.copyfile(TRUSTED_NATIVE, decompressor)
    stage = root / "stage"
    package_manifest = root / "final-package.json"
    generate_final_package(
        tokenizer_model=TOKENIZER,
        archive=archive,
        archive_manifest_a=evidence_a,
        archive_manifest_b=evidence_b,
        decompressor=decompressor,
        licenses_source=TRUSTED_LICENSES_SOURCE,
        quality_gate_report=quality_gate,
        conversion_report=conversion_report,
        stage_root=stage,
        package_manifest_path=package_manifest,
    )
    return {
        "stage": stage,
        "packageManifest": package_manifest,
        "decompressor": decompressor,
        "releaseEvidence": quality_gate,
        "tar": tar_path,
        "archive": stage / "translation-models.tar.xz",
        "archiveManifest": archive_manifest,
    }
