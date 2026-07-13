#!/usr/bin/env python3
"""Evaluate rejected rescue weights without making them promotion candidates."""

import argparse
import json
import math
import sys
import time
from pathlib import Path

if __package__ in {None, ""}:
    sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from tools.translation.distill_en_zh import STUDENT_SHA256, canonical_json_bytes
from tools.translation.evaluate_translation import (
    corpus_metrics,
    corruption_reasons,
    load_manual_set,
    load_runtime,
    translate_preserving_boundaries,
    translate_texts,
)
from tools.translation.train_bidirectional import (
    _forward_loss,
    _load_json,
    _memmap_batch,
    _sha256_file,
    build_token_cache,
    load_training_config,
    verify_dataset_inputs,
)
from tools.translation.train_rescue import DIAGNOSTIC_STATUS


DIRECTION_IDS = {"zh-en": 32001, "en-zh": 32002}


class DiagnosticEvaluationError(RuntimeError):
    pass


def _number(value, label):
    if (
        isinstance(value, bool)
        or not isinstance(value, (int, float))
        or not math.isfinite(value)
    ):
        raise DiagnosticEvaluationError("%s is not finite" % label)
    return float(value)


def _artifact(path):
    size, digest = _sha256_file(path)
    return {"path": Path(path).name, "bytes": size, "sha256": digest}


def _valid_artifact(value):
    return (
        isinstance(value, dict)
        and set(value) == {"path", "bytes", "sha256"}
        and Path(value["path"]).name == value["path"]
        and isinstance(value["bytes"], int)
        and not isinstance(value["bytes"], bool)
        and value["bytes"] > 0
        and isinstance(value["sha256"], str)
        and len(value["sha256"]) == 64
        and all(character in "0123456789abcdef" for character in value["sha256"])
    )


def _canonical_load(path, label):
    path = Path(path)
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeDecodeError, json.JSONDecodeError) as error:
        raise DiagnosticEvaluationError("cannot read %s" % label) from error
    if path.read_bytes() != canonical_json_bytes(value):
        raise DiagnosticEvaluationError("%s is not canonical" % label)
    return value


def evaluation_budget_snapshot(prior_seconds, evaluation_seconds, total_seconds):
    prior = _number(prior_seconds, "prior cumulative seconds")
    elapsed = _number(evaluation_seconds, "evaluation seconds")
    total = _number(total_seconds, "total budget seconds")
    if prior < 0 or elapsed < 0 or total <= 0 or prior + elapsed > total:
        raise DiagnosticEvaluationError("diagnostic evaluation exceeds cumulative budget")
    return {
        "priorCumulativeSeconds": prior,
        "evaluationActualSeconds": elapsed,
        "cumulativeActualSeconds": prior + elapsed,
        "totalBudgetSeconds": total,
        "remainingSeconds": total - prior - elapsed,
    }


def build_budget_terminal(
    stage,
    status,
    prior_evidence,
    prior_seconds,
    evaluation_seconds,
    total_seconds,
    error,
    root_evidence=None,
):
    if root_evidence is None:
        root_evidence = prior_evidence
    if (
        not isinstance(stage, str)
        or not stage
        or status not in {"completed", "failed"}
        or not _valid_artifact(prior_evidence)
        or not _valid_artifact(root_evidence)
        or (error is not None and (not isinstance(error, str) or not error))
        or (status == "completed" and error is not None)
        or (status == "failed" and error is None)
    ):
        raise DiagnosticEvaluationError("budget terminal metadata differs")
    prior = _number(prior_seconds, "prior cumulative seconds")
    elapsed = _number(evaluation_seconds, "evaluation seconds")
    total = _number(total_seconds, "total budget seconds")
    if prior < 0 or elapsed < 0 or total <= 0:
        raise DiagnosticEvaluationError("budget terminal values differ")
    cumulative = prior + elapsed
    return {
        "schema_version": 1,
        "stage": stage,
        "status": status,
        "priorEvidence": prior_evidence,
        "rootEvidence": root_evidence,
        "priorCumulativeSeconds": prior,
        "evaluationActualSeconds": elapsed,
        "cumulativeActualSeconds": cumulative,
        "totalBudgetSeconds": total,
        "remainingSeconds": total - cumulative,
        "error": error,
    }


def _validate_diagnostic_provenance(path):
    provenance = _canonical_load(path, "diagnostic provenance")
    expected_keys = {
        "schema_version", "status", "gate_eligible", "reason",
        "final_rescue_step", "resume_epoch_index", "baseline_validation_loss",
        "validation_history", "checkpoint", "gpuLedger", "objectiveHashes",
        "sourceArtifacts",
    }
    ledger_keys = {
        "baselineGpuSeconds", "probeAndLoadActualSeconds",
        "teacherGenerationActualSeconds", "rescueActualSeconds",
        "cumulativeActualSeconds", "totalBudgetSeconds", "remainingSeconds",
    }
    if (
        not isinstance(provenance, dict)
        or set(provenance) != expected_keys
        or provenance.get("schema_version") != 1
        or provenance.get("status") != DIAGNOSTIC_STATUS
        or provenance.get("gate_eligible") is not False
        or provenance.get("final_rescue_step") != 1406
        or provenance.get("resume_epoch_index") != 0
        or not isinstance(provenance.get("reason"), str)
        or not provenance["reason"]
        or not isinstance(provenance.get("checkpoint"), dict)
        or set(provenance["checkpoint"]) != {"model", "tokenizer"}
        or not all(_valid_artifact(value) for value in provenance["checkpoint"].values())
        or not isinstance(provenance.get("gpuLedger"), dict)
        or set(provenance["gpuLedger"]) != ledger_keys
        or not isinstance(provenance.get("objectiveHashes"), dict)
        or not provenance["objectiveHashes"]
        or any(
            not isinstance(value, str)
            or len(value) != 64
            or any(character not in "0123456789abcdef" for character in value)
            for value in provenance["objectiveHashes"].values()
        )
        or not isinstance(provenance.get("sourceArtifacts"), dict)
        or set(provenance["sourceArtifacts"])
        != {"progress", "trainingReport", "baselineReplayReceipt"}
        or not all(_valid_artifact(value) for value in provenance["sourceArtifacts"].values())
    ):
        raise DiagnosticEvaluationError("diagnostic provenance contract differs")
    ledger = provenance["gpuLedger"]
    try:
        components = sum(
            _number(ledger[name], name)
            for name in (
                "baselineGpuSeconds", "probeAndLoadActualSeconds",
                "teacherGenerationActualSeconds", "rescueActualSeconds",
            )
        )
        cumulative = _number(ledger["cumulativeActualSeconds"], "cumulative")
        total = _number(ledger["totalBudgetSeconds"], "total")
        remaining = _number(ledger["remainingSeconds"], "remaining")
    except KeyError as error:
        raise DiagnosticEvaluationError("diagnostic provenance ledger differs") from error
    if components != cumulative or total - cumulative != remaining or remaining < 0:
        raise DiagnosticEvaluationError("diagnostic provenance ledger arithmetic differs")
    return provenance


def load_budget_evidence(path):
    path = Path(path)
    value = _canonical_load(path, "budget evidence")
    if isinstance(value, dict) and value.get("status") == DIAGNOSTIC_STATUS:
        provenance = _validate_diagnostic_provenance(path)
        ledger = provenance["gpuLedger"]
        return {
            "artifact": _artifact(path),
            "rootEvidence": _artifact(path),
            "cumulativeActualSeconds": float(ledger["cumulativeActualSeconds"]),
            "totalBudgetSeconds": float(ledger["totalBudgetSeconds"]),
        }
    expected = {
        "schema_version", "stage", "status", "priorEvidence", "rootEvidence",
        "priorCumulativeSeconds", "evaluationActualSeconds",
        "cumulativeActualSeconds", "totalBudgetSeconds", "remainingSeconds",
        "error",
    }
    if (
        not isinstance(value, dict)
        or set(value) != expected
        or value.get("schema_version") != 1
        or value.get("status") not in {"completed", "failed"}
        or not isinstance(value.get("stage"), str)
        or not value["stage"]
        or not _valid_artifact(value.get("priorEvidence"))
        or not _valid_artifact(value.get("rootEvidence"))
        or (value["status"] == "completed" and value.get("error") is not None)
        or (
            value["status"] == "failed"
            and (not isinstance(value.get("error"), str) or not value["error"])
        )
    ):
        raise DiagnosticEvaluationError("budget evidence contract differs")
    prior = _number(value["priorCumulativeSeconds"], "prior")
    elapsed = _number(value["evaluationActualSeconds"], "elapsed")
    cumulative = _number(value["cumulativeActualSeconds"], "cumulative")
    total = _number(value["totalBudgetSeconds"], "total")
    remaining = _number(value["remainingSeconds"], "remaining")
    if (
        prior < 0
        or elapsed < 0
        or total <= 0
        or prior + elapsed != cumulative
        or total - cumulative != remaining
    ):
        raise DiagnosticEvaluationError("budget evidence arithmetic differs")
    return {
        "artifact": _artifact(path),
        "rootEvidence": value["rootEvidence"],
        "cumulativeActualSeconds": cumulative,
        "totalBudgetSeconds": total,
    }


def load_bist_rows(path, direction, expected_count):
    if direction not in DIRECTION_IDS:
        raise DiagnosticEvaluationError("unsupported BiST direction")
    rows = []
    try:
        with Path(path).open("rb") as stream:
            for raw in stream:
                if b"\r" in raw or not raw.endswith(b"\n"):
                    raise DiagnosticEvaluationError("BiST JSONL is not canonical LF")
                row = json.loads(raw.decode("utf-8"))
                if (
                    not isinstance(row, dict)
                    or set(row) != {"direction_id", "source", "target"}
                    or list(row) != ["source", "target", "direction_id"]
                    or row["direction_id"] != DIRECTION_IDS[direction]
                    or not isinstance(row["source"], str)
                    or not row["source"]
                    or not isinstance(row["target"], str)
                    or not row["target"]
                    or raw != (
                        json.dumps(
                            row, ensure_ascii=False, separators=(",", ":")
                        ).encode("utf-8") + b"\n"
                    )
                ):
                    raise DiagnosticEvaluationError("BiST row contract differs")
                rows.append(row)
    except (OSError, UnicodeDecodeError, json.JSONDecodeError) as error:
        raise DiagnosticEvaluationError("cannot read BiST JSONL") from error
    if len(rows) != expected_count:
        raise DiagnosticEvaluationError("BiST row count differs")
    return rows


def directional_validation_loss(
    torch, model, validation, physical_microbatch, label_smoothing, budget_guard=None
):
    losses = {}
    device = next(model.parameters()).device
    model.eval()
    with torch.no_grad():
        for direction in ("zh-en", "en-zh"):
            rows = validation[direction]
            total_loss = 0.0
            total_examples = 0
            for start in range(0, len(rows), physical_microbatch):
                if budget_guard is not None:
                    budget_guard()
                indices = list(range(start, min(start + physical_microbatch, len(rows))))
                batch = _memmap_batch(torch, rows, indices, device)
                loss, unused_logits = _forward_loss(
                    torch, model, batch, label_smoothing
                )
                del unused_logits
                total_loss += float(loss.item()) * len(indices)
                total_examples += len(indices)
            if not total_examples:
                raise DiagnosticEvaluationError("validation direction is empty")
            losses[direction] = total_loss / total_examples
    return losses


def _manual_outputs(torch, model, processor, manual_rows, budget_guard=None):
    results = []
    for direction in ("zh-en", "en-zh"):
        selected = [row for row in manual_rows if row["direction"] == direction]
        outputs = []
        for row in selected:
            if budget_guard is not None:
                budget_guard()
            outputs.append(translate_preserving_boundaries(
                row["source"],
                lambda chunks, selected_direction=direction: translate_texts(
                    torch, model, processor, chunks, selected_direction
                ),
            ))
        for row, output in zip(selected, outputs):
            results.append({
                **row,
                "output": output,
                "fatal_corruptions": corruption_reasons(
                    row["source"],
                    output,
                    reference=row["reference"],
                    check_proper_names="names" in row["categories"],
                ),
                "pass": None,
                "reason": "pending explicit semantic audit",
            })
    return sorted(results, key=lambda row: row["id"])


def evaluate_checkpoint(
    checkpoint_dir,
    tokenizer_model,
    label,
    dataset_root,
    dataset_manifest_path,
    training_config_path,
    manual_path,
    output_root,
    prior_evidence_path,
    budget_root_provenance_path,
    diagnostic_provenance_path=None,
):
    if not isinstance(label, str) or not label:
        raise DiagnosticEvaluationError("checkpoint label is empty")
    checkpoint_dir = Path(checkpoint_dir).resolve()
    prior_evidence = load_budget_evidence(prior_evidence_path)
    budget_root_provenance_path = Path(budget_root_provenance_path).resolve()
    _validate_diagnostic_provenance(budget_root_provenance_path)
    budget_root_artifact = _artifact(budget_root_provenance_path)
    if prior_evidence["rootEvidence"] != budget_root_artifact:
        raise DiagnosticEvaluationError("prior budget evidence root differs")
    diagnostic_provenance = None
    diagnostic_provenance_artifact = None
    if label == "diagnostic":
        if diagnostic_provenance_path is None:
            raise DiagnosticEvaluationError("diagnostic evaluation requires provenance")
        diagnostic_provenance_path = Path(diagnostic_provenance_path).resolve()
        diagnostic_provenance = _validate_diagnostic_provenance(
            diagnostic_provenance_path
        )
        diagnostic_provenance_artifact = _artifact(diagnostic_provenance_path)
        if (
            diagnostic_provenance_path.parent != checkpoint_dir
            or diagnostic_provenance["checkpoint"]["model"]
            != _artifact(checkpoint_dir / "model.safetensors")
            or diagnostic_provenance["checkpoint"]["tokenizer"]
            != _artifact(tokenizer_model)
            or diagnostic_provenance_artifact != budget_root_artifact
        ):
            raise DiagnosticEvaluationError("diagnostic provenance differs")
    elif diagnostic_provenance_path is not None:
        raise DiagnosticEvaluationError("baseline evaluation rejects diagnostic provenance")
    if label == "baseline" and _artifact(
        checkpoint_dir / "model.safetensors"
    )["sha256"] != STUDENT_SHA256:
        raise DiagnosticEvaluationError("baseline checkpoint hash differs")
    dataset_manifest = _load_json(dataset_manifest_path)
    training_config = load_training_config(training_config_path)
    verify_dataset_inputs(dataset_root, dataset_manifest)
    output_root = Path(output_root).resolve()
    if output_root.exists():
        raise DiagnosticEvaluationError("diagnostic output already exists")
    output_root.mkdir(parents=True)
    started = time.monotonic()
    terminal_path = output_root / "budget-terminal-v1.json"
    prior = prior_evidence["cumulativeActualSeconds"]
    total = prior_evidence["totalBudgetSeconds"]

    def budget_guard():
        elapsed_now = time.monotonic() - started
        if prior + elapsed_now >= total:
            raise DiagnosticEvaluationError(
                "diagnostic evaluation reached cumulative GPU ceiling"
            )

    try:
        budget_guard()
        torch, model, processor = load_runtime(checkpoint_dir, tokenizer_model)
        torch.cuda.reset_peak_memory_stats()
        validation = {}
        cache_root = output_root / "token-cache"
        for direction in ("zh-en", "en-zh"):
            artifact = dataset_manifest["outputs"][direction + ".validation.jsonl"]
            validation[direction] = build_token_cache(
                cache_root,
                Path(dataset_root) / artifact["path"],
                artifact,
                training_config["tokenizer"],
                processor,
                direction,
                "validation",
                128,
            )
        losses = directional_validation_loss(
            torch, model, validation, 32, 0.1, budget_guard=budget_guard
        )
        bist_metrics = {}
        bist_outputs = []
        for direction in ("zh-en", "en-zh"):
            artifact = dataset_manifest["outputs"][direction + ".test.jsonl"]
            rows = load_bist_rows(
                Path(dataset_root) / artifact["path"], direction, artifact["count"]
            )
            outputs = []
            for start in range(0, len(rows), 256):
                budget_guard()
                outputs.extend(translate_texts(
                    torch,
                    model,
                    processor,
                    [row["source"] for row in rows[start:start + 256]],
                    direction,
                ))
            references = [row["target"] for row in rows]
            bist_metrics[direction] = corpus_metrics(
                outputs, references, tokenizer="13a" if direction == "zh-en" else "zh"
            )
            bist_outputs.extend(
                {
                    "direction": direction,
                    "index": index,
                    "source": row["source"],
                    "reference": row["target"],
                    "output": output,
                }
                for index, (row, output) in enumerate(zip(rows, outputs), 1)
            )
        bist_path = output_root / "bist-test-outputs-v1.jsonl"
        with bist_path.open("wb") as stream:
            for row in bist_outputs:
                stream.write(canonical_json_bytes(row))
        manual_rows = load_manual_set(manual_path)
        manual_results = _manual_outputs(
            torch, model, processor, manual_rows, budget_guard=budget_guard
        )
        manual_results_path = output_root / "manual-results-raw-v1.jsonl"
        with manual_results_path.open("wb") as stream:
            for row in manual_results:
                stream.write(canonical_json_bytes(row))
        elapsed = time.monotonic() - started
        budget = evaluation_budget_snapshot(prior, elapsed, total)
        terminal = build_budget_terminal(
            "translation_diagnostic_evaluation",
            "completed",
            prior_evidence["artifact"],
            prior,
            elapsed,
            total,
            None,
            budget_root_artifact,
        )
        terminal_path.write_bytes(canonical_json_bytes(terminal))
        report = {
            "schema_version": 1,
            "label": label,
            "checkpoint": {
                "model": _artifact(checkpoint_dir / "model.safetensors"),
                "tokenizer": _artifact(tokenizer_model),
            },
            "dataset": {
                "manifest": _artifact(dataset_manifest_path),
                "repo": dataset_manifest["dataset"]["repo"],
                "revision": dataset_manifest["dataset"]["revision"],
                "rows_per_direction": {"validation": 5000, "test": 5000},
            },
            "directional_validation_loss": losses,
            "bist_test": bist_metrics,
            "bistOutputs": {**_artifact(bist_path), "rows": len(bist_outputs)},
            "manual": {
                "asset": {**_artifact(manual_path), "rows": len(manual_rows)},
                "results": {**_artifact(manual_results_path), "rows": len(manual_results)},
                "audit_complete": False,
            },
            "decode": {
                "strategy": "greedy",
                "max_tokens": 128,
                "tie": "smallest-token-id",
            },
            "diagnosticProvenance": diagnostic_provenance_artifact,
            "budgetRootProvenance": budget_root_artifact,
            "priorEvidence": prior_evidence["artifact"],
            "budgetReceipt": _artifact(terminal_path),
            "gpuLedger": budget,
            "peak_cuda_bytes": torch.cuda.max_memory_allocated(),
        }
        (output_root / "diagnostic-evaluation-v1.json").write_bytes(
            canonical_json_bytes(report)
        )
        return report
    except BaseException as error:
        elapsed = time.monotonic() - started
        terminal = build_budget_terminal(
            "translation_diagnostic_evaluation",
            "failed",
            prior_evidence["artifact"],
            prior,
            elapsed,
            total,
            "%s: %s" % (type(error).__name__, error),
            budget_root_artifact,
        )
        terminal_path.write_bytes(canonical_json_bytes(terminal))
        raise


def _valid_row_artifact(value, rows):
    return (
        isinstance(value, dict)
        and set(value) == {"path", "bytes", "sha256", "rows"}
        and value.get("rows") == rows
        and _valid_artifact({name: value[name] for name in ("path", "bytes", "sha256")})
    )


def _validate_evaluation_report(path, expected_label):
    path = Path(path).resolve()
    report = _canonical_load(path, "%s evaluation report" % expected_label)
    expected_keys = {
        "schema_version", "label", "checkpoint", "dataset",
        "directional_validation_loss", "bist_test", "bistOutputs", "manual",
        "decode", "diagnosticProvenance", "budgetRootProvenance",
        "priorEvidence", "budgetReceipt",
        "gpuLedger", "peak_cuda_bytes",
    }
    if (
        not isinstance(report, dict)
        or set(report) != expected_keys
        or report.get("schema_version") != 1
        or report.get("label") != expected_label
        or not isinstance(report.get("checkpoint"), dict)
        or set(report["checkpoint"]) != {"model", "tokenizer"}
        or not all(_valid_artifact(value) for value in report["checkpoint"].values())
        or not isinstance(report.get("dataset"), dict)
        or set(report["dataset"]) != {"manifest", "repo", "revision", "rows_per_direction"}
        or not _valid_artifact(report["dataset"].get("manifest"))
        or report["dataset"].get("repo") != "Mxode/BiST"
        or report["dataset"].get("revision")
        != "aca6be897afc319f779009379c8b849c1eb8d63e"
        or report["dataset"].get("rows_per_direction")
        != {"validation": 5000, "test": 5000}
        or report.get("decode")
        != {"strategy": "greedy", "max_tokens": 128, "tie": "smallest-token-id"}
        or not _valid_row_artifact(report.get("bistOutputs"), 10000)
        or not isinstance(report.get("manual"), dict)
        or set(report["manual"]) != {"asset", "results", "audit_complete"}
        or report["manual"].get("audit_complete") is not False
        or not _valid_row_artifact(report["manual"].get("asset"), 100)
        or not _valid_row_artifact(report["manual"].get("results"), 100)
        or not _valid_artifact(report.get("priorEvidence"))
        or not _valid_artifact(report.get("budgetRootProvenance"))
        or not _valid_artifact(report.get("budgetReceipt"))
        or not isinstance(report.get("peak_cuda_bytes"), int)
        or isinstance(report.get("peak_cuda_bytes"), bool)
        or report["peak_cuda_bytes"] < 0
    ):
        raise DiagnosticEvaluationError("%s evaluation report contract differs" % expected_label)
    if (
        not isinstance(report.get("directional_validation_loss"), dict)
        or set(report["directional_validation_loss"]) != {"zh-en", "en-zh"}
        or not isinstance(report.get("bist_test"), dict)
        or set(report["bist_test"]) != {"zh-en", "en-zh"}
    ):
        raise DiagnosticEvaluationError("evaluation direction schema differs")
    for direction in ("zh-en", "en-zh"):
        _number(report["directional_validation_loss"][direction], "validation loss")
        metrics = report["bist_test"][direction]
        if (
            not isinstance(metrics, dict)
            or set(metrics) != {"bleu", "chrf2", "bleu_signature", "chrf2_signature"}
            or not isinstance(metrics["bleu_signature"], str)
            or not metrics["bleu_signature"]
            or not isinstance(metrics["chrf2_signature"], str)
            or not metrics["chrf2_signature"]
        ):
            raise DiagnosticEvaluationError("evaluation metric contract differs")
        _number(metrics["bleu"], "BLEU")
        _number(metrics["chrf2"], "chrF2")
    ledger = report.get("gpuLedger")
    if not isinstance(ledger, dict) or set(ledger) != {
        "priorCumulativeSeconds", "evaluationActualSeconds",
        "cumulativeActualSeconds", "totalBudgetSeconds", "remainingSeconds",
    }:
        raise DiagnosticEvaluationError("evaluation ledger schema differs")
    expected_ledger = evaluation_budget_snapshot(
        ledger["priorCumulativeSeconds"],
        ledger["evaluationActualSeconds"],
        ledger["totalBudgetSeconds"],
    )
    if ledger != expected_ledger:
        raise DiagnosticEvaluationError("evaluation ledger arithmetic differs")
    receipt_path = path.parent / report["budgetReceipt"]["path"]
    if not receipt_path.is_file() or _artifact(receipt_path) != report["budgetReceipt"]:
        raise DiagnosticEvaluationError("evaluation budget receipt hash differs")
    receipt = _canonical_load(receipt_path, "evaluation budget receipt")
    receipt_evidence = load_budget_evidence(receipt_path)
    if (
        receipt.get("status") != "completed"
        or receipt.get("priorEvidence") != report["priorEvidence"]
        or receipt.get("rootEvidence") != report["budgetRootProvenance"]
        or receipt_evidence["cumulativeActualSeconds"] != ledger["cumulativeActualSeconds"]
        or receipt_evidence["totalBudgetSeconds"] != ledger["totalBudgetSeconds"]
    ):
        raise DiagnosticEvaluationError("evaluation budget receipt differs")
    if expected_label == "baseline":
        if (
            report.get("diagnosticProvenance") is not None
            or report["checkpoint"]["model"]["sha256"] != STUDENT_SHA256
        ):
            raise DiagnosticEvaluationError("baseline checkpoint provenance differs")
    elif not _valid_artifact(report.get("diagnosticProvenance")):
        raise DiagnosticEvaluationError("diagnostic evaluation provenance artifact differs")
    return report


def build_checkpoint_comparison(
    baseline_report_path,
    diagnostic_report_path,
    diagnostic_provenance_path,
    baseline_prior_evidence_path,
):
    baseline_path = Path(baseline_report_path).resolve()
    diagnostic_path = Path(diagnostic_report_path).resolve()
    provenance_path = Path(diagnostic_provenance_path).resolve()
    prior_path = Path(baseline_prior_evidence_path).resolve()
    baseline = _validate_evaluation_report(baseline_path, "baseline")
    diagnostic = _validate_evaluation_report(diagnostic_path, "diagnostic")
    provenance = _validate_diagnostic_provenance(provenance_path)
    prior = load_budget_evidence(prior_path)
    baseline_receipt_path = baseline_path.parent / baseline["budgetReceipt"]["path"]
    if (
        baseline["priorEvidence"] != prior["artifact"]
        or prior["rootEvidence"] != _artifact(provenance_path)
        or baseline["budgetRootProvenance"] != _artifact(provenance_path)
        or diagnostic["budgetRootProvenance"] != _artifact(provenance_path)
        or baseline["gpuLedger"]["priorCumulativeSeconds"]
        != prior["cumulativeActualSeconds"]
        or baseline["gpuLedger"]["totalBudgetSeconds"] != prior["totalBudgetSeconds"]
        or diagnostic["diagnosticProvenance"] != _artifact(provenance_path)
        or diagnostic["checkpoint"] != provenance["checkpoint"]
        or diagnostic["priorEvidence"] != _artifact(baseline_receipt_path)
        or diagnostic["gpuLedger"]["priorCumulativeSeconds"]
        != baseline["gpuLedger"]["cumulativeActualSeconds"]
        or diagnostic["gpuLedger"]["totalBudgetSeconds"]
        != baseline["gpuLedger"]["totalBudgetSeconds"]
        or baseline["checkpoint"]["tokenizer"] != diagnostic["checkpoint"]["tokenizer"]
        or baseline["dataset"] != diagnostic["dataset"]
        or baseline["decode"] != diagnostic["decode"]
        or baseline["manual"]["asset"] != diagnostic["manual"]["asset"]
    ):
        raise DiagnosticEvaluationError("comparison provenance chain differs")
    directions = {}
    try:
        for direction in ("zh-en", "en-zh"):
            base_loss = _number(
                baseline["directional_validation_loss"][direction], "baseline loss"
            )
            diagnostic_loss = _number(
                diagnostic["directional_validation_loss"][direction], "diagnostic loss"
            )
            base_bleu = _number(
                baseline["bist_test"][direction]["bleu"], "baseline BLEU"
            )
            diagnostic_bleu = _number(
                diagnostic["bist_test"][direction]["bleu"], "diagnostic BLEU"
            )
            base_chrf = _number(
                baseline["bist_test"][direction]["chrf2"], "baseline chrF2"
            )
            diagnostic_chrf = _number(
                diagnostic["bist_test"][direction]["chrf2"], "diagnostic chrF2"
            )
            directions[direction] = {
                "validation_loss_baseline": base_loss,
                "validation_loss_diagnostic": diagnostic_loss,
                "validation_loss_delta": diagnostic_loss - base_loss,
                "bleu_baseline": base_bleu,
                "bleu_diagnostic": diagnostic_bleu,
                "bleu_delta": diagnostic_bleu - base_bleu,
                "chrf2_baseline": base_chrf,
                "chrf2_diagnostic": diagnostic_chrf,
                "chrf2_delta": diagnostic_chrf - base_chrf,
            }
    except (KeyError, TypeError) as error:
        raise DiagnosticEvaluationError("comparison schema differs") from error
    sequence_improved = all(
        item["bleu_delta"] > 0 and item["chrf2_delta"] > 0
        for item in directions.values()
    )
    nll_regressed = all(
        item["validation_loss_delta"] > 0 for item in directions.values()
    )
    return {
        "schema_version": 1,
        "sourceReports": {
            "baseline": _artifact(baseline_path),
            "diagnostic": _artifact(diagnostic_path),
            "diagnosticProvenance": _artifact(provenance_path),
            "baselinePriorEvidence": _artifact(prior_path),
        },
        "directions": directions,
        "sequence_metrics_improved": sequence_improved,
        "validation_nll_regressed": nll_regressed,
        "sequence_gain_with_nll_regression": sequence_improved and nll_regressed,
    }


def build_parser():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    evaluate = commands.add_parser("evaluate")
    evaluate.add_argument("--checkpoint-dir", required=True, type=Path)
    evaluate.add_argument("--tokenizer-model", required=True, type=Path)
    evaluate.add_argument("--label", required=True, choices=("baseline", "diagnostic"))
    evaluate.add_argument("--dataset-root", required=True, type=Path)
    evaluate.add_argument("--dataset-manifest", required=True, type=Path)
    evaluate.add_argument("--training-config", required=True, type=Path)
    evaluate.add_argument("--manual", required=True, type=Path)
    evaluate.add_argument("--output-root", required=True, type=Path)
    evaluate.add_argument("--prior-evidence", required=True, type=Path)
    evaluate.add_argument("--budget-root-provenance", required=True, type=Path)
    evaluate.add_argument("--diagnostic-provenance", type=Path)
    compare = commands.add_parser("compare")
    compare.add_argument("--baseline-summary", required=True, type=Path)
    compare.add_argument("--diagnostic-summary", required=True, type=Path)
    compare.add_argument("--diagnostic-provenance", required=True, type=Path)
    compare.add_argument("--baseline-prior-evidence", required=True, type=Path)
    compare.add_argument("--output", required=True, type=Path)
    return parser


def main(argv=None):
    args = build_parser().parse_args(argv)
    if args.command == "evaluate":
        report = evaluate_checkpoint(
            args.checkpoint_dir,
            args.tokenizer_model,
            args.label,
            args.dataset_root,
            args.dataset_manifest,
            args.training_config,
            args.manual,
            args.output_root,
            args.prior_evidence,
            args.budget_root_provenance,
            args.diagnostic_provenance,
        )
    else:
        report = build_checkpoint_comparison(
            args.baseline_summary,
            args.diagnostic_summary,
            args.diagnostic_provenance,
            args.baseline_prior_evidence,
        )
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_bytes(canonical_json_bytes(report))
    print(json.dumps(report, ensure_ascii=False, sort_keys=True), flush=True)


if __name__ == "__main__":
    try:
        main()
    except DiagnosticEvaluationError as error:
        raise SystemExit("error: %s" % error)
