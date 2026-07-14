#!/usr/bin/env python3
"""Export fixed Marian encoder/prefill/step ONNX graphs and verify their contract."""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import os
from pathlib import Path
from typing import Dict, Optional, Sequence


PINNED_REPOSITORY = "Helsinki-NLP/opus-mt_tiny_zho-eng"
PINNED_REVISION = "4ee3a9342aae4ca6fbae82c930b5dccff5dd68dd"
PROTOTYPE_MODEL_SHA256 = "e285c15744265535ce9cbcbb59e4144e2e7c0e6f113f05ca092f8c41f1f6b28a"
REJECTED_DIAGNOSTIC_MODEL_SHA256S = frozenset({
    "c28e7f7f8af8009d634795d2fd012a891695bf59dc134ddf7e50516da9831237",
})
FLORES_REPOSITORY = "openlanguagedata/flores_plus"
FLORES_REVISION = "b3a5298db5721c8a682e7ef00a37fcc9ab522757"
FLORES_PATHS = {"devtest/cmn_Hans.jsonl", "devtest/eng_Latn.jsonl"}
PYTORCH_ONNX_MAX_ABS = 0.03
DECODER_PYTORCH_ONNX_MAX_ABS = 0.03
LOCAL_LEARNING_LIMITATIONS = (
    "manual-quality-gate-not-passed",
    "flores-plus-access-gated",
    "local-learning-only-not-production-approved",
    "device-functionality-not-validated",
)
LOCAL_LEARNING_USER_AUTHORIZATION = {
    "purpose": "local-learning",
    "repositoryVisibility": "private",
    "modelCommitAllowed": True,
}
V5_EVALUATOR_CODE_SHA256 = "e331e9bed826c3b8c94f8db4c5e74d0a67a09957769994547908626d7db39971"
V5_EVALUATION_REPORT_SHA256 = "5999214747b78cf23d1895acb7dc479f786fb982810c1b69a807e6a4d9003b2c"
V5_EVALUATION_MANIFEST_SHA256 = "651da63181c1bbfed7a3dccabf1734d838fd0d857cd5d0850de01890d7592b39"
V5_EVALUATION_BUDGET_SHA256 = "bc1f9d8fad59530b4f47ceb054b9dab22e4c33877d2255dbf5bd27d8400a7f14"


class ContractError(RuntimeError):
    pass


def _canonical_json_bytes(value: object) -> bytes:
    return (json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":")) + "\n").encode("utf-8")


def _sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with Path(path).open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _file_artifact(path: Path) -> dict:
    path = Path(path)
    return {"path": path.name, "bytes": path.stat().st_size, "sha256": _sha256_file(path)}


def _canonical_report(path: Path, label: str) -> dict:
    path = Path(path)
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeDecodeError, json.JSONDecodeError) as error:
        raise ContractError(f"invalid {label}: {error}") from error
    if not isinstance(value, dict) or path.read_bytes() != _canonical_json_bytes(value):
        raise ContractError(f"{label} must be canonical JSON")
    return value


def _valid_artifact(value: object) -> bool:
    return (
        isinstance(value, dict)
        and set(value) == {"path", "bytes", "sha256"}
        and isinstance(value["path"], str)
        and bool(value["path"])
        and Path(value["path"]).name == value["path"]
        and isinstance(value["bytes"], int)
        and not isinstance(value["bytes"], bool)
        and value["bytes"] > 0
        and isinstance(value["sha256"], str)
        and len(value["sha256"]) == 64
    )


def _valid_row_artifact(value: object, rows: int) -> bool:
    return (
        isinstance(value, dict)
        and set(value) == {"path", "bytes", "sha256", "rows"}
        and value.get("rows") == rows
        and _valid_artifact({name: value[name] for name in ("path", "bytes", "sha256")})
    )


def _require_artifact(path: Path, expected: dict, label: str, rows: Optional[int] = None) -> None:
    path = Path(path).resolve()
    valid = _valid_artifact(expected) if rows is None else _valid_row_artifact(expected, rows)
    actual = _file_artifact(path) if path.is_file() and not path.is_symlink() else None
    if rows is not None and actual is not None:
        actual["rows"] = rows
    if not valid or actual != expected:
        raise ContractError(f"{label} artifact differs")


def load_budget_evidence(path: Path, supporting_evidence_paths=()):
    from tools.translation.diagnose_translation import load_budget_evidence as load

    return load(path, supporting_evidence_paths)


def _native_number(value: object) -> bool:
    return type(value) in (int, float) and math.isfinite(float(value))


def _validate_local_learning_approval_record(approval: object) -> bool:
    if not isinstance(approval, dict) or set(approval) != {
        "releaseChannel", "productionPromotionAllowed", "userAuthorization",
        "limitations", "candidate", "candidateGlobalStep", "candidateAdamWStep",
        "evaluatorCodeSha256", "authorizationReport", "v5Terminal",
        "evaluationReport", "evaluationManifest", "budgetReceipt",
    }:
        return False
    candidate = approval.get("candidate")
    return (
        approval.get("releaseChannel") == "local-learning"
        and approval.get("productionPromotionAllowed") is False
        and approval.get("userAuthorization") == LOCAL_LEARNING_USER_AUTHORIZATION
        and approval.get("limitations") == list(LOCAL_LEARNING_LIMITATIONS)
        and isinstance(candidate, dict)
        and set(candidate) == {"model_sha256", "tokenizer_sha256"}
        and all(
            isinstance(value, str)
            and len(value) == 64
            and all(character in "0123456789abcdef" for character in value)
            for value in candidate.values()
        )
        and type(approval.get("candidateGlobalStep")) is int
        and approval["candidateGlobalStep"] > 0
        and type(approval.get("candidateAdamWStep")) is int
        and approval["candidateAdamWStep"] > 0
        and approval.get("evaluatorCodeSha256") == V5_EVALUATOR_CODE_SHA256
        and approval.get("evaluationReport", {}).get("sha256") == V5_EVALUATION_REPORT_SHA256
        and approval.get("evaluationManifest", {}).get("sha256") == V5_EVALUATION_MANIFEST_SHA256
        and approval.get("budgetReceipt", {}).get("sha256") == V5_EVALUATION_BUDGET_SHA256
        and all(
            _valid_artifact(approval.get(name))
            for name in (
                "authorizationReport", "v5Terminal", "evaluationReport",
                "evaluationManifest", "budgetReceipt",
            )
        )
    )


def validate_local_learning_authorization(
    checkpoint: Optional[Path],
    authorization_report_path: Path,
    v5_terminal_path: Path,
    evaluation_report_path: Path,
    evaluation_manifest_path: Path,
    budget_receipt_path: Path,
    budget_supporting_evidence=(),
) -> dict:
    checkpoint = Path(checkpoint).resolve() if checkpoint is not None else None
    authorization_report_path = Path(authorization_report_path).resolve()
    v5_terminal_path = Path(v5_terminal_path).resolve()
    evaluation_report_path = Path(evaluation_report_path).resolve()
    evaluation_manifest_path = Path(evaluation_manifest_path).resolve()
    budget_receipt_path = Path(budget_receipt_path).resolve()
    supporting = tuple(Path(path).resolve() for path in budget_supporting_evidence)
    authorization = _canonical_report(authorization_report_path, "local-learning authorization")
    expected_authorization_keys = {
        "schemaVersion", "releaseChannel", "productionPromotionAllowed",
        "userAuthorization", "limitations", "candidate", "candidateGlobalStep",
        "candidateAdamWStep", "evaluatorCodeSha256", "v5Terminal",
        "evaluationReport", "evaluationManifest", "budgetReceipt",
    }
    if (
        set(authorization) != expected_authorization_keys
        or authorization.get("schemaVersion") != 1
        or authorization.get("releaseChannel") != "local-learning"
        or authorization.get("productionPromotionAllowed") is not False
        or authorization.get("userAuthorization") != LOCAL_LEARNING_USER_AUTHORIZATION
        or authorization.get("limitations") != list(LOCAL_LEARNING_LIMITATIONS)
        or authorization.get("evaluatorCodeSha256") != V5_EVALUATOR_CODE_SHA256
    ):
        raise ContractError("local-learning authorization cannot grant production promotion")
    _require_artifact(v5_terminal_path, authorization.get("v5Terminal"), "V5 terminal")
    _require_artifact(evaluation_report_path, authorization.get("evaluationReport"), "evaluation report")
    _require_artifact(
        evaluation_manifest_path, authorization.get("evaluationManifest"), "evaluation manifest"
    )
    _require_artifact(budget_receipt_path, authorization.get("budgetReceipt"), "evaluation budget receipt")
    if (
        authorization["evaluationReport"]["sha256"] != V5_EVALUATION_REPORT_SHA256
        or authorization["evaluationManifest"]["sha256"] != V5_EVALUATION_MANIFEST_SHA256
        or authorization["budgetReceipt"]["sha256"] != V5_EVALUATION_BUDGET_SHA256
    ):
        raise ContractError("local-learning release is not bound to the pinned V5 evaluation evidence")

    expected_names = {
        "base_revision.txt", "config.json", "generation_config.json",
        "model.safetensors", "selection.json", "tokenizer.model",
    }
    terminal = _canonical_report(v5_terminal_path, "V5 terminal")
    terminal_candidate = terminal.get("candidate")
    terminal_checkpoint = terminal_candidate.get("checkpoint") if isinstance(terminal_candidate, dict) else None
    candidate_files = terminal_checkpoint.get("files") if isinstance(terminal_checkpoint, dict) else None
    if (
        not isinstance(candidate_files, dict)
        or set(candidate_files) != expected_names
        or any(not _valid_artifact(record) or record["path"] != name for name, record in candidate_files.items())
    ):
        raise ContractError("local-learning candidate file inventory differs")
    if checkpoint is not None:
        try:
            actual_names = {path.name for path in checkpoint.iterdir() if path.is_file()}
        except OSError as error:
            raise ContractError("cannot read local-learning candidate checkpoint") from error
        actual_files = {name: _file_artifact(checkpoint / name) for name in sorted(expected_names)}
        if actual_names != expected_names or actual_files != candidate_files:
            raise ContractError("local-learning candidate file inventory differs")
    candidate = {
        "model_sha256": candidate_files["model.safetensors"]["sha256"],
        "tokenizer_sha256": candidate_files["tokenizer.model"]["sha256"],
    }
    if authorization.get("candidate") != candidate:
        raise ContractError("local-learning authorization candidate differs from checkpoint")

    terminal_step = terminal_candidate.get("globalStep") if isinstance(terminal_candidate, dict) else None
    terminal_adam = terminal_candidate.get("adamWStep") if isinstance(terminal_candidate, dict) else None
    if (
        terminal.get("schema_version") != 1
        or terminal.get("stage") != "translation_v5_original_bist_continuation"
        or terminal.get("status") != "completed"
        or terminal.get("error") is not None
        or terminal.get("finalGlobalStep") != terminal_step
        or terminal.get("adamWStep") != terminal_adam
        or not isinstance(terminal_checkpoint, dict)
        or terminal_checkpoint.get("path") != "checkpoint"
        or terminal_checkpoint.get("files") != candidate_files
        or authorization.get("candidateGlobalStep") != terminal_step
        or authorization.get("candidateAdamWStep") != terminal_adam
    ):
        raise ContractError("completed V5 terminal does not bind the local-learning candidate")
    terminal_budget = terminal.get("budgetReceipt")
    if not _valid_artifact(terminal_budget):
        raise ContractError("V5 terminal budget receipt differs")
    terminal_budget_path = v5_terminal_path.parent / terminal_budget["path"]
    _require_artifact(terminal_budget_path, terminal_budget, "V5 terminal budget receipt")

    evaluation = _canonical_report(evaluation_report_path, "V5 candidate evaluation report")
    expected_evaluation_keys = {
        "schema_version", "identity", "stage", "status", "checkpoint", "dataset",
        "bistTest", "manual", "decode", "runtime", "execution", "priorEvidence",
        "rootEvidence", "gpuLedger", "peakCudaBytes", "artifacts",
    }
    evaluation_checkpoint = evaluation.get("checkpoint")
    dataset = evaluation.get("dataset")
    manual = evaluation.get("manual")
    artifacts = evaluation.get("artifacts")
    selection = evaluation_checkpoint.get("selection") if isinstance(evaluation_checkpoint, dict) else None
    selection_bytes = _canonical_json_bytes(selection) if isinstance(selection, dict) else b""
    selection_artifact = {
        "path": "selection.json",
        "bytes": len(selection_bytes),
        "sha256": hashlib.sha256(selection_bytes).hexdigest(),
    }
    if (
        set(evaluation) != expected_evaluation_keys
        or evaluation.get("schema_version") != 1
        or evaluation.get("identity") != "v5-final-candidate"
        or evaluation.get("stage") != "translation_v5_candidate_quality_evaluation"
        or evaluation.get("status") != "completed"
        or not isinstance(evaluation_checkpoint, dict)
        or set(evaluation_checkpoint) != {"globalStep", "adamWStep", "files", "selection"}
        or evaluation_checkpoint.get("globalStep") != terminal_step
        or evaluation_checkpoint.get("adamWStep") != terminal_adam
        or evaluation_checkpoint.get("files") != candidate_files
        or selection_artifact != candidate_files["selection.json"]
        or dataset != {
            "repo": "Mxode/BiST",
            "revision": "aca6be897afc319f779009379c8b849c1eb8d63e",
            "testRowsPerDirection": 5000,
        }
        or manual != {
            "rows": 100,
            "mode": "raw-model-outputs-with-automatic-corruption-flags-only",
        }
        or not isinstance(evaluation.get("runtime"), dict)
        or not evaluation["runtime"]
        or not isinstance(evaluation.get("execution"), dict)
        or not evaluation["execution"]
        or evaluation["execution"].get("evaluatorCodeSha256") != V5_EVALUATOR_CODE_SHA256
        or type(evaluation.get("peakCudaBytes")) is not int
        or evaluation["peakCudaBytes"] < 0
        or not isinstance(artifacts, dict)
        or set(artifacts) != {"bistTestOutputs", "manualRawResults", "budgetReceipt"}
    ):
        raise ContractError("V5 candidate evaluation contract differs")
    metrics = evaluation.get("bistTest")
    if not isinstance(metrics, dict) or set(metrics) != {"zh-en", "en-zh"}:
        raise ContractError("V5 candidate evaluation metrics differ")
    for direction in ("zh-en", "en-zh"):
        values = metrics[direction]
        if (
            not isinstance(values, dict)
            or not {"bleu", "chrf2"}.issubset(values)
            or not _native_number(values["bleu"])
            or not _native_number(values["chrf2"])
        ):
            raise ContractError("V5 candidate evaluation metrics differ")
    _require_artifact(
        evaluation_report_path.parent / artifacts["bistTestOutputs"]["path"],
        artifacts["bistTestOutputs"], "BiST evaluation outputs", rows=10000,
    )
    _require_artifact(
        evaluation_report_path.parent / artifacts["manualRawResults"]["path"],
        artifacts["manualRawResults"], "manual raw evaluation outputs", rows=100,
    )
    if artifacts["budgetReceipt"] != authorization["budgetReceipt"]:
        raise ContractError("evaluation budget receipt differs from authorization")

    evaluation_manifest = _canonical_report(
        evaluation_manifest_path, "V5 candidate evaluation manifest"
    )
    manifest_inputs = evaluation_manifest.get("inputs")
    manifest_outputs = evaluation_manifest.get("outputs")
    expected_checkpoint_inputs = {
        "checkpoint_" + name.replace(".", "_").replace("-", "_"): record
        for name, record in candidate_files.items()
    }
    if (
        evaluation_manifest.get("schema_version") != 1
        or evaluation_manifest.get("identity") != "v5-final-candidate"
        or evaluation_manifest.get("stage") != "translation_v5_candidate_quality_evaluation"
        or not isinstance(manifest_inputs, dict)
        or not isinstance(manifest_outputs, dict)
        or set(manifest_outputs) != {
            "bist_test_outputs", "manual_raw_results", "budget_receipt", "quality_report"
        }
        or manifest_outputs.get("bist_test_outputs") != artifacts["bistTestOutputs"]
        or manifest_outputs.get("manual_raw_results") != artifacts["manualRawResults"]
        or manifest_outputs.get("budget_receipt") != artifacts["budgetReceipt"]
        or manifest_outputs.get("quality_report") != authorization["evaluationReport"]
        or manifest_inputs.get("v5_terminal") != authorization["v5Terminal"]
        or manifest_inputs.get("v5_budget_terminal") != terminal_budget
        or not isinstance(manifest_inputs.get("evaluator_code"), dict)
        or manifest_inputs["evaluator_code"].get("sha256") != V5_EVALUATOR_CODE_SHA256
        or any(manifest_inputs.get(name) != record for name, record in expected_checkpoint_inputs.items())
    ):
        raise ContractError("V5 candidate complete evaluation manifest differs")

    receipt = _canonical_report(budget_receipt_path, "evaluation budget receipt")
    ledger = evaluation.get("gpuLedger")
    if (
        set(receipt) != {
            "schema_version", "stage", "status", "priorEvidence", "rootEvidence",
            "priorCumulativeSeconds", "evaluationActualSeconds", "cumulativeActualSeconds",
            "totalBudgetSeconds", "remainingSeconds", "error",
        }
        or receipt.get("schema_version") != 1
        or receipt.get("stage") != evaluation["stage"]
        or receipt.get("status") != "completed"
        or receipt.get("error") is not None
        or receipt.get("priorEvidence") != terminal_budget
        or receipt.get("priorEvidence") != evaluation.get("priorEvidence")
        or receipt.get("rootEvidence") != terminal.get("rootEvidence")
        or receipt.get("rootEvidence") != evaluation.get("rootEvidence")
        or ledger != receipt
        or not all(_native_number(receipt[name]) for name in (
            "priorCumulativeSeconds", "evaluationActualSeconds", "cumulativeActualSeconds",
            "totalBudgetSeconds", "remainingSeconds",
        ))
        or receipt["priorCumulativeSeconds"] + receipt["evaluationActualSeconds"]
        != receipt["cumulativeActualSeconds"]
        or receipt["totalBudgetSeconds"] - receipt["cumulativeActualSeconds"]
        != receipt["remainingSeconds"]
        or receipt["remainingSeconds"] < 0
    ):
        raise ContractError("evaluation budget evidence chain differs")
    try:
        budget = load_budget_evidence(budget_receipt_path, supporting)
    except Exception as error:
        raise ContractError("cannot verify recursive local-learning budget evidence") from error
    if (
        budget.get("artifact") != authorization["budgetReceipt"]
        or budget.get("rootEvidence") != evaluation["rootEvidence"]
        or budget.get("cumulativeActualSeconds") != receipt["cumulativeActualSeconds"]
        or budget.get("totalBudgetSeconds") != receipt["totalBudgetSeconds"]
    ):
        raise ContractError("recursive local-learning budget evidence differs")

    approval = {
        "releaseChannel": "local-learning",
        "productionPromotionAllowed": False,
        "userAuthorization": LOCAL_LEARNING_USER_AUTHORIZATION,
        "limitations": list(LOCAL_LEARNING_LIMITATIONS),
        "candidate": candidate,
        "candidateGlobalStep": terminal_step,
        "candidateAdamWStep": terminal_adam,
        "evaluatorCodeSha256": V5_EVALUATOR_CODE_SHA256,
        "authorizationReport": _file_artifact(authorization_report_path),
        "v5Terminal": authorization["v5Terminal"],
        "evaluationReport": authorization["evaluationReport"],
        "evaluationManifest": authorization["evaluationManifest"],
        "budgetReceipt": authorization["budgetReceipt"],
    }
    if not _validate_local_learning_approval_record(approval):
        raise ContractError("local-learning approval record differs")
    return approval


def load_profile(contract_path: Path, profile_name: str) -> dict:
    try:
        contract = json.loads(Path(contract_path).read_text(encoding="utf-8"))
        profile = contract["profiles"][profile_name]
    except (OSError, json.JSONDecodeError, KeyError, TypeError) as error:
        raise ContractError(f"unknown or invalid contract profile: {profile_name}") from error
    if contract.get("schemaVersion") != 1:
        raise ContractError("unsupported contract schema")
    return profile


def validate_graph_contract(expected: dict, actual: dict, graph_name: str) -> None:
    if expected != actual:
        raise ContractError(
            f"{graph_name} graph contract mismatch\n"
            f"expected={json.dumps(expected, sort_keys=True)}\n"
            f"actual={json.dumps(actual, sort_keys=True)}"
        )


def _inspect_onnx(path: Path) -> tuple[dict, list[dict]]:
    import onnx

    model = onnx.load(str(path))
    initializer_names = {item.name for item in model.graph.initializer}

    def tensor_map(values) -> dict:
        result = {}
        for value in values:
            tensor = value.type.tensor_type
            shape = []
            for dimension in tensor.shape.dim:
                if not dimension.HasField("dim_value"):
                    raise ContractError(f"dynamic dimension in {path.name}: {value.name}")
                shape.append(dimension.dim_value)
            result[value.name] = {
                "dtype": onnx.TensorProto.DataType.Name(tensor.elem_type),
                "shape": shape,
            }
        return result

    inputs = [value for value in model.graph.input if value.name not in initializer_names]
    contract = {"inputs": tensor_map(inputs), "outputs": tensor_map(model.graph.output)}
    nodes = [
        {"opType": node.op_type, "inputs": list(node.input), "outputs": list(node.output)}
        for node in model.graph.node
    ]
    return contract, nodes


def _validate_stable_softmax(nodes: list[dict], graph_name: str, expected_chains: int) -> None:
    operators = [node["opType"] for node in nodes]
    if "Softmax" in operators:
        raise ContractError(f"{graph_name} contains forbidden native Softmax")
    for operator in ("ReduceMax", "Exp", "ReduceSum", "Div"):
        if operators.count(operator) != expected_chains:
            raise ContractError(
                f"{graph_name} stable softmax dataflow expected {expected_chains} {operator} nodes, "
                f"got {operators.count(operator)}"
            )

    producers = {}
    for node in nodes:
        for output in node["outputs"]:
            if output in producers:
                raise ContractError(f"{graph_name} stable softmax dataflow has duplicate producer: {output}")
            producers[output] = node

    chains = 0
    for divide in (node for node in nodes if node["opType"] == "Div"):
        if len(divide["inputs"]) != 2:
            continue
        exponent = producers.get(divide["inputs"][0])
        denominator = producers.get(divide["inputs"][1])
        if not exponent or exponent["opType"] != "Exp" or not denominator or denominator["opType"] != "ReduceSum":
            continue
        if len(exponent["inputs"]) != 1 or len(exponent["outputs"]) != 1:
            continue
        if not denominator["inputs"] or denominator["inputs"][0] != exponent["outputs"][0]:
            continue
        subtract = producers.get(exponent["inputs"][0])
        if not subtract or subtract["opType"] != "Sub" or len(subtract["inputs"]) != 2:
            continue
        maximum = producers.get(subtract["inputs"][1])
        if not maximum or maximum["opType"] != "ReduceMax" or len(maximum["inputs"]) != 1:
            continue
        if subtract["inputs"][0] != maximum["inputs"][0]:
            continue
        chains += 1
    if chains != expected_chains:
        raise ContractError(
            f"{graph_name} stable softmax dataflow expected {expected_chains} complete chains, got {chains}"
        )


def _checkpoint_revision(checkpoint: Path) -> Optional[str]:
    metadata = checkpoint / ".cache" / "huggingface" / "download" / "config.json.metadata"
    if metadata.is_file():
        return metadata.read_text(encoding="utf-8").splitlines()[0].strip()
    provenance = checkpoint / "base_revision.txt"
    if provenance.is_file():
        return provenance.read_text(encoding="utf-8").strip()
    return None


def _validate_candidate_approval(
    checkpoint: Path,
    training_report_path: Path,
    quality_gate_report_path: Path,
) -> dict:
    training = _canonical_report(training_report_path, "training report")
    gate = _canonical_report(quality_gate_report_path, "quality gate report")
    training_keys = {
        "schema_version", "epoch", "seed", "plan_epoch_index", "optimizer_reset",
        "rescue_steps", "logical_batches", "dropped_partial_logical_batches",
        "validation_history", "baseline_validation_loss", "best_rescue_step",
        "best_validation_loss", "candidate_checkpoint", "candidate",
        "promotion_allowed", "promotion_status", "resumed",
        "teacher_generation_gpu_seconds", "probe_gpu_seconds", "rescue_gpu_seconds",
        "epoch_gpu_seconds", "cumulative_gpu_seconds", "gpuLedger",
        "training_view_manifest_sha256", "distillation_manifest_sha256",
        "peak_cuda_bytes", "last_progress", "objective_hashes",
        "replayed_from_baseline", "replayed_optimizer_steps", "baseline_replay_receipt",
    }
    gate_keys = {
        "schema_version", "epoch2_allowed", "epoch2_launch_allowed", "epoch2_status",
        "promotion_allowed", "candidate", "candidateEpoch", "trainingReport",
        "objectiveHashes", "manualAsset", "manualResults", "manual", "flores",
    }
    if set(training) != training_keys or set(gate) != gate_keys:
        raise ContractError("candidate approval report schema differs")
    epoch = training.get("epoch")
    candidate = training.get("candidate")
    objective = training.get("objective_hashes")
    if (
        training.get("schema_version") != 1
        or isinstance(epoch, bool)
        or epoch not in (1, 2)
        or training.get("candidate_checkpoint") != f"candidate-epoch{epoch}/selected"
        or not isinstance(candidate, dict)
        or set(candidate) != {"model_sha256", "tokenizer_sha256"}
        or training.get("best_rescue_step") is None
        or training.get("promotion_allowed") is not False
        or training.get("promotion_status") != "pending_manual_and_flores_gate"
        or not isinstance(training.get("replayed_from_baseline"), bool)
        or isinstance(training.get("replayed_optimizer_steps"), bool)
        or not isinstance(training.get("replayed_optimizer_steps"), int)
        or training.get("replayed_optimizer_steps") < 0
        or (
            training.get("replayed_from_baseline")
            and not _valid_artifact(training.get("baseline_replay_receipt"))
        )
        or (
            not training.get("replayed_from_baseline")
            and (training.get("replayed_optimizer_steps") != 0 or training.get("baseline_replay_receipt") is not None)
        )
        or not isinstance(objective, dict)
        or not objective
        or any(not isinstance(value, str) or len(value) != 64 for value in objective.values())
    ):
        raise ContractError("training report does not bind a strict-best candidate")
    expected_candidate = {
        "model_sha256": _sha256_file(Path(checkpoint) / "model.safetensors"),
        "tokenizer_sha256": _sha256_file(Path(checkpoint) / "tokenizer.model"),
    }
    if candidate != expected_candidate:
        raise ContractError("training report candidate differs from checkpoint")
    manual = gate.get("manual")
    manual_passed = (
        isinstance(manual, dict)
        and set(manual) == {"zh-en", "en-zh"}
        and all(
            isinstance(manual.get(direction), dict)
            and set(manual[direction]) == {"total", "passed", "fatal_corruptions"}
            and manual[direction]["total"] == 50
            and isinstance(manual[direction]["passed"], int)
            and not isinstance(manual[direction]["passed"], bool)
            and 45 <= manual[direction]["passed"] <= 50
            and manual[direction]["fatal_corruptions"] == 0
            for direction in ("zh-en", "en-zh")
        )
    )
    flores = gate.get("flores")
    flores_passed = False
    if isinstance(flores, dict) and set(flores) == {"repo", "revision", "files", "metrics"}:
        files = flores.get("files")
        metrics = flores.get("metrics")
        if (
            flores.get("repo") == FLORES_REPOSITORY
            and flores.get("revision") == FLORES_REVISION
            and isinstance(files, list)
            and len(files) == 2
            and all(
                isinstance(item, dict)
                and set(item) == {"language", "path", "bytes", "sha256"}
                and item["path"] in FLORES_PATHS
                and isinstance(item["bytes"], int)
                and not isinstance(item["bytes"], bool)
                and item["bytes"] > 0
                and isinstance(item["sha256"], str)
                and len(item["sha256"]) == 64
                for item in files
            )
            and {item["path"] for item in files} == FLORES_PATHS
            and isinstance(metrics, dict)
            and set(metrics) == {"zh-en", "en-zh"}
        ):
            thresholds = {"zh-en": (19.0, 49.0), "en-zh": (17.0, 40.0)}
            flores_passed = all(
                isinstance(metrics.get(direction), dict)
                and set(metrics[direction]) == {"bleu", "chrf2"}
                and all(
                    isinstance(metrics[direction][name], (int, float))
                    and not isinstance(metrics[direction][name], bool)
                    and math.isfinite(float(metrics[direction][name]))
                    for name in ("bleu", "chrf2")
                )
                and float(metrics[direction]["bleu"]) >= thresholds[direction][0]
                and float(metrics[direction]["chrf2"]) >= thresholds[direction][1]
                for direction in ("zh-en", "en-zh")
            )
    if (
        gate.get("schema_version") != 1
        or gate.get("promotion_allowed") is not True
        or gate.get("candidate") != candidate
        or gate.get("candidateEpoch") != epoch
        or gate.get("trainingReport") != _file_artifact(training_report_path)
        or gate.get("objectiveHashes") != objective
        or not _valid_artifact(gate.get("manualAsset"))
        or not _valid_artifact(gate.get("manualResults"))
        or not manual_passed
        or not flores_passed
    ):
        raise ContractError("quality gate does not approve the exported candidate")
    return {
        "candidate": candidate,
        "candidateEpoch": epoch,
        "objectiveHashes": objective,
        "trainingReport": _file_artifact(training_report_path),
        "qualityGateReport": _file_artifact(quality_gate_report_path),
    }


def _validate_checkpoint(
    checkpoint: Path,
    profile: dict,
    profile_name: str,
    training_report_path: Optional[Path] = None,
    quality_gate_report_path: Optional[Path] = None,
    local_learning_authorization_path: Optional[Path] = None,
    v5_terminal_path: Optional[Path] = None,
    evaluation_report_path: Optional[Path] = None,
    evaluation_manifest_path: Optional[Path] = None,
    budget_receipt_path: Optional[Path] = None,
    budget_supporting_evidence=(),
) -> Optional[dict]:
    config_path = checkpoint / "config.json"
    if not config_path.is_file() or not (checkpoint / "model.safetensors").is_file():
        raise ContractError("checkpoint must contain config.json and model.safetensors")
    model_sha256 = _sha256_file(checkpoint / "model.safetensors")
    if model_sha256 in REJECTED_DIAGNOSTIC_MODEL_SHA256S:
        raise ContractError("all export profiles reject known rejected diagnostic models")
    config = json.loads(config_path.read_text(encoding="utf-8"))
    expected = {
        "vocab_size": profile["vocabSize"],
        "decoder_vocab_size": profile["vocabSize"],
        "d_model": 256,
        "encoder_layers": 6,
        "decoder_layers": 2,
        "encoder_attention_heads": 8,
        "decoder_attention_heads": 8,
    }
    wrong = {name: (config.get(name), value) for name, value in expected.items() if config.get(name) != value}
    if wrong:
        raise ContractError(f"checkpoint config mismatch for {profile_name}: {wrong}")
    revision = _checkpoint_revision(checkpoint)
    if revision != PINNED_REVISION:
        raise ContractError(f"checkpoint revision mismatch: expected {PINNED_REVISION}, got {revision}")
    if profile_name == "final":
        if not (checkpoint / "tokenizer.model").is_file():
            raise ContractError("final checkpoint must contain tokenizer.model")
        production = (training_report_path, quality_gate_report_path)
        local_learning = (
            local_learning_authorization_path, v5_terminal_path,
            evaluation_report_path, evaluation_manifest_path, budget_receipt_path,
        )
        if all(path is not None for path in production) and all(path is None for path in local_learning):
            return _validate_candidate_approval(
                checkpoint, Path(training_report_path), Path(quality_gate_report_path)
            )
        if all(path is None for path in production) and all(path is not None for path in local_learning):
            return validate_local_learning_authorization(
                checkpoint,
                Path(local_learning_authorization_path),
                Path(v5_terminal_path),
                Path(evaluation_report_path),
                Path(evaluation_manifest_path),
                Path(budget_receipt_path),
                budget_supporting_evidence,
            )
        raise ContractError(
            "final export requires canonical production quality approval or complete local-learning authorization"
        )
    if any(path is not None for path in (
        training_report_path, quality_gate_report_path, local_learning_authorization_path,
        v5_terminal_path, evaluation_report_path, evaluation_manifest_path, budget_receipt_path,
    )) or budget_supporting_evidence:
        raise ContractError("prototype export rejects final release approval reports")
    if model_sha256 != PROTOTYPE_MODEL_SHA256:
        raise ContractError("prototype checkpoint model is outside the pinned allowlist")
    return None


def download_pinned_checkpoint(download_root: Path) -> Path:
    from huggingface_hub import snapshot_download

    download_root = Path(download_root).resolve()
    repository_root = Path(__file__).resolve().parents[2]
    if download_root == repository_root or repository_root in download_root.parents:
        raise ContractError("checkpoint/cache downloads must stay outside the repository")
    download_root.mkdir(parents=True, exist_ok=True)
    snapshot_download(
        repo_id=PINNED_REPOSITORY,
        revision=PINNED_REVISION,
        local_dir=str(download_root),
        cache_dir=str(download_root / ".hf-cache"),
        allow_patterns=("config.json", "model.safetensors"),
    )
    return download_root


def _wrappers(torch):
    nn = torch.nn

    def stable_softmax(value):
        maximum = torch.amax(value, dim=-1, keepdim=True)
        numerator = torch.exp(value - maximum)
        return numerator / torch.sum(numerator, dim=-1, keepdim=True)

    def additive_mask(mask, dtype):
        return (1.0 - mask[:, None, None, :].to(dtype)) * torch.finfo(dtype).min

    def project(module, hidden, projection):
        value = projection(hidden)
        return value.view(value.shape[0], value.shape[1], module.num_heads, module.head_dim).transpose(1, 2)

    def attention(module, query_hidden, key_hidden, mask, past_key=None, past_value=None, cached=None):
        query = project(module, query_hidden, module.q_proj)
        if cached is None:
            new_key = project(module, key_hidden, module.k_proj)
            new_value = project(module, key_hidden, module.v_proj)
            key = torch.cat((past_key, new_key), dim=2) if past_key is not None else new_key
            value = torch.cat((past_value, new_value), dim=2) if past_value is not None else new_value
        else:
            key, value = cached
            new_key, new_value = key, value
        scores = torch.matmul(query, key.transpose(2, 3)) * module.scaling
        if mask is not None:
            scores = scores + mask
        output = torch.matmul(stable_softmax(scores), value)
        output = output.transpose(1, 2).contiguous().reshape(query_hidden.shape[0], query_hidden.shape[1], -1)
        return module.out_proj(output), new_key, new_value

    def feed_forward(layer, hidden):
        residual = hidden
        hidden = layer.activation_fn(layer.fc1(hidden))
        hidden = layer.fc2(hidden)
        return layer.final_layer_norm(residual + hidden)

    class Encoder(nn.Module):
        def __init__(self, model):
            super().__init__()
            self.encoder = model.model.encoder

        def forward(self, input_ids, attention_mask):
            hidden = self.encoder.embed_tokens(input_ids.to(torch.int64)) * self.encoder.embed_scale
            hidden = hidden + self.encoder.embed_positions(hidden.shape[:-1])
            mask = additive_mask(attention_mask, hidden.dtype)
            for layer in self.encoder.layers:
                residual = hidden
                attended, _, _ = attention(layer.self_attn, hidden, hidden, mask)
                hidden = layer.self_attn_layer_norm(residual + attended)
                hidden = feed_forward(layer, hidden)
            return hidden

    class DecoderBase(nn.Module):
        def __init__(self, model):
            super().__init__()
            self.decoder = model.model.decoder
            self.lm_head = model.lm_head
            self.register_buffer("final_logits_bias", model.final_logits_bias)

        def embed(self, input_ids, position_id):
            hidden = self.decoder.embed_tokens(input_ids.to(torch.int64)) * self.decoder.embed_scale
            positions = self.decoder.embed_positions(hidden.shape[:-1], position_ids=position_id.to(torch.int64))
            return hidden + positions

        def finish(self, hidden):
            return self.lm_head(hidden)[:, -1, :] + self.final_logits_bias

    class Prefill(DecoderBase):
        def forward(self, decoder_input_ids, encoder_hidden_states, encoder_attention_mask):
            position = torch.zeros((1,), dtype=torch.int64, device=decoder_input_ids.device)
            hidden = self.embed(decoder_input_ids, position)
            cross_mask = additive_mask(encoder_attention_mask, hidden.dtype)
            caches = []
            for layer in self.decoder.layers:
                residual = hidden
                attended, self_key, self_value = attention(layer.self_attn, hidden, hidden, None)
                hidden = layer.self_attn_layer_norm(residual + attended)
                residual = hidden
                attended, cross_key, cross_value = attention(
                    layer.encoder_attn, hidden, encoder_hidden_states, cross_mask
                )
                hidden = layer.encoder_attn_layer_norm(residual + attended)
                hidden = feed_forward(layer, hidden)
                caches.extend((self_key, self_value, cross_key, cross_value))
            return (self.finish(hidden), *caches)

    class Step(DecoderBase):
        def forward(self, decoder_input_ids, position_id, self_attention_mask, cross_attention_mask, *caches):
            hidden = self.embed(decoder_input_ids, position_id)
            self_mask = additive_mask(self_attention_mask, hidden.dtype)
            cross_mask = additive_mask(cross_attention_mask, hidden.dtype)
            outputs = []
            for index, layer in enumerate(self.decoder.layers):
                past_key, past_value, cross_key, cross_value = caches[index * 4 : index * 4 + 4]
                residual = hidden
                attended, new_key, new_value = attention(
                    layer.self_attn, hidden, hidden, self_mask, past_key, past_value
                )
                hidden = layer.self_attn_layer_norm(residual + attended)
                residual = hidden
                attended, _, _ = attention(
                    layer.encoder_attn, hidden, hidden, cross_mask, cached=(cross_key, cross_value)
                )
                hidden = layer.encoder_attn_layer_norm(residual + attended)
                hidden = feed_forward(layer, hidden)
                outputs.extend((new_key, new_value))
            return (self.finish(hidden), *outputs)

    return Encoder, Prefill, Step


def _numpy_outputs(values) -> list:
    import numpy as np

    if not isinstance(values, tuple):
        values = (values,)
    outputs = [value.detach().cpu().numpy() for value in values]
    if not all(np.isfinite(value).all() for value in outputs):
        raise ContractError("PyTorch produced non-finite tensors")
    return outputs


def _export_one(torch, wrapper, inputs, names, output_names, path: Path, max_abs: float) -> list:
    wrapper.eval()
    with torch.no_grad():
        expected = _numpy_outputs(wrapper(*inputs))
    torch.onnx.export(
        wrapper,
        inputs,
        str(path),
        input_names=names,
        output_names=output_names,
        opset_version=17,
        do_constant_folding=True,
        dynamo=False,
    )
    import numpy as np
    import onnxruntime as ort

    session_options = ort.SessionOptions()
    session_options.graph_optimization_level = ort.GraphOptimizationLevel.ORT_DISABLE_ALL
    session_options.execution_mode = ort.ExecutionMode.ORT_SEQUENTIAL
    session_options.intra_op_num_threads = 1
    session_options.inter_op_num_threads = 1
    session = ort.InferenceSession(str(path), sess_options=session_options, providers=["CPUExecutionProvider"])
    actual = session.run(None, {name: value.detach().cpu().numpy() for name, value in zip(names, inputs)})
    for name, reference, candidate in zip(output_names, expected, actual):
        if not np.isfinite(candidate).all():
            raise ContractError(f"{path.name}:{name} produced non-finite ONNX output")
        error = float(np.max(np.abs(reference.astype(np.float32) - candidate.astype(np.float32))))
        if error > max_abs:
            raise ContractError(
                f"{path.name}:{name} PyTorch/ONNX max_abs {error} > {max_abs}"
            )
    return actual


def export_graphs(
    checkpoint: Path,
    output_root: Path,
    contract_path: Path,
    profile_name: str,
    training_report_path: Optional[Path] = None,
    quality_gate_report_path: Optional[Path] = None,
    local_learning_authorization_path: Optional[Path] = None,
    v5_terminal_path: Optional[Path] = None,
    evaluation_report_path: Optional[Path] = None,
    evaluation_manifest_path: Optional[Path] = None,
    budget_receipt_path: Optional[Path] = None,
    budget_supporting_evidence=(),
) -> dict:
    import numpy as np
    import torch
    from transformers import MarianMTModel

    profile = load_profile(contract_path, profile_name)
    approval = _validate_checkpoint(
        checkpoint,
        profile,
        profile_name,
        training_report_path,
        quality_gate_report_path,
        local_learning_authorization_path,
        v5_terminal_path,
        evaluation_report_path,
        evaluation_manifest_path,
        budget_receipt_path,
        budget_supporting_evidence,
    )
    output_root = output_root.resolve()
    repository_root = Path(__file__).resolve().parents[2]
    if output_root == repository_root or repository_root in output_root.parents:
        raise ContractError("large generated artifacts must be outside the repository")
    output_root.mkdir(parents=True, exist_ok=True)

    model = MarianMTModel.from_pretrained(
        str(checkpoint), local_files_only=True, dtype=torch.float16, attn_implementation="eager"
    ).eval()
    Encoder, Prefill, Step = _wrappers(torch)
    encoder, prefill, step = Encoder(model), Prefill(model), Step(model)
    length = profile["maxTokens"]
    vocab = profile["vocabSize"]
    generator = torch.Generator().manual_seed(20260713)
    input_ids = torch.randint(2, min(vocab - 1, 1000), (1, length), dtype=torch.int32, generator=generator)
    input_ids[:, -1] = 0
    encoder_mask = torch.ones((1, length), dtype=torch.int32)
    decoder_ids = torch.tensor([[model.config.decoder_start_token_id]], dtype=torch.int32)

    graph_inputs = {}
    encoder_outputs = _export_one(
        torch, encoder, (input_ids, encoder_mask), ["input_ids", "attention_mask"],
        ["last_hidden_state"], output_root / "encoder.onnx", PYTORCH_ONNX_MAX_ABS
    )
    hidden = torch.from_numpy(encoder_outputs[0])
    prefill_names = ["logits"]
    for layer in range(2):
        prefill_names.extend((f"self_key_{layer}", f"self_value_{layer}", f"cross_key_{layer}", f"cross_value_{layer}"))
    prefill_outputs = _export_one(
        torch, prefill, (decoder_ids, hidden, encoder_mask),
        ["decoder_input_ids", "encoder_hidden_states", "encoder_attention_mask"], prefill_names,
        output_root / "decoder_prefill.onnx", DECODER_PYTORCH_ONNX_MAX_ABS
    )
    history = []
    for layer in range(2):
        past_key = torch.zeros((1, 8, length - 1, 32), dtype=torch.float16)
        past_value = torch.zeros_like(past_key)
        past_key[:, :, 0:1, :] = torch.from_numpy(prefill_outputs[1 + layer * 4])
        past_value[:, :, 0:1, :] = torch.from_numpy(prefill_outputs[2 + layer * 4])
        history.extend((past_key, past_value, torch.from_numpy(prefill_outputs[3 + layer * 4]), torch.from_numpy(prefill_outputs[4 + layer * 4])))
    self_mask = torch.zeros((1, length), dtype=torch.int32)
    self_mask[:, 0] = 1
    self_mask[:, -1] = 1
    position = torch.tensor([1], dtype=torch.int32)
    next_ids = torch.from_numpy(np.argmax(prefill_outputs[0], axis=-1).astype(np.int32)).reshape(1, 1)
    step_input_names = ["decoder_input_ids", "position_id", "self_attention_mask", "cross_attention_mask"]
    for layer in range(2):
        step_input_names.extend((f"past_key_{layer}", f"past_value_{layer}", f"cross_key_{layer}", f"cross_value_{layer}"))
    step_output_names = ["logits", "new_key_0", "new_value_0", "new_key_1", "new_value_1"]
    step_inputs = (next_ids, position, self_mask, encoder_mask, *history)
    _export_one(
        torch, step, step_inputs, step_input_names, step_output_names,
        output_root / "decoder_step.onnx", DECODER_PYTORCH_ONNX_MAX_ABS
    )

    for graph_name in ("encoder", "decoder_prefill", "decoder_step"):
        actual, nodes = _inspect_onnx(output_root / f"{graph_name}.onnx")
        validate_graph_contract(profile["graphs"][graph_name], actual, graph_name)
        _validate_stable_softmax(nodes, graph_name, profile["stableSoftmaxChains"][graph_name])
        graph_inputs[graph_name] = actual
    report = {
        "schemaVersion": 1,
        "profile": profile_name,
        "checkpointRevision": PINNED_REVISION,
        "approval": approval,
        "vocabSize": vocab,
        "maxTokens": length,
        "graphs": graph_inputs,
        "pytorchOnnxMaxAbsLimit": PYTORCH_ONNX_MAX_ABS,
        "decoderPytorchOnnxMaxAbsLimit": DECODER_PYTORCH_ONNX_MAX_ABS,
        "stableSoftmax": ["ReduceMax", "Sub", "Exp", "ReduceSum", "Div"],
        "onnxArtifacts": {
            f"{name}.onnx": _file_artifact(output_root / f"{name}.onnx")
            for name in ("encoder", "decoder_prefill", "decoder_step")
        },
    }
    (output_root / "export-report.json").write_bytes(_canonical_json_bytes(report))
    return report


def inspect_exports(output_root: Path, contract_path: Path, profile_name: str) -> dict:
    profile = load_profile(contract_path, profile_name)
    inspected = {}
    for graph_name in ("encoder", "decoder_prefill", "decoder_step"):
        actual, nodes = _inspect_onnx(Path(output_root) / f"{graph_name}.onnx")
        validate_graph_contract(profile["graphs"][graph_name], actual, graph_name)
        _validate_stable_softmax(nodes, graph_name, profile["stableSoftmaxChains"][graph_name])
        inspected[graph_name] = actual
    return {"profile": profile_name, "graphs": inspected}


def verify_export_report(output_root: Path, contract_path: Path, profile_name: str) -> dict:
    output_root = Path(output_root)
    report_path = output_root / "export-report.json"
    report = _canonical_report(report_path, "export report")
    expected_keys = {
        "schemaVersion", "profile", "checkpointRevision", "approval", "vocabSize",
        "maxTokens", "graphs", "pytorchOnnxMaxAbsLimit", "decoderPytorchOnnxMaxAbsLimit",
        "stableSoftmax", "onnxArtifacts",
    }
    profile = load_profile(contract_path, profile_name)
    inspected = inspect_exports(output_root, contract_path, profile_name)
    expected_artifacts = {
        f"{name}.onnx": _file_artifact(output_root / f"{name}.onnx")
        for name in ("encoder", "decoder_prefill", "decoder_step")
    }
    if (
        set(report) != expected_keys
        or report.get("schemaVersion") != 1
        or report.get("profile") != profile_name
        or report.get("checkpointRevision") != PINNED_REVISION
        or report.get("vocabSize") != profile["vocabSize"]
        or report.get("maxTokens") != profile["maxTokens"]
        or report.get("graphs") != inspected["graphs"]
        or report.get("onnxArtifacts") != expected_artifacts
    ):
        raise ContractError("export report does not bind the inspected ONNX graphs")
    approval = report.get("approval")
    if profile_name == "final":
        if isinstance(approval, dict) and approval.get("releaseChannel") == "local-learning":
            if not _validate_local_learning_approval_record(approval):
                raise ContractError("final export report lacks local-learning approval provenance")
        else:
            candidate = approval.get("candidate") if isinstance(approval, dict) else None
            objective = approval.get("objectiveHashes") if isinstance(approval, dict) else None
            artifacts = (
                approval.get("trainingReport") if isinstance(approval, dict) else None,
                approval.get("qualityGateReport") if isinstance(approval, dict) else None,
            )
            if (
                not isinstance(approval, dict)
                or set(approval) != {
                    "candidate", "candidateEpoch", "objectiveHashes",
                    "trainingReport", "qualityGateReport",
                }
                or not isinstance(candidate, dict)
                or set(candidate) != {"model_sha256", "tokenizer_sha256"}
                or any(
                    not isinstance(value, str)
                    or len(value) != 64
                    or any(character not in "0123456789abcdef" for character in value.lower())
                    for value in candidate.values()
                )
                or approval.get("candidateEpoch") not in (1, 2)
                or not isinstance(objective, dict)
                or not objective
                or any(not isinstance(value, str) or len(value) != 64 for value in objective.values())
                or any(not _valid_artifact(artifact) for artifact in artifacts)
            ):
                raise ContractError("final export report lacks candidate approval provenance")
    elif approval is not None:
        raise ContractError("prototype export report contains production approval provenance")
    return report


def encoder_mindspore_parity(
    output_root: Path,
    contract_path: Path,
    profile_name: str,
    mindspore_output: Path,
    valid_tokens: int,
) -> dict:
    """Compare one float MindSpore encoder result with the matching ONNX run."""
    import numpy as np
    import onnxruntime as ort

    profile = load_profile(contract_path, profile_name)
    length = profile["maxTokens"]
    if isinstance(valid_tokens, bool) or not isinstance(valid_tokens, int) or not 1 <= valid_tokens <= length:
        raise ContractError("encoder valid-token count is outside the fixed contract")
    session = ort.InferenceSession(
        str(Path(output_root) / "encoder.onnx"), providers=["CPUExecutionProvider"]
    )
    input_ids = np.arange(length, dtype=np.int32).reshape(1, length)
    attention_mask = np.zeros((1, length), dtype=np.int32)
    attention_mask[:, :valid_tokens] = 1
    reference = session.run(None, {"input_ids": input_ids, "attention_mask": attention_mask})[0].astype(
        np.float32, copy=False
    )
    actual = np.fromfile(Path(mindspore_output), dtype=np.float32)
    if actual.size != reference.size:
        raise ContractError("MindSpore encoder parity output size differs")
    actual = actual.reshape(reference.shape)
    if not np.isfinite(reference).all() or not np.isfinite(actual).all():
        raise ContractError("encoder parity contains non-finite values")
    difference = np.abs(reference - actual)
    return {
        "profile": profile_name,
        "validTokens": valid_tokens,
        "elements": int(difference.size),
        "maxAbs": float(difference.max()),
        "meanAbs": float(difference.mean()),
    }


def onnx_cache_loop(
    output_root: Path,
    contract_path: Path,
    profile_name: str,
    steps: int = 5,
    binary_fixture_root: Optional[Path] = None,
) -> dict:
    import numpy as np
    import onnxruntime as ort

    profile = load_profile(contract_path, profile_name)
    length = profile["maxTokens"]
    if isinstance(steps, bool) or not isinstance(steps, int) or not 1 <= steps < length - 1:
        raise ContractError("cache-loop steps are outside the fixed cache contract")
    sessions = {
        name: ort.InferenceSession(str(Path(output_root) / f"{name}.onnx"), providers=["CPUExecutionProvider"])
        for name in ("encoder", "decoder_prefill", "decoder_step")
    }
    input_ids = np.arange(length, dtype=np.int32).reshape(1, length)
    encoder_mask = np.zeros((1, length), dtype=np.int32)
    encoder_mask[:, : length // 2] = 1
    cross_mask = encoder_mask.copy()
    hidden = sessions["encoder"].run(None, {"input_ids": input_ids, "attention_mask": encoder_mask})[0]
    if binary_fixture_root is not None:
        fixture = Path(binary_fixture_root)
        hidden = np.fromfile(fixture / "pre_01_encoder.bin", dtype=np.float32).reshape(1, length, 256).astype(np.float16)
        cross_mask = np.fromfile(fixture / "pre_02_mask.bin", dtype=np.int32).reshape(1, length)
    prefill = sessions["decoder_prefill"].run(None, {
        "decoder_input_ids": np.array([[32000]], dtype=np.int32),
        "encoder_hidden_states": hidden,
        "encoder_attention_mask": cross_mask,
    })
    if not all(np.isfinite(value).all() for value in (hidden, *prefill)):
        raise ContractError("ONNX cache loop produced non-finite tensors")
    token = int(np.argmax(prefill[0], axis=-1)[0])
    tokens = [token]
    history = []
    for layer in range(2):
        past_key = np.zeros((1, 8, length - 1, 32), dtype=prefill[1 + layer * 4].dtype)
        past_value = np.zeros_like(past_key)
        past_key[:, :, 0:1, :] = prefill[1 + layer * 4]
        past_value[:, :, 0:1, :] = prefill[2 + layer * 4]
        history.extend((past_key, past_value, prefill[3 + layer * 4], prefill[4 + layer * 4]))
    if binary_fixture_root is not None:
        fixture = Path(binary_fixture_root)
        token = int(np.fromfile(fixture / "step_00_ids.bin", dtype=np.int32)[0])
        tokens = [token]
        history = []
        for layer in range(2):
            history.extend((
                np.fromfile(fixture / f"step_{4 + layer * 4:02d}_past_key_{layer}.bin", dtype=np.float32)
                .reshape(1, 8, length - 1, 32).astype(np.float16),
                np.fromfile(fixture / f"step_{5 + layer * 4:02d}_past_value_{layer}.bin", dtype=np.float32)
                .reshape(1, 8, length - 1, 32).astype(np.float16),
                np.fromfile(fixture / f"step_{6 + layer * 4:02d}_cross_key_{layer}.bin", dtype=np.float32)
                .reshape(1, 8, length, 32).astype(np.float16),
                np.fromfile(fixture / f"step_{7 + layer * 4:02d}_cross_value_{layer}.bin", dtype=np.float32)
                .reshape(1, 8, length, 32).astype(np.float16),
            ))
    for position in range(1, steps + 1):
        self_mask = np.zeros((1, length), dtype=np.int32)
        self_mask[:, :position] = 1
        self_mask[:, -1] = 1
        feed = {
            "decoder_input_ids": np.array([[token]], dtype=np.int32),
            "position_id": np.array([position], dtype=np.int32),
            "self_attention_mask": self_mask,
            "cross_attention_mask": cross_mask,
        }
        for layer in range(2):
            offset = layer * 4
            feed[f"past_key_{layer}"] = history[offset]
            feed[f"past_value_{layer}"] = history[offset + 1]
            feed[f"cross_key_{layer}"] = history[offset + 2]
            feed[f"cross_value_{layer}"] = history[offset + 3]
        outputs = sessions["decoder_step"].run(None, feed)
        if not all(np.isfinite(value).all() for value in outputs):
            raise ContractError("ONNX decoder step produced non-finite tensors")
        token = int(np.argmax(outputs[0], axis=-1)[0])
        tokens.append(token)
        if position < length - 1:
            for layer in range(2):
                history[layer * 4][:, :, position : position + 1, :] = outputs[1 + layer * 2]
                history[layer * 4 + 1][:, :, position : position + 1, :] = outputs[2 + layer * 2]
    return {"profile": profile_name, "steps": steps, "tokens": tokens}


def _parse(argv: Optional[Sequence[str]] = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--checkpoint", type=Path)
    parser.add_argument("--download-root", type=Path)
    parser.add_argument("--output-root", required=True, type=Path)
    parser.add_argument("--contract", required=True, type=Path)
    parser.add_argument("--profile", choices=("prototype", "final"), required=True)
    parser.add_argument("--inspect-only", action="store_true")
    parser.add_argument("--verify-export-report", action="store_true")
    parser.add_argument("--cache-loop-only", action="store_true")
    parser.add_argument("--cache-loop-steps", type=int, default=5)
    parser.add_argument("--binary-fixture-root", type=Path)
    parser.add_argument("--encoder-mindspore-output", type=Path)
    parser.add_argument("--encoder-valid-tokens", type=int)
    parser.add_argument("--training-report", type=Path)
    parser.add_argument("--quality-gate-report", type=Path)
    parser.add_argument("--local-learning-authorization", type=Path)
    parser.add_argument("--v5-terminal", type=Path)
    parser.add_argument("--evaluation-report", type=Path)
    parser.add_argument("--evaluation-manifest", type=Path)
    parser.add_argument("--budget-receipt", type=Path)
    parser.add_argument("--budget-supporting-evidence", action="append", type=Path, default=[])
    return parser.parse_args(argv)


def main(argv: Optional[Sequence[str]] = None) -> int:
    args = _parse(argv)
    if args.encoder_mindspore_output is not None:
        if args.encoder_valid_tokens is None:
            raise ContractError("--encoder-valid-tokens is required for encoder parity")
        result = encoder_mindspore_parity(
            args.output_root,
            args.contract,
            args.profile,
            args.encoder_mindspore_output,
            args.encoder_valid_tokens,
        )
    elif args.cache_loop_only:
        result = onnx_cache_loop(
            args.output_root,
            args.contract,
            args.profile,
            steps=args.cache_loop_steps,
            binary_fixture_root=args.binary_fixture_root,
        )
    elif args.verify_export_report:
        result = verify_export_report(args.output_root, args.contract, args.profile)
    elif args.inspect_only:
        result = inspect_exports(args.output_root, args.contract, args.profile)
    else:
        checkpoint = args.checkpoint
        if checkpoint is None:
            if args.download_root is None:
                raise ContractError("provide --checkpoint or an explicit --download-root")
            checkpoint = download_pinned_checkpoint(args.download_root)
        result = export_graphs(
            checkpoint,
            args.output_root,
            args.contract,
            args.profile,
            args.training_report,
            args.quality_gate_report,
            args.local_learning_authorization,
            args.v5_terminal,
            args.evaluation_report,
            args.evaluation_manifest,
            args.budget_receipt,
            args.budget_supporting_evidence,
        )
    print(json.dumps(result, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
