"""Generate small, immutable ArkTS tokenizer goldens from the pinned BiST model."""

from __future__ import annotations

import argparse
import hashlib
import json
import struct
from pathlib import Path
from typing import Dict, Iterable, List, Set, Tuple

MODEL_SHA256 = "e5528a5c3685d08f8868902d31febeb763eea8519f9997f43b05964b02554640"
MODEL_SIZE = 755175
EOS_ID = 0
UNK_ID = 1
PAD_ID = 32000
TO_ENGLISH_ID = 32001
TO_CHINESE_ID = 32002
PIECE_CAPACITY = 126

CASE_NAMES = (
    "chinese",
    "english",
    "mixed",
    "full_width",
    "ascii_punctuation",
    "repeated_whitespace",
    "unknown_unicode",
    "unknown_run",
    "unknown_bmp_run",
    "unknown_adjacency",
    "unknown_boundary_128",
    "boundary_127",
    "boundary_128",
    "boundary_129",
    "multiple_newlines",
    "separator_whitespace_line",
    "separator_edges",
    "separator_punctuation",
    "combining_nfkc",
    "priority_mixed",
    "priority_english",
    "priority_space",
    "priority_hard",
)


def _case_definitions() -> List[Tuple[str, str, str]]:
    return [
        ("chinese", "\u4f60\u597d\uff0c\u4e16\u754c\uff01", "en"),
        ("english", "Hello world!", "zh"),
        ("mixed", "Hello \u4e16\u754c 123", "en"),
        ("full_width", "\uff28\uff45\uff4c\uff4c\uff4f\u3000\uff0c\u4e16\u754c\uff01", "en"),
        ("ascii_punctuation", "Wait... really?!; yes.", "zh"),
        ("repeated_whitespace", "  Hello\t   world  ", "zh"),
        ("unknown_unicode", "Hello \U0001f9ea world", "zh"),
        ("unknown_run", "A\U0001f9ea\U0001f9ecB", "zh"),
        ("unknown_bmp_run", "A\ue000\ue001B", "zh"),
        ("unknown_adjacency", "\U0001f9eaA \U0001f9ec", "zh"),
        ("unknown_boundary_128", "x " * 123 + "A\U0001f9ea\U0001f9ecB", "zh"),
        ("boundary_127", " ".join(["x"] * 125), "zh"),
        ("boundary_128", " ".join(["x"] * 126), "zh"),
        ("boundary_129", " ".join(["x"] * 127), "zh"),
        ("multiple_newlines", "\u4f60\u597d\n\nHello\r\n\u4e16\u754c\n", "en"),
        ("separator_whitespace_line", "a\n  \nb", "zh"),
        ("separator_edges", "\nA\r\n\r\n \t\r\nB\n", "zh"),
        ("separator_punctuation", "x " * 90 + "\u3002 " + "x " * 80 + "x\r\nHello", "zh"),
        ("combining_nfkc", "e\u0301", "zh"),
        ("priority_mixed", "x " * 90 + "\u3002 " + "x " * 25 + ". " + "x " * 80 + "x", "zh"),
        ("priority_english", "x " * 90 + ". " + "x " * 105 + "x", "zh"),
        ("priority_space", "x " * 200 + "x", "zh"),
        ("priority_hard", "\u4f60" * 200, "en"),
    ]


def _unit_offset(unit: int) -> int:
    return (unit >> 10) << ((unit & (1 << 9)) >> 6)


def _unit_label(unit: int) -> int:
    return unit & ((1 << 31) | 0xFF)


def _unit_has_leaf(unit: int) -> bool:
    return ((unit >> 8) & 1) == 1


def _unit_value(unit: int) -> int:
    return unit & ((1 << 31) - 1)


def _read_c_string(blob: bytes, offset: int) -> bytes:
    end = blob.find(b"\0", offset)
    if end < 0:
        raise ValueError("invalid nmt_nfkc normalized string table")
    return blob[offset:end]


def _decode_normalization_map(precompiled: bytes, inputs: Iterable[str]) -> Dict[str, str]:
    if len(precompiled) < 4:
        raise ValueError("missing nmt_nfkc precompiled charsmap")
    trie_size = struct.unpack_from("<I", precompiled, 0)[0]
    if trie_size == 0 or trie_size % 4 != 0 or 4 + trie_size > len(precompiled):
        raise ValueError("invalid nmt_nfkc trie size")
    units = struct.unpack_from(f"<{trie_size // 4}I", precompiled, 4)
    strings = precompiled[4 + trie_size :]
    rules: Dict[str, str] = {}
    for text in inputs:
        for start in range(len(text)):
            suffix = text[start:].encode("utf-8")
            position = 0
            consumed = bytearray()
            for byte in suffix:
                child = position ^ _unit_offset(units[position]) ^ byte
                if child >= len(units) or _unit_label(units[child]) != byte:
                    break
                position = child
                consumed.append(byte)
                if _unit_has_leaf(units[position]):
                    leaf = position ^ _unit_offset(units[position])
                    if leaf >= len(units):
                        raise ValueError("invalid nmt_nfkc leaf")
                    value = _unit_value(units[leaf])
                    key = bytes(consumed).decode("utf-8")
                    rules[key] = _read_c_string(strings, value).decode("utf-8")
    return rules


def _split_preserved_newlines(text: str) -> List[Tuple[str, str]]:
    """Return non-newline runs paired with the exact newlines before each run."""
    runs: List[Tuple[str, str]] = []
    separator = ""
    start = 0
    index = 0
    while index < len(text):
        if text[index] not in "\r\n":
            index += 1
            continue
        if start < index:
            runs.append((separator, text[start:index]))
            separator = ""
        if text[index] == "\r" and index + 1 < len(text) and text[index + 1] == "\n":
            separator += "\r\n"
            index += 2
        else:
            separator += text[index]
            index += 1
        start = index
    if start < len(text):
        runs.append((separator, text[start:]))
        separator = ""
    if separator:
        runs.append((separator, ""))
    return runs


def _normalize_with_map(text: str, rules: Dict[str, str], used: Set[str]) -> str:
    output: List[str] = []
    index = 0
    while index < len(text):
        selected = ""
        replacement = ""
        for length in range(1, len(text) - index + 1):
            candidate = text[index : index + length]
            if candidate in rules:
                selected = candidate
                replacement = rules[candidate]
        if selected:
            used.add(selected)
            output.append(replacement)
            index += len(selected)
        else:
            output.append(text[index])
            index += 1
    mapped = "".join(output)
    collapsed = " ".join(part for part in mapped.split(" ") if part)
    if not collapsed:
        return ""
    return "\u2581" + collapsed.replace(" ", "\u2581")


def _codepoints(text: str) -> str:
    if not text:
        return "-"
    return ",".join(f"{ord(character):X}" for character in text)


def _build_chunks(
    processor: sentencepiece.SentencePieceProcessor,
    text: str,
    target: str,
    normalized_inputs: List[str],
) -> List[dict]:
    chunks: List[dict] = []
    leading_separator = ""
    for separator, content in _split_preserved_newlines(text):
        if separator:
            if chunks:
                chunks[-1]["separatorAfter"] += separator
            else:
                leading_separator += separator
        if not content:
            continue
        if not processor.normalize(content):
            if chunks:
                chunks[-1]["separatorAfter"] += content
            else:
                leading_separator += content
            continue
        normalized_inputs.append(content)
        for source_chunk in _split_content_by_priority(processor, content):
            chunk_pieces = processor.encode(source_chunk, out_type=str)
            chunk_ids = processor.encode(source_chunk, out_type=int)
            if len(chunk_pieces) != len(chunk_ids) or len(chunk_ids) > PIECE_CAPACITY:
                raise ValueError("SentencePiece returned an invalid fixture chunk")
            chunks.append(
                {
                    "sourceText": source_chunk,
                    "normalized": processor.normalize(source_chunk),
                    "pieces": chunk_pieces,
                    "pieceIds": chunk_ids,
                    "decoded": processor.decode(chunk_ids),
                    "separatorBefore": leading_separator,
                    "separatorAfter": "",
                }
            )
            leading_separator = ""
    direction_id = TO_ENGLISH_ID if target == "en" else TO_CHINESE_ID
    for chunk in chunks:
        chunk["directionId"] = direction_id
    return chunks


def _split_content_by_priority(
    processor: sentencepiece.SentencePieceProcessor,
    content: str,
) -> List[str]:
    chunks: List[str] = []
    remaining = content
    predicates = (
        lambda character: character in "\u3002\uff01\uff1f\uff1b",
        lambda character: character in ".?!;",
        lambda character: character in " \t",
    )
    while remaining:
        if len(processor.encode(remaining, out_type=int)) <= PIECE_CAPACITY:
            chunks.append(remaining)
            break
        cut = 0
        for predicate in predicates:
            for index in range(len(remaining) - 1, -1, -1):
                if not predicate(remaining[index]):
                    continue
                candidate = remaining[: index + 1]
                token_count = len(processor.encode(candidate, out_type=int))
                if 0 < token_count <= PIECE_CAPACITY:
                    cut = index + 1
                    break
            if cut > 0:
                break
        if cut == 0:
            for index in range(len(remaining), 0, -1):
                token_count = len(processor.encode(remaining[:index], out_type=int))
                if 0 < token_count <= PIECE_CAPACITY:
                    cut = index
                    break
        if cut == 0:
            raise ValueError("unable to split tokenizer fixture within 126 pieces")
        chunks.append(remaining[:cut])
        remaining = remaining[cut:]
    return chunks


def _render_runtime_table(runtime: dict) -> str:
    header = runtime["header"]
    lines = [
        "\t".join(
            [
                "TTOK1_TEST",
                header["modelSha256"],
                str(header["vocabSize"]),
                str(header["unknownId"]),
                repr(header["minScore"]),
                "1" if header["addDummyPrefix"] else "0",
                "1" if header["removeExtraWhitespaces"] else "0",
                "1" if header["escapeWhitespaces"] else "0",
            ]
        )
    ]
    for source, target in runtime["normalizationRules"]:
        lines.append(f"N\t{_codepoints(source)}\t{_codepoints(target)}")
    for piece in runtime["pieces"]:
        lines.append(
            f"P\t{piece['id']}\t{piece['score']!r}\t{piece['type']}\t{_codepoints(piece['piece'])}"
        )
    return "\n".join(lines)


def build_fixture(model_path: Path) -> dict:
    import sentencepiece as sentencepiece
    from sentencepiece import sentencepiece_model_pb2

    model_bytes = model_path.read_bytes()
    if len(model_bytes) != MODEL_SIZE or hashlib.sha256(model_bytes).hexdigest() != MODEL_SHA256:
        raise ValueError("model is not the pinned source.spm")

    model = sentencepiece_model_pb2.ModelProto()
    model.ParseFromString(model_bytes)
    if model.trainer_spec.model_type != sentencepiece_model_pb2.TrainerSpec.UNIGRAM:
        raise ValueError("pinned source.spm is not Unigram")
    normalizer = model.normalizer_spec
    if (
        normalizer.name != "nmt_nfkc"
        or not normalizer.add_dummy_prefix
        or not normalizer.remove_extra_whitespaces
        or not normalizer.escape_whitespaces
    ):
        raise ValueError("pinned source.spm has an unexpected normalizer contract")

    processor = sentencepiece.SentencePieceProcessor(model_proto=model_bytes)
    decode_id_sequences = ([1], [1, 256], [71, 1], [1, 1], [3, 1, 192], [12249])
    decode_goldens = [
        {"pieceIds": list(piece_ids), "decoded": processor.decode(piece_ids)}
        for piece_ids in decode_id_sequences
    ]
    normalized_inputs: List[str] = []
    for _, text, _ in _case_definitions():
        normalized_inputs.extend(content for _, content in _split_preserved_newlines(text) if content)
    examples = ["e\u0301", "\uff21\uff22\uff23\u3000\uff11\uff12\uff13"]
    normalized_inputs.extend(examples)
    all_rules = _decode_normalization_map(normalizer.precompiled_charsmap, normalized_inputs)
    encoded_inputs: List[str] = []
    cases: List[dict] = []
    for name, text, target in _case_definitions():
        chunks = _build_chunks(processor, text, target, encoded_inputs)
        cases.append({"name": name, "text": text, "target": target, "chunks": chunks})

    used_rules: Set[str] = set()
    for text in normalized_inputs:
        generated = _normalize_with_map(text, all_rules, used_rules)
        expected = processor.normalize(text)
        if generated != expected:
            raise ValueError(
                f"decompiled nmt_nfkc mismatch for {text!r}: {generated!r} != {expected!r}"
            )

    normalized_texts = [processor.normalize(text) for text in encoded_inputs + examples]
    needed_ids: Set[int] = {EOS_ID, UNK_ID}
    for golden in decode_goldens:
        needed_ids.update(golden["pieceIds"])
    for case in cases:
        for chunk in case["chunks"]:
            needed_ids.update(chunk["pieceIds"])
    pieces: List[dict] = []
    min_score = min(piece.score for piece in model.pieces)
    for piece_id, piece in enumerate(model.pieces):
        if piece_id in needed_ids or (
            piece.type == sentencepiece_model_pb2.ModelProto.SentencePiece.NORMAL
            and any(piece.piece in normalized for normalized in normalized_texts)
        ):
            pieces.append(
                {
                    "id": piece_id,
                    "piece": piece.piece,
                    "score": piece.score,
                    "type": int(piece.type),
                }
            )

    fixture = {
        "directions": {"toEnglish": TO_ENGLISH_ID, "toChinese": TO_CHINESE_ID},
        "normalizationExamples": {text: processor.normalize(text).replace("\u2581", " ").lstrip() for text in examples},
        "decodeGoldens": decode_goldens,
        "runtime": {
            "header": {
                "modelSha256": MODEL_SHA256,
                "vocabSize": len(model.pieces),
                "unknownId": processor.unk_id(),
                "minScore": min_score,
                "addDummyPrefix": normalizer.add_dummy_prefix,
                "removeExtraWhitespaces": normalizer.remove_extra_whitespaces,
                "escapeWhitespaces": normalizer.escape_whitespaces,
            },
            "normalizationRules": sorted(
                ((source, all_rules[source]) for source in used_rules), key=lambda item: tuple(map(ord, item[0]))
            ),
            "pieces": pieces,
        },
        "cases": cases,
    }
    fixture["runtimeTable"] = _render_runtime_table(fixture["runtime"])
    return fixture


def render_arkts_fixture(fixture: dict) -> str:
    runtime = json.dumps(fixture["runtimeTable"], ensure_ascii=True, separators=(",", ":"))
    cases = json.dumps(fixture["cases"], ensure_ascii=True, separators=(",", ":"))
    decode_goldens = json.dumps(fixture["decodeGoldens"], ensure_ascii=True, separators=(",", ":"))
    return f"""// Generated by tools/translation/tokenizer_generate_fixture.py. Do not edit.
export interface TranslationTokenizerGoldenChunk {{
  readonly sourceText: string;
  readonly normalized: string;
  readonly pieces: Array<string>;
  readonly pieceIds: Array<number>;
  readonly decoded: string;
  readonly separatorBefore: string;
  readonly separatorAfter: string;
  readonly directionId: number;
}}

export interface TranslationTokenizerGoldenCase {{
  readonly name: string;
  readonly text: string;
  readonly target: string;
  readonly chunks: Array<TranslationTokenizerGoldenChunk>;
}}

export interface TranslationTokenizerDecodeGolden {{
  readonly pieceIds: Array<number>;
  readonly decoded: string;
}}

export const TOKENIZER_RUNTIME_FIXTURE: string = {runtime};
export const TOKENIZER_GOLDEN_CASES: Array<TranslationTokenizerGoldenCase> = {cases};
export const TOKENIZER_DECODE_GOLDENS: Array<TranslationTokenizerDecodeGolden> = {decode_goldens};
"""


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--model", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    output = render_arkts_fixture(build_fixture(args.model))
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open("w", encoding="utf-8", newline="\n") as output_file:
        output_file.write(output)


if __name__ == "__main__":
    main()
