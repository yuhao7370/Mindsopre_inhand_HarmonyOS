#!/usr/bin/env python3
"""Deterministically distill the pinned English-to-Chinese teacher into a Temp dataset."""

import argparse
import hashlib
import json
import math
import os
import re
import shutil
import time
import unicodedata
from pathlib import Path


TEACHER_REPO = "Helsinki-NLP/opus-mt-en-zh"
TEACHER_REVISION = "408d9bc410a388e1d9aef112a2daba955b945255"
TEACHER_PREFIX = ">>cmn_Hans<<"
MODEL_SHA256 = "69a1d6ec829cee349360b3b677ac0aa99a7d88822d1a6578370029efffdca3f5"
STUDENT_SHA256 = "a7603325361de12f35ebc660c861c648a1f7293b31174280b32bbea34d9f491a"
SOURCE_SHA256 = "20b908acd71a734f8252c383c5cd2f0bf476214809d0f64cfcc50c1cb5e5670e"
SOURCE_ROWS = 90000
CHUNK_ROWS = 512
HEX64 = re.compile(r"^[0-9a-f]{64}$")
LATIN = re.compile(r"[A-Za-z]")
URL = re.compile(r"https?://[A-Za-z0-9._~:/?#\[\]@!$&'()*+,;=%-]+", re.IGNORECASE)
NUMBER = re.compile(r"(?<![A-Za-z])\d+(?:[.,:/-]\d+)*(?![A-Za-z])")


class DistillationError(RuntimeError):
    pass


def _int(value, label, minimum=None):
    if isinstance(value, bool) or not isinstance(value, int) or (
        minimum is not None and value < minimum
    ):
        raise DistillationError("%s is invalid" % label)
    return value


def _number(value, label, minimum=None):
    if isinstance(value, bool) or not isinstance(value, (int, float)) or not math.isfinite(value) or (
        minimum is not None and value < minimum
    ):
        raise DistillationError("%s is invalid" % label)
    return float(value)


def _exact_keys(value, expected, label):
    if not isinstance(value, dict) or set(value) != set(expected):
        raise DistillationError("%s schema differs" % label)


def _load_json(path):
    try:
        return json.loads(Path(path).read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise DistillationError("cannot load %s: %s" % (Path(path).name, error)) from error


def canonical_json_bytes(value):
    return (json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":")) + "\n").encode("utf-8")


def _write_bytes_atomic(path, payload):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = Path(str(path) + ".partial")
    try:
        temporary.write_bytes(payload)
        os.replace(temporary, path)
    finally:
        temporary.unlink(missing_ok=True)


def _sha256_file(path):
    digest = hashlib.sha256()
    size = 0
    with Path(path).open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
            size += len(chunk)
    return size, digest.hexdigest()


def _portable_path(value, label):
    if (
        not isinstance(value, str)
        or not value
        or "\\" in value
        or Path(value).is_absolute()
        or any(part in {"", ".", ".."} for part in value.split("/"))
    ):
        raise DistillationError("%s is not portable" % label)
    return value


def load_distillation_config(path):
    config = _load_json(path)
    _exact_keys(
        config,
        {
            "schema_version", "seed", "teacher", "student", "data", "generation",
            "target_validation", "validationPolicy", "rescue_training", "budget", "epoch2_gate",
            "gpuLedger", "promotion_gate",
        },
        "distillation config",
    )
    _int(config["schema_version"], "schema_version", 1)
    _int(config["seed"], "seed", 1)
    if config["schema_version"] != 4 or config["seed"] != 20260713:
        raise DistillationError("v4 identity differs")
    expected_teacher = {
        "repo": TEACHER_REPO,
        "revision": TEACHER_REVISION,
        "license": "apache-2.0",
        "prefix": TEACHER_PREFIX,
    }
    if config["teacher"] != expected_teacher:
        raise DistillationError("teacher contract differs")
    expected_student = {
        "checkpoint_step": 16878,
        "model_sha256": STUDENT_SHA256,
        "tokenizer_sha256": "e5528a5c3685d08f8868902d31febeb763eea8519f9997f43b05964b02554640",
    }
    if config["student"] != expected_student:
        raise DistillationError("student contract differs")
    expected_data = {
        "repo": "Mxode/BiST",
        "revision": "aca6be897afc319f779009379c8b849c1eb8d63e",
        "source_file": "en-zh.train.jsonl",
        "source_rows": SOURCE_ROWS,
        "source_bytes": 36670761,
        "source_sha256": SOURCE_SHA256,
    }
    if config["data"] != expected_data:
        raise DistillationError("source data contract differs")
    expected_generation = {
        "precision": "fp16",
        "num_beams": 4,
        "do_sample": False,
        "renormalize_logits": True,
        "max_tokens": 128,
        "probe_rows": 128,
        "selected_batch": 64,
        "batch_candidates": [256, 128, 64, 32, 16, 8, 4, 2, 1],
    }
    if config["generation"] != expected_generation:
        raise DistillationError("generation contract differs")
    expected_target = {
        "student_decoder_max_tokens": 128,
        "reject_controls": True,
        "reject_degenerate_repetition": True,
        "latin_residue_diagnostic_only": True,
    }
    if config["target_validation"] != expected_target:
        raise DistillationError("target validation contract differs")
    expected_policy = {
        "teacherTargetValidation": "sourceTargetConservative",
        "originalFallbackValidation": "targetContractOnly",
        "originalPreservationWarnings": "sourceTargetConservativeAuditOnly",
        "hardFailDefinition": "teacherFailedAndOriginalTargetContractFailed",
        "rationale": "strict source-target regex can falsely reject valid dates and Chinese-number translations; original targets preserve the approved T2 corpus and warnings remain audit-only",
    }
    if config["validationPolicy"] != expected_policy:
        raise DistillationError("target provenance policy differs")
    expected_training = {
        "precision": "fp16", "device": "cuda", "microbatch_per_direction": 32,
        "physical_microbatch": 32, "gradient_accumulation": 4,
        "learning_rate": 0.00001, "weight_decay": 0.01, "label_smoothing": 0.1,
        "warmup_optimizer_steps": 100, "evaluate_rescue_steps": [500, 1000],
        "max_epochs": 2, "optimizer_reset": True,
    }
    if config["rescue_training"] != expected_training:
        raise DistillationError("rescue training contract differs")
    expected_budget = {
        "previous_gpu_seconds": 13924.157,
        "total_gpu_seconds": 43200,
        "rescue_reserve_seconds": 2400,
        "include_teacher_generation": True,
        "include_rescue_training": True,
    }
    if config["budget"] != expected_budget:
        raise DistillationError("cumulative budget contract differs")
    expected_ledger = {
        "measurement": "observed monotonic wall seconds for GPU probe calls plus retained teacher-load, warmup, failed-retry process wall",
        "probeEntries": [
            {"name": "initial-fp32-batch64", "seconds": 43.78100000001723},
            {"name": "precision-v1-fp16", "seconds": 20.68699999997625},
            {"name": "precision-v1-fp32", "seconds": 32.84299999999348},
            {"name": "capacity-fp16-batch256", "seconds": 58.90700000000652},
            {"name": "precision-v2-fp16", "seconds": 21.70299999997951},
            {"name": "precision-v2-fp32", "seconds": 54.96899999998277},
            {"name": "sorted-fp16-batch64", "seconds": 73.92200000002049},
            {"name": "sorted-fp16-batch128", "seconds": 83.70299999997951},
            {"name": "teacher-load-warmup-failed-retry-process-wall", "seconds": 287.385},
        ],
        "measuredProbeEntriesSeconds": 390.515,
        "observedTeacherLoadWarmupRetrySeconds": 287.385,
        "probeActualSeconds": 677.9,
    }
    if config["gpuLedger"] != expected_ledger:
        raise DistillationError("GPU probe/load ledger differs")
    expected_epoch2 = {"en-zh_min_passed": 33, "en-zh_max_fatal": 2, "zh-en_min_passed": 32}
    if config["epoch2_gate"] != expected_epoch2:
        raise DistillationError("epoch2 gate differs")
    expected_promotion = {
        "manual_min_passed_per_direction": 45, "manual_max_fatal_per_direction": 0,
        "flores_zh-en_bleu": 19.0, "flores_zh-en_chrf2": 49.0,
        "flores_en-zh_bleu": 17.0, "flores_en-zh_chrf2": 40.0,
    }
    if config["promotion_gate"] != expected_promotion:
        raise DistillationError("promotion gate differs")
    return config


def load_teacher_manifest(path):
    manifest = _load_json(path)
    _exact_keys(manifest, {"schema_version", "repo", "revision", "license", "repository_tree", "files"}, "teacher manifest")
    if (
        manifest["schema_version"] != 1
        or manifest["repo"] != TEACHER_REPO
        or manifest["revision"] != TEACHER_REVISION
        or manifest["license"] != "apache-2.0"
    ):
        raise DistillationError("teacher manifest identity differs")
    if not isinstance(manifest["repository_tree"], list) or len(set(manifest["repository_tree"])) != len(manifest["repository_tree"]):
        raise DistillationError("teacher repository tree is invalid")
    if not isinstance(manifest["files"], list) or not manifest["files"]:
        raise DistillationError("teacher files are empty")
    paths = []
    for item in manifest["files"]:
        _exact_keys(item, {"path", "bytes", "sha256"}, "teacher file")
        paths.append(_portable_path(item["path"], "teacher file"))
        _int(item["bytes"], "teacher file bytes", 1)
        if not isinstance(item["sha256"], str) or not HEX64.fullmatch(item["sha256"]):
            raise DistillationError("teacher file hash is invalid")
    if len(paths) != len(set(paths)) or paths != sorted(paths):
        raise DistillationError("teacher files are not unique lexical paths")
    weights = next((item for item in manifest["files"] if item["path"] == "pytorch_model.bin"), None)
    if weights != {"path": "pytorch_model.bin", "bytes": 312087009, "sha256": MODEL_SHA256}:
        raise DistillationError("teacher weights differ")
    return manifest


def verify_teacher_files(root, manifest):
    root = Path(root).resolve()
    files = manifest.get("files") if isinstance(manifest, dict) else None
    if not isinstance(files, list) or not files:
        raise DistillationError("teacher file manifest is invalid")
    verified = []
    expected_paths = set()
    for item in files:
        _exact_keys(item, {"path", "bytes", "sha256"}, "teacher file")
        relative = _portable_path(item["path"], "teacher file")
        expected_paths.add(relative)
        path = (root / relative).resolve()
        try:
            path.relative_to(root)
        except ValueError as error:
            raise DistillationError("teacher file leaves root") from error
        size, digest = _sha256_file(path)
        if size != item["bytes"] or digest != item["sha256"]:
            raise DistillationError("teacher file integrity failure: %s" % relative)
        verified.append(path)
    actual = {
        path.relative_to(root).as_posix()
        for path in root.iterdir()
        if path.is_file() and path.name not in {"download-v1.json", "probe-v1.json"}
    }
    if actual != expected_paths:
        raise DistillationError("teacher local inventory differs")
    return verified


def _degenerate_repetition(text):
    compact = "".join(text.split())
    for width in range(1, min(16, len(compact) // 4) + 1):
        unit = compact[:width]
        repeated = unit * (len(compact) // width)
        if len(repeated) >= 8 and compact.startswith(repeated) and len(repeated) / len(compact) >= 0.8:
            return True
    return False


def validate_teacher_target(text, student_processor, max_decoder_tokens=128):
    if not isinstance(text, str) or not text.strip():
        raise DistillationError("teacher target is empty")
    normalized = text.strip()
    if any(unicodedata.category(character) in {"Cc", "Cf"} for character in normalized):
        raise DistillationError("teacher target contains a control character")
    if _degenerate_repetition(normalized):
        raise DistillationError("teacher target is degenerate repetition")
    ids = list(student_processor.encode(normalized, out_type=int))
    if not ids or len(ids) + 1 > max_decoder_tokens:
        raise DistillationError("teacher target exceeds student decoder contract")
    return ids


def _matches(pattern, text):
    if pattern is NUMBER:
        text = re.sub(r"(?<=\d)\s*([.,:/-])\s*(?=\d)", r"\1", text)
    return sorted(match.rstrip(".,;!?)。；！？，）") for match in pattern.findall(text))


def corruption_evidence(source, target):
    return {
        "source_numbers": _matches(NUMBER, source),
        "target_numbers": _matches(NUMBER, target),
        "source_urls": _matches(URL, source),
        "target_urls": _matches(URL, target),
    }


def source_target_corruption_reasons(source, target):
    if not isinstance(source, str) or not isinstance(target, str):
        raise DistillationError("corruption inputs must be strings")
    reasons = []
    if _matches(NUMBER, source) != _matches(NUMBER, target):
        reasons.append("number")
    if _matches(URL, source) != _matches(URL, target):
        reasons.append("url")
    return reasons


def _source_hash(source):
    if not isinstance(source, str) or not source:
        raise DistillationError("source is empty")
    return hashlib.sha256(source.encode("utf-8")).hexdigest()


def build_output_row(index, source, target, student_processor, original_target=None):
    _int(index, "source index", 0)
    teacher_failure = None
    try:
        validate_teacher_target(target, student_processor)
        corruption = source_target_corruption_reasons(source, target)
        if corruption:
            teacher_failure = "teacher-conservative-gate:" + ",".join(corruption)
    except DistillationError as error:
        teacher_failure = "teacher-target-contract:" + str(error)
    if teacher_failure is None:
        selected_target = target.strip()
        origin = "teacher"
        reason = "teacher_passed_conservative_gate"
    else:
        if original_target is None:
            raise DistillationError(teacher_failure)
        try:
            validate_teacher_target(original_target, student_processor)
        except DistillationError as error:
            raise DistillationError("teacher and original targets failed: %s; %s" % (teacher_failure, error)) from error
        selected_target = original_target.strip()
        origin = "original_fallback"
        reason = teacher_failure
    return {
        "id": index,
        "source_sha256": _source_hash(source),
        "source": source,
        "target": selected_target,
        "direction_id": 32002,
        "target_origin": origin,
        "target_reason": reason,
    }


def write_chunk_atomic(path, rows):
    path = Path(path)
    if path.suffix != ".jsonl" or not isinstance(rows, list) or not rows:
        raise DistillationError("chunk contract is invalid")
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists():
        raise DistillationError("completed chunk cannot be overwritten")
    temporary = Path(str(path) + ".partial")
    try:
        with temporary.open("wb") as stream:
            for row in rows:
                stream.write(canonical_json_bytes(row))
        os.replace(temporary, path)
    finally:
        temporary.unlink(missing_ok=True)


def _read_source_rows(path, expected_rows=None):
    rows = []
    digest = hashlib.sha256()
    size = 0
    with Path(path).open("rb") as stream:
        for line_number, raw in enumerate(stream, 1):
            digest.update(raw)
            size += len(raw)
            if b"\r" in raw or not raw.endswith(b"\n"):
                raise DistillationError("source JSONL is not canonical at line %d" % line_number)
            try:
                row = json.loads(raw.decode("utf-8"))
            except (UnicodeDecodeError, json.JSONDecodeError) as error:
                raise DistillationError("source JSONL is invalid at line %d" % line_number) from error
            if not isinstance(row, dict) or set(row) != {"source", "target", "direction_id"} or row["direction_id"] != 32002:
                raise DistillationError("source row schema differs at line %d" % line_number)
            if not isinstance(row["source"], str) or not row["source"]:
                raise DistillationError("source text is empty at line %d" % line_number)
            rows.append(row)
    if expected_rows is not None and len(rows) != expected_rows:
        raise DistillationError("source row count differs")
    return rows, size, digest.hexdigest()


def verify_completed_chunks(source_path, chunk_root, student_processor, expected_source_rows=SOURCE_ROWS):
    sources, source_bytes, source_digest = _read_source_rows(source_path, expected_source_rows)
    chunk_root = Path(chunk_root)
    chunks = sorted(chunk_root.glob("*.jsonl")) if chunk_root.is_dir() else []
    expected_index = 0
    chunk_files = []
    latin_rows = 0
    teacher_accept_rows = 0
    for chunk in chunks:
        try:
            declared_start = int(chunk.stem)
        except ValueError as error:
            raise DistillationError("chunk name is not an integer cursor") from error
        if chunk.name != "%08d.jsonl" % declared_start or declared_start != expected_index:
            raise DistillationError("chunk cursor is not contiguous")
        chunk_count = 0
        with chunk.open("rb") as stream:
            for raw in stream:
                if b"\r" in raw or not raw.endswith(b"\n"):
                    raise DistillationError("chunk JSONL is not canonical")
                try:
                    row = json.loads(raw.decode("utf-8"))
                except (UnicodeDecodeError, json.JSONDecodeError) as error:
                    raise DistillationError("chunk JSONL is invalid") from error
                if not isinstance(row, dict) or set(row) != {"id", "source_sha256", "source", "target", "direction_id", "target_origin", "target_reason"}:
                    raise DistillationError("chunk row schema differs")
                if expected_index >= len(sources) or row["id"] != expected_index:
                    raise DistillationError("chunk row ID/order differs")
                source = sources[expected_index]["source"]
                if row["source"] != source or row["source_sha256"] != _source_hash(source) or row["direction_id"] != 32002:
                    raise DistillationError("chunk source identity differs")
                validate_teacher_target(row["target"], student_processor)
                if row["target_origin"] == "teacher":
                    if row["target_reason"] != "teacher_passed_conservative_gate" or source_target_corruption_reasons(source, row["target"]):
                        raise DistillationError("teacher-origin row fails conservative gate")
                    teacher_accept_rows += 1
                elif row["target_origin"] == "original_fallback":
                    if row["target"] != sources[expected_index]["target"] or not isinstance(row["target_reason"], str) or not row["target_reason"].startswith("teacher-"):
                        raise DistillationError("fallback row differs from original target")
                else:
                    raise DistillationError("target origin is invalid")
                latin_rows += bool(LATIN.search(row["target"]))
                expected_index += 1
                chunk_count += 1
        if not chunk_count:
            raise DistillationError("chunk is empty")
        size, digest = _sha256_file(chunk)
        chunk_files.append({"path": chunk.name, "rows": chunk_count, "bytes": size, "sha256": digest})
    return {
        "completed_rows": expected_index,
        "next_index": expected_index,
        "source_rows": len(sources),
        "source_bytes": source_bytes,
        "source_sha256": source_digest,
        "latin_residue_rows": latin_rows,
        "teacher_accept_rows": teacher_accept_rows,
        "chunks": chunk_files,
    }


def generation_budget_snapshot(config, generation_gpu_seconds):
    generation_gpu_seconds = _number(generation_gpu_seconds, "generation GPU seconds", 0)
    baseline = _number(config["budget"]["previous_gpu_seconds"], "baseline GPU seconds", 0)
    probes = _number(config["gpuLedger"]["probeActualSeconds"], "probe/load actual seconds", 0)
    reserve = _number(config["budget"]["rescue_reserve_seconds"], "rescue reserve seconds", 0)
    cumulative_actual = baseline + probes + generation_gpu_seconds
    cumulative_with_reserve = cumulative_actual + reserve
    total = _number(config["budget"]["total_gpu_seconds"], "total GPU seconds", 0)
    if cumulative_with_reserve > total:
        raise DistillationError("baseline + probes/load actual + generation actual + rescue reserve exceeds GPU budget")
    return {
        "baselineGpuSeconds": baseline,
        "probeAndLoadActualSeconds": probes,
        "generationActualSeconds": generation_gpu_seconds,
        "rescueReserveSeconds": reserve,
        "cumulativeActualSeconds": cumulative_actual,
        "cumulativeWithReserveSeconds": cumulative_with_reserve,
        "totalBudgetSeconds": total,
        "remainingAfterReserveSeconds": total - cumulative_with_reserve,
    }


def _validate_budget_terminal_fields(phase, measured_gpu_seconds, objective_hashes, cursor):
    if not isinstance(phase, str) or not phase:
        raise DistillationError("terminal budget phase differs")
    measured = _number(measured_gpu_seconds, "terminal measured GPU seconds", 0)
    if (
        not isinstance(objective_hashes, dict)
        or not objective_hashes
        or any(
            not isinstance(name, str)
            or not name
            or not isinstance(digest, str)
            or len(digest) != 64
            for name, digest in objective_hashes.items()
        )
        or not isinstance(cursor, dict)
        or not cursor
    ):
        raise DistillationError("terminal budget objective/cursor differs")
    return measured


def persist_terminal_budget_journal(
    path, phase, measured_gpu_seconds, objective_hashes, cursor
):
    measured = _validate_budget_terminal_fields(
        phase, measured_gpu_seconds, objective_hashes, cursor
    )
    payload = {
        "schema_version": 1,
        "phase": phase,
        "measured_gpu_seconds": measured,
        "objective_hashes": objective_hashes,
        "cursor": cursor,
    }
    _write_bytes_atomic(path, canonical_json_bytes(payload))
    return payload


def require_no_terminal_budget_journal(
    path, expected_phase, expected_objective_hashes, expected_cursor_keys
):
    path = Path(path)
    if not path.exists():
        return
    payload = _load_json(path)
    if (
        not isinstance(payload, dict)
        or set(payload) != {
            "schema_version", "phase", "measured_gpu_seconds", "objective_hashes", "cursor"
        }
        or payload["schema_version"] != 1
        or payload["phase"] != expected_phase
        or payload["objective_hashes"] != expected_objective_hashes
        or not isinstance(payload["cursor"], dict)
        or set(payload["cursor"]) != set(expected_cursor_keys)
        or path.read_bytes() != canonical_json_bytes(payload)
    ):
        raise DistillationError("terminal budget journal schema/objective differs")
    _validate_budget_terminal_fields(
        payload["phase"],
        payload["measured_gpu_seconds"],
        payload["objective_hashes"],
        payload["cursor"],
    )
    raise DistillationError("terminal GPU budget journal exists; resume is fail-closed")


def checked_generation_budget_snapshot(
    config, generation_gpu_seconds, terminal_path, objective_hashes, cursor
):
    try:
        return generation_budget_snapshot(config, generation_gpu_seconds)
    except DistillationError:
        persist_terminal_budget_journal(
            terminal_path,
            "teacher_generation",
            generation_gpu_seconds,
            objective_hashes,
            cursor,
        )
        raise


def _generation_progress_payload(config, verified, generation_gpu_seconds, wall_seconds, batch_size, prefix_ids):
    snapshot = generation_budget_snapshot(config, generation_gpu_seconds)
    completed = verified["completed_rows"]
    teacher = verified["teacher_accept_rows"]
    return {
        "schema_version": 1,
        "completed_rows": completed,
        "next_index": completed,
        "source_sha256": verified["source_sha256"],
        "generation_gpu_seconds": generation_gpu_seconds,
        "wall_seconds": _number(wall_seconds, "generation wall seconds", 0),
        "selected_batch": validate_generation_batch(config, batch_size),
        "teacher_prefix_ids": prefix_ids,
        "latin_residue_rows": verified["latin_residue_rows"],
        "teacher_accept_rows": teacher,
        "original_fallback_rows": completed - teacher,
        "hard_fail_rows": 0,
        "teacher_accept_ratio": teacher / completed if completed else 0.0,
        "cumulative_gpu_seconds": snapshot["cumulativeActualSeconds"],
        "cumulative_with_reserve_seconds": snapshot["cumulativeWithReserveSeconds"],
        "gpuLedger": snapshot,
    }


def reconcile_generation_progress(
    config,
    source_path,
    chunk_root,
    student_processor,
    progress_path,
    batch_size,
    expected_rows=SOURCE_ROWS,
):
    validate_generation_batch(config, batch_size)
    verified = verify_completed_chunks(source_path, chunk_root, student_processor, expected_rows)
    existing = {}
    if Path(progress_path).is_file():
        try:
            existing = _load_json(progress_path)
        except DistillationError as error:
            if verified["completed_rows"]:
                raise DistillationError(
                    "completed chunks exist but generation progress/timer is corrupt; refusing GPU-ledger rollback"
                ) from error
            existing = {}
    elif verified["completed_rows"]:
        raise DistillationError(
            "completed chunks exist but generation progress/timer is missing; refusing GPU-ledger rollback"
        )
    if not isinstance(existing, dict):
        if verified["completed_rows"]:
            raise DistillationError("completed chunks exist but generation progress/timer schema differs")
        existing = {}
    if "selected_batch" in existing and existing["selected_batch"] != batch_size:
        raise DistillationError("saved progress used a different generation batch")
    generation_seconds = _number(existing.get("generation_gpu_seconds", 0.0), "saved generation seconds", 0)
    if verified["completed_rows"] and (
        generation_seconds <= 0
        or existing.get("source_sha256") != verified["source_sha256"]
        or existing.get("teacher_prefix_ids") != [5]
    ):
        raise DistillationError("completed chunks are not bound to a trustworthy nonzero generation timer")
    wall_seconds = _number(existing.get("wall_seconds", generation_seconds), "saved wall seconds", 0)
    prefix_ids = existing.get("teacher_prefix_ids", [5])
    if prefix_ids != [5]:
        raise DistillationError("saved teacher prefix differs")
    rebuilt = _generation_progress_payload(
        config,
        verified,
        generation_seconds,
        max(wall_seconds, generation_seconds),
        batch_size,
        prefix_ids,
    )
    _write_bytes_atomic(progress_path, canonical_json_bytes(rebuilt))
    return rebuilt


def verify_final_audit_matches_chunks(
    source_path,
    chunk_root,
    final_path,
    student_processor,
    expected_rows=SOURCE_ROWS,
):
    verified = verify_completed_chunks(source_path, chunk_root, student_processor, expected_rows)
    if verified["completed_rows"] != expected_rows:
        raise DistillationError("completed chunk rows differ from full audit contract")
    try:
        final_stream = Path(final_path).open("rb")
    except OSError as error:
        raise DistillationError("full distilled audit is missing") from error
    with final_stream:
        for item in verified["chunks"]:
            with (Path(chunk_root) / item["path"]).open("rb") as chunk_stream:
                for block in iter(lambda: chunk_stream.read(1024 * 1024), b""):
                    if final_stream.read(len(block)) != block:
                        raise DistillationError("full distilled audit is not byte-identical to ordered chunks")
        if final_stream.read(1):
            raise DistillationError("full distilled audit has extra bytes after ordered chunks")
    size, digest = _sha256_file(final_path)
    return {
        "path": Path(final_path).name,
        "rows": expected_rows,
        "bytes": size,
        "sha256": digest,
    }


def select_probe_batch(candidates, attempt):
    if not isinstance(candidates, list) or not candidates:
        raise DistillationError("probe batch candidates are empty")
    attempts = []
    for batch in candidates:
        _int(batch, "probe batch", 1)
        try:
            metrics = attempt(batch)
        except RuntimeError as error:
            if "out of memory" not in str(error).lower():
                raise
            attempts.append({"batch_size": batch, "status": "oom"})
            continue
        attempts.append({"batch_size": batch, "status": "passed", **metrics})
        return {"selected_batch": batch, "attempts": attempts}
    raise DistillationError("every probe batch size exhausted CUDA memory")


def validate_generation_batch(config, batch_size):
    _int(batch_size, "generation batch", 1)
    if batch_size != config["generation"]["selected_batch"]:
        raise DistillationError("generation/resume batch must remain the selected batch 64")
    return batch_size


def materialize_training_view(audit_path, output_path, expected_rows=SOURCE_ROWS):
    output_path = Path(output_path)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    temporary = Path(str(output_path) + ".partial")
    counts = {"teacher": 0, "original_fallback": 0}
    rows = 0
    with Path(audit_path).open("rb") as source, temporary.open("wb") as destination:
        for raw in source:
            if b"\r" in raw or not raw.endswith(b"\n"):
                raise DistillationError("audit JSONL is not canonical")
            row = json.loads(raw.decode("utf-8"))
            if not isinstance(row, dict) or set(row) != {
                "id", "source_sha256", "source", "target", "direction_id", "target_origin", "target_reason"
            }:
                raise DistillationError("audit row schema differs")
            if row["id"] != rows or row["source_sha256"] != _source_hash(row["source"]) or row["direction_id"] != 32002:
                raise DistillationError("audit row identity/order differs")
            if row["target_origin"] not in counts:
                raise DistillationError("audit target origin differs")
            counts[row["target_origin"]] += 1
            destination.write(canonical_json_bytes({"direction_id": 32002, "source": row["source"], "target": row["target"]}))
            rows += 1
    if rows != expected_rows:
        temporary.unlink(missing_ok=True)
        raise DistillationError("audit row count differs")
    os.replace(temporary, output_path)
    size, digest = _sha256_file(output_path)
    return {"rows": rows, "bytes": size, "sha256": digest, **counts}


def build_training_view_manifest(audit_path, output_path, result):
    _exact_keys(result, {"rows", "bytes", "sha256", "teacher", "original_fallback"}, "training view result")
    rows = _int(result["rows"], "training view rows", 1)
    _int(result["bytes"], "training view bytes", 1)
    _int(result["teacher"], "training view teacher rows", 0)
    _int(result["original_fallback"], "training view fallback rows", 0)
    if result["teacher"] + result["original_fallback"] != rows:
        raise DistillationError("training view origin counts differ")
    audit_bytes, audit_sha256 = _sha256_file(audit_path)
    output_bytes, output_sha256 = _sha256_file(output_path)
    if output_bytes != result["bytes"] or output_sha256 != result["sha256"]:
        raise DistillationError("training view output differs from materialization result")
    return {
        "schema_version": 1,
        "audit": {
            "path": Path(audit_path).name,
            "rows": rows,
            "bytes": audit_bytes,
            "sha256": audit_sha256,
        },
        "output": {
            "path": Path(output_path).name,
            "rows": rows,
            "bytes": output_bytes,
            "sha256": output_sha256,
        },
        "target_origins": {
            "teacher": result["teacher"],
            "original_fallback": result["original_fallback"],
        },
    }


def _fallback_preservation_records(audit_path):
    records = []
    warning_counts = {"number": 0, "url": 0}
    expected_id = 0
    with Path(audit_path).open("rb") as source:
        for raw in source:
            if b"\r" in raw or not raw.endswith(b"\n"):
                raise DistillationError("audit JSONL is not canonical")
            try:
                row = json.loads(raw.decode("utf-8"))
            except (UnicodeDecodeError, json.JSONDecodeError) as error:
                raise DistillationError("audit JSONL is invalid") from error
            if not isinstance(row, dict) or set(row) != {
                "id", "source_sha256", "source", "target", "direction_id", "target_origin", "target_reason"
            }:
                raise DistillationError("audit row schema differs")
            if (
                row["id"] != expected_id
                or row["source_sha256"] != _source_hash(row["source"])
                or row["direction_id"] != 32002
            ):
                raise DistillationError("audit row identity/order differs")
            if row["target_origin"] == "original_fallback":
                warnings = source_target_corruption_reasons(row["source"], row["target"])
                for warning in warnings:
                    warning_counts[warning] += 1
                records.append({
                    "id": row["id"],
                    "source_sha256": row["source_sha256"],
                    "originalPreservationWarnings": warnings,
                })
            elif row["target_origin"] != "teacher":
                raise DistillationError("audit target origin differs")
            expected_id += 1
    return records, warning_counts


def _fallback_sidecar_result(sidecar_path, records, warning_counts):
    size, digest = _sha256_file(sidecar_path)
    return {
        "path": Path(sidecar_path).name,
        "rows": len(records),
        "bytes": size,
        "sha256": digest,
        "fallbackWithPreservationWarnings": sum(bool(row["originalPreservationWarnings"]) for row in records),
        "number": warning_counts["number"],
        "url": warning_counts["url"],
    }


def build_fallback_preservation_sidecar(audit_path, sidecar_path):
    records, warning_counts = _fallback_preservation_records(audit_path)
    sidecar_path = Path(sidecar_path)
    sidecar_path.parent.mkdir(parents=True, exist_ok=True)
    temporary = Path(str(sidecar_path) + ".partial")
    try:
        with temporary.open("wb") as destination:
            for row in records:
                destination.write(canonical_json_bytes(row))
        os.replace(temporary, sidecar_path)
    finally:
        temporary.unlink(missing_ok=True)
    return _fallback_sidecar_result(sidecar_path, records, warning_counts)


def verify_fallback_preservation_sidecar(audit_path, sidecar_path):
    records, warning_counts = _fallback_preservation_records(audit_path)
    expected = b"".join(canonical_json_bytes(row) for row in records)
    try:
        actual = Path(sidecar_path).read_bytes()
    except OSError as error:
        raise DistillationError("fallback preservation sidecar is missing") from error
    if actual != expected:
        raise DistillationError("fallback preservation sidecar differs")
    return _fallback_sidecar_result(sidecar_path, records, warning_counts)


def augment_distillation_manifest(config, audit_path, manifest_path, sidecar_path):
    manifest = _load_json(manifest_path)
    audit_bytes, audit_sha256 = _sha256_file(audit_path)
    output = manifest.get("output") if isinstance(manifest, dict) else None
    origins = manifest.get("target_origins") if isinstance(manifest, dict) else None
    if not isinstance(output, dict) or not isinstance(origins, dict):
        raise DistillationError("distillation manifest output/origins are missing")
    if output.get("bytes") != audit_bytes or output.get("sha256") != audit_sha256:
        raise DistillationError("distillation manifest output differs from audit")
    sidecar = verify_fallback_preservation_sidecar(audit_path, sidecar_path)
    if (
        origins.get("original_fallback") != sidecar["rows"]
        or origins.get("hard_fail") != 0
        or origins.get("teacher", -1) + sidecar["rows"] != output.get("rows")
    ):
        raise DistillationError("distillation target-origin totals differ")
    manifest["validationPolicy"] = config["validationPolicy"]
    manifest["fallbackPreservationWarnings"] = sidecar
    manifest["fullAudit"] = {
        "path": output["path"],
        "rows": output["rows"],
        "bytes": output["bytes"],
        "sha256": output["sha256"],
    }
    budget_snapshot = generation_budget_snapshot(config, manifest.get("generation_gpu_seconds", 0.0))
    manifest["gpuLedger"] = {
        "probeAndLoad": config["gpuLedger"],
        "budget": budget_snapshot,
    }
    manifest["cumulative_gpu_seconds"] = budget_snapshot["cumulativeActualSeconds"]
    manifest["cumulative_with_reserve_seconds"] = budget_snapshot["cumulativeWithReserveSeconds"]
    _write_bytes_atomic(manifest_path, canonical_json_bytes(manifest))
    return manifest


def validate_epoch2_gate(manual):
    try:
        return (
            isinstance(manual, dict)
            and set(manual) == {"zh-en", "en-zh"}
            and manual["en-zh"]["passed"] >= 33
            and manual["en-zh"]["fatal_corruptions"] <= 2
            and manual["zh-en"]["passed"] >= 32
        )
    except (KeyError, TypeError):
        return False


def rescue_accumulation_groups(plan, accumulation):
    _int(accumulation, "rescue accumulation", 1)
    groups = [plan[start:start + accumulation] for start in range(0, len(plan) - accumulation + 1, accumulation)]
    consumed = len(groups) * accumulation
    return groups, plan[consumed:]


def select_strict_rescue_best(baseline_loss, history):
    _number(baseline_loss, "baseline validation loss", 0)
    candidates = [(step, float(loss)) for step, loss in history if _number(loss, "rescue validation loss", 0) < baseline_loss]
    return min(candidates, key=lambda item: item[1]) if candidates else None


def download_teacher(manifest, destination):
    try:
        from huggingface_hub import HfApi, hf_hub_download
    except ImportError as error:
        raise DistillationError("teacher download requires pinned huggingface-hub") from error
    destination = Path(destination).resolve()
    destination.mkdir(parents=True, exist_ok=True)
    info = HfApi().model_info(TEACHER_REPO, revision=TEACHER_REVISION, files_metadata=True)
    if info.sha != TEACHER_REVISION or getattr(info.card_data, "license", None) != "apache-2.0":
        raise DistillationError("remote teacher identity/license differs")
    remote_tree = sorted(item.rfilename for item in info.siblings)
    if remote_tree != sorted(manifest["repository_tree"]):
        raise DistillationError("remote teacher repository tree differs")
    remote_weights = next(item for item in info.siblings if item.rfilename == "pytorch_model.bin")
    if remote_weights.size != 312087009 or remote_weights.lfs.sha256 != MODEL_SHA256:
        raise DistillationError("remote teacher weight metadata differs")
    for item in manifest["files"]:
        hf_hub_download(
            repo_id=TEACHER_REPO,
            revision=TEACHER_REVISION,
            filename=item["path"],
            local_dir=destination,
        )
    verified = verify_teacher_files(destination, manifest)
    result = {
        "schema_version": 1,
        "repo": TEACHER_REPO,
        "revision": TEACHER_REVISION,
        "license": "apache-2.0",
        "files": [
            {"path": path.relative_to(destination).as_posix(), "bytes": _sha256_file(path)[0], "sha256": _sha256_file(path)[1]}
            for path in verified
        ],
    }
    _write_bytes_atomic(destination / "download-v1.json", canonical_json_bytes(result))
    return result


def verify_student_tokenizer_file(tokenizer_model, expected_sha256):
    size, digest = _sha256_file(tokenizer_model)
    if not isinstance(expected_sha256, str) or not HEX64.fullmatch(expected_sha256) or digest != expected_sha256:
        raise DistillationError("student tokenizer file hash differs")
    return size, digest


def _load_student_processor(tokenizer_model, expected_sha256=None):
    if expected_sha256 is not None:
        verify_student_tokenizer_file(tokenizer_model, expected_sha256)
    try:
        import sentencepiece
    except ImportError as error:
        raise DistillationError("student validation requires sentencepiece") from error
    processor = sentencepiece.SentencePieceProcessor(model_file=str(tokenizer_model))
    if processor.get_piece_size() != 32000:
        raise DistillationError("student tokenizer vocabulary differs")
    return processor


def _load_teacher_runtime(teacher_root):
    try:
        import torch
        from transformers import MarianMTModel, MarianTokenizer
    except ImportError as error:
        raise DistillationError("teacher runtime dependencies are missing") from error
    if not torch.cuda.is_available():
        raise DistillationError("CUDA is unavailable")
    tokenizer = MarianTokenizer.from_pretrained(str(teacher_root), local_files_only=True)
    prefix_ids = tokenizer(TEACHER_PREFIX, add_special_tokens=False)["input_ids"]
    if not prefix_ids or tokenizer.unk_token_id in prefix_ids or TEACHER_PREFIX not in tokenizer.supported_language_codes:
        raise DistillationError("teacher tokenizer does not support the exact cmn_Hans prefix")
    model = MarianMTModel.from_pretrained(str(teacher_root), local_files_only=True).half().to("cuda").eval()
    return torch, model, tokenizer, prefix_ids


def _teacher_translate(torch, model, tokenizer, sources, batch_size, max_tokens=128, return_ids=False):
    outputs = []
    token_rows = []
    with torch.no_grad():
        for start in range(0, len(sources), batch_size):
            texts = [TEACHER_PREFIX + " " + value for value in sources[start:start + batch_size]]
            encoded = tokenizer(texts, return_tensors="pt", padding=True, truncation=False)
            if encoded["input_ids"].shape[1] > model.config.max_position_embeddings:
                raise DistillationError("teacher source exceeds model position contract")
            encoded = {name: value.to("cuda") for name, value in encoded.items()}
            generated = model.generate(
                **encoded,
                num_beams=4,
                do_sample=False,
                renormalize_logits=True,
                max_length=max_tokens,
                use_cache=True,
            )
            if not torch.isfinite(generated.float()).all().item():
                raise DistillationError("teacher generation returned non-finite token IDs")
            outputs.extend(tokenizer.batch_decode(generated, skip_special_tokens=True, clean_up_tokenization_spaces=True))
            if return_ids:
                token_rows.extend(generated.cpu().tolist())
    return (outputs, token_rows) if return_ids else outputs


def _teacher_source_order(tokenizer, sources):
    texts = [TEACHER_PREFIX + " " + value for value in sources]
    tokenized = tokenizer(texts, add_special_tokens=True, padding=False, truncation=False)["input_ids"]
    return sorted(range(len(sources)), key=lambda index: (len(tokenized[index]), index))


def _teacher_translate_sorted(torch, model, tokenizer, sources, batch_size, max_tokens=128, return_ids=False):
    order = _teacher_source_order(tokenizer, sources)
    sorted_sources = [sources[index] for index in order]
    translated = _teacher_translate(
        torch, model, tokenizer, sorted_sources, batch_size, max_tokens=max_tokens, return_ids=return_ids
    )
    if return_ids:
        sorted_outputs, sorted_ids = translated
    else:
        sorted_outputs, sorted_ids = translated, None
    outputs = [None] * len(sources)
    token_rows = [None] * len(sources) if return_ids else None
    for sorted_index, original_index in enumerate(order):
        outputs[original_index] = sorted_outputs[sorted_index]
        if return_ids:
            token_rows[original_index] = sorted_ids[sorted_index]
    return (outputs, token_rows) if return_ids else outputs


def run_throughput_probe(config, teacher_root, source_path, student_tokenizer, output_path):
    sources, source_bytes, source_digest = _read_source_rows(source_path, config["data"]["source_rows"])
    if source_bytes != config["data"]["source_bytes"] or source_digest != config["data"]["source_sha256"]:
        raise DistillationError("throughput probe source differs")
    selected = sources[:512]
    selected_sources = [row["source"] for row in selected]
    processor = _load_student_processor(student_tokenizer, config["student"]["tokenizer_sha256"])
    torch, model, tokenizer, prefix_ids = _load_teacher_runtime(teacher_root)
    _teacher_translate_sorted(torch, model, tokenizer, selected_sources[:16], 16)
    runs = {}
    generated = {}
    for batch_size in (64, 128):
        torch.cuda.empty_cache()
        torch.cuda.reset_peak_memory_stats()
        started = time.monotonic()
        outputs, token_rows = _teacher_translate_sorted(
            torch, model, tokenizer, selected_sources, batch_size, return_ids=True
        )
        elapsed = time.monotonic() - started
        rows = [
            build_output_row(index, source_row["source"], output, processor, source_row["target"])
            for index, (source_row, output) in enumerate(zip(selected, outputs))
        ]
        generated[batch_size] = token_rows
        runs[str(batch_size)] = {
            "rows": len(rows),
            "elapsed_seconds": elapsed,
            "rows_per_second": len(rows) / elapsed,
            "peak_cuda_bytes": torch.cuda.max_memory_allocated(),
            "teacher_accept": sum(row["target_origin"] == "teacher" for row in rows),
            "original_fallback": sum(row["target_origin"] == "original_fallback" for row in rows),
            "hard_fail": 0,
        }
    differing = [
        index
        for index, (left, right) in enumerate(zip(generated[64], generated[128]))
        if left != right
    ]
    fastest = max((64, 128), key=lambda value: runs[str(value)]["rows_per_second"])
    slower = 128 if fastest == 64 else 64
    gain = runs[str(fastest)]["rows_per_second"] / runs[str(slower)]["rows_per_second"] - 1.0
    selected_batch = fastest if gain >= 0.10 else 64
    selected_run = runs[str(selected_batch)]
    estimate = SOURCE_ROWS / selected_run["rows_per_second"]
    result = {
        "schema_version": 1,
        "rows": len(selected),
        "sort": "teacher_source_token_length_then_original_id_within_chunk",
        "output_order": "original_id",
        "teacher_prefix_ids": prefix_ids,
        "precision": "fp16",
        "runs": runs,
        "fastest_batch": fastest,
        "fastest_gain": gain,
        "selected_batch": selected_batch,
        "estimated_90000_seconds": estimate,
        "cumulative_with_rescue_reserve_seconds": config["budget"]["previous_gpu_seconds"] + estimate + config["budget"]["rescue_reserve_seconds"],
        "token_outputs_equal": not differing,
        "differing_token_rows": differing,
    }
    _write_bytes_atomic(output_path, canonical_json_bytes(result))
    return result


def run_probe(config, teacher_root, source_path, student_tokenizer, output_path):
    sources, source_bytes, source_digest = _read_source_rows(source_path, config["data"]["source_rows"])
    if source_bytes != config["data"]["source_bytes"] or source_digest != config["data"]["source_sha256"]:
        raise DistillationError("probe source artifact integrity differs")
    selected_sources = [row["source"] for row in sources[:config["generation"]["probe_rows"]]]
    processor = _load_student_processor(student_tokenizer, config["student"]["tokenizer_sha256"])
    torch, model, tokenizer, prefix_ids = _load_teacher_runtime(teacher_root)
    successful_outputs = []

    def attempt(batch_size):
        nonlocal successful_outputs
        torch.cuda.empty_cache()
        torch.cuda.reset_peak_memory_stats()
        started = time.monotonic()
        attempt_rows = max(config["generation"]["probe_rows"], batch_size)
        attempt_sources = [row["source"] for row in sources[:attempt_rows]]
        outputs = _teacher_translate(torch, model, tokenizer, attempt_sources, batch_size)
        elapsed = time.monotonic() - started
        for output in outputs:
            validate_teacher_target(output, processor)
        successful_outputs = outputs
        corruptions = [
            {"id": index, "reasons": source_target_corruption_reasons(source, output)}
            for index, (source, output) in enumerate(zip(attempt_sources, outputs))
            if source_target_corruption_reasons(source, output)
        ]
        return {
            "rows": len(outputs),
            "elapsed_seconds": elapsed,
            "rows_per_second": len(outputs) / elapsed,
            "peak_cuda_bytes": torch.cuda.max_memory_allocated(),
            "latin_residue_rows": sum(bool(LATIN.search(output)) for output in outputs),
            "fatal_corruptions": corruptions,
        }

    result = select_probe_batch(config["generation"]["batch_candidates"], attempt)
    passed = result["attempts"][-1]
    result.update(
        {
            "schema_version": 1,
            "teacher_prefix": TEACHER_PREFIX,
            "precision": "fp16",
            "teacher_prefix_ids": prefix_ids,
            "probe_rows": len(selected_sources),
            "samples": [
                {
                    "source": sources[index]["source"],
                    "reference": sources[index]["target"],
                    "teacher_output": successful_outputs[index],
                }
                for index in range(5)
            ],
            "estimated_90000_seconds": SOURCE_ROWS / passed["rows_per_second"],
            "cumulative_projected_seconds": config["budget"]["previous_gpu_seconds"] + SOURCE_ROWS / passed["rows_per_second"],
            "cumulative_with_rescue_reserve_seconds": config["budget"]["previous_gpu_seconds"] + SOURCE_ROWS / passed["rows_per_second"] + config["budget"]["rescue_reserve_seconds"],
            "quality_passed": not passed["fatal_corruptions"],
        }
    )
    _write_bytes_atomic(output_path, canonical_json_bytes(result))
    return result


def compare_teacher_precisions(config, teacher_root, source_path, student_tokenizer, output_path):
    try:
        import torch
        from transformers import MarianMTModel, MarianTokenizer
    except ImportError as error:
        raise DistillationError("teacher runtime dependencies are missing") from error
    if not torch.cuda.is_available():
        raise DistillationError("CUDA is unavailable")
    sources, source_bytes, source_digest = _read_source_rows(source_path, config["data"]["source_rows"])
    if source_bytes != config["data"]["source_bytes"] or source_digest != config["data"]["source_sha256"]:
        raise DistillationError("precision comparison source differs")
    selected = sources[:config["generation"]["probe_rows"]]
    texts = [row["source"] for row in selected]
    processor = _load_student_processor(student_tokenizer, config["student"]["tokenizer_sha256"])
    tokenizer = MarianTokenizer.from_pretrained(str(teacher_root), local_files_only=True)
    runs = {}
    generated = {}
    for precision in ("fp32", "fp16"):
        model = MarianMTModel.from_pretrained(str(teacher_root), local_files_only=True)
        if precision == "fp16":
            model = model.half()
        model = model.to("cuda").eval()
        torch.cuda.empty_cache()
        torch.cuda.reset_peak_memory_stats()
        started = time.monotonic()
        outputs, token_rows = _teacher_translate(torch, model, tokenizer, texts, 64, return_ids=True)
        elapsed = time.monotonic() - started
        for output in outputs:
            validate_teacher_target(output, processor)
        generated[precision] = {"outputs": outputs, "token_rows": token_rows}
        fatal_rows = []
        for index, (row, output) in enumerate(zip(selected, outputs)):
            reasons = source_target_corruption_reasons(row["source"], output)
            if reasons:
                fatal_rows.append(
                    {
                        "id": index,
                        "source": row["source"],
                        "original_target": row["target"],
                        "teacher_output": output,
                        "reasons": reasons,
                        "evidence": corruption_evidence(row["source"], output),
                    }
                )
        runs[precision] = {
            "rows": len(outputs),
            "elapsed_seconds": elapsed,
            "rows_per_second": len(outputs) / elapsed,
            "peak_cuda_bytes": torch.cuda.max_memory_allocated(),
            "token_sha256": hashlib.sha256(canonical_json_bytes(token_rows)).hexdigest(),
            "fatal_corruptions": fatal_rows,
        }
        del model
        torch.cuda.empty_cache()
    differing = [
        index for index, (left, right) in enumerate(zip(generated["fp32"]["token_rows"], generated["fp16"]["token_rows"]))
        if left != right
    ]
    fallback_rows = []
    for index, row in enumerate(selected):
        teacher_output = generated["fp16"]["outputs"][index]
        teacher_reasons = source_target_corruption_reasons(row["source"], teacher_output)
        try:
            validate_teacher_target(row["target"], processor)
            original_reasons = source_target_corruption_reasons(row["source"], row["target"])
        except DistillationError as error:
            original_reasons = ["target-contract:" + str(error)]
        if not teacher_reasons:
            origin = "teacher"
        elif not original_reasons:
            origin = "original_fallback"
        else:
            origin = "hard_fail"
        fallback_rows.append(
            {
                "id": index,
                "origin": origin,
                "teacher_reasons": teacher_reasons,
                "original_reasons": original_reasons,
            }
        )
    result = {
        "schema_version": 1,
        "rows": len(selected),
        "batch_size": 64,
        "finite_token_ids": True,
        "exact_token_rows": len(selected) - len(differing),
        "differing_token_rows": differing,
        "runs": runs,
        "fallback_analysis": {
            "teacher_accept": sum(row["origin"] == "teacher" for row in fallback_rows),
            "original_fallback": sum(row["origin"] == "original_fallback" for row in fallback_rows),
            "hard_fail": sum(row["origin"] == "hard_fail" for row in fallback_rows),
            "rows": fallback_rows,
        },
        "samples": [
            {
                "source": selected[index]["source"],
                "reference": selected[index]["target"],
                "fp32": generated["fp32"]["outputs"][index],
                "fp16": generated["fp16"]["outputs"][index],
            }
            for index in range(5)
        ],
    }
    _write_bytes_atomic(output_path, canonical_json_bytes(result))
    return result


def generate_targets(config, teacher_root, source_path, student_tokenizer, output_root, batch_size):
    validate_generation_batch(config, batch_size)
    output_root = Path(output_root).resolve()
    terminal_path = output_root / "budget-terminal-v1.json"
    objective_hashes = {
        "config": hashlib.sha256(canonical_json_bytes(config)).hexdigest(),
        "source": config["data"]["source_sha256"],
        "student_tokenizer": config["student"]["tokenizer_sha256"],
        "teacher_revision": hashlib.sha256(
            config["teacher"]["revision"].encode("utf-8")
        ).hexdigest(),
    }
    require_no_terminal_budget_journal(
        terminal_path,
        "teacher_generation",
        objective_hashes,
        {"completed_rows", "attempted_end"},
    )
    chunks = output_root / "chunks"
    chunks.mkdir(parents=True, exist_ok=True)
    processor = _load_student_processor(student_tokenizer, config["student"]["tokenizer_sha256"])
    progress_path = output_root / "progress-v1.json"
    progress = reconcile_generation_progress(
        config,
        source_path,
        chunks,
        processor,
        progress_path,
        batch_size,
        config["data"]["source_rows"],
    )
    sources, source_bytes, source_hash = _read_source_rows(source_path, config["data"]["source_rows"])
    if source_bytes != config["data"]["source_bytes"] or source_hash != config["data"]["source_sha256"]:
        raise DistillationError("generation source artifact differs")
    torch, model, tokenizer, prefix_ids = _load_teacher_runtime(teacher_root)
    if prefix_ids != [5] or progress["teacher_prefix_ids"] != prefix_ids:
        raise DistillationError("generation teacher prefix differs")
    started = time.monotonic()
    generation_seconds = progress["generation_gpu_seconds"]
    previous_wall_seconds = progress["wall_seconds"]
    next_index = progress["completed_rows"]
    while next_index < len(sources):
        end = min(next_index + CHUNK_ROWS, len(sources))
        checked_generation_budget_snapshot(
            config,
            generation_seconds,
            terminal_path,
            objective_hashes,
            {"completed_rows": next_index, "attempted_end": end},
        )
        chunk_sources = [row["source"] for row in sources[next_index:end]]
        batch_started = time.monotonic()
        outputs = _teacher_translate_sorted(torch, model, tokenizer, chunk_sources, batch_size)
        generation_seconds += time.monotonic() - batch_started
        wall_seconds = previous_wall_seconds + time.monotonic() - started
        checked_generation_budget_snapshot(
            config,
            generation_seconds,
            terminal_path,
            objective_hashes,
            {"completed_rows": next_index, "attempted_end": end},
        )
        inflight = _generation_progress_payload(
            config, progress, generation_seconds, wall_seconds, batch_size, prefix_ids
        )
        _write_bytes_atomic(progress_path, canonical_json_bytes(inflight))
        rows = []
        failures = []
        for offset, (source, target) in enumerate(zip(chunk_sources, outputs)):
            index = next_index + offset
            try:
                rows.append(build_output_row(index, source, target, processor, sources[index]["target"]))
            except DistillationError as error:
                failures.append({"id": index, "source_sha256": _source_hash(source), "error": str(error)})
        if failures:
            _write_bytes_atomic(
                output_root / "failures-v1.json",
                canonical_json_bytes({"schema_version": 1, "failures": failures}),
            )
            raise DistillationError("teacher target validation failed; failures-v1.json preserved")
        write_chunk_atomic(chunks / ("%08d.jsonl" % next_index), rows)
        next_index = end
        progress["completed_rows"] = next_index
        progress["next_index"] = next_index
        progress["teacher_accept_rows"] += sum(row["target_origin"] == "teacher" for row in rows)
        progress["latin_residue_rows"] += sum(bool(LATIN.search(row["target"])) for row in rows)
        teacher_ratio = progress["teacher_accept_rows"] / progress["completed_rows"]
        checkpoint = _generation_progress_payload(
            config, progress, generation_seconds, wall_seconds, batch_size, prefix_ids
        )
        _write_bytes_atomic(progress_path, canonical_json_bytes(checkpoint))
        progress = checkpoint
        print(json.dumps(checkpoint, sort_keys=True), flush=True)
        if progress["completed_rows"] >= CHUNK_ROWS and teacher_ratio < 0.80:
            raise DistillationError("cumulative teacher acceptance fell below 80 percent")
    final_path = output_root / "en-zh.distilled.train.jsonl"
    temporary = Path(str(final_path) + ".partial")
    with temporary.open("wb") as destination:
        final_progress = verify_completed_chunks(source_path, chunks, processor, config["data"]["source_rows"])
        for item in final_progress["chunks"]:
            chunk = chunks / item["path"]
            with chunk.open("rb") as source:
                shutil.copyfileobj(source, destination)
    os.replace(temporary, final_path)
    full_audit = verify_final_audit_matches_chunks(
        source_path, chunks, final_path, processor, config["data"]["source_rows"]
    )
    budget_snapshot = generation_budget_snapshot(config, generation_seconds)
    manifest = {
        "schema_version": 1,
        "teacher": {"repo": TEACHER_REPO, "revision": TEACHER_REVISION, "prefix": TEACHER_PREFIX},
        "source": {"path": "en-zh.train.jsonl", "rows": SOURCE_ROWS, "bytes": final_progress["source_bytes"], "sha256": final_progress["source_sha256"]},
        "output": full_audit,
        "fullAudit": full_audit,
        "chunks": final_progress["chunks"],
        "latin_residue_rows": final_progress["latin_residue_rows"],
        "target_origins": {
            "teacher": final_progress["teacher_accept_rows"],
            "original_fallback": SOURCE_ROWS - final_progress["teacher_accept_rows"],
            "hard_fail": 0,
        },
        "validationPolicy": config["validationPolicy"],
        "generation": {"precision": "fp16", "num_beams": 4, "do_sample": False, "renormalize_logits": True, "max_tokens": 128, "batch_size": batch_size},
        "generation_gpu_seconds": generation_seconds,
        "cumulative_gpu_seconds": budget_snapshot["cumulativeActualSeconds"],
        "cumulative_with_reserve_seconds": budget_snapshot["cumulativeWithReserveSeconds"],
        "gpuLedger": {"probeAndLoad": config["gpuLedger"], "budget": budget_snapshot},
    }
    _write_bytes_atomic(output_root / "distillation-manifest-v1.json", canonical_json_bytes(manifest))
    return manifest


def verify_distillation(config, source_path, student_tokenizer, output_root):
    output_root = Path(output_root).resolve()
    processor = _load_student_processor(student_tokenizer, config["student"]["tokenizer_sha256"])
    progress = verify_completed_chunks(source_path, output_root / "chunks", processor, config["data"]["source_rows"])
    manifest = _load_json(output_root / "distillation-manifest-v1.json")
    expected_manifest_keys = {
        "schema_version", "teacher", "source", "output", "fullAudit", "chunks",
        "latin_residue_rows", "target_origins", "validationPolicy", "generation",
        "generation_gpu_seconds", "cumulative_gpu_seconds", "cumulative_with_reserve_seconds",
        "gpuLedger", "fallbackPreservationWarnings",
    }
    if (
        not isinstance(manifest, dict)
        or set(manifest) != expected_manifest_keys
        or not isinstance(manifest.get("output"), dict)
    ):
        raise DistillationError("offline distillation manifest schema differs")
    output_relative = _portable_path(manifest["output"].get("path"), "distilled output")
    final_path = (output_root / output_relative).resolve()
    try:
        final_path.relative_to(output_root)
    except ValueError as error:
        raise DistillationError("distilled output leaves output root") from error
    sidecar_path = output_root / "fallback-preservation-warnings-v1.jsonl"
    full_audit = verify_final_audit_matches_chunks(
        source_path,
        output_root / "chunks",
        final_path,
        processor,
        config["data"]["source_rows"],
    )
    sidecar = verify_fallback_preservation_sidecar(final_path, sidecar_path)
    budget_snapshot = generation_budget_snapshot(config, manifest.get("generation_gpu_seconds"))
    if (
        progress["completed_rows"] != SOURCE_ROWS
        or progress["source_sha256"] != config["data"]["source_sha256"]
        or manifest.get("schema_version") != 1
        or manifest.get("teacher") != {"repo": TEACHER_REPO, "revision": TEACHER_REVISION, "prefix": TEACHER_PREFIX}
        or manifest.get("source") != {
            "path": config["data"]["source_file"],
            "rows": config["data"]["source_rows"],
            "bytes": config["data"]["source_bytes"],
            "sha256": config["data"]["source_sha256"],
        }
        or manifest["output"] != full_audit
        or manifest.get("fullAudit") != full_audit
        or progress["chunks"] != manifest["chunks"]
        or manifest.get("latin_residue_rows") != progress["latin_residue_rows"]
        or manifest.get("validationPolicy") != config["validationPolicy"]
        or manifest.get("fallbackPreservationWarnings") != sidecar
        or manifest.get("target_origins", {}).get("teacher") != progress["teacher_accept_rows"]
        or manifest.get("target_origins", {}).get("original_fallback") != sidecar["rows"]
        or manifest.get("target_origins", {}).get("hard_fail") != 0
        or manifest.get("generation") != {
            "precision": "fp16", "num_beams": 4, "do_sample": False,
            "renormalize_logits": True, "max_tokens": 128, "batch_size": 64,
        }
        or manifest.get("gpuLedger") != {"probeAndLoad": config["gpuLedger"], "budget": budget_snapshot}
        or manifest.get("cumulative_gpu_seconds") != budget_snapshot["cumulativeActualSeconds"]
        or manifest.get("cumulative_with_reserve_seconds") != budget_snapshot["cumulativeWithReserveSeconds"]
    ):
        raise DistillationError("offline distillation verification differs")
    return {
        "schema_version": 1,
        "verified": True,
        "rows": SOURCE_ROWS,
        "output_bytes": full_audit["bytes"],
        "output_sha256": full_audit["sha256"],
        "network_calls": 0,
        "gpuLedger": budget_snapshot,
        "manifest_sha256": _sha256_file(output_root / "distillation-manifest-v1.json")[1],
        "student_tokenizer_sha256": config["student"]["tokenizer_sha256"],
    }


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)
    common = argparse.ArgumentParser(add_help=False)
    common.add_argument("--config", required=True, type=Path)
    common.add_argument("--teacher-manifest", required=True, type=Path)
    download = subparsers.add_parser("download", parents=[common])
    download.add_argument("--teacher-root", required=True, type=Path)
    probe = subparsers.add_parser("probe", parents=[common])
    probe.add_argument("--teacher-root", required=True, type=Path)
    probe.add_argument("--source", required=True, type=Path)
    probe.add_argument("--student-tokenizer", required=True, type=Path)
    probe.add_argument("--output", required=True, type=Path)
    compare = subparsers.add_parser("compare-precision", parents=[common])
    compare.add_argument("--teacher-root", required=True, type=Path)
    compare.add_argument("--source", required=True, type=Path)
    compare.add_argument("--student-tokenizer", required=True, type=Path)
    compare.add_argument("--output", required=True, type=Path)
    throughput = subparsers.add_parser("throughput-probe", parents=[common])
    throughput.add_argument("--teacher-root", required=True, type=Path)
    throughput.add_argument("--source", required=True, type=Path)
    throughput.add_argument("--student-tokenizer", required=True, type=Path)
    throughput.add_argument("--output", required=True, type=Path)
    generate = subparsers.add_parser("generate", parents=[common])
    generate.add_argument("--teacher-root", required=True, type=Path)
    generate.add_argument("--source", required=True, type=Path)
    generate.add_argument("--student-tokenizer", required=True, type=Path)
    generate.add_argument("--output-root", required=True, type=Path)
    generate.add_argument("--batch-size", required=True, type=int)
    verify = subparsers.add_parser("verify", parents=[common])
    verify.add_argument("--source", required=True, type=Path)
    verify.add_argument("--student-tokenizer", required=True, type=Path)
    verify.add_argument("--output-root", required=True, type=Path)
    verify.add_argument("--output", required=True, type=Path)
    materialize = subparsers.add_parser("materialize-view", parents=[common])
    materialize.add_argument("--audit", required=True, type=Path)
    materialize.add_argument("--output", required=True, type=Path)
    finalize = subparsers.add_parser("finalize-provenance", parents=[common])
    finalize.add_argument("--audit", required=True, type=Path)
    finalize.add_argument("--source", required=True, type=Path)
    finalize.add_argument("--student-tokenizer", required=True, type=Path)
    finalize.add_argument("--output-root", required=True, type=Path)
    args = parser.parse_args(argv)
    config = load_distillation_config(args.config)
    manifest = load_teacher_manifest(args.teacher_manifest)
    if args.command == "download":
        result = download_teacher(manifest, args.teacher_root)
    else:
        verify_teacher_files(args.teacher_root, manifest) if hasattr(args, "teacher_root") else None
        if args.command == "probe":
            result = run_probe(config, args.teacher_root, args.source, args.student_tokenizer, args.output)
        elif args.command == "compare-precision":
            result = compare_teacher_precisions(config, args.teacher_root, args.source, args.student_tokenizer, args.output)
        elif args.command == "throughput-probe":
            result = run_throughput_probe(config, args.teacher_root, args.source, args.student_tokenizer, args.output)
        elif args.command == "generate":
            result = generate_targets(config, args.teacher_root, args.source, args.student_tokenizer, args.output_root, args.batch_size)
        elif args.command == "materialize-view":
            result = materialize_training_view(args.audit, args.output, config["data"]["source_rows"])
            view_manifest = build_training_view_manifest(args.audit, args.output, result)
            _write_bytes_atomic(
                args.output.parent / "training-view-manifest-v1.json",
                canonical_json_bytes(view_manifest),
            )
        elif args.command == "finalize-provenance":
            args.output_root.mkdir(parents=True, exist_ok=True)
            processor = _load_student_processor(
                args.student_tokenizer, config["student"]["tokenizer_sha256"]
            )
            reconcile_generation_progress(
                config,
                args.source,
                args.output_root / "chunks",
                processor,
                args.output_root / "progress-v1.json",
                config["generation"]["selected_batch"],
                config["data"]["source_rows"],
            )
            verify_final_audit_matches_chunks(
                args.source,
                args.output_root / "chunks",
                args.audit,
                processor,
                config["data"]["source_rows"],
            )
            sidecar_path = args.output_root / "fallback-preservation-warnings-v1.jsonl"
            build_fallback_preservation_sidecar(args.audit, sidecar_path)
            result = augment_distillation_manifest(
                config,
                args.audit,
                args.output_root / "distillation-manifest-v1.json",
                sidecar_path,
            )
        else:
            result = verify_distillation(config, args.source, args.student_tokenizer, args.output_root)
            args.output.parent.mkdir(parents=True, exist_ok=True)
            _write_bytes_atomic(args.output, canonical_json_bytes(result))
    print(json.dumps(result, ensure_ascii=False, sort_keys=True), flush=True)


if __name__ == "__main__":
    try:
        main()
    except DistillationError as error:
        raise SystemExit("error: %s" % error)
