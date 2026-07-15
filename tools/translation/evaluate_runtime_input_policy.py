#!/usr/bin/env python3
"""Evaluate the local translation runtime input policy against V5 outputs."""

import argparse
import hashlib
import json
from pathlib import Path
import sys
from typing import Callable, List, Sequence

from tools.translation.evaluate_translation import (
    corruption_reasons,
    load_manual_set,
    load_runtime,
    translate_preserving_boundaries,
    translate_texts,
)
from tools.translation.evaluate_v5_candidate import validate_v5_binding
from tools.translation.runtime_input_policy import (
    RuntimeInputPolicyError,
    translate_with_policy,
)


EXPECTED_CHECKPOINT_SHA256 = (
    "3b8b9a61910ae1b147947eef0168d6b0c5b8033d0a9059e82ef79cc468ce705f"
)
EXPECTED_TOKENIZER_SHA256 = (
    "e5528a5c3685d08f8868902d31febeb763eea8519f9997f43b05964b02554640"
)
_DIRECTIONS = ("zh-en", "en-zh")
_EXPECTED_MANUAL = {
    "path": "manual-eval-v1.jsonl",
    "bytes": 15433,
    "sha256": "0b8d0393eb46128065a05d6fdb38fa660828c85ca435980f74e59a91efea2ca1",
}
_EXPECTED_BASELINE = {
    "path": "manual-results-raw-v5-candidate-v1.jsonl",
    "bytes": 23209,
    "sha256": "f05ffa227aab96196b6bc8ae170d99631ffc6c8d644fcc8effd6008ef2ad79eb",
}


class RuntimeInputPolicyEvaluationError(RuntimeError):
    pass


def validate_bound_hashes(checkpoint_sha256: str, tokenizer_sha256: str) -> None:
    if (
        checkpoint_sha256 != EXPECTED_CHECKPOINT_SHA256
        or tokenizer_sha256 != EXPECTED_TOKENIZER_SHA256
    ):
        raise RuntimeInputPolicyEvaluationError("V5 model identity differs")


def build_policy_results(
    manual_rows: Sequence[dict],
    translate: Callable[[List[str], str], Sequence[str]],
) -> List[dict]:
    results = []
    for row in manual_rows:
        _validate_manual_row(row)
        try:
            output = translate_with_policy(
                row["source"],
                lambda texts, direction=row["direction"]: translate(texts, direction),
            )
        except (RuntimeInputPolicyError, TypeError, ValueError) as error:
            raise RuntimeInputPolicyEvaluationError(
                "policy translation failed for row %d" % row["id"]
            ) from error
        if not output:
            raise RuntimeInputPolicyEvaluationError(
                "policy translation is empty for row %d" % row["id"]
            )
        results.append(
            {
                "id": row["id"],
                "direction": row["direction"],
                "source": row["source"],
                "reference": row["reference"],
                "categories": row["categories"],
                "output": output,
                "automatic_corruption_flags": corruption_reasons(
                    row["source"], output, row["reference"]
                ),
            }
        )
    return results


def evaluate_inputs(
    manual_rows: Sequence[dict],
    baseline_rows: Sequence[dict],
    translate: Callable[[List[str], str], Sequence[str]],
    checkpoint_sha256: str,
    tokenizer_sha256: str,
):
    validate_bound_hashes(checkpoint_sha256, tokenizer_sha256)
    policy_rows = build_policy_results(manual_rows, translate)
    gate = evaluate_gate(baseline_rows, policy_rows)
    return (
        {
            "schemaVersion": 1,
            "identity": "local-translation-runtime-input-policy-v1",
            "status": "passed" if gate["passed"] else "failed",
            "model": {
                "checkpointSha256": checkpoint_sha256,
                "tokenizerSha256": tokenizer_sha256,
                "changed": False,
            },
            "gate": gate,
        },
        policy_rows,
    )


def write_evaluation_outputs(output_root: Path, report: dict, policy_rows: Sequence[dict]) -> dict:
    output_root = Path(output_root)
    try:
        output_root.mkdir(parents=True, exist_ok=False)
    except OSError as error:
        raise RuntimeInputPolicyEvaluationError("evaluation output root must be new") from error
    report_path = output_root / "runtime-input-policy-evaluation-v1.json"
    rows_path = output_root / "runtime-input-policy-results-v1.jsonl"
    try:
        report_path.write_bytes(_canonical_bytes(report))
        with rows_path.open("wb") as stream:
            for row in policy_rows:
                stream.write(_canonical_bytes(row))
    except OSError as error:
        raise RuntimeInputPolicyEvaluationError("cannot write evaluation outputs") from error
    return {"report": _artifact(report_path), "policyResults": _artifact(rows_path)}


def run_evaluation(
    v5_terminal: Path,
    budget_terminal: Path,
    manual_path: Path,
    baseline_path: Path,
    output_root: Path,
) -> dict:
    _require_external_output_root(output_root)
    binding = validate_v5_binding(v5_terminal, budget_terminal)
    checkpoint = binding["checkpoint"]
    checkpoint_files = binding["checkpointFiles"]
    checkpoint_sha256 = checkpoint_files["model.safetensors"]["sha256"]
    tokenizer_sha256 = checkpoint_files["tokenizer.model"]["sha256"]
    validate_bound_hashes(checkpoint_sha256, tokenizer_sha256)
    _require_artifact(manual_path, _EXPECTED_MANUAL, "manual set")
    _require_artifact(baseline_path, _EXPECTED_BASELINE, "baseline results")
    manual_rows = load_manual_set(manual_path)
    baseline_rows = _load_jsonl(baseline_path)
    _validate_baseline_alignment(manual_rows, baseline_rows)

    torch, model, processor = load_runtime(checkpoint, checkpoint / "tokenizer.model")

    def translate(values: List[str], direction: str) -> List[str]:
        outputs = []
        for value in values:
            outputs.append(
                translate_preserving_boundaries(
                    value,
                    lambda chunks, selected=direction: translate_texts(
                        torch, model, processor, chunks, selected
                    ),
                )
            )
        return outputs

    report, policy_rows = evaluate_inputs(
        manual_rows,
        baseline_rows,
        translate,
        checkpoint_sha256,
        tokenizer_sha256,
    )
    report["inputs"] = {
        "v5Terminal": binding["terminalArtifact"],
        "v5Budget": binding["budgetArtifact"],
        "manual": _artifact(manual_path),
        "baselineResults": _artifact(baseline_path),
        "policyCode": _artifact(Path(__file__).with_name("runtime_input_policy.py")),
        "evaluatorCode": _artifact(Path(__file__)),
    }
    report["limitations"] = [
        "manual-quality-gate-not-passed",
        "local-learning-only-not-production-approved",
        "device-functionality-not-validated",
    ]
    artifacts = write_evaluation_outputs(output_root, report, policy_rows)
    if not report["gate"]["passed"]:
        raise RuntimeInputPolicyEvaluationError(
            "runtime input policy gate failed; evidence preserved at %s" % output_root
        )
    return {"report": report, "artifacts": artifacts}


def evaluate_gate(baseline_rows: Sequence[dict], policy_rows: Sequence[dict]) -> dict:
    if len(baseline_rows) != len(policy_rows) or not baseline_rows:
        raise RuntimeInputPolicyEvaluationError("evaluation row counts differ")
    baseline_counts = {direction: 0 for direction in _DIRECTIONS}
    policy_counts = {direction: 0 for direction in _DIRECTIONS}
    changed_ids = []
    for baseline, policy in zip(baseline_rows, policy_rows):
        baseline_identity = _result_identity_and_flags(baseline)
        policy_identity = _result_identity_and_flags(policy)
        if baseline_identity[:2] != policy_identity[:2]:
            raise RuntimeInputPolicyEvaluationError("evaluation rows are misaligned")
        row_id, direction, baseline_flags = baseline_identity
        _, _, policy_flags = policy_identity
        baseline_counts[direction] += len(baseline_flags)
        policy_counts[direction] += len(policy_flags)
        if baseline_flags != policy_flags or baseline.get("output") != policy.get("output"):
            changed_ids.append(row_id)
    regressed = [
        direction
        for direction in _DIRECTIONS
        if policy_counts[direction] > baseline_counts[direction]
    ]
    baseline_total = sum(baseline_counts.values())
    policy_total = sum(policy_counts.values())
    decrease = baseline_total - policy_total
    return {
        "passed": not regressed and decrease > 0,
        "baseline": baseline_counts,
        "policy": policy_counts,
        "totalDecrease": decrease,
        "regressedDirections": regressed,
        "changedRowIds": changed_ids,
    }


def _validate_manual_row(row: dict) -> None:
    if (
        not isinstance(row, dict)
        or not isinstance(row.get("id"), int)
        or isinstance(row.get("id"), bool)
        or row["id"] < 1
        or row.get("direction") not in _DIRECTIONS
        or not isinstance(row.get("source"), str)
        or not row["source"]
        or not isinstance(row.get("reference"), str)
        or not row["reference"]
        or not isinstance(row.get("categories"), list)
    ):
        raise RuntimeInputPolicyEvaluationError("manual row is invalid")


def _result_identity_and_flags(row: dict):
    if (
        not isinstance(row, dict)
        or not isinstance(row.get("id"), int)
        or isinstance(row.get("id"), bool)
        or row.get("direction") not in _DIRECTIONS
        or not isinstance(row.get("automatic_corruption_flags"), list)
        or any(
            not isinstance(flag, str) or not flag
            for flag in row["automatic_corruption_flags"]
        )
    ):
        raise RuntimeInputPolicyEvaluationError("evaluation row is invalid")
    return row["id"], row["direction"], row["automatic_corruption_flags"]


def _canonical_bytes(value: dict) -> bytes:
    return (
        json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
        + "\n"
    ).encode("utf-8")


def _artifact(path: Path) -> dict:
    digest = hashlib.sha256()
    size = 0
    with Path(path).open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
            size += len(chunk)
    return {"path": Path(path).name, "bytes": size, "sha256": digest.hexdigest()}


def _require_artifact(path: Path, expected: dict, label: str) -> None:
    try:
        actual = _artifact(path)
    except OSError as error:
        raise RuntimeInputPolicyEvaluationError("cannot read %s" % label) from error
    if actual != expected:
        raise RuntimeInputPolicyEvaluationError("%s artifact differs" % label)


def _load_jsonl(path: Path) -> List[dict]:
    rows = []
    try:
        with Path(path).open("r", encoding="utf-8", newline="") as stream:
            for line_number, line in enumerate(stream, 1):
                if "\r" in line or not line.endswith("\n"):
                    raise RuntimeInputPolicyEvaluationError(
                        "baseline JSONL is not canonical at line %d" % line_number
                    )
                rows.append(json.loads(line))
    except (OSError, UnicodeDecodeError, json.JSONDecodeError) as error:
        raise RuntimeInputPolicyEvaluationError("cannot read baseline results") from error
    return rows


def _validate_baseline_alignment(manual_rows: Sequence[dict], baseline_rows: Sequence[dict]) -> None:
    if len(manual_rows) != len(baseline_rows):
        raise RuntimeInputPolicyEvaluationError("baseline row count differs")
    for manual, baseline in zip(manual_rows, baseline_rows):
        if (
            baseline.get("id") != manual["id"]
            or baseline.get("direction") != manual["direction"]
            or baseline.get("source") != manual["source"]
            or baseline.get("reference") != manual["reference"]
            or baseline.get("categories") != manual["categories"]
            or not isinstance(baseline.get("output"), str)
            or not baseline["output"]
        ):
            raise RuntimeInputPolicyEvaluationError("baseline rows are misaligned")
        _result_identity_and_flags(baseline)


def _require_external_output_root(output_root: Path) -> None:
    output = Path(output_root).resolve()
    repository = Path(__file__).resolve().parents[2]
    try:
        output.relative_to(repository)
    except ValueError:
        return
    raise RuntimeInputPolicyEvaluationError("evaluation output root must be outside the repository")


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--v5-terminal", required=True, type=Path)
    parser.add_argument("--budget-terminal", required=True, type=Path)
    parser.add_argument("--manual", required=True, type=Path)
    parser.add_argument("--baseline-results", required=True, type=Path)
    parser.add_argument("--output-root", required=True, type=Path)
    return parser


def main(argv=None) -> int:
    args = _parser().parse_args(argv)
    try:
        result = run_evaluation(
            args.v5_terminal,
            args.budget_terminal,
            args.manual,
            args.baseline_results,
            args.output_root,
        )
    except RuntimeInputPolicyEvaluationError as error:
        print(str(error), file=sys.stderr)
        return 1
    print(json.dumps(result["report"]["gate"], sort_keys=True, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    sys.exit(main())
