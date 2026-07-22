#!/usr/bin/env python3
"""Convert pinned static Marian ONNX graphs to MindSpore Lite W8 graphs."""

from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
from pathlib import Path


CONVERTER_VERSION = "2.8.0"
CONVERTER_ARCHIVE_URL = (
    "https://ms-release.obs.cn-north-4.myhuaweicloud.com/2.8.0/"
    "MindSporeLite/lite/release/linux/x86_64/"
    "mindspore-lite-2.8.0-linux-x64.tar.gz"
)
CONVERTER_ARCHIVE_SHA256 = "657579ba8ad27f0116e32ed49fc12e9b8409b614defa712de1e7e63c4c06336d"
CONVERTER_BINARY_SHA256 = "2e21f91190de81d8fb60514390094afb21282e2060ff24da08f59e2df9125ee5"
QUANT_CONFIG_SHA256 = "742d8be0f75ac1739ce2edbd985789eee335628e5578b0adb81474619818b2d9"
QUANTIZATION = {
    "type": "WEIGHT_QUANT",
    "bitNum": 8,
    "minWeightSize": 0,
    "minWeightChannel": 0,
}
GRAPH_NAMES = ("encoder", "decoder_full")
CONVERSION_POLICY = {
    "selectedDecoder": "static-full-decoder",
    "cachedStep": {
        "status": "rejected",
        "reason": "cached-step-semantics-diverged",
    },
}


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _validate_quant_config(path: Path) -> None:
    text = path.read_text(encoding="utf-8")
    expected = {
        "quant_type=WEIGHT_QUANT",
        "bit_num=8",
        "min_quant_weight_size=0",
        "min_quant_weight_channel=0",
    }
    missing = sorted(expected.difference(line.strip() for line in text.splitlines()))
    if missing:
        raise ValueError(f"quantization config is missing: {', '.join(missing)}")


def _validate_toolchain(converter: Path, converter_archive: Path, config: Path) -> dict:
    for label, path in (
        ("converter", converter), ("converter archive", converter_archive),
        ("quantization config", config),
    ):
        if not path.is_file():
            raise FileNotFoundError(f"{label} is missing: {path}")
    actual = {
        "converterBinarySha256": _sha256(converter),
        "converterArchiveSha256": _sha256(converter_archive),
        "quantConfigSha256": _sha256(config),
    }
    expected = {
        "converterBinarySha256": CONVERTER_BINARY_SHA256,
        "converterArchiveSha256": CONVERTER_ARCHIVE_SHA256,
        "quantConfigSha256": QUANT_CONFIG_SHA256,
    }
    if actual != expected:
        raise ValueError(f"converter toolchain receipt differs: {actual}")
    return actual


def convert_direction(
    converter: Path,
    converter_archive: Path,
    onnx_root: Path,
    output_root: Path,
    config: Path,
    direction: str,
) -> dict:
    _validate_quant_config(config)
    receipt = _validate_toolchain(converter, converter_archive, config)
    output_root.mkdir(parents=True, exist_ok=True)
    graphs = {}
    for graph_name in GRAPH_NAMES:
        source = onnx_root / f"{graph_name}.onnx"
        if not source.is_file():
            raise FileNotFoundError(source)
        output_base = output_root / graph_name
        command = [
            str(converter),
            "--fmk=ONNX",
            f"--modelFile={source}",
            f"--outputFile={output_base}",
            "--saveType=MINDIR_LITE",
            "--optimize=general",
            "--fp16=off",
            f"--configFile={config}",
        ]
        completed = subprocess.run(command, text=True, capture_output=True, check=False)
        log_path = output_root / f"{graph_name}.converter.log"
        log_path.write_text(completed.stdout + completed.stderr, encoding="utf-8")
        if completed.returncode:
            raise RuntimeError(
                f"converter failed for {direction}/{graph_name} with exit "
                f"{completed.returncode}; see {log_path}"
            )
        output = output_base.with_suffix(".ms")
        if not output.is_file():
            raise RuntimeError(f"converter did not create {output}")
        graphs[graph_name] = {
            "onnx": {"size": source.stat().st_size, "sha256": _sha256(source)},
            "mindSporeLite": {"size": output.stat().st_size, "sha256": _sha256(output)},
            "converterLog": str(log_path),
        }
    return {
        "schemaVersion": 1,
        "direction": direction,
        "converter": {
            "version": CONVERTER_VERSION,
            "archiveUrl": CONVERTER_ARCHIVE_URL,
            "archiveSha256": CONVERTER_ARCHIVE_SHA256,
            "binarySha256": receipt["converterBinarySha256"],
        },
        "quantization": {**QUANTIZATION, "configSha256": receipt["quantConfigSha256"]},
        "conversionPolicy": CONVERSION_POLICY,
        "graphs": graphs,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--converter", type=Path, required=True)
    parser.add_argument("--converter-archive", type=Path, required=True)
    parser.add_argument("--onnx-root", type=Path, required=True)
    parser.add_argument("--output-root", type=Path, required=True)
    parser.add_argument("--config", type=Path, required=True)
    parser.add_argument("--direction", choices=("en-zh", "zh-en"), required=True)
    args = parser.parse_args()
    report = convert_direction(
        args.converter, args.converter_archive, args.onnx_root,
        args.output_root, args.config, args.direction
    )
    report_path = args.output_root / "conversion-report.json"
    report_path.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(report_path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
