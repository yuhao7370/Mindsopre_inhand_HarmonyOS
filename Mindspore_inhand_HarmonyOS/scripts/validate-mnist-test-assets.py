#!/usr/bin/env python3
"""Run the College tutorial MindIR against the handwritten-digit fixtures."""

from __future__ import annotations

import argparse
import json
import math
import tempfile
import zipfile
from pathlib import Path

import mindspore as ms
import numpy as np
from mindspore import Tensor, nn
from PIL import Image

INPUT_SIZE = 28
BODY_SIZE = 20
MEAN = 0.1307
STD = 0.3081
MINIMUM_CONTRAST = 32 / 255
FOREGROUND_THRESHOLD = 0.15
FOREGROUND_PADDING_RATIO = 0.1
MAX_IMAGE_DIMENSION = 4096
MAX_RGBA_BYTES = MAX_IMAGE_DIMENSION * MAX_IMAGE_DIMENSION * 4
FIXTURES = (("digit-2.png", 2), ("digit-7.png", 7), ("digit-9.png", 9))
MINDIR_ENTRY = "artifacts/lenet_mnist.mindir"


def sample(values: np.ndarray, x: int, y: int) -> float:
    if x < 0 or y < 0 or x >= values.shape[1] or y >= values.shape[0]:
        return 0.0
    return float(values[y, x])


def bilinear_sample(values: np.ndarray, source_x: float, source_y: float) -> float:
    left = math.floor(source_x)
    top = math.floor(source_y)
    horizontal = source_x - left
    vertical = source_y - top
    top_left = sample(values, left, top)
    top_right = sample(values, left + 1, top)
    bottom_left = sample(values, left, top + 1)
    bottom_right = sample(values, left + 1, top + 1)
    return (top_left * (1 - horizontal) * (1 - vertical) + top_right * horizontal * (1 - vertical) +
            bottom_left * (1 - horizontal) * vertical + bottom_right * horizontal * vertical)


def js_round(value: float) -> int:
    return math.floor(value + 0.5)


def validate_rgba(rgba: np.ndarray, width: int, height: int) -> None:
    if (not isinstance(width, (int, np.integer)) or isinstance(width, bool) or
            not isinstance(height, (int, np.integer)) or isinstance(height, bool) or
            width <= 0 or height <= 0 or width > MAX_IMAGE_DIMENSION or height > MAX_IMAGE_DIMENSION):
        raise ValueError("Handwritten digit RGBA dimensions do not match the pixel data.")
    expected_bytes = int(width) * int(height) * 4
    if expected_bytes > MAX_RGBA_BYTES or rgba.ndim != 1 or rgba.size != expected_bytes:
        raise ValueError("Handwritten digit RGBA dimensions do not match the pixel data.")


def border_background(grayscale: np.ndarray, width: int, height: int) -> float:
    if width == 1 or height == 1:
        return float(grayscale.sum(dtype=np.float64) / (width * height))
    border = np.concatenate((grayscale[0, :], grayscale[-1, :], grayscale[1:-1, 0], grayscale[1:-1, -1]))
    return float(border.sum(dtype=np.float64) / border.size)


def arkts_input_from_rgba(rgba: np.ndarray, width: int, height: int) -> np.ndarray:
    """Mirror HandwrittenDigitPreprocess.ets, including its trust-boundary checks."""
    validate_rgba(rgba, width, height)
    rgba = rgba.reshape((height, width, 4))
    rgb = rgba[:, :, :3].astype(np.float64)
    grayscale = ((rgb[:, :, 0] * 0.299 + rgb[:, :, 1] * 0.587 + rgb[:, :, 2] * 0.114) / 255).astype(np.float32)
    background = border_background(grayscale, width, height)
    minimum = float(grayscale.min())
    maximum = float(grayscale.max())
    if maximum - minimum < MINIMUM_CONTRAST:
        raise ValueError("Handwritten digit image is blank or low contrast.")
    if background > 0.5:
        ink = np.clip(background - grayscale, 0, 1).astype(np.float32)
    else:
        ink = np.clip(grayscale - background, 0, 1).astype(np.float32)
    foreground = np.argwhere(ink >= FOREGROUND_THRESHOLD)
    if foreground.size == 0:
        raise ValueError("Handwritten digit image is blank or low contrast.")
    top, left = foreground.min(axis=0)
    bottom, right = foreground.max(axis=0)
    foreground_width = int(right - left + 1)
    foreground_height = int(bottom - top + 1)
    square_size = max(foreground_width, foreground_height)
    padded_size = square_size + max(1, js_round(square_size * FOREGROUND_PADDING_RATIO)) * 2
    crop_left = float(left) - (padded_size - foreground_width) / 2
    crop_top = float(top) - (padded_size - foreground_height) / 2
    resized = np.zeros((INPUT_SIZE, INPUT_SIZE), dtype=np.float32)
    offset = (INPUT_SIZE - BODY_SIZE) // 2
    for y in range(BODY_SIZE):
        for x in range(BODY_SIZE):
            source_x = crop_left + (x + 0.5) * padded_size / BODY_SIZE - 0.5
            source_y = crop_top + (y + 0.5) * padded_size / BODY_SIZE - 0.5
            resized[y + offset, x + offset] = bilinear_sample(ink, source_x, source_y)
    mass = 0.0
    center_x = 0.0
    center_y = 0.0
    nonzero = np.argwhere(resized > 0)
    for y in range(INPUT_SIZE):
        for x in range(INPUT_SIZE):
            value = float(resized[y, x])
            mass += value
            center_x += value * x
            center_y += value * y
    if mass <= 0 or not math.isfinite(mass):
        raise ValueError("Handwritten digit image is blank.")
    top, left = nonzero.min(axis=0)
    bottom, right = nonzero.max(axis=0)
    desired_shift_x = js_round((INPUT_SIZE - 1) / 2 - center_x / mass)
    desired_shift_y = js_round((INPUT_SIZE - 1) / 2 - center_y / mass)
    shift_x = min(INPUT_SIZE - 1 - int(right), max(-int(left), desired_shift_x))
    shift_y = min(INPUT_SIZE - 1 - int(bottom), max(-int(top), desired_shift_y))
    translated = np.zeros_like(resized)
    for y in range(INPUT_SIZE):
        for x in range(INPUT_SIZE):
            translated[y, x] = sample(resized, x - shift_x, y - shift_y)
    return np.asarray([(float(value) - MEAN) / STD for value in translated.ravel()], dtype=np.float32).reshape(1, 1, 28, 28)


def arkts_input(image_path: Path) -> np.ndarray:
    """Decode a PNG then pass exact RGBA bytes through the ArkTS mirror."""
    with Image.open(image_path) as image:
        rgba = np.asarray(image.convert("RGBA"), dtype=np.uint8)
    height, width = rgba.shape[:2]
    return arkts_input_from_rgba(rgba.reshape(-1), width, height)


def self_test() -> None:
    one_by_three = np.asarray([[0.1, 0.2, 0.3]], dtype=np.float32)
    three_by_one = np.asarray([[0.1], [0.2], [0.3]], dtype=np.float32)
    assert math.isclose(border_background(one_by_three, 3, 1), 0.2, abs_tol=1e-6)
    assert math.isclose(border_background(three_by_one, 1, 3), 0.2, abs_tol=1e-6)
    for rgba, width, height in ((np.zeros(3, dtype=np.uint8), 1, 1), (np.zeros(0, dtype=np.uint8), 4097, 1)):
        try:
            validate_rgba(rgba, width, height)
        except ValueError:
            continue
        raise AssertionError("RGBA trust-boundary validation accepted invalid input")


def load_network(archive_path: Path, temp_dir: Path) -> nn.GraphCell:
    with zipfile.ZipFile(archive_path) as archive:
        extracted = temp_dir / "lenet_mnist.mindir"
        with archive.open(MINDIR_ENTRY) as source, extracted.open("wb") as destination:
            destination.write(source.read())
    return nn.GraphCell(ms.load(str(extracted)))


def run(root: Path) -> list[dict[str, object]]:
    asset_root = root / "test-assets" / "handwritten-digits"
    archive_path = root / "docs" / "tutorials" / "college-hap" / "college-hap.zip"
    if not archive_path.is_file():
        raise FileNotFoundError(f"Missing College tutorial ZIP: {archive_path}")
    ms.set_context(mode=ms.GRAPH_MODE)
    with tempfile.TemporaryDirectory(prefix="mih-mnist-mindir-") as temporary:
        network = load_network(archive_path, Path(temporary))
        results: list[dict[str, object]] = []
        for file_name, expected in FIXTURES:
            logits = network(Tensor(arkts_input(asset_root / file_name), ms.float32)).asnumpy().reshape(-1)
            maximum = float(np.max(logits))
            probabilities = np.exp(logits - maximum)
            probabilities /= np.sum(probabilities)
            predicted = int(np.argmax(probabilities))
            results.append({
                "file": file_name,
                "expected": expected,
                "predicted": predicted,
                "confidence": float(probabilities[predicted]),
                "logits": [float(value) for value in logits],
            })
    return results


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--json", action="store_true")
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    if args.self_test:
        self_test()
        print("MNIST fixture preprocessor self-test passed.")
        return 0
    results = run(args.root.resolve())
    if args.json:
        print(json.dumps(results, separators=(",", ":")))
    else:
        for result in results:
            print(f"{result['file']}: expected={result['expected']} predicted={result['predicted']} confidence={result['confidence']:.6f} logits={result['logits']}")
    return 0 if all(result["predicted"] == result["expected"] for result in results) else 1


if __name__ == "__main__":
    raise SystemExit(main())
