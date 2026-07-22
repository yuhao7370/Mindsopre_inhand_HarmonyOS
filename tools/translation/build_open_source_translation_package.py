#!/usr/bin/env python3
"""Build the deterministic dual-direction open-source translation package."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import shutil
import sys
import tempfile
from pathlib import Path

if __package__ in (None, ""):
    sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from tools.translation.build_translation_archive import (
    CANONICAL_MEMBERS,
    MAX_ARCHIVE_BYTES,
    MAX_TAR_BYTES,
    _sha256,
    build_archive,
)
from tools.translation.export_marian_smoke import validate_official_models_manifest
from tools.translation.generate_final_translation_package import _codepoints, _normalization_rules


DIRECTION_GRAPH_LIMITS = {"zh-en": 36 * 1024 * 1024, "en-zh": 147 * 1024 * 1024}
SOURCE_PREFIX_TOKEN_IDS = {"zh-en": -1, "en-zh": 5}
SPECIAL_TOKEN_TEXT = {"eos": "</s>", "unk": "<unk>", "pad": "<pad>"}
EXPECTED_DIRECTION_CONTRACTS = {
    "en": {
        "name": "zh-en", "source": "zh", "target": "en", "hiddenSize": 256,
        "vocabularySize": 32001, "strategy": "greedy", "numBeams": 1,
        "sourcePrefix": "", "graphLimit": 36 * 1024 * 1024,
        "repository": "Helsinki-NLP/opus-mt_tiny_zho-eng",
        "revision": "4ee3a9342aae4ca6fbae82c930b5dccff5dd68dd",
        "graphs": {
            "encoder": {"size": 16115736, "sha256": "86a9272199af2b3699a3d873b69e5741de3e26da545de06180902df071ff91bb"},
            "decoderFull": {"size": 21247904, "sha256": "8dc03af96ac9f7bf9efb37ffcc42a0034f5305810a0059cd7c3cb66e48a3550d"},
        },
        "tokenizers": {
            "source": {"modelSha256": "e5528a5c3685d08f8868902d31febeb763eea8519f9997f43b05964b02554640", "vocabularySha256": "13690d04e27310a43f0d879dfd38823c317e9ac69f436754baffbb0da6fc9dbe", "pieceCount": 32000, "decodeVocabularySize": 32001},
            "target": {"modelSha256": "e5528a5c3685d08f8868902d31febeb763eea8519f9997f43b05964b02554640", "vocabularySha256": "13690d04e27310a43f0d879dfd38823c317e9ac69f436754baffbb0da6fc9dbe", "pieceCount": 32000, "decodeVocabularySize": 32001},
        },
    },
    "zh": {
        "name": "en-zh", "source": "en", "target": "zh", "hiddenSize": 512,
        "vocabularySize": 65001, "strategy": "beam", "numBeams": 4,
        "sourcePrefix": ">>cmn_Hans<< ", "graphLimit": 147 * 1024 * 1024,
        "repository": "Helsinki-NLP/opus-mt-en-zh",
        "revision": "408d9bc410a388e1d9aef112a2daba955b945255",
        "graphs": {
            "encoder": {"size": 55211640, "sha256": "4a1eae7e4b3600801b88df822bd42f786e9e34f715d12d0bac6454683599c5ee"},
            "decoderFull": {"size": 97121896, "sha256": "5046af7b4311c14676d099e6cd01839f9c3b910d437184017797e972e559e66e"},
        },
        "tokenizers": {
            "source": {"modelSha256": "5775ddc9e3ff2fae91554da56468ad35ff56edaba870fea74447bc7234bfdaa8", "vocabularySha256": "f1832ca38f7aa158b9a944ff583e4901e6b37d9d4ad9241f03838e636e9cfb03", "pieceCount": 32000, "decodeVocabularySize": 0},
            "target": {"modelSha256": "81dc94efa84e4025ef38d25d5d07429fe41e3eb29d44003f1db6fe98487b0052", "vocabularySha256": "f1832ca38f7aa158b9a944ff583e4901e6b37d9d4ad9241f03838e636e9cfb03", "pieceCount": 0, "decodeVocabularySize": 65001},
        },
    },
}


class PackageV2Error(RuntimeError):
    pass


def _read_json(path: Path, label: str) -> dict:
    try:
        value = json.loads(Path(path).read_text(encoding="utf-8"))
    except (OSError, UnicodeDecodeError, json.JSONDecodeError) as error:
        raise PackageV2Error(f"invalid {label}: {error}") from error
    if not isinstance(value, dict):
        raise PackageV2Error(f"{label} must be an object")
    return value


def _artifact(path: Path) -> dict:
    path = Path(path)
    return {"size": path.stat().st_size, "sha256": _sha256(path)}


def _canonical_json_bytes(value: object) -> bytes:
    return (json.dumps(value, indent=2, sort_keys=True, ensure_ascii=False) + "\n").encode("utf-8")


def _canonical_checksum_bytes(lines: list[str]) -> bytes:
    return ("\n".join(lines) + "\n").encode("ascii")


def _is_sha256(value: object) -> bool:
    return isinstance(value, str) and re.fullmatch(r"[0-9a-f]{64}", value) is not None


def _is_positive_integer(value: object) -> bool:
    return type(value) is int and value > 0


def _verify_artifact(path: Path, expected: dict, label: str) -> None:
    if not path.is_file() or path.is_symlink() or _artifact(path) != expected:
        raise PackageV2Error(f"{label} differs from its pinned artifact")


def compile_tokenizer_runtime(
    model_path: Path,
    vocabulary_path: Path,
    expected_model: dict,
    expected_vocabulary: dict,
    output: Path,
    *,
    include_pieces: bool = True,
    include_vocabulary: bool = True,
) -> dict:
    """Compile one Marian role to deterministic TTOK2 encode/decode tables."""
    from sentencepiece import sentencepiece_model_pb2

    _verify_artifact(model_path, expected_model, "SentencePiece model")
    _verify_artifact(vocabulary_path, expected_vocabulary, "tokenizer vocabulary")
    vocabulary = _read_json(vocabulary_path, "tokenizer vocabulary")
    if (
        len(vocabulary) < 2
        or vocabulary.get("</s>") != 0
        or vocabulary.get("<unk>") != 1
        or set(vocabulary.values()) != set(range(len(vocabulary)))
    ):
        raise PackageV2Error("tokenizer vocabulary IDs are not exact and contiguous")
    model = sentencepiece_model_pb2.ModelProto()
    try:
        model.ParseFromString(Path(model_path).read_bytes())
    except Exception as error:
        raise PackageV2Error("SentencePiece model is unreadable") from error
    if model.trainer_spec.model_type != sentencepiece_model_pb2.TrainerSpec.UNIGRAM:
        raise PackageV2Error("tokenizer model must be Unigram")
    normalizer = model.normalizer_spec
    if (
        normalizer.name != "nmt_nfkc"
        or not normalizer.add_dummy_prefix
        or not normalizer.remove_extra_whitespaces
        or not normalizer.escape_whitespaces
    ):
        raise PackageV2Error("tokenizer normalizer contract differs")
    if len(model.pieces) != 32000:
        raise PackageV2Error("official tokenizer must contain 32000 SentencePiece entries")

    model_sha = expected_model["sha256"]
    vocab_sha = expected_vocabulary["sha256"]
    scores = [float(piece.score) for piece in model.pieces]
    piece_count = len(model.pieces) if include_pieces else 0
    decode_vocabulary_size = len(vocabulary) if include_vocabulary else 0
    header = "\t".join((
        "TTOK2", model_sha, vocab_sha, str(len(vocabulary)), str(piece_count),
        str(decode_vocabulary_size), "1", repr(min(scores)), "1", "1", "1",
    ))
    lines = [header]
    if include_pieces:
        for source, target in _normalization_rules(normalizer.precompiled_charsmap):
            lines.append(f"N\t{_codepoints(source)}\t{_codepoints(target)}")
        for piece in model.pieces:
            # Missing pieces deliberately share UNK=1; P IDs are not required to be unique.
            token_id = vocabulary.get(piece.piece, 1)
            lines.append(
                f"P\t{token_id}\t{repr(float(piece.score))}\t{int(piece.type)}\t{_codepoints(piece.piece)}"
            )
    if include_vocabulary:
        inverse = {token_id: token for token, token_id in vocabulary.items()}
        for token_id in range(len(vocabulary)):
            lines.append(f"V\t{token_id}\t{_codepoints(inverse[token_id])}")
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_bytes(("\n".join(lines) + "\n").encode("ascii"))
    descriptor = {
        "file": "",
        **_artifact(output),
        "modelSha256": model_sha,
        "vocabularySha256": vocab_sha,
        "pieceCount": piece_count,
        "decodeVocabularySize": decode_vocabulary_size,
        "specialTokens": dict(SPECIAL_TOKEN_TEXT),
    }
    validate_tokenizer_runtime_bytes(output.read_bytes(), descriptor)
    return descriptor


def _decode_codepoints(value: str) -> str:
    if value == "-":
        return ""
    try:
        codepoints = [int(item, 16) for item in value.split(",")]
        if any(item < 0 or item > 0x10FFFF or 0xD800 <= item <= 0xDFFF for item in codepoints):
            raise ValueError("invalid Unicode scalar")
        return "".join(chr(item) for item in codepoints)
    except (ValueError, OverflowError) as error:
        raise PackageV2Error("TTOK2 contains invalid codepoints") from error


def validate_tokenizer_runtime_bytes(runtime: bytes, descriptor: dict) -> dict:
    """Validate TTOK2 table roles and return their deterministic decoded form."""
    try:
        lines = runtime.decode("ascii").splitlines()
    except UnicodeDecodeError as error:
        raise PackageV2Error("TTOK2 must be ASCII") from error
    if not lines:
        raise PackageV2Error("TTOK2 is empty")
    header = lines[0].split("\t")
    if len(header) != 11 or header[0] != "TTOK2":
        raise PackageV2Error("TTOK2 header differs")
    try:
        vocabulary_size = int(header[3])
        piece_count = int(header[4])
        decode_vocabulary_size = int(header[5])
        unknown_id = int(header[6])
        float(header[7])
        flags = tuple(int(item) for item in header[8:11])
    except ValueError as error:
        raise PackageV2Error("TTOK2 header values are invalid") from error
    expected_decode = descriptor["decodeVocabularySize"]
    if (
        header[1] != descriptor["modelSha256"]
        or header[2] != descriptor["vocabularySha256"]
        or piece_count != descriptor["pieceCount"]
        or decode_vocabulary_size != expected_decode
        or vocabulary_size < max(piece_count, decode_vocabulary_size)
        or unknown_id != 1
        or flags != (1, 1, 1)
    ):
        raise PackageV2Error("TTOK2 header contract differs")
    piece_ids = []
    piece_texts = []
    vocabulary_by_id = {}
    vocabulary_texts = set()
    for line in lines[1:]:
        fields = line.split("\t")
        if fields[0] == "N" and len(fields) == 3:
            _decode_codepoints(fields[1])
            _decode_codepoints(fields[2])
        elif fields[0] == "P" and len(fields) == 5:
            try:
                token_id = int(fields[1])
                float(fields[2])
                int(fields[3])
            except ValueError as error:
                raise PackageV2Error("TTOK2 P record is invalid") from error
            if not 0 <= token_id < vocabulary_size:
                raise PackageV2Error("TTOK2 P ID is outside the joint vocabulary")
            piece_texts.append(_decode_codepoints(fields[4]))
            piece_ids.append(token_id)
        elif fields[0] == "V" and len(fields) == 3:
            try:
                token_id = int(fields[1])
            except ValueError as error:
                raise PackageV2Error("TTOK2 V ID is invalid") from error
            text = _decode_codepoints(fields[2])
            if token_id in vocabulary_by_id or text in vocabulary_texts:
                raise PackageV2Error("TTOK2 V records must have unique IDs and text")
            vocabulary_by_id[token_id] = text
            vocabulary_texts.add(text)
        else:
            raise PackageV2Error("TTOK2 contains an unexpected record")
    if len(piece_ids) != piece_count:
        raise PackageV2Error("TTOK2 P table size differs")
    if set(vocabulary_by_id) != set(range(decode_vocabulary_size)):
        raise PackageV2Error("TTOK2 V table must cover every decode vocabulary ID")
    vocabulary = [vocabulary_by_id[index] for index in range(decode_vocabulary_size)]
    if decode_vocabulary_size:
        special = descriptor.get("specialTokens")
        if special != SPECIAL_TOKEN_TEXT or (
            vocabulary[0] != special["eos"]
            or vocabulary[1] != special["unk"]
            or vocabulary[-1] != special["pad"]
        ):
            raise PackageV2Error("TTOK2 special token definitions differ")
    return {"pieceIds": piece_ids, "pieceTexts": piece_texts, "vocabulary": vocabulary}


def _tensor_list(values: dict) -> list:
    return [
        {"name": name, "dtype": spec[0], "shape": spec[1]}
        for name, spec in values.items()
    ]


def _graph(member: dict, contract: dict) -> dict:
    return {
        "file": member["name"],
        "size": member["size"],
        "sha256": member["sha256"],
        "inputs": _tensor_list(contract["inputs"]),
        "outputs": _tensor_list(contract["outputs"]),
    }


def _tokenizer_descriptor(member: dict, compiled: dict) -> dict:
    result = dict(compiled)
    result["file"] = member["name"]
    if {"size": result["size"], "sha256": result["sha256"]} != {
        "size": member["size"], "sha256": member["sha256"]
    }:
        raise PackageV2Error("compiled tokenizer differs from archive member")
    return result


def build_runtime_manifest(
    official: dict,
    evidence: dict,
    archive_manifest: dict,
    compiled_tokenizers: dict,
) -> dict:
    validate_official_models_manifest(official)
    if evidence.get("schemaVersion") != 1:
        raise PackageV2Error("conversion evidence schema differs")
    members = {item["name"]: item for item in archive_manifest.get("members", [])}
    if tuple(item["name"] for item in archive_manifest.get("members", [])) != CANONICAL_MEMBERS:
        raise PackageV2Error("archive member contract differs")
    directions = {}
    for direction in ("zh-en", "en-zh"):
        profile = official["directions"][direction]
        conversion = evidence["directions"][direction]
        contracts = evidence["mindSporeLiteContracts"][direction]
        encoder_member = members[f"{direction}/encoder.ms"]
        decoder_member = members[f"{direction}/decoder_full.ms"]
        for graph_name, member in (("encoder", encoder_member), ("decoder_full", decoder_member)):
            wanted = conversion["graphs"][graph_name]["mindSporeLite"]
            if {"size": member["size"], "sha256": member["sha256"]} != wanted:
                raise PackageV2Error(f"{direction}/{graph_name} is not the verified W8 graph")
        graph_bytes = encoder_member["size"] + decoder_member["size"]
        if graph_bytes > DIRECTION_GRAPH_LIMITS[direction]:
            raise PackageV2Error(f"{direction} graph bytes exceed their measured limit")
        if direction == "zh-en":
            shared = _tokenizer_descriptor(
                members["zh-en/tokenizer.ttok"], compiled_tokenizers["zh-en/shared"]
            )
            tokenizers = {"source": shared, "target": dict(shared)}
        else:
            tokenizers = {
                "source": _tokenizer_descriptor(
                    members["en-zh/source.ttok"], compiled_tokenizers["en-zh/source"]
                ),
                "target": _tokenizer_descriptor(
                    members["en-zh/target.ttok"], compiled_tokenizers["en-zh/target"]
                ),
            }
        architecture = profile["architecture"]
        directions[profile["targetLanguage"]] = {
            "sourceLanguage": profile["sourceLanguage"],
            "targetLanguage": profile["targetLanguage"],
            "repository": profile["repository"],
            "revision": profile["revision"],
            "generation": {
                **profile["generation"],
                "sourcePrefixTokenId": SOURCE_PREFIX_TOKEN_IDS[direction],
                "sourceMaxTokens": architecture["maxTokens"],
                "targetMaxTokens": architecture["targetMaxTokens"],
            },
            "vocabulary": {
                "size": architecture["vocabSize"],
                "eos": architecture["eosTokenId"],
                "unk": 1,
                "pad": architecture["padTokenId"],
                "decoderStart": architecture["decoderStartTokenId"],
            },
            "tokenizers": tokenizers,
            "graphs": {
                "encoder": _graph(encoder_member, contracts["encoder"]),
                "decoderFull": _graph(decoder_member, contracts["decoder_full"]),
            },
            "graphBytes": graph_bytes,
            "maxGraphBytes": DIRECTION_GRAPH_LIMITS[direction],
        }
    manifest = {
        "schemaVersion": 2,
        "archive": {
            "file": "translation-models.tar.xz",
            "size": archive_manifest["archive"]["size"],
            "sha256": archive_manifest["archive"]["sha256"],
            "cacheKey": "ARCHIVE_SHA256",
            "tarSize": archive_manifest["tar"]["size"],
            "tarSha256": archive_manifest["tar"]["sha256"],
            "maxArchiveBytes": MAX_ARCHIVE_BYTES,
            "maxTarBytes": MAX_TAR_BYTES,
        },
        "directions": directions,
    }
    validate_runtime_manifest(manifest)
    return manifest


def _exact_keys(value: object, keys: set[str], label: str) -> dict:
    if not isinstance(value, dict) or set(value) != keys:
        raise PackageV2Error(f"{label} properties differ")
    return value


def validate_runtime_manifest(manifest: object) -> None:
    root = _exact_keys(manifest, {"schemaVersion", "archive", "directions"}, "manifest")
    if root["schemaVersion"] != 2:
        raise PackageV2Error("runtime manifest schema differs")
    archive = _exact_keys(
        root["archive"],
        {
            "file", "size", "sha256", "cacheKey", "tarSize", "tarSha256",
            "maxArchiveBytes", "maxTarBytes",
        },
        "archive",
    )
    if (
        archive["file"] != "translation-models.tar.xz"
        or archive["cacheKey"] != "ARCHIVE_SHA256"
        or archive["maxArchiveBytes"] != MAX_ARCHIVE_BYTES
        or archive["maxTarBytes"] != MAX_TAR_BYTES
        or not _is_positive_integer(archive["size"])
        or archive["size"] > MAX_ARCHIVE_BYTES
        or not _is_positive_integer(archive["tarSize"])
        or archive["tarSize"] > MAX_TAR_BYTES
        or not _is_sha256(archive["sha256"])
        or not _is_sha256(archive["tarSha256"])
    ):
        raise PackageV2Error("runtime archive contract differs")
    directions = root["directions"]
    if not isinstance(directions, dict) or set(directions) != {"en", "zh"}:
        raise PackageV2Error("runtime directions differ")
    direction_keys = {
        "sourceLanguage", "targetLanguage", "repository", "revision", "generation",
        "vocabulary", "tokenizers", "graphs", "graphBytes", "maxGraphBytes",
    }
    for target_key, contract in EXPECTED_DIRECTION_CONTRACTS.items():
        direction_name = contract["name"]
        source = contract["source"]
        target = contract["target"]
        hidden_size = contract["hiddenSize"]
        vocab_size = contract["vocabularySize"]
        graph_limit = contract["graphLimit"]
        direction = _exact_keys(directions[target_key], direction_keys, target_key)
        if (
            direction["sourceLanguage"] != source
            or direction["targetLanguage"] != target
            or direction["repository"] != contract["repository"]
            or direction["revision"] != contract["revision"]
        ):
            raise PackageV2Error(f"{target_key} language contract differs")
        generation = direction["generation"]
        if generation != {
            "strategy": contract["strategy"], "numBeams": contract["numBeams"],
            "sourcePrefix": contract["sourcePrefix"],
            "sourcePrefixTokenId": SOURCE_PREFIX_TOKEN_IDS[direction_name],
            "sourceMaxTokens": 128, "targetMaxTokens": 32,
        }:
            raise PackageV2Error(f"{target_key} generation contract differs")
        vocabulary = _exact_keys(
            direction["vocabulary"], {"size", "eos", "unk", "pad", "decoderStart"},
            f"{target_key} vocabulary",
        )
        if vocabulary != {
            "size": vocab_size, "eos": 0, "unk": 1,
            "pad": vocab_size - 1, "decoderStart": vocab_size - 1,
        }:
            raise PackageV2Error(f"{target_key} vocabulary contract differs")
        if direction["maxGraphBytes"] != graph_limit:
            raise PackageV2Error(f"{target_key} graph size contract differs")
        tokenizers = _exact_keys(direction["tokenizers"], {"source", "target"}, f"{target_key} tokenizers")
        if direction_name == "zh-en" and tokenizers["source"] != tokenizers["target"]:
            raise PackageV2Error("zh-en must reuse its identical source/target tokenizer")
        for role in ("source", "target"):
            tokenizer = _exact_keys(
                tokenizers[role],
                {
                    "file", "size", "sha256", "modelSha256", "vocabularySha256",
                    "pieceCount", "decodeVocabularySize", "specialTokens",
                },
                f"{target_key} {role} tokenizer",
            )
            expected_tokenizer_file = (
                f"{direction_name}/tokenizer.ttok"
                if direction_name == "zh-en" else f"{direction_name}/{role}.ttok"
            )
            expected_tokenizer = contract["tokenizers"][role]
            if (
                tokenizer["file"] != expected_tokenizer_file
                or tokenizer["modelSha256"] != expected_tokenizer["modelSha256"]
                or tokenizer["vocabularySha256"] != expected_tokenizer["vocabularySha256"]
                or tokenizer["pieceCount"] != expected_tokenizer["pieceCount"]
                or tokenizer["decodeVocabularySize"] != expected_tokenizer["decodeVocabularySize"]
                or tokenizer["specialTokens"] != SPECIAL_TOKEN_TEXT
                or not _is_positive_integer(tokenizer["size"])
                or not _is_sha256(tokenizer["sha256"])
            ):
                raise PackageV2Error(f"{target_key} {role} tokenizer contract differs")
        graphs = _exact_keys(direction["graphs"], {"encoder", "decoderFull"}, f"{target_key} graphs")
        if graphs["encoder"].get("file") != f"{direction_name}/encoder.ms" or graphs["decoderFull"].get("file") != f"{direction_name}/decoder_full.ms":
            raise PackageV2Error(f"{target_key} graph file contract differs")
        expected_graph_contracts = {
            "encoder": {
                "inputs": [
                    {"name": "input_ids", "dtype": "INT32", "shape": [1, 128]},
                    {"name": "attention_mask", "dtype": "INT32", "shape": [1, 128]},
                ],
                "outputs": [
                    {
                        "name": "last_hidden_state", "dtype": "FLOAT32",
                        "shape": [1, 128, hidden_size],
                    }
                ],
            },
            "decoderFull": {
                "inputs": [
                    {"name": "decoder_input_ids", "dtype": "INT32", "shape": [1, 32]},
                    {"name": "decoder_attention_mask", "dtype": "INT32", "shape": [1, 32]},
                    {
                        "name": "encoder_hidden_states", "dtype": "FLOAT32",
                        "shape": [1, 128, hidden_size],
                    },
                    {"name": "encoder_attention_mask", "dtype": "INT32", "shape": [1, 128]},
                ],
                "outputs": [
                    {"name": "logits", "dtype": "FLOAT32", "shape": [1, 32, vocab_size]}
                ],
            },
        }
        graph_bytes = 0
        for graph_name, tensor_contract in expected_graph_contracts.items():
            graph = _exact_keys(
                graphs[graph_name], {"file", "size", "sha256", "inputs", "outputs"},
                f"{target_key} {graph_name}",
            )
            artifact_contract = contract["graphs"][graph_name]
            if (
                graph["inputs"] != tensor_contract["inputs"]
                or graph["outputs"] != tensor_contract["outputs"]
                or graph["size"] != artifact_contract["size"]
                or graph["sha256"] != artifact_contract["sha256"]
            ):
                raise PackageV2Error(f"{target_key} {graph_name} tensor contract differs")
            graph_bytes += graph["size"]
        if direction["graphBytes"] != graph_bytes or graph_bytes > graph_limit:
            raise PackageV2Error(f"{target_key} graphBytes differs from exact graph sum")


def archive_contract_from_manifest(manifest: dict) -> dict:
    validate_runtime_manifest(manifest)
    directions = manifest["directions"]
    descriptors = {
        "zh-en/encoder.ms": directions["en"]["graphs"]["encoder"],
        "zh-en/decoder_full.ms": directions["en"]["graphs"]["decoderFull"],
        "zh-en/tokenizer.ttok": directions["en"]["tokenizers"]["source"],
        "en-zh/encoder.ms": directions["zh"]["graphs"]["encoder"],
        "en-zh/decoder_full.ms": directions["zh"]["graphs"]["decoderFull"],
        "en-zh/source.ttok": directions["zh"]["tokenizers"]["source"],
        "en-zh/target.ttok": directions["zh"]["tokenizers"]["target"],
    }
    return {
        "schemaVersion": 2,
        "members": [
            {"name": name, "size": descriptors[name]["size"], "sha256": descriptors[name]["sha256"]}
            for name in CANONICAL_MEMBERS
        ],
        "tar": {"size": manifest["archive"]["tarSize"], "sha256": manifest["archive"]["tarSha256"]},
        "archive": {"size": manifest["archive"]["size"], "sha256": manifest["archive"]["sha256"]},
    }


def build_package_lock(manifest: dict, archive_contract: dict, manifest_artifact: dict) -> dict:
    expected_archive_contract = archive_contract_from_manifest(manifest)
    if archive_contract != expected_archive_contract:
        raise PackageV2Error("archive contract differs from runtime manifest")
    artifact = _exact_keys(manifest_artifact, {"size", "sha256"}, "runtime manifest artifact")
    if (
        not _is_positive_integer(artifact["size"])
        or not _is_sha256(artifact["sha256"])
    ):
        raise PackageV2Error("runtime manifest artifact differs")
    directions = manifest["directions"]
    tokenizer_descriptors = {
        "zh-en/shared": directions["en"]["tokenizers"]["source"],
        "en-zh/source": directions["zh"]["tokenizers"]["source"],
        "en-zh/target": directions["zh"]["tokenizers"]["target"],
    }
    tokenizers = {}
    for role, descriptor in tokenizer_descriptors.items():
        tokenizers[role] = {
            key: descriptor[key]
            for key in (
                "file", "modelSha256", "vocabularySha256", "pieceCount",
                "decodeVocabularySize", "specialTokens",
            )
        }
    return {
        "schemaVersion": 2,
        "runtimeManifest": {"file": "manifest.json", **artifact},
        "archive": {
            "file": "translation-models.tar.xz",
            **archive_contract["archive"],
        },
        "tar": {"file": "translation-models.tar", **archive_contract["tar"]},
        "members": archive_contract["members"],
        "tokenizers": tokenizers,
    }


def validate_package_lock(
    lock: object,
    manifest: dict,
    archive_contract: dict,
    manifest_artifact: dict,
) -> None:
    if not isinstance(lock, dict) or lock != build_package_lock(
        manifest, archive_contract, manifest_artifact
    ):
        raise PackageV2Error("external translation package lock differs")


def build_package(
    official_manifest: Path,
    conversion_evidence: Path,
    zh_en_graph_root: Path,
    en_zh_graph_root: Path,
    zh_en_snapshot: Path,
    en_zh_snapshot: Path,
    tar_path: Path,
    archive_path: Path,
    xz: Path,
    rawfile_root: Path,
    package_lock_path: Path,
) -> dict:
    official = _read_json(official_manifest, "official model manifest")
    evidence = _read_json(conversion_evidence, "conversion evidence")
    validate_official_models_manifest(official)
    rawfile_root.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory() as temporary_directory:
        temporary = Path(temporary_directory)
        compiled = {}
        zh_profile = official["directions"]["zh-en"]
        en_profile = official["directions"]["en-zh"]
        compiled["zh-en/shared"] = compile_tokenizer_runtime(
            zh_en_snapshot / "source.spm", zh_en_snapshot / "vocab.json",
            zh_profile["files"]["source.spm"], zh_profile["files"]["vocab.json"],
            temporary / "zh-en-tokenizer.ttok",
            include_pieces=True, include_vocabulary=True,
        )
        compiled["en-zh/source"] = compile_tokenizer_runtime(
            en_zh_snapshot / "source.spm", en_zh_snapshot / "vocab.json",
            en_profile["files"]["source.spm"], en_profile["files"]["vocab.json"],
            temporary / "en-zh-source.ttok",
            include_pieces=True, include_vocabulary=False,
        )
        compiled["en-zh/target"] = compile_tokenizer_runtime(
            en_zh_snapshot / "target.spm", en_zh_snapshot / "vocab.json",
            en_profile["files"]["target.spm"], en_profile["files"]["vocab.json"],
            temporary / "en-zh-target.ttok",
            include_pieces=False, include_vocabulary=True,
        )
        sources = {
            "zh-en/encoder.ms": zh_en_graph_root / "encoder.ms",
            "zh-en/decoder_full.ms": zh_en_graph_root / "decoder_full.ms",
            "zh-en/tokenizer.ttok": temporary / "zh-en-tokenizer.ttok",
            "en-zh/encoder.ms": en_zh_graph_root / "encoder.ms",
            "en-zh/decoder_full.ms": en_zh_graph_root / "decoder_full.ms",
            "en-zh/source.ttok": temporary / "en-zh-source.ttok",
            "en-zh/target.ttok": temporary / "en-zh-target.ttok",
        }
        archive_manifest = build_archive(sources, tar_path, archive_path, xz)
        archive_manifest["tar"] = _artifact(tar_path)
        archive_manifest["archive"] = _artifact(archive_path)
        manifest = build_runtime_manifest(official, evidence, archive_manifest, compiled)
    destination_archive = rawfile_root / "translation-models.tar.xz"
    if archive_path.resolve() != destination_archive.resolve():
        shutil.copyfile(archive_path, destination_archive)
    manifest_path = rawfile_root / "manifest.json"
    manifest_path.write_bytes(_canonical_json_bytes(manifest))
    package_lock_path = Path(package_lock_path)
    try:
        package_lock_path.resolve().relative_to(rawfile_root.resolve())
    except ValueError:
        pass
    else:
        raise PackageV2Error("package lock must remain outside rawfile resources")
    package_lock = build_package_lock(
        manifest, archive_contract_from_manifest(manifest), _artifact(manifest_path)
    )
    package_lock_path.parent.mkdir(parents=True, exist_ok=True)
    package_lock_path.write_bytes(_canonical_json_bytes(package_lock))
    checksums = []
    for name in ("LICENSES.md", "manifest.json", "translation-models.tar.xz"):
        path = rawfile_root / name
        if path.is_file():
            checksums.append(f"{_sha256(path).upper()}  {name}")
    (rawfile_root / "SHA256SUMS").write_bytes(_canonical_checksum_bytes(checksums))
    return manifest


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--official-manifest", required=True, type=Path)
    parser.add_argument("--conversion-evidence", required=True, type=Path)
    parser.add_argument("--zh-en-graph-root", required=True, type=Path)
    parser.add_argument("--en-zh-graph-root", required=True, type=Path)
    parser.add_argument("--zh-en-snapshot", required=True, type=Path)
    parser.add_argument("--en-zh-snapshot", required=True, type=Path)
    parser.add_argument("--tar", required=True, type=Path)
    parser.add_argument("--archive", required=True, type=Path)
    parser.add_argument("--xz", required=True, type=Path)
    parser.add_argument("--rawfile-root", required=True, type=Path)
    parser.add_argument("--package-lock", required=True, type=Path)
    args = parser.parse_args()
    manifest = build_package(
        args.official_manifest, args.conversion_evidence,
        args.zh_en_graph_root, args.en_zh_graph_root,
        args.zh_en_snapshot, args.en_zh_snapshot,
        args.tar, args.archive, args.xz, args.rawfile_root, args.package_lock,
    )
    print(json.dumps(manifest["archive"], sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
