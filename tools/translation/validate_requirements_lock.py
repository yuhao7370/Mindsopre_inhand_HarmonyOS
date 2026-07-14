#!/usr/bin/env python3
"""Validate the single-host hashed dependency lock used by T1 export tools."""

from __future__ import annotations

import argparse
import platform
import re
import sys
from pathlib import Path
from typing import Optional, Sequence


LOCK_PYTHON = "3.13.14"
LOCK_PLATFORM = "win32"
LOCK_MACHINE = "AMD64"
DIRECT_PACKAGES = {"huggingface-hub", "numpy", "onnx", "onnxruntime", "safetensors", "torch", "transformers"}


class LockError(RuntimeError):
    pass


def _logical_lines(text: str) -> list[str]:
    result = []
    pending = ""
    for physical in text.splitlines():
        stripped = physical.strip()
        if not stripped or stripped.startswith("#"):
            continue
        pending = f"{pending} {stripped}".strip()
        if pending.endswith("\\"):
            pending = pending[:-1].rstrip()
        else:
            result.append(pending)
            pending = ""
    if pending:
        raise LockError("unterminated requirements continuation")
    return result


def validate_lock(path: Path, *, check_runtime: bool) -> dict:
    text = Path(path).read_text(encoding="utf-8")
    metadata = {
        "python": re.findall(r"^# t1-lock-python: (.+)$", text, re.MULTILINE),
        "platform": re.findall(r"^# t1-lock-platform: (.+)$", text, re.MULTILINE),
        "machine": re.findall(r"^# t1-lock-machine: (.+)$", text, re.MULTILINE),
    }
    expected = {"python": LOCK_PYTHON, "platform": LOCK_PLATFORM, "machine": LOCK_MACHINE}
    for name, value in expected.items():
        if metadata[name] != [value]:
            raise LockError(f"lock must declare exactly one {name}: {value}")
    if check_runtime:
        actual = {
            "python": ".".join(str(value) for value in sys.version_info[:3]),
            "platform": sys.platform,
            "machine": platform.machine(),
        }
        if actual != expected:
            raise LockError(f"lock host mismatch: expected={expected}, actual={actual}")

    lines = _logical_lines(text)
    if lines.count("--require-hashes") != 1:
        raise LockError("lock must enable --require-hashes exactly once")
    requirements = [line for line in lines if line != "--require-hashes"]
    packages = set()
    pattern = re.compile(r"^([A-Za-z0-9_.-]+)==([^\s]+)((?:\s+--hash=sha256:[0-9a-f]{64})+)$")
    for requirement in requirements:
        match = pattern.fullmatch(requirement)
        if not match:
            raise LockError(f"unhashed or unpinned requirement: {requirement}")
        name = re.sub(r"[-_.]+", "-", match.group(1)).lower()
        if name in packages:
            raise LockError(f"duplicate locked package: {name}")
        packages.add(name)
    missing_direct = sorted(DIRECT_PACKAGES - packages)
    if missing_direct:
        raise LockError(f"lock is missing direct export packages: {missing_direct}")
    return {**expected, "packages": len(packages)}


def main(argv: Optional[Sequence[str]] = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("lock", type=Path)
    parser.add_argument("--skip-runtime-check", action="store_true")
    args = parser.parse_args(argv)
    result = validate_lock(args.lock, check_runtime=not args.skip_runtime_check)
    print(f"validated {result['packages']} packages for {result['platform']}/{result['machine']} Python {result['python']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
