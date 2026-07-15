"""Pure input policy for the packaged local translation model."""

import re
from dataclasses import dataclass
from typing import Callable, List, Literal, Sequence, Tuple


class RuntimeInputPolicyError(RuntimeError):
    pass


@dataclass(frozen=True)
class TranslationSegment:
    kind: Literal["model", "protected"]
    text: str


_OCR_SEQUENCE = re.compile(
    r"(?<![A-Za-z])"
    r"[A-Za-z](?: [A-Za-z]){2,}"
    r"(?: {2,}[A-Za-z](?: [A-Za-z]){2,})*"
    r"(?![A-Za-z])"
    r"(?: {2,}(?=\S))?"
)
_URL = re.compile(r"https?://[^\s<>]+", re.IGNORECASE)
_EMAIL = re.compile(
    r"[A-Za-z0-9.!#$%&'*+/=?^_`{|}~-]+@"
    r"[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?"
    r"(?:\.[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?)+"
)
_CODE_TOKEN = re.compile(
    r"(?<![A-Za-z0-9])[A-Za-z0-9]+(?:[-_./:][A-Za-z0-9]+)+(?![A-Za-z0-9])"
)
_URL_TRAILING_PUNCTUATION = ".,;!?)]}"


def normalize_ocr_letter_spacing(text: str) -> str:
    if not isinstance(text, str):
        raise TypeError("translation input must be a string")

    def collapse(match: re.Match) -> str:
        words = re.split(r" {2,}", match.group(0))
        return " ".join(word.replace(" ", "") for word in words)

    return _OCR_SEQUENCE.sub(collapse, text)


def prepare_translation_segments(text: str) -> List[TranslationSegment]:
    normalized = normalize_ocr_letter_spacing(text)
    ranges = _protected_ranges(normalized)
    segments: List[TranslationSegment] = []
    cursor = 0
    for start, end in ranges:
        _append_segment(segments, "model", normalized[cursor:start])
        _append_segment(segments, "protected", normalized[start:end])
        cursor = end
    _append_segment(segments, "model", normalized[cursor:])
    return segments


def translate_with_policy(
    text: str, translate: Callable[[List[str]], Sequence[str]]
) -> str:
    segments = prepare_translation_segments(text)
    model_texts = [
        segment.text
        for segment in segments
        if segment.kind == "model" and _contains_zh_or_en_text(segment.text)
    ]
    outputs = list(translate(model_texts)) if model_texts else []
    if len(outputs) != len(model_texts) or any(
        not isinstance(output, str) or not output for output in outputs
    ):
        raise RuntimeInputPolicyError("model output count differs")
    output_index = 0
    result = []
    for segment in segments:
        if segment.kind == "protected" or not _contains_zh_or_en_text(segment.text):
            result.append(segment.text)
        else:
            result.append(outputs[output_index])
            output_index += 1
    return "".join(result)


def _contains_zh_or_en_text(text: str) -> bool:
    return any(
        "A" <= character <= "Z"
        or "a" <= character <= "z"
        or "\u3400" <= character <= "\u4dbf"
        or "\u4e00" <= character <= "\u9fff"
        or "\uf900" <= character <= "\ufaff"
        for character in text
    )


def _protected_ranges(text: str) -> List[Tuple[int, int]]:
    candidates: List[Tuple[int, int, int]] = []
    for match in _URL.finditer(text):
        end = match.end()
        while end > match.start() and text[end - 1] in _URL_TRAILING_PUNCTUATION:
            end -= 1
        if end > match.start():
            candidates.append((match.start(), end, 0))
    candidates.extend((match.start(), match.end(), 1) for match in _EMAIL.finditer(text))
    for match in _CODE_TOKEN.finditer(text):
        value = match.group(0)
        has_letter = any(character.isascii() and character.isalpha() for character in value)
        has_digit = any(character.isdigit() for character in value)
        if "_" in value or (has_letter and has_digit):
            candidates.append((match.start(), match.end(), 2))

    accepted: List[Tuple[int, int]] = []
    for start, end, _ in sorted(candidates, key=lambda item: (item[0], item[2], -item[1])):
        if any(start < accepted_end and end > accepted_start for accepted_start, accepted_end in accepted):
            continue
        accepted.append((start, end))
    accepted.sort()
    return accepted


def _append_segment(
    segments: List[TranslationSegment],
    kind: Literal["model", "protected"],
    text: str,
) -> None:
    if not text:
        return
    if segments and segments[-1].kind == kind:
        previous = segments[-1]
        segments[-1] = TranslationSegment(kind, previous.text + text)
        return
    segments.append(TranslationSegment(kind, text))
