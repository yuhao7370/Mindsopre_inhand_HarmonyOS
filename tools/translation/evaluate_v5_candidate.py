"""Fail-closed quality evaluation for the selected V5 BiST continuation candidate."""

import argparse
import hashlib
import json
import math
import os
import platform
import time
from pathlib import Path

from tools.translation.diagnose_translation import load_bist_rows, load_budget_evidence
from tools.translation.evaluate_translation import (
    corpus_metrics,
    corruption_reasons,
    load_manual_set,
    load_runtime,
    translate_texts,
)
from tools.translation.train_bidirectional import verify_dataset_inputs


EVALUATION_IDENTITY = "v5-final-candidate"
EVALUATION_STAGE = "translation_v5_candidate_quality_evaluation"
TOTAL_GPU_BUDGET_SECONDS = 43200.0
EXPECTED_V5_TERMINAL = {
    "path": "v5-terminal-v1.json",
    "bytes": 7020,
    "sha256": "61f9554923cbc617d813d3c0b7128d44456e703bd3e1806978810cd1fa5ebd13",
}
EXPECTED_V5_BUDGET = {
    "path": "budget-terminal-v1.json",
    "bytes": 578,
    "sha256": "96d4c9baca530799b1c1a6ce026efdca320c28ff9b6f7873fce05eeab7ed1a7d",
}
EXPECTED_DATASET_MANIFEST = {
    "path": "run1-manifest.json",
    "bytes": 6565,
    "sha256": "6776016325cc0a42653aa964acb30d577c9aa05fe08bfc695d691ccfb1a738a6",
}
EXPECTED_MANUAL = {
    "path": "manual-eval-v1.jsonl",
    "bytes": 15433,
    "sha256": "0b8d0393eb46128065a05d6fdb38fa660828c85ca435980f74e59a91efea2ca1",
}
EXPECTED_TRAINING_CONFIG = {
    "path": "training-run-v3.json",
    "bytes": 1635,
    "sha256": "43fd95c607fadf33b04d6eaae3a54d3cc8de0be56e2dec729cadd78ebe88f5db",
}
EXPECTED_SUPPORTING_EVIDENCE = {
    (650, "7ebfebc0f39a5af8b5f0b4973874579244e61c68921cb77181f5353a7ef3a257"),
    (584, "2996575f8100857820d92a4874989c561211ac2a68c617b7d287ceff28307675"),
    (596, "4dc8803c2f81855224883627dc06f734ed6b48a31c99fe21aa2bc525a0d33bc3"),
    (668, "edda591abc9943f0f0b65eda34487ec6e8abd5a7310a29a5b694da6c38dd639f"),
    (2382, "5ab469aca6d5f147e3dcdc1dc3a0ddbe198ed00b128b62aacdcaf34415e591c5"),
}
EXPECTED_DEPENDENCIES = {
    "diagnose_translation.py": "3c1cfcf1dcce535b4c1c483e5ccd8518ebe1452fd3069ae68ed4bc09fcf30590",
    "distill_en_zh.py": "cb2f27ea5089317745e71cd6f28f70e14bc2f447253a4205ac02f96773628910",
    "evaluate_translation.py": "87d5f0c04f37efd5050bc6cb16e227bc34ebb5784afad8db8edb26b7ef95dc40",
    "requirements-t3.lock.txt": "28f1214f4e830efc85601ad38d3337aa5b034ffbbd128e3cccea6024ee8a9060",
    "train_bidirectional.py": "a0c69b229a6d2f8bb52a3cf014e2e8275d2d3631a06843f33c038260a41ff419",
}


class CandidateEvaluationError(RuntimeError):
    pass


def _artifact(path, logical_path=None):
    path = Path(path)
    digest = hashlib.sha256()
    size = 0
    try:
        with path.open("rb") as stream:
            for chunk in iter(lambda: stream.read(1024 * 1024), b""):
                digest.update(chunk)
                size += len(chunk)
    except OSError as error:
        raise CandidateEvaluationError("cannot hash evaluation artifact") from error
    return {
        "path": logical_path if logical_path is not None else path.name,
        "bytes": size,
        "sha256": digest.hexdigest(),
    }


def _canonical_bytes(value):
    return (
        json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":")) + "\n"
    ).encode("utf-8")


def _write_json(path, value):
    Path(path).write_bytes(_canonical_bytes(value))


def _write_jsonl(path, rows):
    with Path(path).open("wb") as stream:
        for row in rows:
            stream.write(_canonical_bytes(row))


def _canonical_load(path, label):
    try:
        raw = Path(path).read_bytes()
        value = json.loads(raw.decode("utf-8"))
    except (OSError, UnicodeDecodeError, json.JSONDecodeError) as error:
        raise CandidateEvaluationError("cannot read %s" % label) from error
    if raw != _canonical_bytes(value):
        raise CandidateEvaluationError("%s is not canonical JSON" % label)
    return value


def _json_load(path, label):
    try:
        return json.loads(Path(path).read_text(encoding="utf-8"))
    except (OSError, UnicodeDecodeError, json.JSONDecodeError) as error:
        raise CandidateEvaluationError("cannot read %s" % label) from error


def _require_artifact(path, expected, label):
    actual = _artifact(path)
    if actual != expected:
        raise CandidateEvaluationError("%s artifact differs" % label)
    return actual


def _valid_artifact(value):
    return (
        isinstance(value, dict)
        and set(value) == {"path", "bytes", "sha256"}
        and isinstance(value["path"], str)
        and bool(value["path"])
        and isinstance(value["bytes"], int)
        and not isinstance(value["bytes"], bool)
        and value["bytes"] >= 0
        and isinstance(value["sha256"], str)
        and len(value["sha256"]) == 64
    )


def validate_v5_binding(terminal_path, budget_path):
    terminal_path = Path(terminal_path).resolve()
    budget_path = Path(budget_path).resolve()
    if terminal_path.parent != budget_path.parent:
        raise CandidateEvaluationError("V5 terminal and budget must share one artifact root")
    terminal_artifact = _require_artifact(
        terminal_path, EXPECTED_V5_TERMINAL, "V5 terminal"
    )
    budget_artifact = _require_artifact(budget_path, EXPECTED_V5_BUDGET, "V5 budget")
    terminal = _canonical_load(terminal_path, "V5 terminal")
    budget = _canonical_load(budget_path, "V5 budget")
    candidate = terminal.get("candidate") if isinstance(terminal, dict) else None
    checkpoint_contract = candidate.get("checkpoint") if isinstance(candidate, dict) else None
    if (
        terminal.get("schema_version") != 1
        or terminal.get("stage") != "translation_v5_original_bist_continuation"
        or terminal.get("status") != "completed"
        or terminal.get("error") is not None
        or terminal.get("finalGlobalStep") != 18284
        or terminal.get("adamWStep") != 18279
        or terminal.get("skippedOptimizerUpdates") != 2
        or terminal.get("budgetReceipt") != budget_artifact
        or not isinstance(candidate, dict)
        or candidate.get("globalStep") != 18284
        or candidate.get("adamWStep") != 18279
        or candidate.get("skippedUpdates") != 2
        or not isinstance(checkpoint_contract, dict)
        or checkpoint_contract.get("path") != "checkpoint"
        or not isinstance(checkpoint_contract.get("files"), dict)
        or budget.get("schema_version") != 1
        or budget.get("stage") != "translation_v5_original_bist_continuation"
        or budget.get("status") != "completed"
        or budget.get("error") is not None
        or budget.get("cumulativeActualSeconds") != 28924.02908489965
        or budget.get("totalBudgetSeconds") != TOTAL_GPU_BUDGET_SECONDS
        or budget.get("remainingSeconds") != 14275.970915100352
    ):
        raise CandidateEvaluationError("V5 terminal/budget semantic contract differs")
    expected_names = {
        "base_revision.txt", "config.json", "generation_config.json",
        "model.safetensors", "selection.json", "tokenizer.model",
    }
    files = checkpoint_contract["files"]
    if set(files) != expected_names:
        raise CandidateEvaluationError("V5 checkpoint inventory differs")
    checkpoint = terminal_path.parent / "candidate-step-18284" / "checkpoint"
    if not checkpoint.is_dir() or {item.name for item in checkpoint.iterdir()} != expected_names:
        raise CandidateEvaluationError("V5 checkpoint directory differs")
    for name in sorted(expected_names):
        if not _valid_artifact(files[name]) or files[name]["path"] != name:
            raise CandidateEvaluationError("V5 checkpoint contract differs")
        if _artifact(checkpoint / name) != files[name]:
            raise CandidateEvaluationError("V5 checkpoint artifact differs: %s" % name)
    selection = _canonical_load(checkpoint / "selection.json", "V5 candidate selection")
    if (
        selection.get("schema_version") != 1
        or selection.get("optimizer_step") != 18284
        or selection.get("adamw_step") != 18279
        or selection.get("skipped_optimizer_updates") != 2
        or selection.get("optimizer_independent") is not True
        or selection.get("vocab_size") != 32003
    ):
        raise CandidateEvaluationError("V5 candidate selection differs")
    return {
        "terminal": terminal,
        "terminalArtifact": terminal_artifact,
        "budget": budget,
        "budgetArtifact": budget_artifact,
        "checkpoint": checkpoint.resolve(),
        "checkpointFiles": files,
        "selection": selection,
    }


def build_manual_results(manual_rows, translations):
    if len(manual_rows) != len(translations):
        raise CandidateEvaluationError("manual result count differs")
    results = []
    for row, output in zip(manual_rows, translations):
        if not isinstance(output, str) or not output:
            raise CandidateEvaluationError("manual translation is empty")
        results.append({
            "id": row["id"],
            "direction": row["direction"],
            "source": row["source"],
            "reference": row["reference"],
            "categories": row["categories"],
            "output": output,
            "automatic_corruption_flags": corruption_reasons(
                row["source"], output, row["reference"]
            ),
        })
    return results


def build_budget_receipt(prior, elapsed, status, error):
    if (
        not isinstance(prior, dict)
        or not _valid_artifact(prior.get("artifact"))
        or not _valid_artifact(prior.get("rootEvidence"))
        or status not in {"completed", "failed"}
        or isinstance(elapsed, bool)
        or not isinstance(elapsed, (int, float))
        or not math.isfinite(elapsed)
        or elapsed < 0
        or (status == "completed" and error is not None)
        or (status == "failed" and (not isinstance(error, str) or not error))
    ):
        raise CandidateEvaluationError("evaluation budget receipt inputs differ")
    previous = float(prior["cumulativeActualSeconds"])
    total = float(prior["totalBudgetSeconds"])
    cumulative = previous + float(elapsed)
    remaining = total - cumulative
    if total != TOTAL_GPU_BUDGET_SECONDS or remaining < 0:
        raise CandidateEvaluationError("evaluation GPU budget is exhausted")
    return {
        "schema_version": 1,
        "stage": EVALUATION_STAGE,
        "status": status,
        "priorEvidence": prior["artifact"],
        "rootEvidence": prior["rootEvidence"],
        "priorCumulativeSeconds": previous,
        "evaluationActualSeconds": float(elapsed),
        "cumulativeActualSeconds": cumulative,
        "totalBudgetSeconds": total,
        "remainingSeconds": remaining,
        "error": error,
    }


def evaluation_budget_guard(prior, started, now=time.perf_counter):
    if not isinstance(prior, dict) or isinstance(started, bool) or not isinstance(
        started, (int, float)
    ):
        raise CandidateEvaluationError("evaluation budget guard inputs differ")
    elapsed = float(now()) - float(started)
    remaining = float(prior["totalBudgetSeconds"]) - float(
        prior["cumulativeActualSeconds"]
    )
    if not math.isfinite(elapsed) or elapsed < 0 or remaining < 0 or elapsed > remaining:
        raise CandidateEvaluationError("evaluation GPU budget exceeded during decode")
    return elapsed


def build_budget_overrun_terminal(prior, elapsed, error):
    if (
        not isinstance(prior, dict)
        or not _valid_artifact(prior.get("artifact"))
        or not _valid_artifact(prior.get("rootEvidence"))
        or isinstance(elapsed, bool)
        or not isinstance(elapsed, (int, float))
        or not math.isfinite(elapsed)
        or elapsed < 0
        or not isinstance(error, str)
        or not error
    ):
        raise CandidateEvaluationError("budget overrun terminal inputs differ")
    previous = float(prior["cumulativeActualSeconds"])
    total = float(prior["totalBudgetSeconds"])
    cumulative = previous + float(elapsed)
    remaining = total - cumulative
    if total != TOTAL_GPU_BUDGET_SECONDS or remaining >= 0:
        raise CandidateEvaluationError("budget overrun terminal requires a real overrun")
    return {
        "schema_version": 1,
        "stage": EVALUATION_STAGE,
        "status": "failed",
        "admissibleForContinuation": False,
        "priorEvidence": prior["artifact"],
        "rootEvidence": prior["rootEvidence"],
        "priorCumulativeSeconds": previous,
        "evaluationActualSeconds": float(elapsed),
        "cumulativeActualSeconds": cumulative,
        "totalBudgetSeconds": total,
        "remainingSeconds": remaining,
        "error": error,
    }


def build_complete_manifest(identity, inputs, outputs):
    if identity != EVALUATION_IDENTITY or not inputs or not outputs:
        raise CandidateEvaluationError("complete manifest identity or inventory differs")
    input_artifacts = {}
    for label, path in sorted(inputs.items()):
        input_artifacts[label] = _artifact(path)
    output_artifacts = {}
    for label, item in sorted(outputs.items()):
        path, rows = item
        artifact = _artifact(path)
        if rows is not None:
            artifact["rows"] = rows
        output_artifacts[label] = artifact
    return {
        "schema_version": 1,
        "identity": identity,
        "stage": EVALUATION_STAGE,
        "inputs": input_artifacts,
        "outputs": output_artifacts,
    }


def validate_complete_manifest(manifest, root, input_paths=None):
    if (
        not isinstance(manifest, dict)
        or set(manifest) != {"schema_version", "identity", "stage", "inputs", "outputs"}
        or manifest.get("schema_version") != 1
        or manifest.get("identity") != EVALUATION_IDENTITY
        or manifest.get("stage") != EVALUATION_STAGE
        or not isinstance(manifest.get("inputs"), dict)
        or not isinstance(manifest.get("outputs"), dict)
        or not manifest["inputs"]
        or not manifest["outputs"]
    ):
        raise CandidateEvaluationError("complete manifest contract differs")
    root = Path(root).resolve()
    if input_paths is not None:
        if not isinstance(input_paths, dict) or set(input_paths) != set(manifest["inputs"]):
            raise CandidateEvaluationError("complete manifest input inventory differs")
        for label, artifact in manifest["inputs"].items():
            expected = {key: artifact[key] for key in ("path", "bytes", "sha256")}
            path = Path(input_paths[label]).resolve()
            if (
                not _valid_artifact(expected)
                or path.name != expected["path"]
                or _artifact(path) != expected
            ):
                raise CandidateEvaluationError("complete manifest input inventory differs")
    else:
        for artifact in manifest["inputs"].values():
            expected = {key: artifact[key] for key in ("path", "bytes", "sha256")}
            if not _valid_artifact(expected) or _artifact(root / expected["path"]) != expected:
                raise CandidateEvaluationError("complete manifest artifact differs")
    for artifact in manifest["outputs"].values():
        expected = {key: artifact[key] for key in ("path", "bytes", "sha256")}
        if not _valid_artifact(expected) or _artifact(root / expected["path"]) != expected:
            raise CandidateEvaluationError("complete manifest artifact differs")
    return manifest


def validate_evaluator_trust_anchor(report, manifest, authorized_evaluator_sha256):
    if (
        not isinstance(authorized_evaluator_sha256, str)
        or len(authorized_evaluator_sha256) != 64
        or any(value not in "0123456789abcdef" for value in authorized_evaluator_sha256)
        or not isinstance(report, dict)
        or report.get("identity") != EVALUATION_IDENTITY
        or report.get("stage") != EVALUATION_STAGE
        or report.get("status") != "completed"
        or not isinstance(report.get("execution"), dict)
        or report["execution"].get("evaluatorCodeSha256") != authorized_evaluator_sha256
        or not isinstance(manifest, dict)
        or manifest.get("identity") != EVALUATION_IDENTITY
        or manifest.get("stage") != EVALUATION_STAGE
        or not isinstance(manifest.get("inputs"), dict)
        or not isinstance(manifest["inputs"].get("evaluator_code"), dict)
        or manifest["inputs"]["evaluator_code"].get("sha256")
        != authorized_evaluator_sha256
    ):
        raise CandidateEvaluationError("externally authorized evaluator hash differs")
    return authorized_evaluator_sha256


def validate_evaluation_bundle(
    report_path, manifest_path, receipt_path, output_root, input_paths,
    authorized_evaluator_sha256, supporting_budget_evidence,
):
    report = _canonical_load(report_path, "V5 quality report")
    manifest = _canonical_load(manifest_path, "V5 quality manifest")
    receipt = _canonical_load(receipt_path, "V5 quality budget receipt")
    validate_complete_manifest(manifest, output_root, input_paths)
    validate_evaluator_trust_anchor(report, manifest, authorized_evaluator_sha256)
    receipt_artifact = _artifact(receipt_path)
    if (
        report.get("gpuLedger") != receipt
        or report.get("artifacts", {}).get("budgetReceipt") != receipt_artifact
        or manifest.get("outputs", {}).get("budget_receipt") != receipt_artifact
        or receipt.get("stage") != EVALUATION_STAGE
        or receipt.get("status") != "completed"
        or receipt.get("error") is not None
    ):
        raise CandidateEvaluationError("V5 quality bundle budget binding differs")
    try:
        chain = load_budget_evidence(receipt_path, supporting_budget_evidence)
    except Exception as error:
        raise CandidateEvaluationError("V5 quality bundle recursive budget differs") from error
    if (
        chain.get("artifact") != receipt_artifact
        or chain.get("cumulativeActualSeconds") != receipt.get("cumulativeActualSeconds")
        or chain.get("rootEvidence") != receipt.get("rootEvidence")
    ):
        raise CandidateEvaluationError("V5 quality bundle recursive budget differs")
    return {"report": report, "manifest": manifest, "receipt": receipt, "chain": chain}


def _validate_static_input(path, expected, label):
    _require_artifact(path, expected, label)
    return Path(path).resolve()


def _supporting_evidence(paths):
    paths = [Path(path).resolve() for path in paths]
    actual = {(_artifact(path)["bytes"], _artifact(path)["sha256"]) for path in paths}
    if len(paths) != 5 or actual != EXPECTED_SUPPORTING_EVIDENCE:
        raise CandidateEvaluationError("supporting budget evidence inventory differs")
    return paths


def _runtime_versions(torch):
    try:
        import sacrebleu
        import sentencepiece
        import safetensors
        import transformers
    except ImportError as error:
        raise CandidateEvaluationError("pinned evaluation runtime is incomplete") from error
    return {
        "python": platform.python_version(),
        "torch": torch.__version__,
        "cuda": torch.version.cuda,
        "transformers": transformers.__version__,
        "sentencepiece": sentencepiece.__version__,
        "sacrebleu": sacrebleu.__version__,
        "safetensors": safetensors.__version__,
        "device": torch.cuda.get_device_name(0),
    }


def _configure_determinism():
    os.environ["CUBLAS_WORKSPACE_CONFIG"] = ":4096:8"
    try:
        import torch
    except ImportError as error:
        raise CandidateEvaluationError("evaluation requires pinned T3 dependencies") from error
    if not torch.cuda.is_available():
        raise CandidateEvaluationError("CUDA is unavailable for bounded V5 evaluation")
    torch.use_deterministic_algorithms(True)
    torch.backends.cudnn.benchmark = False
    return torch


def _translate_bounded(
    torch, model, processor, texts, direction, budget_guard, chunk_size=256,
):
    outputs = []
    for start in range(0, len(texts), chunk_size):
        budget_guard()
        outputs.extend(
            translate_texts(
                torch, model, processor, texts[start:start + chunk_size], direction
            )
        )
        budget_guard()
    if len(outputs) != len(texts):
        raise CandidateEvaluationError("bounded translation result count differs")
    return outputs


def _manual_translations(torch, model, processor, rows, budget_guard):
    outputs = [None] * len(rows)
    for direction in ("zh-en", "en-zh"):
        indexes = [index for index, row in enumerate(rows) if row["direction"] == direction]
        translated = _translate_bounded(
            torch, model, processor, [rows[index]["source"] for index in indexes],
            direction, budget_guard,
        )
        for index, output in zip(indexes, translated):
            outputs[index] = output
    return outputs


def _execution_inputs(script_path):
    directory = Path(script_path).resolve().parent
    paths = {"evaluator_code": Path(script_path).resolve()}
    for name, expected_sha in EXPECTED_DEPENDENCIES.items():
        path = directory / name
        actual = _artifact(path)
        if actual["sha256"] != expected_sha:
            raise CandidateEvaluationError("evaluation dependency hash differs: %s" % name)
        paths["dependency_" + name.replace(".", "_").replace("-", "_")] = path
    return paths


def evaluate(args):
    output_root = Path(args.output_root).resolve()
    if output_root.exists() and any(output_root.iterdir()):
        raise CandidateEvaluationError("evaluation output root must be new or empty")
    output_root.mkdir(parents=True, exist_ok=True)
    binding = validate_v5_binding(args.v5_terminal, args.budget_terminal)
    supports = _supporting_evidence(args.supporting_budget_evidence)
    try:
        prior = load_budget_evidence(args.budget_terminal, supports)
    except Exception as error:
        raise CandidateEvaluationError("recursive V5 budget evidence differs") from error
    if (
        prior["artifact"] != binding["budgetArtifact"]
        or prior["rootEvidence"]["sha256"]
        != "5ab469aca6d5f147e3dcdc1dc3a0ddbe198ed00b128b62aacdcaf34415e591c5"
        or prior["cumulativeActualSeconds"] != 28924.02908489965
        or prior["totalBudgetSeconds"] != TOTAL_GPU_BUDGET_SECONDS
    ):
        raise CandidateEvaluationError("recursive V5 budget root/cumulative differs")
    dataset_manifest_path = _validate_static_input(
        args.dataset_manifest, EXPECTED_DATASET_MANIFEST, "BiST manifest"
    )
    manual_path = _validate_static_input(args.manual_set, EXPECTED_MANUAL, "manual set")
    training_config_path = _validate_static_input(
        args.training_config, EXPECTED_TRAINING_CONFIG, "training config"
    )
    script_path = Path(__file__).resolve()
    code_artifact = _artifact(script_path)
    if args.authorized_evaluator_code_sha256 != code_artifact["sha256"]:
        raise CandidateEvaluationError("externally authorized evaluator code hash differs")
    execution_inputs = _execution_inputs(script_path)
    # The pinned prepare_bist publication format is pretty JSON; its exact byte hash
    # above and the six per-file hashes below bind it without changing that format.
    dataset_manifest = _json_load(dataset_manifest_path, "BiST manifest")
    if (
        dataset_manifest.get("dataset", {}).get("repo") != "Mxode/BiST"
        or dataset_manifest.get("dataset", {}).get("revision")
        != "aca6be897afc319f779009379c8b849c1eb8d63e"
    ):
        raise CandidateEvaluationError("BiST dataset identity differs")
    try:
        dataset_files = verify_dataset_inputs(args.dataset_root, dataset_manifest)
    except Exception as error:
        raise CandidateEvaluationError("BiST dataset inventory differs") from error
    test_rows = {
        direction: load_bist_rows(
            Path(args.dataset_root) / (direction + ".test.jsonl"), direction, 5000
        )
        for direction in ("zh-en", "en-zh")
    }
    manual_rows = load_manual_set(manual_path, 100)

    inputs = {
        "v5_terminal": Path(args.v5_terminal).resolve(),
        "v5_budget_terminal": Path(args.budget_terminal).resolve(),
        "dataset_manifest": dataset_manifest_path,
        "manual_set": manual_path,
        "training_config": training_config_path,
    }
    for name in sorted(binding["checkpointFiles"]):
        inputs["checkpoint_" + name.replace(".", "_")] = binding["checkpoint"] / name
    for index, path in enumerate(sorted(dataset_files, key=lambda value: value.name), 1):
        inputs["dataset_%02d_%s" % (index, path.stem.replace(".", "_"))] = path
    for index, path in enumerate(sorted(supports, key=lambda value: _artifact(value)["sha256"]), 1):
        inputs["budget_support_%02d" % index] = path
    inputs.update(execution_inputs)

    receipt_path = output_root / "budget-terminal-v5-candidate-evaluation-v1.json"
    overrun_path = output_root / "budget-overrun-terminal-v5-candidate-evaluation-v1.json"
    started = time.perf_counter()
    torch = None
    budget_guard = lambda: evaluation_budget_guard(prior, started)
    try:
        budget_guard()
        torch = _configure_determinism()
        torch.cuda.reset_peak_memory_stats()
        torch, model, processor = load_runtime(
            binding["checkpoint"], binding["checkpoint"] / "tokenizer.model"
        )
        direction_outputs = {}
        direction_metrics = {}
        bist_output_rows = []
        for direction in ("zh-en", "en-zh"):
            rows = test_rows[direction]
            outputs = _translate_bounded(
                torch, model, processor, [row["source"] for row in rows], direction,
                budget_guard,
            )
            direction_outputs[direction] = outputs
            direction_metrics[direction] = corpus_metrics(
                outputs,
                [row["target"] for row in rows],
                "13a" if direction == "zh-en" else "zh",
            )
            for index, (row, output) in enumerate(zip(rows, outputs), 1):
                bist_output_rows.append({
                    "direction": direction,
                    "index": index,
                    "source": row["source"],
                    "reference": row["target"],
                    "output": output,
                })
        raw_manual_rows = build_manual_results(
            manual_rows,
            _manual_translations(torch, model, processor, manual_rows, budget_guard),
        )
        torch.cuda.synchronize()
        elapsed = time.perf_counter() - started
        peak_cuda_bytes = int(torch.cuda.max_memory_allocated())
        receipt = build_budget_receipt(prior, elapsed, "completed", None)
    except Exception as error:
        if torch is not None and torch.cuda.is_available():
            try:
                torch.cuda.synchronize()
            except Exception:
                pass
        elapsed = time.perf_counter() - started
        error_text = "%s: %s" % (type(error).__name__, error)
        if float(prior["cumulativeActualSeconds"]) + elapsed > float(
            prior["totalBudgetSeconds"]
        ):
            _write_json(
                overrun_path,
                build_budget_overrun_terminal(prior, elapsed, error_text),
            )
        else:
            receipt = build_budget_receipt(prior, elapsed, "failed", error_text)
            _write_json(receipt_path, receipt)
        raise

    bist_path = output_root / "bist-test-outputs-v5-candidate-v1.jsonl"
    manual_results_path = output_root / "manual-results-raw-v5-candidate-v1.jsonl"
    _write_jsonl(bist_path, bist_output_rows)
    _write_jsonl(manual_results_path, raw_manual_rows)
    _write_json(receipt_path, receipt)
    report_path = output_root / "v5-candidate-quality-evaluation-v1.json"
    report = {
        "schema_version": 1,
        "identity": EVALUATION_IDENTITY,
        "stage": EVALUATION_STAGE,
        "status": "completed",
        "checkpoint": {
            "globalStep": 18284,
            "adamWStep": 18279,
            "files": binding["checkpointFiles"],
            "selection": binding["selection"],
        },
        "dataset": {
            "repo": "Mxode/BiST",
            "revision": "aca6be897afc319f779009379c8b849c1eb8d63e",
            "testRowsPerDirection": 5000,
        },
        "bistTest": direction_metrics,
        "manual": {
            "rows": len(raw_manual_rows),
            "mode": "raw-model-outputs-with-automatic-corruption-flags-only",
        },
        "decode": {"strategy": "greedy", "maxTokens": 128, "batchSize": 32},
        "runtime": _runtime_versions(torch),
        "execution": {
            "evaluatorCodeSha256": code_artifact["sha256"],
            "cublasWorkspaceConfig": os.environ["CUBLAS_WORKSPACE_CONFIG"],
            "deterministicAlgorithms": True,
        },
        "priorEvidence": prior["artifact"],
        "rootEvidence": prior["rootEvidence"],
        "gpuLedger": receipt,
        "peakCudaBytes": peak_cuda_bytes,
        "artifacts": {
            "bistTestOutputs": dict(_artifact(bist_path), rows=10000),
            "manualRawResults": dict(_artifact(manual_results_path), rows=100),
            "budgetReceipt": _artifact(receipt_path),
        },
    }
    _write_json(report_path, report)
    manifest = build_complete_manifest(
        EVALUATION_IDENTITY,
        inputs,
        {
            "bist_test_outputs": (bist_path, 10000),
            "manual_raw_results": (manual_results_path, 100),
            "budget_receipt": (receipt_path, None),
            "quality_report": (report_path, None),
        },
    )
    manifest_path = output_root / "v5-candidate-quality-manifest-v1.json"
    _write_json(manifest_path, manifest)
    validate_complete_manifest(manifest, output_root, inputs)
    return {
        "report": report_path,
        "manifest": manifest_path,
        "receipt": receipt_path,
        "elapsed": elapsed,
    }


def _parser():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--v5-terminal", required=True)
    parser.add_argument("--budget-terminal", required=True)
    parser.add_argument("--supporting-budget-evidence", nargs=5, required=True)
    parser.add_argument("--dataset-root", required=True)
    parser.add_argument("--dataset-manifest", required=True)
    parser.add_argument("--manual-set", required=True)
    parser.add_argument("--training-config", required=True)
    parser.add_argument("--output-root", required=True)
    parser.add_argument("--authorized-evaluator-code-sha256", required=True)
    return parser


def main():
    args = _parser().parse_args()
    try:
        result = evaluate(args)
    except Exception as error:
        raise SystemExit("V5 candidate evaluation failed: %s" % error) from error
    print(json.dumps({key: str(value) for key, value in result.items()}, sort_keys=True))


if __name__ == "__main__":
    main()
