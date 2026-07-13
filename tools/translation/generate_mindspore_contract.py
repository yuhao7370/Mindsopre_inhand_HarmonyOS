#!/usr/bin/env python3
"""Generate the exact MindSpore Lite runtime tensor descriptor header."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Optional, Sequence


GRAPHS = ("encoder", "decoder_prefill", "decoder_step")
KINDS = ("inputs", "outputs")


class DescriptorError(RuntimeError):
    pass


def _profile(contract_path: Path, profile_name: str) -> dict:
    try:
        contract = json.loads(Path(contract_path).read_text(encoding="utf-8"))
        if contract["schemaVersion"] != 1:
            raise DescriptorError("unsupported contract schema")
        profile = contract["profiles"][profile_name]
    except (OSError, json.JSONDecodeError, KeyError, TypeError) as error:
        raise DescriptorError(f"invalid contract profile: {profile_name}") from error
    if profile.get("onnxFloatingDtype") != "FLOAT16" or profile.get("mindsporeFloatingDtype") != "FLOAT32":
        raise DescriptorError("MindSpore runtime descriptor requires ONNX FLOAT16 to runtime FLOAT32")
    if set(profile.get("graphs", {})) != set(GRAPHS):
        raise DescriptorError("runtime contract requires exactly encoder, decoder_prefill, and decoder_step")
    return profile


def _descriptor_lines(profile: dict, graph_name: str, kind: str) -> list[str]:
    graph = profile["graphs"][graph_name]
    if set(graph) != set(KINDS) or not isinstance(graph[kind], dict) or not graph[kind]:
        raise DescriptorError(f"invalid {graph_name} {kind} descriptor map")
    lines = []
    for name, descriptor in graph[kind].items():
        if not isinstance(name, str) or not name or not isinstance(descriptor, dict) or set(descriptor) != {"dtype", "shape"}:
            raise DescriptorError(f"invalid {graph_name} {kind} descriptor")
        dtype = descriptor["dtype"]
        if dtype == "INT32":
            runtime_dtype = "mindspore::DataType::kNumberTypeInt32"
        elif dtype == profile["onnxFloatingDtype"]:
            runtime_dtype = "mindspore::DataType::kNumberTypeFloat32"
        else:
            raise DescriptorError(f"unsupported ONNX dtype in runtime contract: {dtype}")
        shape = descriptor["shape"]
        if not isinstance(shape, list) or not shape or any(type(value) is not int or value <= 0 for value in shape):
            raise DescriptorError(f"invalid shape for {graph_name} {kind} {name}")
        dimensions = ", ".join(str(value) for value in shape)
        lines.append(f'    {{"{name}", {runtime_dtype}, {{{dimensions}}}}},')
    return lines


def generate_header(contract_path: Path, profile_name: str, output_path: Path) -> Path:
    profile = _profile(Path(contract_path), profile_name)
    output_path = Path(output_path).resolve()
    repository_root = Path(__file__).resolve().parents[2]
    if output_path == repository_root or repository_root in output_path.parents:
        raise DescriptorError("generated runtime descriptors must stay outside the repository")

    sections = []
    for graph_name in GRAPHS:
        for kind in KINDS:
            identifier = "k" + "".join(part.title() for part in graph_name.split("_")) + kind.title()
            body = "\n".join(_descriptor_lines(profile, graph_name, kind))
            sections.append(f"inline const std::vector<TensorDescriptor> {identifier} = {{\n{body}\n}};")
    header = "\n".join(
        (
            "#pragma once",
            "",
            "#include <cstdint>",
            "#include <vector>",
            "",
            "namespace translation_contract {",
            "struct TensorDescriptor {",
            "  const char *name;",
            "  mindspore::DataType dtype;",
            "  std::vector<int64_t> shape;",
            "};",
            "",
            "\n\n".join(sections),
            "}  // namespace translation_contract",
            "",
        )
    )
    output_path.parent.mkdir(parents=True, exist_ok=True)
    # ``Path.write_text(..., newline=...)`` was only added in Python 3.10.
    # The export toolchain is pinned to Python 3.9, so use ``open`` directly
    # while still forcing reproducible LF output on Windows.
    with output_path.open("w", encoding="utf-8", newline="\n") as output:
        output.write(header)
    return output_path


def main(argv: Optional[Sequence[str]] = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--contract", required=True, type=Path)
    parser.add_argument("--profile", required=True, choices=("prototype", "final"))
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args(argv)
    generate_header(args.contract, args.profile, args.output)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
