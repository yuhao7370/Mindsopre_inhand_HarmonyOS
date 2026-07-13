#!/usr/bin/env python3
"""Run one bounded optimizer-reset rescue epoch from the step-16878 student."""

import argparse
import hashlib
import json
import math
import os
import random
import sys
import time
from pathlib import Path

if __package__ in {None, ""}:
    sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from tools.translation.distill_en_zh import (
    DistillationError,
    STUDENT_SHA256,
    canonical_json_bytes,
    generation_budget_snapshot,
    load_distillation_config,
    persist_terminal_budget_journal,
    require_no_terminal_budget_journal,
    rescue_accumulation_groups,
    validate_epoch2_gate,
)
from tools.translation.evaluate_translation import (
    FLORES_FILES,
    FLORES_REPO,
    FLORES_REVISION,
    load_manual_set,
    load_runtime,
)
from tools.translation.train_bidirectional import (
    TrainingContractError,
    _evaluate_validation,
    _forward_loss,
    _load_json,
    _memmap_batch,
    _save_selected_checkpoint,
    _set_determinism,
    _sha256_file,
    alternating_batch_plan,
    build_token_cache,
    load_training_config,
    verify_dataset_inputs,
)


BASELINE_LOSS = 3.7039039318084717
CANDIDATE_DIR = "candidate-epoch1"
ATOMIC_REPLACE_ATTEMPTS = 20
ATOMIC_REPLACE_RETRY_SECONDS = 0.05


def _write_atomic_json(path, value):
    temporary = Path(str(path) + ".partial")
    try:
        temporary.write_bytes(canonical_json_bytes(value))
        for attempt in range(ATOMIC_REPLACE_ATTEMPTS):
            try:
                os.replace(temporary, path)
                break
            except PermissionError:
                if attempt + 1 == ATOMIC_REPLACE_ATTEMPTS:
                    raise
                time.sleep(ATOMIC_REPLACE_RETRY_SECONDS)
    finally:
        temporary.unlink(missing_ok=True)


def _verify_rescue_view(path, expected_rows=90000):
    count = 0
    with Path(path).open("rb") as stream:
        for raw in stream:
            if b"\r" in raw or not raw.endswith(b"\n"):
                raise DistillationError("rescue training view is not canonical LF")
            row = json.loads(raw.decode("utf-8"))
            if not isinstance(row, dict) or set(row) != {"direction_id", "source", "target"} or row["direction_id"] != 32002:
                raise DistillationError("rescue training row schema differs")
            if not isinstance(row["source"], str) or not row["source"] or not isinstance(row["target"], str) or not row["target"]:
                raise DistillationError("rescue training row is empty")
            count += 1
    if count != expected_rows:
        raise DistillationError("rescue training row count differs")
    size, digest = _sha256_file(path)
    return {"path": Path(path).name, "count": count, "bytes": size, "sha256": digest}


def rescue_budget_snapshot(distillation_config, teacher_generation_seconds, rescue_elapsed_seconds):
    for value, label in (
        (teacher_generation_seconds, "teacher generation seconds"),
        (rescue_elapsed_seconds, "rescue elapsed seconds"),
    ):
        if isinstance(value, bool) or not isinstance(value, (int, float)) or not math.isfinite(value) or value < 0:
            raise DistillationError("%s is invalid" % label)
    baseline = float(distillation_config["budget"]["previous_gpu_seconds"])
    probes = float(distillation_config["gpuLedger"]["probeActualSeconds"])
    teacher = float(teacher_generation_seconds)
    rescue = float(rescue_elapsed_seconds)
    total = float(distillation_config["budget"]["total_gpu_seconds"])
    cumulative = baseline + probes + teacher + rescue
    if cumulative > total:
        raise DistillationError("rescue actual GPU ledger exceeds cumulative budget")
    return {
        "baselineGpuSeconds": baseline,
        "probeAndLoadActualSeconds": probes,
        "teacherGenerationActualSeconds": teacher,
        "rescueActualSeconds": rescue,
        "cumulativeActualSeconds": cumulative,
        "totalBudgetSeconds": total,
        "remainingSeconds": total - cumulative,
    }


def checked_rescue_budget_snapshot(
    distillation_config,
    teacher_generation_seconds,
    rescue_elapsed_seconds,
    terminal_path,
    objective_hashes,
    cursor,
):
    try:
        return rescue_budget_snapshot(
            distillation_config, teacher_generation_seconds, rescue_elapsed_seconds
        )
    except DistillationError:
        persist_terminal_budget_journal(
            terminal_path,
            "rescue_training",
            rescue_elapsed_seconds,
            objective_hashes,
            cursor,
        )
        raise


def build_rescue_objective_hashes(
    distillation_config,
    training_config,
    dataset_manifest,
    rescue_view,
    training_view_manifest,
    distillation_manifest,
    offline_verification_one,
    offline_verification_two,
    baseline_checkpoint,
    epoch,
):
    if isinstance(epoch, bool) or epoch not in {1, 2}:
        raise DistillationError("rescue objective epoch differs")
    return {
        "distillation_config": hashlib.sha256(
            canonical_json_bytes(distillation_config)
        ).hexdigest(),
        "training_config": hashlib.sha256(canonical_json_bytes(training_config)).hexdigest(),
        "dataset_manifest": hashlib.sha256(canonical_json_bytes(dataset_manifest)).hexdigest(),
        "rescue_view": _sha256_file(rescue_view)[1],
        "training_view_manifest": _sha256_file(training_view_manifest)[1],
        "distillation_manifest": _sha256_file(distillation_manifest)[1],
        "offline_verification_one": _sha256_file(offline_verification_one)[1],
        "offline_verification_two": _sha256_file(offline_verification_two)[1],
        "baseline_model": _sha256_file(
            Path(baseline_checkpoint) / "model.safetensors"
        )[1],
        "baseline_tokenizer": _sha256_file(
            Path(baseline_checkpoint) / "tokenizer.model"
        )[1],
        "rescue_epoch": hashlib.sha256(str(epoch).encode("ascii")).hexdigest(),
    }


def verify_rescue_bundle(
    distillation_config,
    rescue_view,
    training_view_manifest_path,
    distillation_manifest_path,
    offline_verification_one,
    offline_verification_two,
    expected_rows=90000,
):
    if Path(offline_verification_one).resolve() == Path(offline_verification_two).resolve():
        raise DistillationError("offline verification receipt paths must be distinct")
    view_artifact = _verify_rescue_view(rescue_view, expected_rows=expected_rows)
    training_view = _load_json(training_view_manifest_path)
    if not isinstance(training_view, dict) or set(training_view) != {
        "schema_version", "audit", "output", "target_origins"
    }:
        raise DistillationError("training-view manifest schema differs")
    audit = training_view["audit"]
    output = training_view["output"]
    origins = training_view["target_origins"]
    artifact_keys = {"path", "rows", "bytes", "sha256"}
    if (
        training_view["schema_version"] != 1
        or not isinstance(audit, dict)
        or set(audit) != artifact_keys
        or not isinstance(output, dict)
        or set(output) != artifact_keys
        or not isinstance(origins, dict)
        or set(origins) != {"teacher", "original_fallback"}
        or output != {
            "path": view_artifact["path"],
            "rows": view_artifact["count"],
            "bytes": view_artifact["bytes"],
            "sha256": view_artifact["sha256"],
        }
        or output["rows"] != expected_rows
        or origins["teacher"] + origins["original_fallback"] != expected_rows
    ):
        raise DistillationError("training-view manifest does not bind rescue view")
    manifest_root = Path(training_view_manifest_path).resolve().parent
    if Path(audit["path"]).name != audit["path"] or Path(output["path"]).name != output["path"]:
        raise DistillationError("training-view artifact path is not local")
    audit_path = manifest_root / audit["path"]
    audit_size, audit_sha256 = _sha256_file(audit_path)
    if audit["rows"] != expected_rows or audit_size != audit["bytes"] or audit_sha256 != audit["sha256"]:
        raise DistillationError("training-view audit artifact differs")
    with audit_path.open("rb") as audit_stream, Path(rescue_view).open("rb") as view_stream:
        for expected_id in range(expected_rows):
            audit_raw = audit_stream.readline()
            view_raw = view_stream.readline()
            if not audit_raw or not view_raw or b"\r" in audit_raw or b"\r" in view_raw:
                raise DistillationError("rescue view/audit materialization row count or LF differs")
            try:
                audit_row = json.loads(audit_raw.decode("utf-8"))
                view_row = json.loads(view_raw.decode("utf-8"))
            except (UnicodeDecodeError, json.JSONDecodeError) as error:
                raise DistillationError("rescue view/audit materialization JSON differs") from error
            if (
                not isinstance(audit_row, dict)
                or set(audit_row) != {
                    "id", "source_sha256", "source", "target", "direction_id",
                    "target_origin", "target_reason",
                }
                or audit_row["id"] != expected_id
                or audit_row["source_sha256"] != hashlib.sha256(audit_row["source"].encode("utf-8")).hexdigest()
                or audit_row["direction_id"] != 32002
                or audit_raw != canonical_json_bytes(audit_row)
            ):
                raise DistillationError("rescue audit row identity/canonical schema differs")
            expected_view = {
                "direction_id": 32002,
                "source": audit_row["source"],
                "target": audit_row["target"],
            }
            if view_row != expected_view or view_raw != canonical_json_bytes(expected_view):
                raise DistillationError("rescue view is not the canonical row-wise audit materialization")
        if audit_stream.read(1) or view_stream.read(1):
            raise DistillationError("rescue view/audit has extra rows")
    distillation = _load_json(distillation_manifest_path)
    expected_distillation_keys = {
        "schema_version", "teacher", "source", "output", "fullAudit", "chunks",
        "latin_residue_rows", "target_origins", "validationPolicy", "generation",
        "generation_gpu_seconds", "cumulative_gpu_seconds", "cumulative_with_reserve_seconds",
        "gpuLedger", "fallbackPreservationWarnings",
    }
    if not isinstance(distillation, dict) or set(distillation) != expected_distillation_keys:
        raise DistillationError("distillation manifest schema differs")
    teacher_seconds = distillation.get("generation_gpu_seconds")
    budget = generation_budget_snapshot(distillation_config, teacher_seconds)
    sidecar = distillation.get("fallbackPreservationWarnings")
    sidecar_keys = {
        "path", "rows", "bytes", "sha256", "fallbackWithPreservationWarnings", "number", "url"
    }
    if not isinstance(sidecar, dict) or set(sidecar) != sidecar_keys or Path(sidecar["path"]).name != sidecar["path"]:
        raise DistillationError("distillation fallback sidecar manifest differs")
    sidecar_size, sidecar_sha256 = _sha256_file(Path(distillation_manifest_path).resolve().parent / sidecar["path"])
    chunks = distillation.get("chunks")
    if (
        not isinstance(chunks, list)
        or not chunks
        or any(
            not isinstance(item, dict)
            or set(item) != {"path", "rows", "bytes", "sha256"}
            or Path(item["path"]).name != item["path"]
            or not isinstance(item["rows"], int)
            or isinstance(item["rows"], bool)
            or item["rows"] < 1
            or not isinstance(item["bytes"], int)
            or isinstance(item["bytes"], bool)
            or item["bytes"] < 1
            or not isinstance(item["sha256"], str)
            or len(item["sha256"]) != 64
            for item in chunks
        )
        or sum(item["rows"] for item in chunks) != expected_rows
    ):
        raise DistillationError("distillation chunk manifest differs")
    if (
        distillation.get("schema_version") != 1
        or distillation.get("teacher") != {
            "repo": distillation_config["teacher"]["repo"],
            "revision": distillation_config["teacher"]["revision"],
            "prefix": distillation_config["teacher"]["prefix"],
        }
        or distillation.get("source") != {
            "path": distillation_config["data"]["source_file"],
            "rows": distillation_config["data"]["source_rows"],
            "bytes": distillation_config["data"]["source_bytes"],
            "sha256": distillation_config["data"]["source_sha256"],
        }
        or distillation.get("output") != audit
        or distillation.get("fullAudit") != audit
        or distillation.get("target_origins") != {
            "teacher": origins["teacher"],
            "original_fallback": origins["original_fallback"],
            "hard_fail": 0,
        }
        or distillation.get("validationPolicy") != distillation_config["validationPolicy"]
        or distillation.get("generation") != {
            "precision": "fp16", "num_beams": 4, "do_sample": False,
            "renormalize_logits": True, "max_tokens": 128, "batch_size": 64,
        }
        or sidecar["rows"] != origins["original_fallback"]
        or sidecar_size != sidecar["bytes"]
        or sidecar_sha256 != sidecar["sha256"]
        or distillation.get("gpuLedger") != {
            "probeAndLoad": distillation_config["gpuLedger"],
            "budget": budget,
        }
        or distillation.get("cumulative_gpu_seconds") != budget["cumulativeActualSeconds"]
        or distillation.get("cumulative_with_reserve_seconds") != budget["cumulativeWithReserveSeconds"]
    ):
        raise DistillationError("distillation manifest does not bind rescue provenance/ledger")
    manifest_sha256 = _sha256_file(distillation_manifest_path)[1]
    verification_one = _load_json(offline_verification_one)
    verification_two = _load_json(offline_verification_two)
    expected_verification = {
        "schema_version": 1,
        "verified": True,
        "rows": expected_rows,
        "output_bytes": audit["bytes"],
        "output_sha256": audit["sha256"],
        "network_calls": 0,
        "gpuLedger": budget,
        "manifest_sha256": manifest_sha256,
        "student_tokenizer_sha256": distillation_config["student"]["tokenizer_sha256"],
    }
    expected_verification_bytes = canonical_json_bytes(expected_verification)
    if (
        verification_one != expected_verification
        or verification_two != expected_verification
        or Path(offline_verification_one).read_bytes() != expected_verification_bytes
        or Path(offline_verification_two).read_bytes() != expected_verification_bytes
    ):
        raise DistillationError("two byte-equivalent offline verification receipts are required")
    return {
        "view_artifact": view_artifact,
        "audit_artifact": audit,
        "target_origins": origins,
        "teacher_generation_gpu_seconds": float(teacher_seconds),
    }


def validate_rescue_resume_state(
    state, total_groups, expected_objective_hashes, expected_epoch=0,
    expected_baseline_loss=BASELINE_LOSS,
):
    expected = {
        "schema_version", "model", "optimizer", "scaler", "rescue_step", "epoch",
        "next_group", "elapsed_seconds", "python_random_state", "torch_random_state",
        "cuda_random_state", "validation_history", "best_loss", "best_step",
        "objective_hashes",
    }
    if (
        not isinstance(state, dict)
        or set(state) != expected
        or state["schema_version"] != 1
        or state["objective_hashes"] != expected_objective_hashes
    ):
        raise DistillationError("rescue resume schema differs")
    step = state["rescue_step"]
    elapsed = state["elapsed_seconds"]
    if (
        isinstance(step, bool)
        or not isinstance(step, int)
        or step < 1
        or step > total_groups
        or state["epoch"] != expected_epoch
        or state["next_group"] != step
        or isinstance(elapsed, bool)
        or not isinstance(elapsed, (int, float))
        or not math.isfinite(elapsed)
        or elapsed < 0
    ):
        raise DistillationError("rescue resume cursor/elapsed differs")
    history = state["validation_history"]
    if not isinstance(history, list):
        raise DistillationError("rescue resume validation history differs")
    for item in history:
        if (
            not isinstance(item, dict)
            or set(item) != {"rescue_step", "loss"}
            or isinstance(item["rescue_step"], bool)
            or not isinstance(item["rescue_step"], int)
            or item["rescue_step"] < 1
            or item["rescue_step"] > step
            or isinstance(item["loss"], bool)
            or not isinstance(item["loss"], (int, float))
            or not math.isfinite(item["loss"])
            or item["loss"] < 0
        ):
            raise DistillationError("rescue resume validation history entry differs")
    history_steps = [item["rescue_step"] for item in history]
    if history_steps != sorted(set(history_steps)):
        raise DistillationError("rescue resume validation history order differs")
    best_loss = state["best_loss"]
    best_step = state["best_step"]
    if (
        isinstance(best_loss, bool)
        or not isinstance(best_loss, (int, float))
        or not math.isfinite(best_loss)
        or best_loss < 0
        or (best_step is None) != (best_loss == expected_baseline_loss)
        or (best_step is not None and (best_step not in [item["rescue_step"] for item in history] or best_step > step))
    ):
        raise DistillationError("rescue resume best checkpoint metadata differs")
    if best_step is not None:
        expected_best = min(
            (item for item in history if item["loss"] < expected_baseline_loss),
            key=lambda item: item["loss"],
            default=None,
        )
        if expected_best is None or expected_best["rescue_step"] != best_step or expected_best["loss"] != best_loss:
            raise DistillationError("rescue resume strict-best metadata differs")
    return step, float(elapsed), history, float(best_loss), best_step


def rescue_elapsed_floor(resume_elapsed, progress, expected_objective_hashes):
    if not isinstance(progress, dict) or progress.get("objective_hashes") != expected_objective_hashes:
        raise DistillationError("rescue elapsed journal objective differs")
    step = progress.get("rescue_step")
    elapsed = progress.get("rescue_gpu_seconds")
    if (
        isinstance(step, bool)
        or not isinstance(step, int)
        or step < 1
        or isinstance(elapsed, bool)
        or not isinstance(elapsed, (int, float))
        or not math.isfinite(elapsed)
        or elapsed < resume_elapsed
    ):
        raise DistillationError("rescue elapsed journal differs")
    return float(elapsed)


def cumulative_rescue_elapsed(previous_elapsed, phase_started, now):
    values = (previous_elapsed, phase_started, now)
    if any(
        isinstance(value, bool)
        or not isinstance(value, (int, float))
        or not math.isfinite(value)
        for value in values
    ) or previous_elapsed < 0 or now < phase_started:
        raise DistillationError("rescue elapsed timer differs")
    return float(previous_elapsed + now - phase_started)


def validate_baseline_replay(
    progress_path,
    resume_path,
    expected_objective_hashes,
    prior_elapsed_floor,
    recovery_path,
):
    progress_path = Path(progress_path)
    recovery_path = Path(recovery_path)
    if Path(resume_path).exists():
        raise DistillationError("baseline replay is forbidden when a resume checkpoint exists")
    if Path(str(resume_path) + ".partial").exists():
        raise DistillationError("baseline replay rejects partial resume checkpoint")
    if Path(str(progress_path) + ".partial").exists():
        raise DistillationError("baseline replay rejects partial progress")
    if recovery_path.exists() or Path(str(recovery_path) + ".partial").exists():
        raise DistillationError("baseline replay receipt already exists")
    progress = _load_json(progress_path)
    if (
        not isinstance(progress, dict)
        or set(progress) != {
            "schema_version", "rescue_step", "loss", "learning_rate",
            "rescue_gpu_seconds", "cumulative_gpu_seconds", "objective_hashes",
        }
        or progress["schema_version"] != 1
        or progress["objective_hashes"] != expected_objective_hashes
        or progress_path.read_bytes() != canonical_json_bytes(progress)
        or isinstance(progress["rescue_step"], bool)
        or not isinstance(progress["rescue_step"], int)
        or progress["rescue_step"] < 1
        or any(
            isinstance(progress[name], bool)
            or not isinstance(progress[name], (int, float))
            or not math.isfinite(progress[name])
            or progress[name] < 0
            for name in (
                "loss", "learning_rate", "rescue_gpu_seconds", "cumulative_gpu_seconds"
            )
        )
    ):
        raise DistillationError("baseline replay progress schema/objective differs")
    elapsed_floor = rescue_elapsed_floor(
        prior_elapsed_floor, progress, expected_objective_hashes
    )
    progress_bytes, progress_sha256 = _sha256_file(progress_path)
    recovery = {
        "schema_version": 1,
        "mode": "explicit_replay_from_baseline",
        "progress": {
            "path": progress_path.name,
            "bytes": progress_bytes,
            "sha256": progress_sha256,
        },
        "elapsed_floor_seconds": elapsed_floor,
        "replayed_optimizer_steps": progress["rescue_step"],
        "objective_hashes": expected_objective_hashes,
    }
    _write_atomic_json(recovery_path, recovery)
    return elapsed_floor, progress["rescue_step"]


def summarize_audited_manual_results(path, expected_manual_rows):
    if not isinstance(expected_manual_rows, list) or len(expected_manual_rows) != 100:
        raise DistillationError("manual asset rows differ")
    rows = []
    with Path(path).open("rb") as stream:
        for raw in stream:
            if b"\r" in raw or not raw.endswith(b"\n"):
                raise DistillationError("audited manual results are not canonical LF")
            try:
                row = json.loads(raw.decode("utf-8"))
            except (UnicodeDecodeError, json.JSONDecodeError) as error:
                raise DistillationError("audited manual results JSON differs") from error
            if (
                not isinstance(row, dict)
                or set(row) != {
                    "id", "direction", "source", "reference", "categories", "output",
                    "fatal_corruptions", "pass", "reason",
                }
                or row["direction"] not in {"zh-en", "en-zh"}
                or not isinstance(row["output"], str)
                or not isinstance(row["pass"], bool)
                or not isinstance(row["fatal_corruptions"], list)
                or any(not isinstance(value, str) or not value for value in row["fatal_corruptions"])
                or not isinstance(row["reason"], str)
                or not row["reason"].strip()
                or raw != canonical_json_bytes(row)
            ):
                raise DistillationError("audited manual result row schema differs")
            rows.append(row)
    if [row["id"] for row in rows] != list(range(1, 101)):
        raise DistillationError("audited manual result IDs/count differ")
    for expected, actual in zip(expected_manual_rows, rows):
        if not isinstance(expected, dict) or set(expected) != {
            "id", "direction", "source", "reference", "categories"
        } or any(actual[name] != expected[name] for name in expected):
            raise DistillationError("audited manual results are not bound to manual asset rows")
    summary = {}
    for direction in ("zh-en", "en-zh"):
        selected = [row for row in rows if row["direction"] == direction]
        if len(selected) != 50:
            raise DistillationError("audited manual direction count differs")
        summary[direction] = {
            "total": 50,
            "passed": sum(row["pass"] for row in selected),
            "fatal_corruptions": sum(bool(row["fatal_corruptions"]) for row in selected),
        }
    size, digest = _sha256_file(path)
    return summary, {
        "path": Path(path).name,
        "rows": 100,
        "bytes": size,
        "sha256": digest,
    }


def _file_artifact(path):
    size, digest = _sha256_file(path)
    return {"path": Path(path).name, "bytes": size, "sha256": digest}


def _is_sha256(value):
    return (
        isinstance(value, str)
        and len(value) == 64
        and all(character in "0123456789abcdef" for character in value)
    )


def _validated_manual_gate_summary(manual):
    if not isinstance(manual, dict) or set(manual) != {"zh-en", "en-zh"}:
        raise DistillationError("rescue manual gate schema differs")
    for direction in ("zh-en", "en-zh"):
        item = manual[direction]
        if (
            not isinstance(item, dict)
            or set(item) != {"total", "passed", "fatal_corruptions"}
            or any(
                isinstance(item[name], bool)
                or not isinstance(item[name], int)
                or item[name] < 0
                for name in item
            )
            or item["total"] != 50
            or item["passed"] > item["total"]
            or item["fatal_corruptions"] > item["total"]
        ):
            raise DistillationError("rescue manual gate value differs")
    return {
        direction: {
            "passed": manual[direction]["passed"],
            "fatal_corruptions": manual[direction]["fatal_corruptions"],
        }
        for direction in ("zh-en", "en-zh")
    }


def _verify_training_replay_receipt(training, training_report_path, objective_hashes):
    replayed = training["replayed_from_baseline"]
    replayed_steps = training["replayed_optimizer_steps"]
    artifact = training["baseline_replay_receipt"]
    if not replayed:
        if replayed_steps != 0 or artifact is not None:
            raise DistillationError("non-replay training report contains replay evidence")
        return
    if (
        replayed_steps < 1
        or not isinstance(artifact, dict)
        or set(artifact) != {"path", "bytes", "sha256"}
        or artifact["path"] != "baseline-replay-v1.json"
        or isinstance(artifact["bytes"], bool)
        or not isinstance(artifact["bytes"], int)
        or artifact["bytes"] < 1
        or not _is_sha256(artifact["sha256"])
    ):
        raise DistillationError("baseline replay artifact schema differs")
    receipt_path = Path(training_report_path).resolve().parent / artifact["path"]
    try:
        actual_artifact = _file_artifact(receipt_path)
    except OSError as error:
        raise DistillationError("baseline replay artifact is missing") from error
    if actual_artifact != artifact:
        raise DistillationError("baseline replay artifact hash differs")
    receipt = _load_json(receipt_path)
    if (
        not isinstance(receipt, dict)
        or set(receipt) != {
            "schema_version", "mode", "progress", "elapsed_floor_seconds",
            "replayed_optimizer_steps", "objective_hashes",
        }
        or receipt["schema_version"] != 1
        or receipt["mode"] != "explicit_replay_from_baseline"
        or receipt["replayed_optimizer_steps"] != replayed_steps
        or receipt["objective_hashes"] != objective_hashes
        or not isinstance(receipt["progress"], dict)
        or set(receipt["progress"]) != {"path", "bytes", "sha256"}
        or receipt["progress"]["path"] != "progress-v1.json"
        or isinstance(receipt["progress"]["bytes"], bool)
        or not isinstance(receipt["progress"]["bytes"], int)
        or receipt["progress"]["bytes"] < 1
        or not _is_sha256(receipt["progress"]["sha256"])
        or isinstance(receipt["elapsed_floor_seconds"], bool)
        or not isinstance(receipt["elapsed_floor_seconds"], (int, float))
        or not math.isfinite(receipt["elapsed_floor_seconds"])
        or receipt["elapsed_floor_seconds"] < 0
        or receipt["elapsed_floor_seconds"] > training["rescue_gpu_seconds"]
        or receipt_path.read_bytes() != canonical_json_bytes(receipt)
    ):
        raise DistillationError("baseline replay receipt content differs")


def verify_epoch2_authorization(
    gate_report_path, epoch1_training_report_path, expected_candidate,
    distillation_config, teacher_generation_seconds,
    expected_epoch1_objective_hashes,
):
    gate = _load_json(gate_report_path)
    training = _load_json(epoch1_training_report_path)
    gate_keys = {
        "schema_version", "epoch2_allowed", "epoch2_launch_allowed", "epoch2_status",
        "promotion_allowed", "candidate", "candidateEpoch", "trainingReport",
        "objectiveHashes", "manualAsset", "manualResults", "manual", "flores",
    }
    objective_hashes = training.get("objective_hashes") if isinstance(training, dict) else None
    training_keys = {
        "schema_version", "epoch", "seed", "plan_epoch_index", "optimizer_reset",
        "rescue_steps", "logical_batches", "dropped_partial_logical_batches",
        "validation_history", "baseline_validation_loss", "best_rescue_step",
        "best_validation_loss", "candidate_checkpoint", "candidate", "promotion_allowed",
        "promotion_status", "resumed", "teacher_generation_gpu_seconds",
        "probe_gpu_seconds", "rescue_gpu_seconds", "epoch_gpu_seconds",
        "cumulative_gpu_seconds", "gpuLedger", "training_view_manifest_sha256",
        "distillation_manifest_sha256", "peak_cuda_bytes", "last_progress",
        "objective_hashes", "replayed_from_baseline", "replayed_optimizer_steps",
        "baseline_replay_receipt",
    }
    manual_asset = gate.get("manualAsset") if isinstance(gate, dict) else None
    manual_results = gate.get("manualResults") if isinstance(gate, dict) else None
    artifact_keys = {"path", "rows", "bytes", "sha256"}
    if (
        not isinstance(gate, dict)
        or set(gate) != gate_keys
        or gate["schema_version"] != 1
        or gate["epoch2_allowed"] is not True
        or gate["epoch2_launch_allowed"] is not True
        or gate["epoch2_status"] != "authorized"
        or gate["candidate"] != expected_candidate
        or gate["candidateEpoch"] != 1
        or gate["trainingReport"] != _file_artifact(epoch1_training_report_path)
        or not isinstance(gate["promotion_allowed"], bool)
        or not isinstance(manual_asset, dict)
        or set(manual_asset) != artifact_keys
        or not isinstance(manual_results, dict)
        or set(manual_results) != artifact_keys
        or any(
            artifact["rows"] != 100
            or Path(artifact["path"]).name != artifact["path"]
            or not isinstance(artifact["bytes"], int)
            or isinstance(artifact["bytes"], bool)
            or artifact["bytes"] < 1
            or not isinstance(artifact["sha256"], str)
            or len(artifact["sha256"]) != 64
            for artifact in (manual_asset, manual_results)
        )
        or not isinstance(training, dict)
        or set(training) != training_keys
        or training.get("schema_version") != 1
        or training.get("epoch") != 1
        or training.get("seed") != distillation_config["seed"]
        or training.get("plan_epoch_index") != 0
        or training.get("optimizer_reset") is not True
        or training.get("rescue_steps") != 1406
        or training.get("logical_batches") != 5624
        or training.get("dropped_partial_logical_batches") != 2
        or training.get("baseline_validation_loss") != BASELINE_LOSS
        or training.get("candidate") != expected_candidate
        or training.get("candidate_checkpoint") != "candidate-epoch1/selected"
        or training.get("promotion_allowed") is not False
        or training.get("promotion_status") != "pending_manual_and_flores_gate"
        or not isinstance(training.get("replayed_from_baseline"), bool)
        or isinstance(training.get("replayed_optimizer_steps"), bool)
        or not isinstance(training.get("replayed_optimizer_steps"), int)
        or training.get("replayed_optimizer_steps") < 0
        or training.get("replayed_optimizer_steps") > 1406
        or not isinstance(objective_hashes, dict)
        or not objective_hashes
        or any(not isinstance(value, str) or len(value) != 64 for value in objective_hashes.values())
        or objective_hashes != expected_epoch1_objective_hashes
        or gate["objectiveHashes"] != objective_hashes
        or Path(gate_report_path).read_bytes() != canonical_json_bytes(gate)
        or Path(epoch1_training_report_path).read_bytes() != canonical_json_bytes(training)
    ):
        raise DistillationError("epoch 2 authorization does not bind passed epoch 1 gate/candidate/objective")
    gate_manual = _validated_manual_gate_summary(gate["manual"])
    if (
        not validate_epoch2_gate(gate_manual)
        or gate["epoch2_allowed"] is not True
        or gate["epoch2_launch_allowed"] is not True
        or gate["epoch2_status"] != "authorized"
    ):
        raise DistillationError("epoch 1 manual gate does not authorize epoch 2")
    _verify_training_replay_receipt(
        training, epoch1_training_report_path, objective_hashes
    )
    history = training["validation_history"]
    if (
        not isinstance(history, list)
        or not history
        or any(
            not isinstance(item, dict)
            or set(item) != {"rescue_step", "loss"}
            or isinstance(item["rescue_step"], bool)
            or not isinstance(item["rescue_step"], int)
            or item["rescue_step"] < 1
            or item["rescue_step"] > 1406
            or isinstance(item["loss"], bool)
            or not isinstance(item["loss"], (int, float))
            or not math.isfinite(item["loss"])
            or item["loss"] < 0
            for item in history
        )
        or [item["rescue_step"] for item in history]
        != sorted(set(item["rescue_step"] for item in history))
    ):
        raise DistillationError("epoch 1 validation history differs")
    strict_best = min(
        (item for item in history if item["loss"] < BASELINE_LOSS),
        key=lambda item: item["loss"],
        default=None,
    )
    if (
        strict_best is None
        or training["best_rescue_step"] != strict_best["rescue_step"]
        or training["best_validation_loss"] != strict_best["loss"]
    ):
        raise DistillationError("epoch 1 strict-best candidate differs")
    elapsed = training.get("rescue_gpu_seconds")
    baseline_loss = training.get("best_validation_loss")
    expected_ledger = None
    if isinstance(elapsed, (int, float)) and not isinstance(elapsed, bool):
        expected_ledger = rescue_budget_snapshot(
            distillation_config, teacher_generation_seconds, elapsed
        )
    if (
        isinstance(elapsed, bool)
        or not isinstance(elapsed, (int, float))
        or not math.isfinite(elapsed)
        or elapsed < 0
        or isinstance(baseline_loss, bool)
        or not isinstance(baseline_loss, (int, float))
        or not math.isfinite(baseline_loss)
        or baseline_loss < 0
        or baseline_loss >= BASELINE_LOSS
        or training.get("teacher_generation_gpu_seconds") != teacher_generation_seconds
        or training.get("probe_gpu_seconds") != distillation_config["gpuLedger"]["probeActualSeconds"]
        or training.get("epoch_gpu_seconds") != elapsed
        or training.get("gpuLedger") != expected_ledger
        or training.get("cumulative_gpu_seconds") != expected_ledger["cumulativeActualSeconds"]
        or not isinstance(training.get("peak_cuda_bytes"), int)
        or isinstance(training.get("peak_cuda_bytes"), bool)
        or training.get("peak_cuda_bytes") < 0
        or any(
            not isinstance(training.get(name), str) or len(training.get(name)) != 64
            for name in ("training_view_manifest_sha256", "distillation_manifest_sha256")
        )
        or training.get("training_view_manifest_sha256")
        != expected_epoch1_objective_hashes["training_view_manifest"]
        or training.get("distillation_manifest_sha256")
        != expected_epoch1_objective_hashes["distillation_manifest"]
        or not isinstance(training.get("last_progress"), dict)
        or set(training["last_progress"]) != {
            "schema_version", "rescue_step", "loss", "learning_rate",
            "rescue_gpu_seconds", "cumulative_gpu_seconds", "objective_hashes",
        }
        or training["last_progress"].get("schema_version") != 1
        or training["last_progress"].get("rescue_step") != 1406
        or training["last_progress"].get("rescue_gpu_seconds") != elapsed
        or training["last_progress"].get("cumulative_gpu_seconds")
        != expected_ledger["cumulativeActualSeconds"]
        or training["last_progress"].get("objective_hashes") != objective_hashes
    ):
        raise DistillationError("epoch 1 cumulative rescue GPU floor differs")
    return {
        "prior_rescue_gpu_seconds": float(elapsed),
        "baseline_validation_loss": float(baseline_loss),
        "epoch1_objective_hashes": objective_hashes,
        "gate_report_sha256": _sha256_file(gate_report_path)[1],
        "training_report_sha256": _sha256_file(epoch1_training_report_path)[1],
    }


def evaluate_rescue_gates(
    distillation_config,
    evaluation,
    expected_candidate,
    expected_manual_asset,
    expected_manual_results,
    expected_manual_summary,
    expected_training_artifact,
    expected_objective_hashes,
    candidate_epoch,
    expected_flores_files=None,
):
    if (
        isinstance(candidate_epoch, bool)
        or candidate_epoch not in {1, 2}
        or not isinstance(expected_training_artifact, dict)
        or set(expected_training_artifact) != {"path", "bytes", "sha256"}
        or Path(expected_training_artifact["path"]).name
        != expected_training_artifact["path"]
        or not isinstance(expected_training_artifact["bytes"], int)
        or isinstance(expected_training_artifact["bytes"], bool)
        or expected_training_artifact["bytes"] < 1
        or not isinstance(expected_training_artifact["sha256"], str)
        or len(expected_training_artifact["sha256"]) != 64
        or not isinstance(expected_objective_hashes, dict)
        or not expected_objective_hashes
        or any(
            not isinstance(value, str) or len(value) != 64
            for value in expected_objective_hashes.values()
        )
    ):
        raise DistillationError("epoch 1 training artifact/objective gate input differs")
    if not isinstance(evaluation, dict) or set(evaluation) != {
        "schema_version", "candidate", "manualAsset", "manualResults", "manual", "flores"
    }:
        raise DistillationError("rescue gate input schema differs")
    if (
        evaluation["schema_version"] != 1
        or evaluation["candidate"] != expected_candidate
        or evaluation["manualAsset"] != expected_manual_asset
        or evaluation["manualResults"] != expected_manual_results
        or evaluation["manual"] != expected_manual_summary
    ):
        raise DistillationError("rescue gate candidate/manual asset provenance differs")
    manual = evaluation["manual"]
    gate_manual = _validated_manual_gate_summary(manual)
    epoch2_allowed = candidate_epoch == 1 and validate_epoch2_gate(gate_manual)
    promotion = distillation_config["promotion_gate"]
    manual_promotion = all(
        gate_manual[direction]["passed"] >= promotion["manual_min_passed_per_direction"]
        and gate_manual[direction]["fatal_corruptions"] <= promotion["manual_max_fatal_per_direction"]
        for direction in ("zh-en", "en-zh")
    )
    flores = evaluation["flores"]
    flores_promotion = False
    if isinstance(flores, dict) and set(flores) == {"repo", "revision", "files", "metrics"}:
        try:
            files = flores["files"]
            metrics = flores["metrics"]
            file_contract = (
                flores["repo"] == FLORES_REPO
                and flores["revision"] == FLORES_REVISION
                and expected_flores_files is not None
                and files == expected_flores_files
                and isinstance(files, list)
                and len(files) == 2
                and {item["path"] for item in files} == {FLORES_FILES["zh"], FLORES_FILES["en"]}
                and all(
                    isinstance(item, dict)
                    and set(item) == {"language", "path", "bytes", "sha256"}
                    and isinstance(item["bytes"], int)
                    and not isinstance(item["bytes"], bool)
                    and item["bytes"] > 0
                    and isinstance(item["sha256"], str)
                    and len(item["sha256"]) == 64
                    for item in files
                )
            )
            values = []
            metric_contract = isinstance(metrics, dict) and set(metrics) == {"zh-en", "en-zh"}
            for direction in ("zh-en", "en-zh"):
                if (
                    not metric_contract
                    or not isinstance(metrics[direction], dict)
                    or set(metrics[direction]) != {"bleu", "chrf2"}
                ):
                    metric_contract = False
                    break
                raw_bleu = metrics[direction]["bleu"]
                raw_chrf2 = metrics[direction]["chrf2"]
                if any(
                    isinstance(value, bool) or not isinstance(value, (int, float))
                    for value in (raw_bleu, raw_chrf2)
                ):
                    metric_contract = False
                    break
                bleu = float(raw_bleu)
                chrf2 = float(raw_chrf2)
                if not math.isfinite(bleu) or not math.isfinite(chrf2):
                    metric_contract = False
                    break
                values.append((direction, bleu, chrf2))
            flores_promotion = file_contract and metric_contract and all(
                bleu >= promotion["flores_" + direction + "_bleu"]
                and chrf2 >= promotion["flores_" + direction + "_chrf2"]
                for direction, bleu, chrf2 in values
            )
        except (KeyError, TypeError, ValueError, OverflowError):
            flores_promotion = False
    return {
        "schema_version": 1,
        "epoch2_allowed": epoch2_allowed,
        "epoch2_launch_allowed": epoch2_allowed,
        "epoch2_status": (
            "authorized"
            if epoch2_allowed
            else ("max_epochs_reached" if candidate_epoch == 2 else "manual_gate_failed")
        ),
        "promotion_allowed": manual_promotion and flores_promotion,
        "candidate": expected_candidate,
        "candidateEpoch": candidate_epoch,
        "trainingReport": expected_training_artifact,
        "objectiveHashes": expected_objective_hashes,
        "manualAsset": expected_manual_asset,
        "manualResults": expected_manual_results,
        "manual": manual,
        "flores": flores,
    }


def _save_rescue_resume(
    torch,
    path,
    model,
    optimizer,
    scaler,
    rescue_step,
    next_group,
    elapsed_seconds,
    validation_history,
    best_loss,
    best_step,
    objective_hashes,
    epoch_index,
):
    state = {
        "schema_version": 1,
        "model": model.state_dict(),
        "optimizer": optimizer.state_dict(),
        "scaler": scaler.state_dict(),
        "rescue_step": rescue_step,
        "epoch": epoch_index,
        "next_group": next_group,
        "elapsed_seconds": elapsed_seconds,
        "python_random_state": random.getstate(),
        "torch_random_state": torch.get_rng_state(),
        "cuda_random_state": torch.cuda.get_rng_state_all(),
        "validation_history": validation_history,
        "best_loss": best_loss,
        "best_step": best_step,
        "objective_hashes": objective_hashes,
    }
    temporary = Path(str(path) + ".partial")
    torch.save(state, temporary)
    os.replace(temporary, path)


def restore_rescue_resume_state(
    torch, state, model, optimizer, scaler, total_groups, expected_objective_hashes,
    expected_epoch=0, expected_baseline_loss=BASELINE_LOSS,
):
    restored = validate_rescue_resume_state(
        state, total_groups, expected_objective_hashes, expected_epoch,
        expected_baseline_loss,
    )
    model.load_state_dict(state["model"])
    optimizer.load_state_dict(state["optimizer"])
    scaler.load_state_dict(state["scaler"])
    random.setstate(state["python_random_state"])
    torch.set_rng_state(state["torch_random_state"])
    torch.cuda.set_rng_state_all(state["cuda_random_state"])
    return restored


def run_rescue_epoch(
    distillation_config,
    training_config,
    dataset_manifest,
    dataset_root,
    rescue_view,
    training_view_manifest,
    distillation_manifest,
    offline_verification_one,
    offline_verification_two,
    baseline_checkpoint,
    artifact_root,
    resume=False,
    epoch=1,
    epoch1_gate_report=None,
    epoch1_training_report=None,
    epoch1_baseline_checkpoint=None,
    replay_from_baseline=False,
):
    if isinstance(epoch, bool) or epoch not in {1, 2}:
        raise DistillationError("rescue epoch must be 1 or 2")
    if resume and replay_from_baseline:
        raise DistillationError("--resume and --replay-from-baseline are mutually exclusive")
    if epoch == 1 and any(
        value is not None
        for value in (
            epoch1_gate_report, epoch1_training_report, epoch1_baseline_checkpoint
        )
    ):
        raise DistillationError("epoch 1 cannot accept epoch 2 authorization inputs")
    if epoch == 2 and any(
        value is None
        for value in (
            epoch1_gate_report, epoch1_training_report, epoch1_baseline_checkpoint
        )
    ):
        raise DistillationError(
            "epoch 2 requires passed epoch 1 gate, training report, and original baseline"
        )
    bundle = verify_rescue_bundle(
        distillation_config,
        rescue_view,
        training_view_manifest,
        distillation_manifest,
        offline_verification_one,
        offline_verification_two,
    )
    teacher_generation_seconds = bundle["teacher_generation_gpu_seconds"]
    probe_gpu_seconds = distillation_config["gpuLedger"]["probeActualSeconds"]
    generation_budget_snapshot(distillation_config, teacher_generation_seconds)
    baseline_model_sha256 = _sha256_file(Path(baseline_checkpoint) / "model.safetensors")[1]
    baseline_tokenizer_sha256 = _sha256_file(Path(baseline_checkpoint) / "tokenizer.model")[1]
    if baseline_tokenizer_sha256 != distillation_config["student"]["tokenizer_sha256"]:
        raise DistillationError("baseline student tokenizer hash differs")
    prior_rescue_seconds = 0.0
    epoch_baseline_loss = BASELINE_LOSS
    epoch2_authorization = None
    if epoch == 1:
        if baseline_model_sha256 != STUDENT_SHA256:
            raise DistillationError("baseline student checkpoint hash differs")
    else:
        if (
            _sha256_file(Path(epoch1_baseline_checkpoint) / "model.safetensors")[1]
            != STUDENT_SHA256
            or _sha256_file(Path(epoch1_baseline_checkpoint) / "tokenizer.model")[1]
            != distillation_config["student"]["tokenizer_sha256"]
        ):
            raise DistillationError("epoch 1 original baseline checkpoint differs")
        expected_epoch1_objective_hashes = build_rescue_objective_hashes(
            distillation_config,
            training_config,
            dataset_manifest,
            rescue_view,
            training_view_manifest,
            distillation_manifest,
            offline_verification_one,
            offline_verification_two,
            epoch1_baseline_checkpoint,
            1,
        )
        epoch2_authorization = verify_epoch2_authorization(
            epoch1_gate_report,
            epoch1_training_report,
            {
                "model_sha256": baseline_model_sha256,
                "tokenizer_sha256": baseline_tokenizer_sha256,
            },
            distillation_config,
            teacher_generation_seconds,
            expected_epoch1_objective_hashes,
        )
        prior_rescue_seconds = epoch2_authorization["prior_rescue_gpu_seconds"]
        epoch_baseline_loss = epoch2_authorization["baseline_validation_loss"]
    objective_hashes = build_rescue_objective_hashes(
        distillation_config,
        training_config,
        dataset_manifest,
        rescue_view,
        training_view_manifest,
        distillation_manifest,
        offline_verification_one,
        offline_verification_two,
        baseline_checkpoint,
        epoch,
    )
    if epoch2_authorization is not None:
        objective_hashes.update({
            "epoch1_gate_report": epoch2_authorization["gate_report_sha256"],
            "epoch1_training_report": epoch2_authorization["training_report_sha256"],
            "epoch1_objective_hashes": hashlib.sha256(
                canonical_json_bytes(epoch2_authorization["epoch1_objective_hashes"])
            ).hexdigest(),
        })
    artifact_root = Path(artifact_root).resolve()
    artifact_root.mkdir(parents=True, exist_ok=True)
    terminal_path = artifact_root / "budget-terminal-v1.json"
    require_no_terminal_budget_journal(
        terminal_path,
        "rescue_training",
        objective_hashes,
        {"stage", "resumable_model_step", "attempted_rescue_step"},
    )
    candidate_dir = "candidate-epoch%d" % epoch
    candidate_root = artifact_root / candidate_dir / "selected"
    resume_path = artifact_root / "resume.pt"
    progress_path = artifact_root / "progress-v1.json"
    replay_elapsed_floor = prior_rescue_seconds
    replayed_optimizer_steps = 0
    baseline_replay_receipt = None
    if replay_from_baseline:
        replay_elapsed_floor, replayed_optimizer_steps = validate_baseline_replay(
            progress_path,
            resume_path,
            objective_hashes,
            prior_rescue_seconds,
            artifact_root / "baseline-replay-v1.json",
        )
        baseline_replay_receipt = _file_artifact(
            artifact_root / "baseline-replay-v1.json"
        )
    elif resume:
        if not resume_path.is_file() or not progress_path.is_file():
            raise DistillationError("--resume requires resume.pt and progress-v1.json")
    elif resume_path.exists() or progress_path.exists():
        raise DistillationError(
            "existing rescue state requires explicit --resume or --replay-from-baseline"
        )
    verified = verify_dataset_inputs(dataset_root, dataset_manifest)
    del verified
    view_artifact = bundle["view_artifact"]
    rescue_phase_started = time.monotonic()
    torch, model, processor = load_runtime(baseline_checkpoint, Path(baseline_checkpoint) / "tokenizer.model")
    _set_determinism(torch, distillation_config["seed"] + epoch - 1)
    cache_root = Path(baseline_checkpoint).resolve().parent / "token-cache"
    datasets = {"train": {}, "validation": {}}
    for direction in ("zh-en", "en-zh"):
        if direction == "zh-en":
            train_artifact = dataset_manifest["outputs"]["zh-en.train.jsonl"]
            train_path = Path(dataset_root) / train_artifact["path"]
        else:
            train_artifact = view_artifact
            train_path = Path(rescue_view)
        datasets["train"][direction] = build_token_cache(
            cache_root,
            train_path,
            train_artifact,
            training_config["tokenizer"],
            processor,
            direction,
            "train" if direction == "zh-en" else "rescue-train",
            128,
        )
        validation_artifact = dataset_manifest["outputs"][direction + ".validation.jsonl"]
        datasets["validation"][direction] = build_token_cache(
            cache_root,
            Path(dataset_root) / validation_artifact["path"],
            validation_artifact,
            training_config["tokenizer"],
            processor,
            direction,
            "validation",
            128,
        )
    rescue = distillation_config["rescue_training"]
    model.train()
    model.gradient_checkpointing_enable()
    optimizer = torch.optim.AdamW(model.parameters(), lr=rescue["learning_rate"], weight_decay=rescue["weight_decay"])
    scaler = torch.amp.GradScaler("cuda")
    plan = alternating_batch_plan(
        {"zh-en": 90000, "en-zh": 90000},
        32,
        distillation_config["seed"],
        epoch - 1,
    )
    groups, dropped = rescue_accumulation_groups(plan, rescue["gradient_accumulation"])
    if len(groups) != 1406 or [item[0] for item in dropped] != ["zh-en", "en-zh"]:
        raise DistillationError("rescue accumulation boundary differs")
    evaluation_steps = set(rescue["evaluate_rescue_steps"] + [len(groups)])
    validation_history = []
    best_loss = epoch_baseline_loss
    best_step = None
    start_group = 0
    resumable_model_step = 0
    previous_elapsed = replay_elapsed_floor
    if resume:
        state = torch.load(resume_path, map_location="cpu", weights_only=False)
        start_group, previous_elapsed, validation_history, best_loss, best_step = restore_rescue_resume_state(
            torch,
            state,
            model,
            optimizer,
            scaler,
            len(groups),
            objective_hashes,
            epoch - 1,
            epoch_baseline_loss,
        )
        resumable_model_step = start_group
        elapsed_progress = _load_json(progress_path)
        if elapsed_progress.get("rescue_step", 0) < start_group:
            raise DistillationError("rescue elapsed journal is behind resume checkpoint")
        previous_elapsed = rescue_elapsed_floor(
            previous_elapsed, elapsed_progress, objective_hashes
        )
        if best_step is not None and not candidate_root.is_dir():
            raise DistillationError("rescue best metadata exists but candidate checkpoint is missing")
    torch.cuda.reset_peak_memory_stats()
    last_progress = _load_json(progress_path) if resume and progress_path.is_file() else None
    for rescue_step, group in enumerate(groups[start_group:], start_group + 1):
        optimizer.zero_grad(set_to_none=True)
        group_loss = 0.0
        for direction, indices in group:
            batch = _memmap_batch(torch, datasets["train"][direction], indices, torch.device("cuda"))
            loss, unused_logits = _forward_loss(torch, model, batch, rescue["label_smoothing"])
            del unused_logits
            scaler.scale(loss / rescue["gradient_accumulation"]).backward()
            group_loss += float(loss.detach().item()) / rescue["gradient_accumulation"]
        for optimizer_group in optimizer.param_groups:
            optimizer_group["lr"] = rescue["learning_rate"] * min(1.0, rescue_step / rescue["warmup_optimizer_steps"])
        scaler.unscale_(optimizer)
        torch.nn.utils.clip_grad_norm_(model.parameters(), 1.0)
        scaler.step(optimizer)
        scaler.update()
        elapsed = cumulative_rescue_elapsed(previous_elapsed, rescue_phase_started, time.monotonic())
        ledger = checked_rescue_budget_snapshot(
            distillation_config,
            teacher_generation_seconds,
            elapsed,
            terminal_path,
            objective_hashes,
            {
                "stage": "optimizer_step",
                "resumable_model_step": resumable_model_step,
                "attempted_rescue_step": rescue_step,
            },
        )
        if rescue_step in evaluation_steps:
            validation_loss = _evaluate_validation(
                torch, model, datasets["validation"], 32, rescue["label_smoothing"]
            )
            elapsed = cumulative_rescue_elapsed(previous_elapsed, rescue_phase_started, time.monotonic())
            ledger = checked_rescue_budget_snapshot(
                distillation_config,
                teacher_generation_seconds,
                elapsed,
                terminal_path,
                objective_hashes,
                {
                    "stage": "validation",
                    "resumable_model_step": resumable_model_step,
                    "attempted_rescue_step": rescue_step,
                },
            )
            validation_history.append({"rescue_step": rescue_step, "loss": validation_loss})
            try:
                _write_atomic_json(
                    artifact_root / "validation-history-v1.json", validation_history
                )
            except PermissionError:
                persist_terminal_budget_journal(
                    terminal_path,
                    "rescue_training",
                    elapsed,
                    objective_hashes,
                    {
                        "stage": "validation_history_journal",
                        "resumable_model_step": resumable_model_step,
                        "attempted_rescue_step": rescue_step,
                    },
                )
                raise
            if validation_loss < best_loss:
                best_loss = validation_loss
                best_step = rescue_step
                _save_selected_checkpoint(
                    model,
                    Path(baseline_checkpoint) / "tokenizer.model",
                    candidate_root,
                    rescue_step,
                    validation_loss,
                )
        last_progress = {
            "schema_version": 1,
            "rescue_step": rescue_step,
            "loss": group_loss,
            "learning_rate": optimizer.param_groups[0]["lr"],
            "rescue_gpu_seconds": elapsed,
            "cumulative_gpu_seconds": ledger["cumulativeActualSeconds"],
            "objective_hashes": objective_hashes,
        }
        try:
            _write_atomic_json(progress_path, last_progress)
        except PermissionError:
            persist_terminal_budget_journal(
                terminal_path,
                "rescue_training",
                elapsed,
                objective_hashes,
                {
                    "stage": "progress_journal",
                    "resumable_model_step": resumable_model_step,
                    "attempted_rescue_step": rescue_step,
                },
            )
            raise
        if rescue_step % 20 == 0:
            print(json.dumps(last_progress, sort_keys=True), flush=True)
        if rescue_step == 100 or rescue_step % 500 == 0:
            _save_rescue_resume(
                torch,
                resume_path,
                model,
                optimizer,
                scaler,
                rescue_step,
                rescue_step,
                elapsed,
                validation_history,
                best_loss,
                best_step,
                objective_hashes,
                epoch - 1,
            )
            resumable_model_step = rescue_step
    elapsed = cumulative_rescue_elapsed(previous_elapsed, rescue_phase_started, time.monotonic())
    ledger = checked_rescue_budget_snapshot(
        distillation_config,
        teacher_generation_seconds,
        elapsed,
        terminal_path,
        objective_hashes,
        {
            "stage": "finalization",
            "resumable_model_step": resumable_model_step,
            "attempted_rescue_step": len(groups),
        },
    )
    _save_rescue_resume(
        torch,
        resume_path,
        model,
        optimizer,
        scaler,
        len(groups),
        len(groups),
        elapsed,
        validation_history,
        best_loss,
        best_step,
        objective_hashes,
        epoch - 1,
    )
    candidate = None
    if best_step is not None:
        candidate = {
            "model_sha256": _sha256_file(candidate_root / "model.safetensors")[1],
            "tokenizer_sha256": _sha256_file(candidate_root / "tokenizer.model")[1],
        }
    report = {
        "schema_version": 1,
        "epoch": epoch,
        "seed": distillation_config["seed"] + epoch - 1,
        "plan_epoch_index": epoch - 1,
        "optimizer_reset": True,
        "rescue_steps": len(groups),
        "logical_batches": len(groups) * 4,
        "dropped_partial_logical_batches": len(dropped),
        "validation_history": validation_history,
        "baseline_validation_loss": epoch_baseline_loss,
        "best_rescue_step": best_step,
        "best_validation_loss": best_loss,
        "candidate_checkpoint": candidate_dir + "/selected" if best_step is not None else None,
        "candidate": candidate,
        "promotion_allowed": False,
        "promotion_status": "pending_manual_and_flores_gate",
        "resumed": bool(resume),
        "replayed_from_baseline": bool(replay_from_baseline),
        "replayed_optimizer_steps": replayed_optimizer_steps,
        "baseline_replay_receipt": baseline_replay_receipt,
        "teacher_generation_gpu_seconds": teacher_generation_seconds,
        "probe_gpu_seconds": probe_gpu_seconds,
        "rescue_gpu_seconds": elapsed,
        "epoch_gpu_seconds": elapsed - prior_rescue_seconds,
        "cumulative_gpu_seconds": ledger["cumulativeActualSeconds"],
        "gpuLedger": ledger,
        "training_view_manifest_sha256": _sha256_file(training_view_manifest)[1],
        "distillation_manifest_sha256": _sha256_file(distillation_manifest)[1],
        "peak_cuda_bytes": torch.cuda.max_memory_allocated(),
        "last_progress": last_progress,
        "objective_hashes": objective_hashes,
    }
    try:
        _write_atomic_json(artifact_root / "training-v1.json", report)
    except PermissionError:
        persist_terminal_budget_journal(
            terminal_path,
            "rescue_training",
            elapsed,
            objective_hashes,
            {
                "stage": "final_report",
                "resumable_model_step": len(groups),
                "attempted_rescue_step": len(groups),
            },
        )
        raise
    return report


def build_parser():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    train = commands.add_parser("train")
    train.add_argument("--distillation-config", required=True, type=Path)
    train.add_argument("--training-config", required=True, type=Path)
    train.add_argument("--dataset-manifest", required=True, type=Path)
    train.add_argument("--dataset-root", required=True, type=Path)
    train.add_argument("--rescue-view", required=True, type=Path)
    train.add_argument("--training-view-manifest", required=True, type=Path)
    train.add_argument("--distillation-manifest", required=True, type=Path)
    train.add_argument("--offline-verification-one", required=True, type=Path)
    train.add_argument("--offline-verification-two", required=True, type=Path)
    train.add_argument("--baseline-checkpoint", required=True, type=Path)
    train.add_argument("--artifact-root", required=True, type=Path)
    train.add_argument("--resume", action="store_true")
    train.add_argument("--epoch", type=int, choices=(1, 2), default=1)
    train.add_argument("--epoch1-gate-report", type=Path)
    train.add_argument("--epoch1-training-report", type=Path)
    train.add_argument("--epoch1-baseline-checkpoint", type=Path)
    train.add_argument("--replay-from-baseline", action="store_true")
    gate = commands.add_parser("gate")
    gate.add_argument("--distillation-config", required=True, type=Path)
    gate.add_argument("--evaluation-summary", required=True, type=Path)
    gate.add_argument("--candidate-checkpoint", required=True, type=Path)
    gate.add_argument("--manual-set", required=True, type=Path)
    gate.add_argument("--manual-results", required=True, type=Path)
    gate.add_argument("--training-report", required=True, type=Path)
    gate.add_argument("--flores-root", type=Path)
    gate.add_argument("--output", required=True, type=Path)
    return parser


def main(argv=None):
    args = build_parser().parse_args(argv)
    distillation_config = load_distillation_config(args.distillation_config)
    if args.command == "gate":
        candidate = {
            "model_sha256": _sha256_file(args.candidate_checkpoint / "model.safetensors")[1],
            "tokenizer_sha256": _sha256_file(args.candidate_checkpoint / "tokenizer.model")[1],
        }
        if candidate["tokenizer_sha256"] != distillation_config["student"]["tokenizer_sha256"]:
            raise DistillationError("gate candidate tokenizer differs from rescue contract")
        manual_rows = load_manual_set(args.manual_set)
        manual_size, manual_sha256 = _sha256_file(args.manual_set)
        manual_asset = {
            "path": args.manual_set.name,
            "rows": len(manual_rows),
            "bytes": manual_size,
            "sha256": manual_sha256,
        }
        manual_summary, manual_results = summarize_audited_manual_results(
            args.manual_results, manual_rows
        )
        training_report = _load_json(args.training_report)
        training_objective_hashes = (
            training_report.get("objective_hashes")
            if isinstance(training_report, dict)
            else None
        )
        if (
            not isinstance(training_report, dict)
            or training_report.get("schema_version") != 1
            or isinstance(training_report.get("epoch"), bool)
            or training_report.get("epoch") not in {1, 2}
            or training_report.get("candidate") != candidate
            or not isinstance(training_objective_hashes, dict)
            or not training_objective_hashes
        ):
            raise DistillationError("gate training report/candidate/objective differs")
        training_artifact = _file_artifact(args.training_report)
        flores_files = None
        if args.flores_root is not None:
            flores_files = []
            for language, relative in (
                ("cmn_Hans", FLORES_FILES["zh"]),
                ("eng_Latn", FLORES_FILES["en"]),
            ):
                size, digest = _sha256_file(args.flores_root / relative)
                flores_files.append({
                    "language": language,
                    "path": relative,
                    "bytes": size,
                    "sha256": digest,
                })
        report = evaluate_rescue_gates(
            distillation_config,
            _load_json(args.evaluation_summary),
            candidate,
            manual_asset,
            manual_results,
            manual_summary,
            training_artifact,
            training_objective_hashes,
            training_report["epoch"],
            flores_files,
        )
        args.output.parent.mkdir(parents=True, exist_ok=True)
        _write_atomic_json(args.output, report)
    else:
        report = run_rescue_epoch(
            distillation_config,
            load_training_config(args.training_config),
            _load_json(args.dataset_manifest),
            args.dataset_root,
            args.rescue_view,
            args.training_view_manifest,
            args.distillation_manifest,
            args.offline_verification_one,
            args.offline_verification_two,
            args.baseline_checkpoint,
            args.artifact_root,
            resume=args.resume,
            epoch=args.epoch,
            epoch1_gate_report=args.epoch1_gate_report,
            epoch1_training_report=args.epoch1_training_report,
            epoch1_baseline_checkpoint=args.epoch1_baseline_checkpoint,
            replay_from_baseline=args.replay_from_baseline,
        )
    print(json.dumps(report, sort_keys=True), flush=True)


if __name__ == "__main__":
    try:
        main()
    except (DistillationError, TrainingContractError) as error:
        raise SystemExit("error: %s" % error)
