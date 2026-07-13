#!/usr/bin/env python3
"""Fail-closed contract for one original-BiST continuation epoch."""

import argparse
import hashlib
import json
import math
import os
import random
import shutil
import sys
import time
from contextlib import contextmanager
from pathlib import Path

from tools.translation.diagnose_translation import (
    PINNED_BIST_MANIFEST_SHA256,
    _published_dataset_manifest_load,
    build_budget_terminal,
    directional_validation_loss,
    load_budget_evidence,
)
from tools.translation.distill_en_zh import canonical_json_bytes
from tools.translation.train_bidirectional import (
    BASE_REVISION,
    TrainingContractError,
    _forward_loss,
    _memmap_batch,
    _save_resume_state,
    _sha256_file,
    alternating_batch_plan,
    build_token_cache,
    load_training_config,
    restore_resume_state,
    verify_dataset_inputs,
)


V5_RESUME_SHA256 = "f9b78ef7f07476881d76ff724188558ed461b9b026113d2ed3de692c8ba29a6d"
V5_RESUME_BYTES = 206519930
V5_BASELINE_MODEL_SHA256 = "a7603325361de12f35ebc660c861c648a1f7293b31174280b32bbea34d9f491a"
V5_TOKENIZER_SHA256 = "e5528a5c3685d08f8868902d31febeb763eea8519f9997f43b05964b02554640"
V5_BUDGET_RECEIPT_SHA256 = "2996575f8100857820d92a4874989c561211ac2a68c617b7d287ceff28307675"
V5_BUDGET_RECEIPT_BYTES = 584
V5_BUDGET_ROOT_SHA256 = "5ab469aca6d5f147e3dcdc1dc3a0ddbe198ed00b128b62aacdcaf34415e591c5"
V5_PRIOR_CUMULATIVE_SECONDS = 27905.514084899634
V5_TOTAL_GPU_SECONDS = 43200.0
V5_MAX_GPU_SECONDS = 2400.0
V5_START_GLOBAL_STEP = 16878
V5_FINAL_GLOBAL_STEP = 18284
V5_VALIDATION_STEPS = (17000, 18000, 18284)
V5_BASELINE_LOSSES = {
    "zh-en": 3.2650395484924317,
    "en-zh": 4.142768315124512,
}
V5_TRAINING_CONFIG = {
    "path": "training-run-v3.json",
    "bytes": 1635,
    "sha256": "43fd95c607fadf33b04d6eaae3a54d3cc8de0be56e2dec729cadd78ebe88f5db",
}
V5_PHYSICAL_MICROBATCH = 32
V5_REQUIREMENTS_LOCK = {
    "path": "requirements-t3.lock.txt",
    "bytes": 79725,
    "sha256": "28f1214f4e830efc85601ad38d3337aa5b034ffbbd128e3cccea6024ee8a9060",
}
V5_TRAINING_CORE = {
    "path": "train_bidirectional.py",
    "bytes": 53753,
    "sha256": "a0c69b229a6d2f8bb52a3cf014e2e8275d2d3631a06843f33c038260a41ff419",
}
V5_DIAGNOSTIC_CORE = {
    "path": "diagnose_translation.py",
    "bytes": 44400,
    "sha256": "3c1cfcf1dcce535b4c1c483e5ccd8518ebe1452fd3069ae68ed4bc09fcf30590",
}
V5_DISTILLATION_CORE = {
    "path": "distill_en_zh.py",
    "bytes": 72610,
    "sha256": "cb2f27ea5089317745e71cd6f28f70e14bc2f447253a4205ac02f96773628910",
}
V5_RUNTIME_VERSIONS = {
    "python": "3.9.7",
    "numpy": "2.0.2",
    "sentencepiece": "0.2.0",
    "torch": "2.5.1+cu121",
    "transformers": "4.46.3",
    "cuda": "12.1",
}
V5_DEVICE = {
    "type": "cuda",
    "name": "NVIDIA GeForce RTX 2070",
    "totalMemoryBytes": 8589475840,
}
V5_DETERMINISM = {
    "cublasWorkspaceConfig": ":4096:8",
    "deterministicAlgorithms": True,
    "cudnnBenchmark": False,
}
V5_BUDGET_SUPPORTING = {
    (596, "4dc8803c2f81855224883627dc06f734ed6b48a31c99fe21aa2bc525a0d33bc3"),
    (668, "edda591abc9943f0f0b65eda34487ec6e8abd5a7310a29a5b694da6c38dd639f"),
    (2382, V5_BUDGET_ROOT_SHA256),
}
V5_SELECTED_FILES = {
    "config.json": {
        "path": "config.json", "bytes": 1139,
        "sha256": "70c13c358b500773c39664a663a0558e1f74c2816095764b0e0d52c3f34a5e32",
    },
    "generation_config.json": {
        "path": "generation_config.json", "bytes": 230,
        "sha256": "9ae6191ef296b47a96bbdee85df2edab91e44b4cda119fdcbec3c2527b362b34",
    },
    "model.safetensors": {
        "path": "model.safetensors", "bytes": 68702684,
        "sha256": V5_BASELINE_MODEL_SHA256,
    },
    "selection.json": {
        "path": "selection.json", "bytes": 129,
        "sha256": "22c204507ecff3fc7f32a796595adeca13b618647492bb8fdfa1c02e2e1fc023",
    },
    "tokenizer.model": {
        "path": "tokenizer.model", "bytes": 755175,
        "sha256": V5_TOKENIZER_SHA256,
    },
}
V5_RESUME_KEYS = {
    "schema_version", "model", "optimizer", "scaler", "optimizer_step",
    "epoch", "plan_index", "elapsed_seconds", "python_random_state",
    "torch_random_state", "cuda_random_state",
}
V5_SCALER = {
    "scale": 2097152.0,
    "growth_factor": 2.0,
    "backoff_factor": 0.5,
    "growth_interval": 2000,
    "_growth_tracker": 57,
}


class V5ContractError(RuntimeError):
    pass


def _artifact(path):
    size, digest = _sha256_file(path)
    return {"path": Path(path).name, "bytes": size, "sha256": digest}


def _finite(value, label):
    if isinstance(value, bool) or not isinstance(value, (int, float)) or not math.isfinite(value):
        raise V5ContractError("%s is not finite" % label)
    return float(value)


def _exact_int(value, expected, label):
    if isinstance(value, bool) or not isinstance(value, int) or value != expected:
        raise V5ContractError("%s differs" % label)


def _forbidden_teacher_value(value):
    if isinstance(value, dict):
        return any(
            any(token in str(key).lower() for token in ("teacher", "distill", "rescue_view"))
            or _forbidden_teacher_value(item)
            for key, item in value.items()
        )
    if isinstance(value, list):
        return any(_forbidden_teacher_value(item) for item in value)
    if isinstance(value, str):
        lowered = value.lower()
        return "teacher" in lowered or "distill" in lowered or "rescue-view" in lowered
    return False


def validate_v5_resume_state(state, resume_artifact, baseline_state, tensor_equal):
    if (
        not isinstance(resume_artifact, dict)
        or resume_artifact != {
            "path": "resume.pt",
            "bytes": V5_RESUME_BYTES,
            "sha256": V5_RESUME_SHA256,
        }
        or not isinstance(state, dict)
        or set(state) != V5_RESUME_KEYS
        or state.get("schema_version") != 1
    ):
        raise V5ContractError("v5 resume artifact/schema differs")
    _exact_int(state.get("optimizer_step"), V5_START_GLOBAL_STEP, "resume optimizer step")
    _exact_int(state.get("epoch"), 11, "resume epoch")
    _exact_int(state.get("plan_index"), 5626, "resume plan cursor")
    if _finite(state.get("elapsed_seconds"), "resume elapsed") != 13924.157000000065:
        raise V5ContractError("resume elapsed differs")
    model = state.get("model")
    if (
        not isinstance(model, dict)
        or not isinstance(baseline_state, dict)
        or len(model) != 155
        or len(baseline_state) != 155
        or set(model) != set(baseline_state)
    ):
        raise V5ContractError("resume model tensor set differs")
    if any(not tensor_equal(model[name], baseline_state[name]) for name in model):
        raise V5ContractError("resume model tensor value differs from selected checkpoint")
    optimizer = state.get("optimizer")
    if (
        not isinstance(optimizer, dict)
        or set(optimizer) != {"state", "param_groups"}
        or not isinstance(optimizer["state"], dict)
        or len(optimizer["state"]) != 149
        or not isinstance(optimizer["param_groups"], list)
        or len(optimizer["param_groups"]) != 1
        or not isinstance(optimizer["param_groups"][0], dict)
        or not isinstance(optimizer["param_groups"][0].get("params"), list)
        or len(optimizer["param_groups"][0]["params"]) != 151
    ):
        raise V5ContractError("resume AdamW state differs")
    try:
        adam_steps = {_state_step_value(item["step"]) for item in optimizer["state"].values()}
    except (AttributeError, KeyError, TypeError, ValueError) as error:
        raise V5ContractError("resume AdamW inner steps are unreadable") from error
    if adam_steps != {16875}:
        raise V5ContractError("resume AdamW inner step differs from 16875")
    if state.get("scaler") != V5_SCALER:
        raise V5ContractError("resume GradScaler state differs")
    if (
        not isinstance(state.get("python_random_state"), tuple)
        or len(state["python_random_state"]) != 3
        or state.get("torch_random_state") is None
        or not isinstance(state.get("cuda_random_state"), list)
        or len(state["cuda_random_state"]) != 1
        or state["cuda_random_state"][0] is None
    ):
        raise V5ContractError("resume RNG state differs")
    return {
        "artifact": resume_artifact,
        "optimizerStep": V5_START_GLOBAL_STEP,
        "epoch": 11,
        "planIndex": 5626,
        "elapsedSeconds": 13924.157000000065,
        "optimizerStateEntries": 149,
        "optimizerParameters": 151,
        "modelTensors": 155,
        "scaler": dict(V5_SCALER),
        "rng": {"python": True, "torch": True, "cudaStates": 1},
    }


def verify_v5_resume_bundle(torch, resume_path, baseline_model_path):
    resume_path = Path(resume_path).resolve()
    baseline_model_path = Path(baseline_model_path).resolve()
    resume_artifact = _artifact(resume_path)
    if _artifact(baseline_model_path)["sha256"] != V5_BASELINE_MODEL_SHA256:
        raise V5ContractError("selected baseline model hash differs")
    try:
        from transformers import AutoModelForSeq2SeqLM
        state = torch.load(resume_path, map_location="cpu", weights_only=False)
        baseline_model = AutoModelForSeq2SeqLM.from_pretrained(
            str(baseline_model_path.parent), local_files_only=True
        )
        baseline = baseline_model.state_dict()
    except Exception as error:
        raise V5ContractError("cannot load v5 resume/baseline state") from error
    return validate_v5_resume_state(state, resume_artifact, baseline, torch.equal)


def verify_v5_dataset_bundle(dataset_root, manifest_path, expected_manifest_sha256=None):
    manifest_path = Path(manifest_path).resolve()
    expected = expected_manifest_sha256 or PINNED_BIST_MANIFEST_SHA256
    try:
        manifest = _published_dataset_manifest_load(manifest_path, expected)
        verified = verify_dataset_inputs(dataset_root, manifest)
    except Exception as error:
        if isinstance(error, V5ContractError):
            raise
        raise V5ContractError("original BiST artifact verification failed") from error
    if (
        manifest.get("dataset")
        != {"repo": "Mxode/BiST", "revision": "aca6be897afc319f779009379c8b849c1eb8d63e"}
        or _forbidden_teacher_value(manifest)
    ):
        raise V5ContractError("v5 requires original BiST and forbids teacher/distillation views")
    artifacts = {
        name: manifest["outputs"][name]
        for name in (
            "zh-en.train.jsonl", "zh-en.validation.jsonl", "zh-en.test.jsonl",
            "en-zh.train.jsonl", "en-zh.validation.jsonl", "en-zh.test.jsonl",
        )
    }
    if len(verified) != 6 or len(artifacts) != 6:
        raise V5ContractError("v5 requires exactly six original BiST artifacts")
    return {
        "manifest": _artifact(manifest_path),
        "repo": "Mxode/BiST",
        "revision": "aca6be897afc319f779009379c8b849c1eb8d63e",
        "artifacts": artifacts,
        "trainingObjectives": ["zh-en.train.jsonl", "en-zh.train.jsonl"],
        "alternation": "strict-1-to-1",
    }


def validate_v5_budget_root(evidence):
    artifact = evidence.get("artifact") if isinstance(evidence, dict) else None
    root = evidence.get("rootEvidence") if isinstance(evidence, dict) else None
    if (
        not isinstance(artifact, dict)
        or artifact.get("path") != "budget-terminal-v1.json"
        or artifact.get("bytes") != V5_BUDGET_RECEIPT_BYTES
        or artifact.get("sha256") != V5_BUDGET_RECEIPT_SHA256
        or not isinstance(root, dict)
        or root.get("sha256") != V5_BUDGET_ROOT_SHA256
        or evidence.get("cumulativeActualSeconds") != V5_PRIOR_CUMULATIVE_SECONDS
        or evidence.get("totalBudgetSeconds") != V5_TOTAL_GPU_SECONDS
        or {
            (item.get("bytes"), item.get("sha256"))
            for item in evidence.get("supportingEvidence", [])
            if isinstance(item, dict)
        } != V5_BUDGET_SUPPORTING
    ):
        raise V5ContractError("v5 reconciled GPU budget root differs")
    return {
        **evidence,
        "maxV5ActualSeconds": V5_MAX_GPU_SECONDS,
        "maxCumulativeSeconds": V5_PRIOR_CUMULATIVE_SECONDS + V5_MAX_GPU_SECONDS,
    }


def verify_v5_budget_root(receipt_path, supporting_evidence_paths=()):
    supporting = [_artifact(path) for path in supporting_evidence_paths]
    supporting = _canonical_supporting_evidence(supporting)
    try:
        evidence = load_budget_evidence(receipt_path, supporting_evidence_paths)
    except Exception as error:
        raise V5ContractError("cannot verify reconciled v5 budget chain") from error
    return validate_v5_budget_root({**evidence, "supportingEvidence": supporting})


def _canonical_supporting_evidence(supporting):
    if (
        not isinstance(supporting, list)
        or len(supporting) != 3
        or any(not isinstance(item, dict) for item in supporting)
        or {(item.get("bytes"), item.get("sha256")) for item in supporting}
        != V5_BUDGET_SUPPORTING
    ):
        raise V5ContractError("V5 requires the complete three-file supporting budget chain")
    return sorted((dict(item) for item in supporting), key=lambda item: item["sha256"])


def _runtime_versions(torch):
    try:
        import numpy
        import sentencepiece
        import transformers
        actual = {
            "python": ".".join(str(value) for value in sys.version_info[:3]),
            "numpy": numpy.__version__,
            "sentencepiece": sentencepiece.__version__,
            "torch": torch.__version__,
            "transformers": transformers.__version__,
            "cuda": torch.version.cuda,
        }
    except (ImportError, AttributeError) as error:
        raise V5ContractError("pinned V5 runtime dependencies are unavailable") from error
    if actual != V5_RUNTIME_VERSIONS:
        raise V5ContractError("V5 runtime versions differ from requirements lock")
    return actual


def _verify_execution_bundle(torch, execution_code_sha256, requirements_lock_path):
    code = _artifact(__file__)
    if execution_code_sha256 != code["sha256"]:
        raise V5ContractError("V5 execution code SHA-256 differs")
    module_root = Path(__file__).resolve().parent
    training_core = _artifact(module_root / "train_bidirectional.py")
    diagnostic_core = _artifact(module_root / "diagnose_translation.py")
    distillation_core = _artifact(module_root / "distill_en_zh.py")
    requirements = _artifact(requirements_lock_path)
    if (
        training_core != V5_TRAINING_CORE
        or diagnostic_core != V5_DIAGNOSTIC_CORE
        or distillation_core != V5_DISTILLATION_CORE
    ):
        raise V5ContractError("V5 imported training code differs")
    if requirements != V5_REQUIREMENTS_LOCK:
        raise V5ContractError("V5 requirements lock differs")
    return {
        "code": code,
        "trainingCore": training_core,
        "diagnosticCore": diagnostic_core,
        "distillationCore": distillation_core,
        "requirementsLock": requirements,
        "runtimeVersions": _runtime_versions(torch),
        "device": dict(V5_DEVICE),
        "determinism": dict(V5_DETERMINISM),
    }


def verify_v5_launch_bundle(
    torch,
    resume_path,
    baseline_checkpoint_dir,
    training_config_path,
    dataset_root,
    manifest_path,
    budget_receipt_path,
    budget_supporting_paths=(),
    physical_microbatch=V5_PHYSICAL_MICROBATCH,
    execution_code_sha256=None,
    requirements_lock_path=None,
):
    if physical_microbatch != V5_PHYSICAL_MICROBATCH:
        raise V5ContractError("V5 physical microbatch must remain 32")
    if requirements_lock_path is None or execution_code_sha256 is None:
        raise V5ContractError("V5 execution code and requirements lock must be bound")
    baseline_checkpoint_dir = Path(baseline_checkpoint_dir).resolve()
    checkpoint = {}
    try:
        actual_names = {path.name for path in baseline_checkpoint_dir.iterdir() if path.is_file()}
    except OSError as error:
        raise V5ContractError("cannot read selected checkpoint") from error
    if actual_names != set(V5_SELECTED_FILES):
        raise V5ContractError("selected checkpoint file inventory differs")
    for name, expected in V5_SELECTED_FILES.items():
        actual = _artifact(baseline_checkpoint_dir / name)
        if actual != expected:
            raise V5ContractError("selected checkpoint artifact differs: %s" % name)
        checkpoint[name] = actual
    config_artifact = _artifact(training_config_path)
    if config_artifact != V5_TRAINING_CONFIG:
        raise V5ContractError("original training config artifact differs")
    try:
        training_config = load_training_config(training_config_path)
    except TrainingContractError as error:
        raise V5ContractError("original training config contract differs") from error
    if (
        training_config["training"]["microbatch_per_direction"] != 32
        or training_config["training"]["gradient_accumulation"] != 4
        or training_config["training"]["early_stop_non_improving_evaluations"] != 2
    ):
        raise V5ContractError("original training schedule differs")
    launch = {
        "schema_version": 1,
        "contract": "original-bist-v5-continuation",
        "resume": verify_v5_resume_bundle(
            torch, resume_path, baseline_checkpoint_dir / "model.safetensors"
        ),
        "selectedCheckpoint": checkpoint,
        "trainingConfig": config_artifact,
        "dataset": verify_v5_dataset_bundle(dataset_root, manifest_path),
        "budget": verify_v5_budget_root(budget_receipt_path, budget_supporting_paths),
        "limits": {
            "startGlobalStep": V5_START_GLOBAL_STEP,
            "finalGlobalStep": V5_FINAL_GLOBAL_STEP,
            "epochs": 1,
            "maxV5ActualSeconds": V5_MAX_GPU_SECONDS,
            "validationSteps": list(V5_VALIDATION_STEPS),
            "physicalMicrobatch": V5_PHYSICAL_MICROBATCH,
        },
        "execution": _verify_execution_bundle(
            torch, execution_code_sha256, requirements_lock_path
        ),
        "teacherView": None,
    }
    validate_v5_launch_bundle(launch)
    return launch


def validate_v5_launch_bundle(launch):
    if (
        not isinstance(launch, dict)
        or set(launch) != {
            "schema_version", "contract", "resume", "selectedCheckpoint",
            "trainingConfig", "dataset", "budget", "limits", "execution",
            "teacherView",
        }
        or launch.get("schema_version") != 1
        or launch.get("contract") != "original-bist-v5-continuation"
        or launch.get("teacherView") is not None
        or launch.get("trainingConfig") != V5_TRAINING_CONFIG
        or launch.get("selectedCheckpoint") != V5_SELECTED_FILES
    ):
        raise V5ContractError("verified v5 launch bundle differs")
    resume = launch.get("resume")
    dataset = launch.get("dataset")
    budget = launch.get("budget")
    execution = launch.get("execution")
    if (
        not isinstance(resume, dict)
        or resume.get("artifact")
        != {"path": "resume.pt", "bytes": V5_RESUME_BYTES, "sha256": V5_RESUME_SHA256}
        or resume.get("optimizerStep") != V5_START_GLOBAL_STEP
        or resume.get("epoch") != 11
        or resume.get("planIndex") != 5626
        or resume.get("optimizerStateEntries") != 149
        or resume.get("modelTensors") != 155
        or not isinstance(dataset, dict)
        or dataset.get("manifest", {}).get("sha256") != PINNED_BIST_MANIFEST_SHA256
        or set(dataset.get("artifacts", {}))
        != {
            "zh-en.train.jsonl", "zh-en.validation.jsonl", "zh-en.test.jsonl",
            "en-zh.train.jsonl", "en-zh.validation.jsonl", "en-zh.test.jsonl",
        }
        or dataset.get("trainingObjectives")
        != ["zh-en.train.jsonl", "en-zh.train.jsonl"]
        or dataset.get("alternation") != "strict-1-to-1"
        or not isinstance(budget, dict)
        or budget.get("artifact", {}).get("sha256") != V5_BUDGET_RECEIPT_SHA256
        or budget.get("rootEvidence", {}).get("sha256") != V5_BUDGET_ROOT_SHA256
        or budget.get("cumulativeActualSeconds") != V5_PRIOR_CUMULATIVE_SECONDS
        or budget.get("totalBudgetSeconds") != V5_TOTAL_GPU_SECONDS
        or {
            (item.get("bytes"), item.get("sha256"))
            for item in budget.get("supportingEvidence", [])
            if isinstance(item, dict)
        } != V5_BUDGET_SUPPORTING
        or not isinstance(execution, dict)
        or set(execution) != {
            "code", "trainingCore", "diagnosticCore", "distillationCore",
            "requirementsLock", "runtimeVersions", "device", "determinism",
        }
        or execution.get("trainingCore") != V5_TRAINING_CORE
        or execution.get("diagnosticCore") != V5_DIAGNOSTIC_CORE
        or execution.get("distillationCore") != V5_DISTILLATION_CORE
        or execution.get("requirementsLock") != V5_REQUIREMENTS_LOCK
        or execution.get("runtimeVersions") != V5_RUNTIME_VERSIONS
        or execution.get("device") != V5_DEVICE
        or execution.get("determinism") != V5_DETERMINISM
        or execution.get("code") != _artifact(__file__)
        or launch.get("limits") != {
            "startGlobalStep": V5_START_GLOBAL_STEP,
            "finalGlobalStep": V5_FINAL_GLOBAL_STEP,
            "epochs": 1,
            "maxV5ActualSeconds": V5_MAX_GPU_SECONDS,
            "validationSteps": list(V5_VALIDATION_STEPS),
            "physicalMicrobatch": V5_PHYSICAL_MICROBATCH,
        }
    ):
        raise V5ContractError("v5 launch provenance/schedule differs")
    return launch


def evaluate_v5_validation_history(history, require_final=False):
    if not isinstance(history, list) or len(history) > len(V5_VALIDATION_STEPS):
        raise V5ContractError("v5 validation history differs")
    expected_steps = list(V5_VALIDATION_STEPS[:len(history)])
    if [row.get("global_step") for row in history if isinstance(row, dict)] != expected_steps:
        raise V5ContractError("v5 validation steps differ")
    normalized = []
    candidate = None
    best_losses = dict(V5_BASELINE_LOSSES)
    non_improving = 0
    for row in history:
        if not isinstance(row, dict) or set(row) != {"global_step", "losses"}:
            raise V5ContractError("v5 validation row schema differs")
        losses = row["losses"]
        if not isinstance(losses, dict) or set(losses) != {"zh-en", "en-zh"}:
            raise V5ContractError("v5 directional loss schema differs")
        values = {direction: _finite(losses[direction], direction + " loss") for direction in V5_BASELINE_LOSSES}
        if any(value <= 0 for value in values.values()):
            raise V5ContractError("v5 directional loss must be positive")
        joint = all(values[direction] < best_losses[direction] for direction in values)
        item = {"global_step": row["global_step"], "losses": values, "jointlyImproved": joint}
        normalized.append(item)
        if joint:
            candidate = item
            best_losses = dict(values)
            non_improving = 0
        else:
            non_improving += 1
    if require_final and expected_steps != list(V5_VALIDATION_STEPS):
        raise V5ContractError("completed v5 epoch requires all fixed validation steps")
    return {
        "history": normalized,
        "candidate": candidate,
        "nonImprovingChecks": non_improving,
        "patienceReached": non_improving >= 2,
    }


def _v5_gpu_ledger(elapsed, completed):
    actual = _finite(elapsed, "v5 actual GPU seconds")
    if actual < 0 or (completed and actual > V5_MAX_GPU_SECONDS):
        raise V5ContractError("v5 GPU time ceiling exceeded")
    cumulative = V5_PRIOR_CUMULATIVE_SECONDS + actual
    return {
        "priorCumulativeSeconds": V5_PRIOR_CUMULATIVE_SECONDS,
        "v5ActualSeconds": actual,
        "cumulativeActualSeconds": cumulative,
        "totalBudgetSeconds": V5_TOTAL_GPU_SECONDS,
        "remainingSeconds": V5_TOTAL_GPU_SECONDS - cumulative,
        "v5CeilingSeconds": V5_MAX_GPU_SECONDS,
        "v5CeilingExceeded": actual > V5_MAX_GPU_SECONDS,
    }


def _write_new_json(path, value):
    path = Path(path).resolve()
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = Path(str(path) + ".partial")
    if path.exists() or temporary.exists():
        raise V5ContractError("v5 terminal path must be new")
    temporary.write_bytes(canonical_json_bytes(value))
    os.replace(str(temporary), str(path))


def _candidate_file_inventory(root):
    root = Path(root).resolve()
    expected = {
        "base_revision.txt", "config.json", "generation_config.json",
        "model.safetensors", "selection.json", "tokenizer.model",
    }
    actual = {path.name for path in root.iterdir() if path.is_file()}
    if actual != expected:
        raise V5ContractError("v5 candidate file inventory differs")
    files = {name: _artifact(root / name) for name in sorted(expected)}
    if files["tokenizer.model"]["sha256"] != V5_TOKENIZER_SHA256:
        raise V5ContractError("v5 candidate tokenizer differs")
    if (root / "base_revision.txt").read_text(encoding="ascii") != BASE_REVISION + "\n":
        raise V5ContractError("v5 candidate base revision differs")
    return {"path": root.name, "files": files}


def _state_step_value(value):
    try:
        return int(value.item())
    except AttributeError:
        return int(value)


def _verify_output_resume(
    torch, path, expected_step, expected_plan_index, expected_v5_elapsed
):
    """Independently reload a saved resume; never trust runtime self-reporting."""
    try:
        state = torch.load(Path(path).resolve(), map_location="cpu", weights_only=False)
    except Exception as error:
        raise V5ContractError("cannot independently reload saved V5 resume") from error
    optimizer = state.get("optimizer") if isinstance(state, dict) else None
    optimizer_state = optimizer.get("state") if isinstance(optimizer, dict) else None
    model = state.get("model") if isinstance(state, dict) else None
    scaler = state.get("scaler") if isinstance(state, dict) else None
    expected_adam_step = 16875 + (expected_step - V5_START_GLOBAL_STEP)
    try:
        adam_steps = {_state_step_value(item["step"]) for item in optimizer_state.values()}
    except (AttributeError, KeyError, TypeError, ValueError) as error:
        raise V5ContractError("saved V5 AdamW steps are unreadable") from error
    if (
        set(state) != V5_RESUME_KEYS
        or state.get("schema_version") != 1
        or state.get("optimizer_step") != expected_step
        or state.get("epoch") != 12
        or state.get("plan_index") != expected_plan_index
        or state.get("elapsed_seconds")
        != 13924.157000000065 + _finite(expected_v5_elapsed, "saved V5 elapsed")
        or not isinstance(model, dict)
        or len(model) != 155
        or not isinstance(optimizer_state, dict)
        or len(optimizer_state) != 149
        or len(optimizer.get("param_groups", [])) != 1
        or len(optimizer["param_groups"][0].get("params", [])) != 151
        or adam_steps != {expected_adam_step}
        or not isinstance(scaler, dict)
        or set(scaler) != set(V5_SCALER)
        or not isinstance(state.get("python_random_state"), tuple)
        or state.get("torch_random_state") is None
        or not isinstance(state.get("cuda_random_state"), list)
        or len(state["cuda_random_state"]) != 1
    ):
        raise V5ContractError("independently loaded V5 resume state/cursor differs")
    return {
        **_artifact(path),
        "optimizerStep": expected_step,
        "adamWStep": expected_adam_step,
        "epoch": 12,
        "planIndex": expected_plan_index,
        "modelTensors": 155,
        "optimizerStateEntries": 149,
    }


@contextmanager
def _preserve_rng(torch):
    python_state = random.getstate()
    torch_state = torch.get_rng_state()
    cuda_state = torch.cuda.get_rng_state_all()
    try:
        yield
    finally:
        random.setstate(python_state)
        torch.set_rng_state(torch_state)
        torch.cuda.set_rng_state_all(cuda_state)


def _verify_candidate_bundle(torch, checkpoint_root, resume_path, step, losses):
    inventory = _candidate_file_inventory(checkpoint_root)
    selection = json.loads(
        (Path(checkpoint_root) / "selection.json").read_text(encoding="utf-8")
    )
    if selection != {
        "schema_version": 1,
        "optimizer_step": step,
        "directional_losses": losses,
        "vocab_size": 32003,
        "optimizer_independent": True,
    }:
        raise V5ContractError("V5 candidate selection metadata differs")
    try:
        from transformers import AutoModelForSeq2SeqLM
        resume = torch.load(resume_path, map_location="cpu", weights_only=False)
        model = AutoModelForSeq2SeqLM.from_pretrained(
            str(Path(checkpoint_root).resolve()), local_files_only=True
        )
        checkpoint_state = model.state_dict()
    except Exception as error:
        raise V5ContractError("cannot independently load V5 candidate model") from error
    resume_state = resume.get("model") if isinstance(resume, dict) else None
    if (
        not isinstance(resume_state, dict)
        or len(checkpoint_state) != 155
        or set(checkpoint_state) != set(resume_state)
        or any(not torch.equal(checkpoint_state[name], resume_state[name]) for name in resume_state)
    ):
        raise V5ContractError("V5 candidate tensors differ from its resume state")
    return inventory


def _write_budget_receipt(path, launch, elapsed, status, error):
    receipt = build_budget_terminal(
        "translation_v5_original_bist_continuation",
        status,
        launch["budget"]["artifact"],
        V5_PRIOR_CUMULATIVE_SECONDS,
        elapsed,
        V5_TOTAL_GPU_SECONDS,
        error,
        launch["budget"]["rootEvidence"],
    )
    _write_new_json(path, receipt)
    return _artifact(path)


def _terminal_report(
    launch, status, current_step, plan_index, history, candidate,
    final_resume, budget_receipt, elapsed, error, secondary_errors=(),
):
    return {
        "schema_version": 1,
        "stage": "translation_v5_original_bist_continuation",
        "status": status,
        "launchBundleSha256": hashlib.sha256(canonical_json_bytes(launch)).hexdigest(),
        "priorEvidence": launch["budget"]["artifact"],
        "rootEvidence": launch["budget"]["rootEvidence"],
        "budgetReceipt": budget_receipt,
        "startGlobalStep": V5_START_GLOBAL_STEP,
        "finalGlobalStep": current_step,
        "optimizerStepsAdvanced": current_step - V5_START_GLOBAL_STEP,
        "epoch": 12,
        "planIndex": plan_index,
        "consumedThenDiscardedPartialLogicalBatches": 2 if status == "completed" else 0,
        "validationHistory": evaluate_v5_validation_history(history)["history"],
        "candidate": candidate,
        "finalResume": final_resume,
        "gpuLedger": _v5_gpu_ledger(elapsed, completed=status != "failed"),
        "error": error,
        "secondaryErrors": list(secondary_errors),
    }


def _execute_v5_training_plan(runtime, budget_guard, on_joint_improvement=None):
    """Private plan engine. Production constructs the runtime; tests may fake only this layer."""
    current_step = V5_START_GLOBAL_STEP
    plan_index = 0
    history = []
    candidate = None
    if runtime.current_optimizer_step() != V5_START_GLOBAL_STEP:
        raise V5ContractError("runtime did not restore optimizer step 16878")
    if runtime.current_plan_index() != 0:
        raise V5ContractError("V5 continuation must begin at epoch-12 plan cursor zero")
    status = "completed"
    for expected_step in range(V5_START_GLOBAL_STEP + 1, V5_FINAL_GLOBAL_STEP + 1):
        budget_guard()
        runtime.train_optimizer_step(expected_step, plan_index, budget_guard)
        plan_index += 4
        if (
            runtime.current_optimizer_step() != expected_step
            or runtime.current_plan_index() != plan_index
        ):
            raise V5ContractError("runtime optimizer/plan cursor did not advance exactly once")
        current_step = expected_step
        budget_guard()
        if current_step not in V5_VALIDATION_STEPS:
            continue
        losses = runtime.directional_validation(budget_guard)
        proposed = history + [{"global_step": current_step, "losses": losses}]
        gate = evaluate_v5_validation_history(proposed)
        history = proposed
        observed = gate["history"][-1]
        if observed["jointlyImproved"]:
            candidate = (
                on_joint_improvement(current_step, plan_index, observed["losses"])
                if on_joint_improvement is not None else observed
            )
        if gate["patienceReached"] and current_step < V5_FINAL_GLOBAL_STEP:
            status = "early_stopped"
            break
    if status == "completed":
        if current_step != V5_FINAL_GLOBAL_STEP or candidate is None:
            raise V5ContractError("completed V5 epoch lacks a joint-improvement candidate")
        runtime.consume_partial_logical_batches(plan_index, budget_guard)
        plan_index += 2
        if runtime.current_plan_index() != plan_index or plan_index != 5626:
            raise V5ContractError("V5 tail logical batches were not actually consumed")
        runtime.discard_partial_gradients()
    return {
        "status": status,
        "currentStep": current_step,
        "planIndex": plan_index,
        "history": history,
        "candidate": candidate,
    }


def _configure_determinism(torch):
    existing = os.environ.get("CUBLAS_WORKSPACE_CONFIG")
    if existing not in (None, V5_DETERMINISM["cublasWorkspaceConfig"]):
        raise V5ContractError("CUBLAS_WORKSPACE_CONFIG conflicts with V5 contract")
    os.environ["CUBLAS_WORKSPACE_CONFIG"] = V5_DETERMINISM["cublasWorkspaceConfig"]
    torch.use_deterministic_algorithms(True)
    torch.backends.cudnn.benchmark = False
    actual = {
        "cublasWorkspaceConfig": os.environ.get("CUBLAS_WORKSPACE_CONFIG"),
        "deterministicAlgorithms": torch.are_deterministic_algorithms_enabled(),
        "cudnnBenchmark": torch.backends.cudnn.benchmark,
    }
    if actual != V5_DETERMINISM:
        raise V5ContractError("V5 deterministic runtime settings did not take effect")
    return actual


def _source_artifact(path, expected):
    actual = _artifact(path)
    pinned = {
        "path": Path(expected["path"]).name,
        "bytes": expected["bytes"],
        "sha256": expected["sha256"],
    }
    if actual != pinned:
        raise V5ContractError("BiST source changed during V5 cache construction")
    return actual


def _build_fresh_token_caches(config, dataset_root, manifest, processor, cache_root):
    dataset_root = Path(dataset_root).resolve()
    cache_root = Path(cache_root).resolve()
    repository = Path(__file__).resolve().parents[2]
    if cache_root.exists() or cache_root == repository or repository in cache_root.parents:
        raise V5ContractError("V5 token cache root must be a new directory outside the repository")
    names = [
        "%s.%s.jsonl" % (direction, split)
        for split in ("train", "validation", "test")
        for direction in ("zh-en", "en-zh")
    ]
    sources = {}
    for name in names:
        expected = manifest["outputs"][name]
        source = dataset_root / expected["path"]
        _source_artifact(source, expected)
        sources[name] = source
    cache_root.mkdir(parents=True)
    datasets = {split: {} for split in ("train", "validation", "test")}
    inventory = []
    for split in datasets:
        for direction in ("zh-en", "en-zh"):
            name = "%s.%s.jsonl" % (direction, split)
            artifact = manifest["outputs"][name]
            datasets[split][direction] = build_token_cache(
                cache_root, sources[name], artifact, config["tokenizer"], processor,
                direction, split, config["model"]["max_tokens"],
            )
            _source_artifact(sources[name], artifact)
            destination = cache_root / (direction + "." + split)
            expected_files = {
                "manifest.json", "input_ids.npy", "attention_mask.npy", "labels.npy",
            }
            actual_files = {path.name for path in destination.iterdir() if path.is_file()}
            if actual_files != expected_files:
                raise V5ContractError("V5 token cache file inventory differs")
            for filename in sorted(expected_files):
                item = _artifact(destination / filename)
                item["path"] = "%s/%s" % (destination.name, filename)
                inventory.append(item)
    for name in names:
        _source_artifact(sources[name], manifest["outputs"][name])
    return datasets, sorted(inventory, key=lambda item: item["path"])


class _TorchV5Runtime:
    """The only production runtime for V5; deliberately private and non-injectable."""

    def __init__(
        self, torch, config, dataset_root, manifest, selected_root,
        resume_path, cache_root,
    ):
        try:
            import sentencepiece
            from transformers import MarianMTModel
        except ImportError as error:
            raise V5ContractError("V5 runtime dependencies are unavailable") from error
        _configure_determinism(torch)
        self.torch = torch
        self.config = config
        self.training = config["training"]
        self.processor = sentencepiece.SentencePieceProcessor(
            model_file=str(Path(selected_root) / "tokenizer.model")
        )
        self.tokenizer_model = Path(selected_root).resolve() / "tokenizer.model"
        if self.processor.get_piece_size() != 32000:
            raise V5ContractError("V5 SentencePiece vocabulary differs")
        self.datasets, self.cache_inventory = _build_fresh_token_caches(
            config, dataset_root, manifest, self.processor, cache_root
        )
        if {key: len(value) for key, value in self.datasets["train"].items()} != {
            "zh-en": 90000, "en-zh": 90000,
        }:
            raise V5ContractError("V5 training cache counts differ")
        if not torch.cuda.is_available():
            raise V5ContractError("V5 training requires the pinned CUDA runtime")
        device = {
            "type": "cuda",
            "name": torch.cuda.get_device_name(0),
            "totalMemoryBytes": torch.cuda.get_device_properties(0).total_memory,
        }
        if device != V5_DEVICE:
            raise V5ContractError("V5 CUDA device identity differs from launch contract")
        self.model = MarianMTModel.from_pretrained(
            str(Path(selected_root).resolve()), local_files_only=True,
            torch_dtype=torch.float32,
        )
        self.device = torch.device("cuda")
        self.model.to(self.device)
        self.model.gradient_checkpointing_enable()
        self.model.train()
        self.optimizer = torch.optim.AdamW(
            self.model.parameters(), lr=self.training["learning_rate"],
            weight_decay=self.training["weight_decay"],
        )
        self.scaler = torch.amp.GradScaler("cuda")
        state = torch.load(Path(resume_path), map_location="cpu", weights_only=False)
        cursor = restore_resume_state(
            torch, state, self.model, self.optimizer, self.scaler, max_epochs=13
        )
        if cursor != (V5_START_GLOBAL_STEP, 11, 5626, 13924.157000000065):
            raise V5ContractError("V5 runtime restored a different resume cursor")
        self.step = V5_START_GLOBAL_STEP
        self.plan_index = 0
        self.previous_elapsed = cursor[3]
        self.plan = alternating_batch_plan(
            {"zh-en": 90000, "en-zh": 90000}, 32, config["seed"], 12
        )
        if (
            len(self.plan) != 5626
            or any(direction != ("zh-en" if index % 2 == 0 else "en-zh")
                   for index, (direction, unused) in enumerate(self.plan))
            or [len(self.plan[-2][1]), len(self.plan[-1][1])] != [16, 16]
            or self._adam_steps() != {16875}
        ):
            raise V5ContractError("V5 epoch-12 plan or restored AdamW cursor differs")

    def _adam_steps(self):
        return {
            _state_step_value(item["step"])
            for item in self.optimizer.state.values()
        }

    def _logical_backward(self, direction, indices, budget_guard):
        for start in range(0, len(indices), V5_PHYSICAL_MICROBATCH):
            budget_guard()
            sub_indices = indices[start:start + V5_PHYSICAL_MICROBATCH]
            batch = _memmap_batch(
                self.torch, self.datasets["train"][direction], sub_indices, self.device
            )
            loss, logits = _forward_loss(
                self.torch, self.model, batch, self.training["label_smoothing"]
            )
            del logits
            weight = len(sub_indices) / len(indices)
            self.scaler.scale(
                loss * weight / self.training["gradient_accumulation"]
            ).backward()

    def current_optimizer_step(self):
        return self.step

    def current_plan_index(self):
        return self.plan_index

    def train_optimizer_step(self, expected_step, expected_plan_index, budget_guard):
        if expected_plan_index != self.plan_index or expected_step != self.step + 1:
            raise V5ContractError("V5 runtime received a non-contiguous optimizer cursor")
        self.optimizer.zero_grad(set_to_none=True)
        for direction, indices in self.plan[self.plan_index:self.plan_index + 4]:
            self._logical_backward(direction, indices, budget_guard)
        for group in self.optimizer.param_groups:
            group["lr"] = self.training["learning_rate"]
        self.scaler.unscale_(self.optimizer)
        self.torch.nn.utils.clip_grad_norm_(self.model.parameters(), 1.0)
        self.scaler.step(self.optimizer)
        self.scaler.update()
        expected_adam_step = 16875 + (expected_step - V5_START_GLOBAL_STEP)
        if self._adam_steps() != {expected_adam_step}:
            raise V5ContractError("V5 AdamW inner step did not advance exactly once")
        self.step = expected_step
        self.plan_index += 4

    def consume_partial_logical_batches(self, expected_plan_index, budget_guard):
        if expected_plan_index != 5624 or self.plan_index != 5624:
            raise V5ContractError("V5 tail cursor differs")
        self.optimizer.zero_grad(set_to_none=True)
        before = self.torch.cuda.get_rng_state_all()
        for direction, indices in self.plan[5624:5626]:
            self._logical_backward(direction, indices, budget_guard)
        after = self.torch.cuda.get_rng_state_all()
        if len(before) != 1 or len(after) != 1 or self.torch.equal(before[0], after[0]):
            raise V5ContractError("V5 tail batches did not advance CUDA RNG")
        self.plan_index = 5626

    def directional_validation(self, budget_guard):
        losses = directional_validation_loss(
            self.torch, self.model, self.datasets["validation"],
            V5_PHYSICAL_MICROBATCH, self.training["label_smoothing"], budget_guard,
        )
        self.model.train()
        return losses

    def discard_partial_gradients(self):
        self.optimizer.zero_grad(set_to_none=True)

    def save_resume(self, path, step, plan_index, elapsed):
        _save_resume_state(
            self.torch, path, self.model, self.optimizer, self.scaler,
            step, 12, plan_index, self.previous_elapsed + elapsed,
        )

    def save_candidate(self, root, step, losses):
        root = Path(root).resolve()
        if root.exists():
            raise V5ContractError("V5 candidate checkpoint path must be new")
        root.mkdir(parents=True)
        self.model.save_pretrained(
            root, safe_serialization=True, max_shard_size="1GB"
        )
        shutil.copyfile(self.tokenizer_model, root / "tokenizer.model")
        (root / "base_revision.txt").write_bytes((BASE_REVISION + "\n").encode("ascii"))
        (root / "selection.json").write_bytes(canonical_json_bytes({
            "schema_version": 1,
            "optimizer_step": step,
            "directional_losses": losses,
            "vocab_size": 32003,
            "optimizer_independent": True,
        }))


def _run_production_v5(
    torch, launch, config, dataset_root, manifest, selected_checkpoint_dir,
    resume_path, cache_root, artifact_root, clock=time.monotonic,
):
    artifact_root = Path(artifact_root).resolve()
    if artifact_root.exists():
        raise V5ContractError("V5 artifact root must be new")
    artifact_root.mkdir(parents=True)
    started = clock()
    runtime = None

    def elapsed_now():
        elapsed = clock() - started
        if elapsed < 0:
            raise V5ContractError("V5 clock moved backwards")
        return elapsed

    def budget_guard():
        if elapsed_now() >= V5_MAX_GPU_SECONDS:
            raise V5ContractError("V5 GPU time ceiling reached")

    def save_candidate(step, plan_index, losses):
        candidate_root = artifact_root / ("candidate-step-%d" % step)
        candidate_root.mkdir()
        resume_path = candidate_root / "resume.pt"
        candidate_elapsed = elapsed_now()
        runtime.save_resume(resume_path, step, plan_index, candidate_elapsed)
        with _preserve_rng(torch):
            resume = _verify_output_resume(
                torch, resume_path, step, plan_index, candidate_elapsed
            )
            checkpoint_root = candidate_root / "checkpoint"
            runtime.save_candidate(checkpoint_root, step, losses)
            checkpoint = _verify_candidate_bundle(
                torch, checkpoint_root, resume_path, step, losses
            )
        return {
            "globalStep": step, "losses": losses,
            "checkpoint": checkpoint, "resume": resume,
        }

    plan = {
        "status": "failed", "currentStep": V5_START_GLOBAL_STEP,
        "planIndex": 0, "history": [], "candidate": None,
    }
    try:
        runtime = _TorchV5Runtime(
            torch, config, dataset_root, manifest, selected_checkpoint_dir,
            resume_path, cache_root,
        )
        plan = _execute_v5_training_plan(runtime, budget_guard, save_candidate)
        final_resume_path = artifact_root / "resume.pt"
        final_elapsed = elapsed_now()
        runtime.save_resume(
            final_resume_path, plan["currentStep"], plan["planIndex"], final_elapsed
        )
        with _preserve_rng(torch):
            final_resume = _verify_output_resume(
                torch, final_resume_path, plan["currentStep"], plan["planIndex"],
                final_elapsed,
            )
        elapsed = elapsed_now()
        budget_guard()
        budget_receipt = _write_budget_receipt(
            artifact_root / "budget-terminal-v1.json", launch, elapsed, "completed", None
        )
        report = _terminal_report(
            launch, plan["status"], plan["currentStep"], plan["planIndex"],
            plan["history"], plan["candidate"], final_resume, budget_receipt,
            elapsed, None,
        )
        report["tokenCache"] = runtime.cache_inventory
        _write_new_json(artifact_root / "v5-terminal-v1.json", report)
        return report
    except BaseException as primary:
        secondary = []
        if runtime is not None:
            try:
                runtime.discard_partial_gradients()
            except BaseException as error:
                secondary.append("discard: %s: %s" % (type(error).__name__, error))
            try:
                plan["currentStep"] = runtime.current_optimizer_step()
                plan["planIndex"] = runtime.current_plan_index()
            except BaseException as error:
                secondary.append("cursor: %s: %s" % (type(error).__name__, error))
        try:
            elapsed = elapsed_now()
        except BaseException as error:
            elapsed = 0.0
            secondary.append("clock: %s: %s" % (type(error).__name__, error))
        failure_resume = None
        try:
            if runtime is None:
                raise V5ContractError("runtime construction did not complete")
            path = artifact_root / "resume-failed.pt"
            runtime.save_resume(path, plan["currentStep"], plan["planIndex"], elapsed)
            with _preserve_rng(torch):
                failure_resume = _verify_output_resume(
                    torch, path, plan["currentStep"], plan["planIndex"], elapsed
                )
        except BaseException as error:
            secondary.append("failureResume: %s: %s" % (type(error).__name__, error))
        message = "%s: %s" % (type(primary).__name__, primary)
        budget_receipt = None
        try:
            budget_receipt = _write_budget_receipt(
                artifact_root / "budget-terminal-v1.json", launch, elapsed, "failed", message
            )
        except BaseException as error:
            secondary.append("budgetTerminal: %s: %s" % (type(error).__name__, error))
        report = _terminal_report(
            launch, "failed", plan["currentStep"], plan["planIndex"],
            plan["history"], plan["candidate"], failure_resume, budget_receipt,
            elapsed, message, secondary,
        )
        report["tokenCache"] = getattr(runtime, "cache_inventory", None)
        try:
            _write_new_json(artifact_root / "v5-terminal-v1.json", report)
        except BaseException as error:
            secondary.append("terminalReport: %s: %s" % (type(error).__name__, error))
            emergency = artifact_root / "v5-terminal-emergency-v1.json"
            if not emergency.exists():
                _write_new_json(emergency, {**report, "secondaryErrors": secondary})
        raise


def run_v5_continuation(
    resume_path, selected_checkpoint_dir, training_config_path, dataset_root,
    manifest_path, budget_receipt_path, budget_supporting_paths,
    requirements_lock_path, execution_code_sha256, cache_root, artifact_root,
):
    """Verify every launch input, construct the private Torch runtime, and train."""
    try:
        import torch
    except ImportError as error:
        raise V5ContractError("pinned Torch runtime is unavailable") from error
    launch = verify_v5_launch_bundle(
        torch, resume_path, selected_checkpoint_dir, training_config_path,
        dataset_root, manifest_path, budget_receipt_path, budget_supporting_paths,
        V5_PHYSICAL_MICROBATCH, execution_code_sha256, requirements_lock_path,
    )
    config = load_training_config(training_config_path)
    manifest = _published_dataset_manifest_load(
        manifest_path, PINNED_BIST_MANIFEST_SHA256
    )
    return _run_production_v5(
        torch, launch, config, dataset_root, manifest, selected_checkpoint_dir,
        resume_path, cache_root, artifact_root,
    )


def _common_arguments(parser):
    parser.add_argument("--resume", required=True, type=Path)
    parser.add_argument("--selected-checkpoint", required=True, type=Path)
    parser.add_argument("--config", required=True, type=Path)
    parser.add_argument("--dataset-root", required=True, type=Path)
    parser.add_argument("--dataset-manifest", required=True, type=Path)
    parser.add_argument("--budget-receipt", required=True, type=Path)
    parser.add_argument(
        "--budget-supporting-evidence", required=True, action="append", type=Path
    )
    parser.add_argument("--requirements-lock", required=True, type=Path)
    parser.add_argument("--execution-code-sha256", required=True)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    verify = commands.add_parser("verify", help="CPU-only dry verification of launch inputs")
    train = commands.add_parser("train", help="run the bounded CUDA continuation")
    for command in (verify, train):
        _common_arguments(command)
    train.add_argument("--cache-root", required=True, type=Path)
    train.add_argument("--artifact-root", required=True, type=Path)
    args = parser.parse_args(argv)
    if args.command == "verify":
        try:
            import torch
        except ImportError as error:
            raise V5ContractError("pinned Torch runtime is unavailable") from error
        launch = verify_v5_launch_bundle(
            torch, args.resume, args.selected_checkpoint, args.config,
            args.dataset_root, args.dataset_manifest, args.budget_receipt,
            args.budget_supporting_evidence, V5_PHYSICAL_MICROBATCH,
            args.execution_code_sha256, args.requirements_lock,
        )
        print(json.dumps({
            "verified": True,
            "launchBundleSha256": hashlib.sha256(
                canonical_json_bytes(launch)
            ).hexdigest(),
        }, sort_keys=True), flush=True)
        return
    report = run_v5_continuation(
        args.resume, args.selected_checkpoint, args.config, args.dataset_root,
        args.dataset_manifest, args.budget_receipt,
        args.budget_supporting_evidence, args.requirements_lock,
        args.execution_code_sha256, args.cache_root, args.artifact_root,
    )
    print(json.dumps(report, sort_keys=True), flush=True)


if __name__ == "__main__":
    try:
        main()
    except (V5ContractError, TrainingContractError) as error:
        raise SystemExit("error: %s" % error)
