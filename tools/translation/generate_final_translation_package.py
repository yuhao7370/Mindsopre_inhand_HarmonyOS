#!/usr/bin/env python3
"""Generate the deterministic final translation raw assets and package manifest."""

import argparse
import hashlib
import json
import math
import re
import shutil
import struct
import sys
from functools import lru_cache
from pathlib import Path

if __package__ in {None, ""}:
    sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from sentencepiece import sentencepiece_model_pb2

from tools.translation.build_translation_archive import verify_archive
from tools.translation.tokenizer_generate_fixture import (
    MODEL_SHA256,
    MODEL_SIZE,
    _read_c_string,
    _unit_has_leaf,
    _unit_label,
    _unit_offset,
    _unit_value,
)
from tools.translation.verify_translation_package import (
    PACKAGE_LIMIT_BYTES,
    REQUIRED_ASSETS,
    verify_package,
)


VOCABULARY_SIZE = 32003
SOURCE_PIECES = 32000
PAD_ID = 32000
TO_ENGLISH_ID = 32001
TO_CHINESE_ID = 32002
GRAPH_NAMES = ("encoder.ms", "decoder_prefill.ms", "decoder_step.ms")
REPOSITORY_ROOT = Path(__file__).resolve().parents[2]
TRUSTED_LICENSES_SOURCE = REPOSITORY_ROOT / "tools/translation/licenses/translation-runtime-LICENSES.md"
TRUSTED_LICENSES_SHA256 = "d7a83e5077ee1a4285ce3d7130b950b94be923484134c4be9c293da9d4465464"
GATE_KEYS = {
    "schema_version", "epoch2_allowed", "epoch2_launch_allowed", "epoch2_status",
    "promotion_allowed", "candidate", "candidateEpoch", "trainingReport",
    "objectiveHashes", "manualAsset", "manualResults", "manual", "flores",
}
CONVERSION_KEYS = {
    "schemaVersion", "profile", "approval", "exportReport", "onnxArtifacts",
    "quantization", "encoderParity", "cacheLoopSteps", "cacheLoopTokens",
    "referenceCacheLoopTokens", "expectedCacheLoopTokens", "argmaxAgreement",
    "matchingTokens", "models",
}
APPROVAL_KEYS = {
    "candidate", "candidateEpoch", "objectiveHashes", "trainingReport", "qualityGateReport",
}
ARTIFACT_KEYS = {"path", "bytes", "sha256"}


class PackageGenerationError(RuntimeError):
    pass


def _sha256(path):
    digest = hashlib.sha256()
    with Path(path).open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _record(path):
    path = Path(path)
    return {"size": path.stat().st_size, "sha256": _sha256(path)}


def _read_json(path, label):
    try:
        value = json.loads(Path(path).read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise PackageGenerationError("invalid %s: %s" % (label, error)) from error
    if not isinstance(value, dict):
        raise PackageGenerationError("%s must be a JSON object" % label)
    return value


def _write_json(path, value):
    Path(path).write_bytes(_json_bytes(value))


def _json_bytes(value):
    return (json.dumps(value, ensure_ascii=False, indent=2, sort_keys=True) + "\n").encode("utf-8")


def _canonical_json_bytes(value):
    return (json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":")) + "\n").encode("utf-8")


def _canonical_license_bytes(path):
    text = Path(path).read_text(encoding="utf-8")
    return text.replace("\r\n", "\n").replace("\r", "\n").encode("utf-8")


def _is_sha256(value):
    return isinstance(value, str) and re.fullmatch(r"[0-9a-f]{64}", value) is not None


def _artifact(path):
    path = Path(path)
    return {"path": path.name, "bytes": path.stat().st_size, "sha256": _sha256(path)}


def _valid_artifact(record, expected_name=None):
    return (
        isinstance(record, dict)
        and set(record) == ARTIFACT_KEYS
        and isinstance(record.get("path"), str)
        and record["path"] == Path(record["path"]).name
        and (expected_name is None or record["path"] == expected_name)
        and isinstance(record.get("bytes"), int)
        and not isinstance(record["bytes"], bool)
        and record["bytes"] > 0
        and _is_sha256(record.get("sha256"))
    )


def _native_number(value):
    return type(value) in (int, float) and math.isfinite(value)


def _validate_conversion_metrics(conversion):
    if conversion.get("quantization") != {
        "type": "WEIGHT_QUANT",
        "bitNum": 8,
        "minWeightSize": 0,
        "minWeightChannel": 0,
    }:
        raise PackageGenerationError("conversion metric quantization must be the pinned W8 profile")

    steps = conversion.get("cacheLoopSteps")
    actual = conversion.get("cacheLoopTokens")
    reference = conversion.get("referenceCacheLoopTokens")
    if (
        type(steps) is not int
        or steps != 100
        or not isinstance(actual, list)
        or not isinstance(reference, list)
        or len(actual) != 101
        or len(reference) != 101
        or any(type(token) is not int or token < 0 or token >= VOCABULARY_SIZE for token in actual + reference)
        or conversion.get("expectedCacheLoopTokens") is not None
    ):
        raise PackageGenerationError("conversion cache-loop metrics differ from the final 100-step contract")

    matches = sum(left == right for left, right in zip(actual, reference))
    matching_tokens = conversion.get("matchingTokens")
    agreement = conversion.get("argmaxAgreement")
    expected_agreement = matches / 101
    if (
        type(matching_tokens) is not int
        or matching_tokens != matches
        or not _native_number(agreement)
        or agreement != expected_agreement
        or agreement < 0.99
    ):
        raise PackageGenerationError("conversion cache-loop matching/agreement metrics are not reproducible")

    parity = conversion.get("encoderParity")
    expected_parity = (("all-valid", 128), ("half-padding", 64))
    if not isinstance(parity, list) or len(parity) != len(expected_parity):
        raise PackageGenerationError("conversion encoder parity schema differs")
    for record, (name, valid_tokens) in zip(parity, expected_parity):
        if (
            not isinstance(record, dict)
            or set(record) != {"name", "validTokens", "elements", "maxAbs", "meanAbs"}
            or record.get("name") != name
            or type(record.get("validTokens")) is not int
            or record["validTokens"] != valid_tokens
            or type(record.get("elements")) is not int
            or record["elements"] != 32768
            or not _native_number(record.get("maxAbs"))
            or not _native_number(record.get("meanAbs"))
            or record["maxAbs"] < 0
            or record["meanAbs"] < 0
            or record["maxAbs"] > 0.02
            or record["meanAbs"] > 0.002
        ):
            raise PackageGenerationError("conversion encoder parity metrics differ from the final bounds")


def _approved_conversion(quality_gate_report, conversion_report, archive_manifest):
    gate_path = Path(quality_gate_report)
    conversion_path = Path(conversion_report)
    for path, label in ((gate_path, "quality gate report"), (conversion_path, "conversion report")):
        if not path.is_file() or path.is_symlink():
            raise PackageGenerationError("%s is not a regular file" % label)
    gate = _read_json(gate_path, "quality gate report")
    if gate_path.read_bytes() != _canonical_json_bytes(gate):
        raise PackageGenerationError("quality gate report is not canonical gate-v1 JSON")
    candidate = gate.get("candidate")
    objective = gate.get("objectiveHashes")
    if (
        set(gate) != GATE_KEYS
        or gate.get("schema_version") != 1
        or gate.get("promotion_allowed") is not True
        or not isinstance(candidate, dict)
        or set(candidate) != {"model_sha256", "tokenizer_sha256"}
        or not all(_is_sha256(value) for value in candidate.values())
        or candidate.get("tokenizer_sha256") != MODEL_SHA256
        or isinstance(gate.get("candidateEpoch"), bool)
        or gate.get("candidateEpoch") not in (1, 2)
        or not isinstance(objective, dict)
        or not objective
        or not all(isinstance(name, str) and name and _is_sha256(value) for name, value in objective.items())
        or not _valid_artifact(gate.get("trainingReport"))
    ):
        raise PackageGenerationError("quality gate does not approve the pinned final candidate")
    conversion = _read_json(conversion_path, "conversion report")
    approval = conversion.get("approval")
    if (
        set(conversion) != CONVERSION_KEYS
        or conversion.get("schemaVersion") != 1
        or conversion.get("profile") != "final"
        or not isinstance(approval, dict)
        or set(approval) != APPROVAL_KEYS
        or approval.get("candidate") != candidate
        or approval.get("candidateEpoch") != gate["candidateEpoch"]
        or approval.get("objectiveHashes") != objective
        or approval.get("trainingReport") != gate["trainingReport"]
        or approval.get("qualityGateReport") != _artifact(gate_path)
        or not _valid_artifact(conversion.get("exportReport"), "export-report.json")
        or not isinstance(conversion.get("onnxArtifacts"), dict)
        or set(conversion["onnxArtifacts"]) != {"encoder.onnx", "decoder_prefill.onnx", "decoder_step.onnx"}
        or any(not _valid_artifact(record, name) for name, record in conversion["onnxArtifacts"].items())
    ):
        raise PackageGenerationError(
            "conversion report final profile/schema/candidate/quality artifact provenance differs"
        )
    _validate_conversion_metrics(conversion)

    models = conversion.get("models")
    members = archive_manifest.get("members")
    if (
        not isinstance(models, list)
        or not isinstance(members, list)
        or len(models) != len(GRAPH_NAMES)
        or len(members) != len(GRAPH_NAMES)
    ):
        raise PackageGenerationError("conversion models and archive members differ")
    for name, model, member in zip(GRAPH_NAMES, models, members):
        if (
            not isinstance(model, dict)
            or set(model) != {"name", "size", "sha256"}
            or model.get("name") != name
            or model.get("name") != member.get("name")
            or model.get("size") != member.get("size")
            or not isinstance(model.get("sha256"), str)
            or model["sha256"].lower() != str(member.get("sha256", "")).lower()
        ):
            raise PackageGenerationError("conversion model differs from archive member: %s" % name)
    return conversion


def _codepoints(value):
    return "-" if not value else ",".join("%X" % ord(character) for character in value)


def _normalization_rules(precompiled):
    if len(precompiled) < 4:
        raise PackageGenerationError("tokenizer lacks a precompiled normalization map")
    trie_size = struct.unpack_from("<I", precompiled, 0)[0]
    if trie_size == 0 or trie_size % 4 or 4 + trie_size > len(precompiled):
        raise PackageGenerationError("tokenizer normalization trie is invalid")
    units = struct.unpack_from("<%dI" % (trie_size // 4), precompiled, 4)
    strings = precompiled[4 + trie_size :]
    active = set()

    @lru_cache(maxsize=None)
    def suffix_rules(position):
        if position in active:
            raise PackageGenerationError("tokenizer normalization trie contains a cycle")
        active.add(position)
        rules = []
        offset = _unit_offset(units[position])
        for byte in range(256):
            child = position ^ offset ^ byte
            if child >= len(units) or _unit_label(units[child]) != byte:
                continue
            encoded = bytes((byte,))
            unit = units[child]
            if _unit_has_leaf(unit):
                leaf = child ^ _unit_offset(unit)
                if leaf >= len(units):
                    raise PackageGenerationError("tokenizer normalization leaf is invalid")
                rules.append((encoded, _read_c_string(strings, _unit_value(units[leaf]))))
            rules.extend((encoded + suffix, target) for suffix, target in suffix_rules(child))
        active.remove(position)
        return tuple(rules)

    rules = {}
    for encoded, target_bytes in suffix_rules(0):
        try:
            source = encoded.decode("utf-8")
            target = target_bytes.decode("utf-8")
        except UnicodeDecodeError as error:
            raise PackageGenerationError("tokenizer normalization rule is invalid") from error
        if source in rules and rules[source] != target:
            raise PackageGenerationError("tokenizer normalization rule is duplicated")
        rules[source] = target
    if not rules:
        raise PackageGenerationError("tokenizer normalization map is empty")
    return sorted(rules.items(), key=lambda item: tuple(ord(character) for character in item[0]))


def _tokenizer_assets(model_path):
    model_path = Path(model_path)
    payload = model_path.read_bytes()
    if len(payload) != MODEL_SIZE or hashlib.sha256(payload).hexdigest() != MODEL_SHA256:
        raise PackageGenerationError("tokenizer.model is not the pinned 32000-piece model")
    model = sentencepiece_model_pb2.ModelProto()
    model.ParseFromString(payload)
    if model.trainer_spec.model_type != sentencepiece_model_pb2.TrainerSpec.UNIGRAM:
        raise PackageGenerationError("tokenizer model must be Unigram")
    normalizer = model.normalizer_spec
    if (
        normalizer.name != "nmt_nfkc"
        or not normalizer.add_dummy_prefix
        or not normalizer.remove_extra_whitespaces
        or not normalizer.escape_whitespaces
    ):
        raise PackageGenerationError("tokenizer normalizer contract differs")
    if len(model.pieces) != SOURCE_PIECES:
        raise PackageGenerationError("tokenizer must contain exactly 32000 source pieces")

    pieces = []
    vocabulary = {}
    for piece_id, piece in enumerate(model.pieces):
        if piece.piece in vocabulary:
            raise PackageGenerationError("tokenizer piece text is duplicated")
        if piece_id == 0 and (piece.type != 3 or piece.piece != "</s>"):
            raise PackageGenerationError("tokenizer EOS piece differs")
        if piece_id == 1 and (piece.type != 2 or piece.piece != "<unk>"):
            raise PackageGenerationError("tokenizer unknown piece differs")
        if piece_id >= 2 and piece.type != 1:
            raise PackageGenerationError("tokenizer normal piece type differs")
        vocabulary[piece.piece] = piece_id
        pieces.append((piece_id, piece.piece, float(piece.score), int(piece.type)))
    for token in ("<pad>", "<2en>", "<2zh>"):
        if token in vocabulary:
            raise PackageGenerationError("extended vocabulary token already exists: %s" % token)
    vocabulary.update({"<pad>": PAD_ID, "<2en>": TO_ENGLISH_ID, "<2zh>": TO_CHINESE_ID})

    header = "\t".join((
        "TTOK1",
        MODEL_SHA256,
        str(SOURCE_PIECES),
        "1",
        repr(min(piece[2] for piece in pieces)),
        "1",
        "1",
        "1",
    ))
    lines = [header]
    for source, target in _normalization_rules(normalizer.precompiled_charsmap):
        lines.append("N\t%s\t%s" % (_codepoints(source), _codepoints(target)))
    for piece_id, text, score, piece_type in pieces:
        lines.append("P\t%d\t%s\t%d\t%s" % (piece_id, repr(score), piece_type, _codepoints(text)))
    return ("\n".join(lines) + "\n").encode("ascii"), vocabulary


def _tensor(name, dtype, shape):
    return {"name": name, "dtype": dtype, "shape": shape}


def _runtime_graphs(members):
    member_by_name = {item["name"]: item for item in members}
    if set(member_by_name) != set(GRAPH_NAMES):
        raise PackageGenerationError("archive member contract differs")
    one = [1, 8, 1, 32]
    cross = [1, 8, 128, 32]
    past = [1, 8, 127, 32]
    return [
        {
            "file": "encoder.ms",
            "size": member_by_name["encoder.ms"]["size"],
            "sha256": member_by_name["encoder.ms"]["sha256"],
            "inputs": [_tensor("input_ids", "INT32", [1, 128]), _tensor("attention_mask", "INT32", [1, 128])],
            "outputs": [_tensor("last_hidden_state", "FLOAT32", [1, 128, 256])],
        },
        {
            "file": "decoder_prefill.ms",
            "size": member_by_name["decoder_prefill.ms"]["size"],
            "sha256": member_by_name["decoder_prefill.ms"]["sha256"],
            "inputs": [
                _tensor("decoder_input_ids", "INT32", [1, 1]),
                _tensor("encoder_hidden_states", "FLOAT32", [1, 128, 256]),
                _tensor("encoder_attention_mask", "INT32", [1, 128]),
            ],
            "outputs": [_tensor("logits", "FLOAT32", [1, 32003])] + [
                _tensor("%s_%d" % (kind, layer), "FLOAT32", one if kind.startswith("self") else cross)
                for layer in range(2)
                for kind in ("self_key", "self_value", "cross_key", "cross_value")
            ],
        },
        {
            "file": "decoder_step.ms",
            "size": member_by_name["decoder_step.ms"]["size"],
            "sha256": member_by_name["decoder_step.ms"]["sha256"],
            "inputs": [
                _tensor("decoder_input_ids", "INT32", [1, 1]),
                _tensor("position_id", "INT32", [1]),
                _tensor("self_attention_mask", "INT32", [1, 128]),
                _tensor("cross_attention_mask", "INT32", [1, 128]),
            ] + [
                _tensor("%s_%d" % (kind, layer), "FLOAT32", past if kind.startswith("past") else cross)
                for layer in range(2)
                for kind in ("past_key", "past_value", "cross_key", "cross_value")
            ],
            "outputs": [_tensor("logits", "FLOAT32", [1, 32003])] + [
                _tensor("new_%s_%d" % (kind, layer), "FLOAT32", one)
                for layer in range(2)
                for kind in ("key", "value")
            ],
        },
    ]


def _asset(role, path):
    record = _record(path)
    return {"role": role, "path": Path(path).name, **record}


def generate_final_package(
    *,
    tokenizer_model,
    archive,
    archive_manifest_a,
    archive_manifest_b,
    decompressor,
    licenses_source,
    quality_gate_report,
    conversion_report,
    stage_root,
    package_manifest_path,
):
    evidence_a = _read_json(archive_manifest_a, "source archive evidence")
    evidence_b = _read_json(archive_manifest_b, "canonical archive rebuild")
    if evidence_a != evidence_b:
        raise PackageGenerationError("archive evidence and canonical rebuild differ")
    if set(evidence_b) != {"schemaVersion", "members", "tar", "archive"}:
        raise PackageGenerationError("archive evidence schema differs")

    archive = Path(archive)
    tokenizer_model = Path(tokenizer_model)
    decompressor = Path(decompressor)
    licenses_source = Path(licenses_source)
    for path, label in (
        (archive, "archive"),
        (tokenizer_model, "tokenizer"),
        (decompressor, "decompressor"),
        (licenses_source, "licenses"),
    ):
        if not path.is_file() or path.is_symlink():
            raise PackageGenerationError("%s input is not a regular file" % label)
    if archive.name != REQUIRED_ASSETS["archive"] or decompressor.name != REQUIRED_ASSETS["decompressor"]:
        raise PackageGenerationError("final package input file name differs")
    try:
        verify_archive(archive, evidence_b)
    except Exception as error:
        raise PackageGenerationError("archive differs from retained evidence: %s" % error) from error
    conversion = _approved_conversion(quality_gate_report, conversion_report, evidence_b)
    if (
        licenses_source.resolve() != TRUSTED_LICENSES_SOURCE.resolve()
        or hashlib.sha256(_canonical_license_bytes(licenses_source)).hexdigest() != TRUSTED_LICENSES_SHA256
    ):
        raise PackageGenerationError("licenses input differs from the trusted translation notices")

    stage_root = Path(stage_root)
    if stage_root.is_symlink():
        raise PackageGenerationError("output stage must not be a symlink")
    if stage_root.exists() and (not stage_root.is_dir() or any(stage_root.iterdir())):
        raise PackageGenerationError("output stage must be absent or empty")
    package_manifest_path = Path(package_manifest_path)
    if package_manifest_path.resolve() == stage_root.resolve() or stage_root.resolve() in package_manifest_path.resolve().parents:
        raise PackageGenerationError("package manifest must stay outside the rawfile stage")

    runtime_table, vocabulary = _tokenizer_assets(tokenizer_model)

    stage_root.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(archive, stage_root / REQUIRED_ASSETS["archive"])
    shutil.copyfile(tokenizer_model, stage_root / REQUIRED_ASSETS["tokenizer"])
    (stage_root / REQUIRED_ASSETS["tokenizer-runtime"]).write_bytes(runtime_table)
    _write_json(stage_root / REQUIRED_ASSETS["vocabulary"], vocabulary)
    (stage_root / REQUIRED_ASSETS["licenses"]).write_bytes(_canonical_license_bytes(licenses_source))

    runtime_manifest = {
        "schemaVersion": 1,
        "vocabulary": {
            "size": VOCABULARY_SIZE,
            "eos": 0,
            "unk": 1,
            "pad": PAD_ID,
            "decoderStart": PAD_ID,
            "toEnglish": TO_ENGLISH_ID,
            "toChinese": TO_CHINESE_ID,
        },
        "archive": {
            "file": REQUIRED_ASSETS["archive"],
            **_record(stage_root / REQUIRED_ASSETS["archive"]),
            "cacheKey": "ARCHIVE_SHA256",
        },
        "graphs": _runtime_graphs(evidence_b["members"]),
    }
    _write_json(stage_root / REQUIRED_ASSETS["manifest"], runtime_manifest)

    checksum_names = sorted(set(REQUIRED_ASSETS.values()) - {REQUIRED_ASSETS["checksums"], REQUIRED_ASSETS["decompressor"]})
    checksums = "".join(
        "%s  %s\n" % (_sha256(stage_root / name).upper(), name)
        for name in checksum_names
    )
    (stage_root / REQUIRED_ASSETS["checksums"]).write_bytes(checksums.encode("ascii"))

    roles_by_name = {name: role for role, name in REQUIRED_ASSETS.items()}
    assets = [_asset(roles_by_name[path.name], path) for path in stage_root.iterdir()]
    assets.append(_asset("decompressor", decompressor))
    assets.sort(key=lambda asset: asset["path"])
    package = {
        "schemaVersion": 1,
        "mode": "final",
        "limitBytes": PACKAGE_LIMIT_BYTES,
        "assets": assets,
        "allowances": [],
        "evidence": {
            "sourceEvidence": {"tar": evidence_a["tar"], "archive": evidence_a["archive"]},
            "canonicalRebuild": {"tar": evidence_b["tar"], "archive": evidence_b["archive"]},
            "qualityGateReport": _artifact(quality_gate_report),
            "conversionReport": _artifact(conversion_report),
            "approval": {
                "candidate": conversion["approval"]["candidate"],
                "candidateEpoch": conversion["approval"]["candidateEpoch"],
                "objectiveHashes": conversion["approval"]["objectiveHashes"],
            },
        },
    }
    package_manifest_path.parent.mkdir(parents=True, exist_ok=True)
    _write_json(package_manifest_path, package)
    verify_package(package_manifest_path, stage_root, decompressor)
    return package


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--tokenizer-model", required=True, type=Path)
    parser.add_argument("--archive", required=True, type=Path)
    parser.add_argument("--archive-manifest-a", required=True, type=Path)
    parser.add_argument("--archive-manifest-b", required=True, type=Path)
    parser.add_argument("--decompressor", required=True, type=Path)
    parser.add_argument("--licenses-source", required=True, type=Path)
    parser.add_argument("--quality-gate-report", required=True, type=Path)
    parser.add_argument("--conversion-report", required=True, type=Path)
    parser.add_argument("--stage-root", required=True, type=Path)
    parser.add_argument("--package-manifest-out", required=True, type=Path)
    args = parser.parse_args(argv)
    package = generate_final_package(
        tokenizer_model=args.tokenizer_model,
        archive=args.archive,
        archive_manifest_a=args.archive_manifest_a,
        archive_manifest_b=args.archive_manifest_b,
        decompressor=args.decompressor,
        licenses_source=args.licenses_source,
        quality_gate_report=args.quality_gate_report,
        conversion_report=args.conversion_report,
        stage_root=args.stage_root,
        package_manifest_path=args.package_manifest_out,
    )
    print(json.dumps({"assets": len(package["assets"]), "mode": package["mode"]}, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
