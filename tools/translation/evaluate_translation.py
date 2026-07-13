#!/usr/bin/env python3
"""Evaluate the selected tiny Marian checkpoint on pinned FLORES+ and manual cases."""

import argparse
import collections
import hashlib
import json
import math
import re
from pathlib import Path


FLORES_REPO = "openlanguagedata/flores_plus"
FLORES_REVISION = "b3a5298db5721c8a682e7ef00a37fcc9ab522757"
FLORES_FILES = {"zh": "devtest/cmn_Hans.jsonl", "en": "devtest/eng_Latn.jsonl"}
DIRECTION_IDS = {"zh-en": 32001, "en-zh": 32002}
EOS = 0
PAD = 32000
MAX_TOKENS = 128


class EvaluationError(RuntimeError):
    pass


def _portable_text(value):
    return isinstance(value, str) and value.strip() and "C:\\" not in value and "/Users/" not in value


def load_manual_set(path, expected_total=100):
    rows = []
    try:
        with Path(path).open("r", encoding="utf-8", newline="") as stream:
            for line_number, line in enumerate(stream, 1):
                if "\r" in line or not line.endswith("\n"):
                    raise EvaluationError("manual JSONL must use canonical LF")
                try:
                    row = json.loads(line)
                except json.JSONDecodeError as error:
                    raise EvaluationError("invalid manual JSONL line %d" % line_number) from error
                if not isinstance(row, dict) or set(row) != {
                    "id", "direction", "source", "reference", "categories"
                }:
                    raise EvaluationError("manual row schema differs at line %d" % line_number)
                if isinstance(row["id"], bool) or not isinstance(row["id"], int) or row["id"] < 1:
                    raise EvaluationError("manual row ID must be a positive integer")
                if row["direction"] not in DIRECTION_IDS:
                    raise EvaluationError("manual row direction is unsupported")
                if not _portable_text(row["source"]) or not _portable_text(row["reference"]):
                    raise EvaluationError("manual text is empty or machine-specific")
                if (
                    not isinstance(row["categories"], list)
                    or not row["categories"]
                    or any(not isinstance(value, str) or not value for value in row["categories"])
                    or len(set(row["categories"])) != len(row["categories"])
                ):
                    raise EvaluationError("manual categories are invalid")
                rows.append(row)
    except OSError as error:
        raise EvaluationError("cannot read manual evaluation set: %s" % error) from error
    if len(rows) != expected_total or [row["id"] for row in rows] != list(range(1, expected_total + 1)):
        raise EvaluationError("manual rows must have exact contiguous IDs and count")
    if expected_total == 100:
        counts = collections.Counter(row["direction"] for row in rows)
        if counts != {"zh-en": 50, "en-zh": 50}:
            raise EvaluationError("manual set must contain exactly 50 rows per direction")
    return rows


def stable_argmax(values):
    if (
        not isinstance(values, (list, tuple))
        or not values
        or any(isinstance(value, bool) or not isinstance(value, (int, float)) or not math.isfinite(value) for value in values)
    ):
        raise EvaluationError("argmax input must be non-empty and finite")
    best_id = 0
    best_value = values[0]
    for token_id in range(1, len(values)):
        if values[token_id] > best_value:
            best_id = token_id
            best_value = values[token_id]
    return best_id


_URL = re.compile(r"https?://[^\s]+", re.IGNORECASE)
_NUMBER = re.compile(r"(?<![A-Za-z])\d+(?:[.,:/-]\d+)*(?![A-Za-z])")
_NAME = re.compile(r"\b(?:[A-Z][a-z]{1,}|[A-Z]{2,})(?:\s+(?:[A-Z][a-z]{1,}|[A-Z]{2,}))*\b")
_NAME_STOP = {
    "A", "An", "The", "Please", "Do", "I", "My", "We", "This", "That", "No",
    "Open", "Send", "Call", "Meet", "Visit", "Use", "Today", "Tomorrow",
}


def _counter(pattern, text):
    return collections.Counter(match.rstrip(".,;!?)。；！？）") for match in pattern.findall(text))


def _names(text):
    without_urls = _URL.sub("", text)
    return collections.Counter(name for name in _NAME.findall(without_urls) if name not in _NAME_STOP)


def corruption_reasons(source, output, reference=None, check_proper_names=True):
    if not isinstance(source, str) or not isinstance(output, str) or (
        reference is not None and not isinstance(reference, str)
    ):
        raise EvaluationError("corruption inputs must be strings")
    expected = source if reference is None else reference
    reasons = []
    if _counter(_NUMBER, expected) != _counter(_NUMBER, output):
        reasons.append("number")
    if _counter(_URL, expected) != _counter(_URL, output):
        reasons.append("url")
    source_names = _names(source)
    expected_names = source_names if reference is None else collections.Counter(
        {name: count for name, count in source_names.items() if reference.count(name) >= count}
    )
    if check_proper_names and expected_names and any(
        output.count(name) < count for name, count in expected_names.items()
    ):
        reasons.append("proper-name")
    return reasons


def _sha256(path):
    digest = hashlib.sha256()
    size = 0
    with Path(path).open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
            size += len(chunk)
    return size, digest.hexdigest()


def write_canonical_json(path, payload):
    with Path(path).open("w", encoding="utf-8", newline="\n") as stream:
        stream.write(
            json.dumps(payload, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
            + "\n"
        )


def _load_flores(path):
    texts = []
    try:
        with Path(path).open("r", encoding="utf-8", newline="") as stream:
            for line_number, line in enumerate(stream, 1):
                if "\r" in line or not line.endswith("\n"):
                    raise EvaluationError("FLORES+ JSONL is not canonical LF")
                row = json.loads(line)
                if not isinstance(row, dict) or not isinstance(row.get("text"), str) or not row["text"].strip():
                    raise EvaluationError("FLORES+ row %d lacks text" % line_number)
                texts.append(row["text"])
    except (OSError, json.JSONDecodeError) as error:
        raise EvaluationError("cannot read pinned FLORES+ JSONL: %s" % error) from error
    if not texts:
        raise EvaluationError("FLORES+ file is empty")
    return texts


def _encode_source(processor, text, direction):
    pieces = list(processor.encode(text, out_type=int))
    if len(pieces) > MAX_TOKENS - 2:
        raise EvaluationError("evaluation source exceeds 128 tokens")
    ids = [DIRECTION_IDS[direction]] + pieces + [EOS]
    mask = [1] * len(ids)
    return ids + [PAD] * (MAX_TOKENS - len(ids)), mask + [0] * (MAX_TOKENS - len(mask))


def _decode_target(processor, ids):
    selected = []
    for value in ids:
        value = int(value)
        if value == EOS:
            break
        if value not in {PAD, 32001, 32002}:
            selected.append(value)
    return processor.decode(selected).strip()


def load_runtime(checkpoint_dir, tokenizer_model):
    try:
        import sentencepiece
        import torch
        from transformers import MarianMTModel
    except ImportError as error:
        raise EvaluationError("evaluation requires pinned T3 dependencies") from error
    if not torch.cuda.is_available():
        raise EvaluationError("CUDA is unavailable for bounded evaluation")
    model = MarianMTModel.from_pretrained(str(checkpoint_dir), local_files_only=True).to("cuda")
    if model.config.vocab_size != 32003:
        raise EvaluationError("selected checkpoint vocabulary differs")
    processor = sentencepiece.SentencePieceProcessor(model_file=str(tokenizer_model))
    if processor.get_piece_size() != 32000:
        raise EvaluationError("selected tokenizer vocabulary differs")
    model.eval()
    return torch, model, processor


def translate_texts(torch, model, processor, texts, direction, batch_size=32):
    outputs = []
    with torch.no_grad():
        for start in range(0, len(texts), batch_size):
            encoded = [_encode_source(processor, text, direction) for text in texts[start:start + batch_size]]
            input_ids = torch.tensor([value[0] for value in encoded], dtype=torch.long, device="cuda")
            attention_mask = torch.tensor([value[1] for value in encoded], dtype=torch.long, device="cuda")
            generated = model.generate(
                input_ids=input_ids,
                attention_mask=attention_mask,
                max_length=MAX_TOKENS,
                num_beams=1,
                do_sample=False,
                use_cache=True,
            )
            if not torch.isfinite(generated.float()).all().item():
                raise EvaluationError("generation returned non-finite token IDs")
            outputs.extend(_decode_target(processor, row.tolist()) for row in generated)
    if any(not output for output in outputs):
        raise EvaluationError("generation returned an empty translation")
    return outputs


def translate_preserving_boundaries(text, translate):
    if not isinstance(text, str):
        raise EvaluationError("translation text must be a string")
    parts = re.split(r"(\r\n|\r|\n)", text)
    positions = [index for index in range(0, len(parts), 2) if parts[index]]
    chunks = [parts[index] for index in positions]
    translations = translate(chunks) if chunks else []
    if len(translations) != len(chunks) or any(not isinstance(value, str) for value in translations):
        raise EvaluationError("boundary-preserving translator returned the wrong result count")
    for position, translation in zip(positions, translations):
        parts[position] = translation
    return "".join(parts)


def corpus_metrics(outputs, references, tokenizer):
    try:
        import sacrebleu
        from sacrebleu.metrics import BLEU, CHRF
    except ImportError as error:
        raise EvaluationError("metrics require sacrebleu 2.4.3") from error
    if sacrebleu.__version__ != "2.4.3" or len(outputs) != len(references) or not outputs:
        raise EvaluationError("metric inputs/version differ from the pinned contract")
    bleu = BLEU(tokenize=tokenizer)
    chrf = CHRF(char_order=6, word_order=0, beta=2)
    bleu_score = bleu.corpus_score(outputs, [references]).score
    chrf_score = chrf.corpus_score(outputs, [references]).score
    return {
        "bleu": bleu_score,
        "chrf2": chrf_score,
        "bleu_signature": str(bleu.get_signature()),
        "chrf2_signature": str(chrf.get_signature()),
    }


def evaluate(checkpoint_dir, tokenizer_model, flores_root, manual_path, output_root):
    try:
        import sacrebleu
    except ImportError as error:
        raise EvaluationError("evaluation requires sacrebleu 2.4.3") from error
    if sacrebleu.__version__ != "2.4.3":
        raise EvaluationError("sacrebleu version differs from 2.4.3")
    output_root = Path(output_root).resolve()
    output_root.mkdir(parents=True, exist_ok=True)
    torch, model, processor = load_runtime(checkpoint_dir, tokenizer_model)
    zh_path = Path(flores_root) / FLORES_FILES["zh"]
    en_path = Path(flores_root) / FLORES_FILES["en"]
    zh = _load_flores(zh_path)
    en = _load_flores(en_path)
    if len(zh) != len(en):
        raise EvaluationError("FLORES+ directions are not line-aligned")
    zh_en = translate_texts(torch, model, processor, zh, "zh-en")
    en_zh = translate_texts(torch, model, processor, en, "en-zh")
    flores_metrics = {
        "zh-en": corpus_metrics(zh_en, en, tokenizer="13a"),
        "en-zh": corpus_metrics(en_zh, zh, tokenizer="zh"),
    }
    flores_rows = []
    for direction, sources, references, translations in (
        ("zh-en", zh, en, zh_en),
        ("en-zh", en, zh, en_zh),
    ):
        flores_rows.extend(
            {
                "direction": direction,
                "index": index,
                "source": source,
                "reference": reference,
                "output": output,
            }
            for index, (source, reference, output) in enumerate(
                zip(sources, references, translations), 1
            )
        )
    with (output_root / "flores-outputs-v1.jsonl").open("w", encoding="utf-8", newline="\n") as stream:
        for row in flores_rows:
            stream.write(json.dumps(row, ensure_ascii=False, separators=(",", ":")) + "\n")
    manual = load_manual_set(manual_path)
    manual_rows = []
    for direction in DIRECTION_IDS:
        selected = [row for row in manual if row["direction"] == direction]
        translations = [
            translate_preserving_boundaries(
                row["source"],
                lambda chunks, selected_direction=direction: translate_texts(
                    torch, model, processor, chunks, selected_direction
                ),
            )
            for row in selected
        ]
        for row, output in zip(selected, translations):
            manual_rows.append(
                {
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
                }
            )
    manual_rows.sort(key=lambda row: row["id"])
    with (output_root / "manual-results-v1.jsonl").open("w", encoding="utf-8", newline="\n") as stream:
        for row in manual_rows:
            stream.write(json.dumps(row, ensure_ascii=False, separators=(",", ":")) + "\n")
    files = []
    for language, path in (("cmn_Hans", zh_path), ("eng_Latn", en_path)):
        size, digest = _sha256(path)
        files.append({"language": language, "path": FLORES_FILES["zh" if language == "cmn_Hans" else "en"], "bytes": size, "sha256": digest})
    result = {
        "schema_version": 1,
        "flores": {
            "repo": FLORES_REPO,
            "revision": FLORES_REVISION,
            "split": "devtest",
            "files": files,
            "rows_per_direction": len(zh),
            "metrics": flores_metrics,
            "sacrebleu": "2.4.3",
            "decode": {"strategy": "greedy", "max_tokens": 128, "tie": "smallest-token-id"},
        },
        "manual": {"rows_per_direction": 50, "audit_complete": False},
    }
    write_canonical_json(output_root / "evaluation-raw-v1.json", result)
    return result


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--checkpoint-dir", required=True, type=Path)
    parser.add_argument("--tokenizer-model", required=True, type=Path)
    parser.add_argument("--flores-root", required=True, type=Path)
    parser.add_argument("--manual", required=True, type=Path)
    parser.add_argument("--output-root", required=True, type=Path)
    args = parser.parse_args(argv)
    result = evaluate(
        args.checkpoint_dir,
        args.tokenizer_model,
        args.flores_root,
        args.manual,
        args.output_root,
    )
    print(json.dumps(result, ensure_ascii=False, sort_keys=True), flush=True)


if __name__ == "__main__":
    try:
        main()
    except EvaluationError as error:
        raise SystemExit("error: %s" % error)
