"""Offline handwritten-digit tutorial reproduced with MindSpore."""

from __future__ import annotations

import argparse
import json
import platform
import time
from pathlib import Path

import mindspore as ms
import mindspore.dataset as ds
import numpy as np
from mindspore import Tensor, nn
from PIL import Image
from sklearn import __version__ as sklearn_version
from sklearn.datasets import load_digits
from sklearn.model_selection import train_test_split


class LeNet5(nn.Cell):
    """Modern LeNet-style classifier for 1x28x28 digit images."""

    def __init__(self) -> None:
        super().__init__()
        self.features = nn.SequentialCell(
            nn.Conv2d(1, 6, kernel_size=5, pad_mode="valid"),
            nn.ReLU(),
            nn.MaxPool2d(kernel_size=2, stride=2),
            nn.Conv2d(6, 16, kernel_size=5, pad_mode="valid"),
            nn.ReLU(),
            nn.MaxPool2d(kernel_size=2, stride=2),
        )
        self.classifier = nn.SequentialCell(
            nn.Flatten(),
            nn.Dense(16 * 4 * 4, 120),
            nn.ReLU(),
            nn.Dense(120, 84),
            nn.ReLU(),
            nn.Dense(84, 10),
        )

    def construct(self, x: Tensor) -> Tensor:
        return self.classifier(self.features(x))


def resize_digits(images: np.ndarray) -> np.ndarray:
    """Convert bundled 8x8 digits to normalized 1x28x28 float tensors."""

    resized = []
    for image in images:
        pixels = np.rint(image / 16.0 * 255.0).astype(np.uint8)
        canvas = Image.fromarray(pixels, mode="L").resize(
            (28, 28), Image.Resampling.BILINEAR
        )
        normalized = np.asarray(canvas, dtype=np.float32) / 255.0
        resized.append(((normalized - 0.5) / 0.5)[None, :, :])
    return np.stack(resized).astype(np.float32)


def make_dataset(
    images: np.ndarray, labels: np.ndarray, batch_size: int, shuffle: bool
) -> ds.Dataset:
    dataset = ds.NumpySlicesDataset(
        {"image": images, "label": labels.astype(np.int32)},
        shuffle=shuffle,
    )
    return dataset.batch(batch_size, drop_remainder=False)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--epochs", type=int, default=20)
    parser.add_argument("--batch-size", type=int, default=64)
    parser.add_argument("--learning-rate", type=float, default=0.002)
    parser.add_argument("--output-dir", type=Path, default=Path("artifacts"))
    args = parser.parse_args()

    started = time.perf_counter()
    ms.set_seed(42)
    np.random.seed(42)
    ds.config.set_seed(42)
    ms.set_context(mode=ms.PYNATIVE_MODE, device_target="CPU")

    bundle = load_digits()
    images = resize_digits(bundle.images)
    labels = bundle.target.astype(np.int32)
    train_x, test_x, train_y, test_y = train_test_split(
        images,
        labels,
        test_size=0.2,
        random_state=42,
        stratify=labels,
    )
    train_data = make_dataset(train_x, train_y, args.batch_size, shuffle=True)
    test_data = make_dataset(test_x, test_y, args.batch_size, shuffle=False)

    network = LeNet5()
    loss_fn = nn.SoftmaxCrossEntropyWithLogits(sparse=True, reduction="mean")
    optimizer = nn.Adam(
        network.trainable_params(), learning_rate=args.learning_rate
    )
    model = ms.Model(
        network,
        loss_fn=loss_fn,
        optimizer=optimizer,
        metrics={"accuracy": nn.Accuracy()},
    )

    history = []
    training_started = time.perf_counter()
    for epoch in range(1, args.epochs + 1):
        epoch_started = time.perf_counter()
        model.train(1, train_data, dataset_sink_mode=False)
        metrics = model.eval(test_data, dataset_sink_mode=False)
        record = {
            "epoch": epoch,
            "test_accuracy": round(float(metrics["accuracy"]), 6),
            "seconds": round(time.perf_counter() - epoch_started, 3),
        }
        history.append(record)
        print(
            f"epoch={epoch:02d} "
            f"test_accuracy={record['test_accuracy']:.4f} "
            f"seconds={record['seconds']:.3f}"
        )
    training_seconds = time.perf_counter() - training_started

    args.output_dir.mkdir(parents=True, exist_ok=True)
    checkpoint = args.output_dir / "lenet_digits.ckpt"
    mindir_stem = args.output_dir / "lenet_digits"
    ms.save_checkpoint(network, str(checkpoint))
    network.set_train(False)
    export_started = time.perf_counter()
    ms.export(
        network,
        Tensor(np.zeros((1, 1, 28, 28), dtype=np.float32)),
        file_name=str(mindir_stem),
        file_format="MINDIR",
    )
    export_seconds = time.perf_counter() - export_started
    mindir = mindir_stem.with_suffix(".mindir")

    # MindIR graphs must execute in GRAPH_MODE after loading.
    ms.set_context(mode=ms.GRAPH_MODE)
    graph_network = nn.GraphCell(ms.load(str(mindir)))
    sample = Tensor(test_x[:1])
    eager_logits = network(sample).asnumpy()
    exported_logits = graph_network(sample).asnumpy()

    summary = {
        "python": platform.python_version(),
        "mindspore": ms.__version__,
        "sklearn": sklearn_version,
        "device_target": ms.get_context("device_target"),
        "dataset": "sklearn.datasets.load_digits (bundled, not real MNIST)",
        "raw_shape": list(bundle.images.shape),
        "model_input_shape": list(images.shape),
        "train_samples": int(len(train_y)),
        "test_samples": int(len(test_y)),
        "epochs": args.epochs,
        "batch_size": args.batch_size,
        "learning_rate": args.learning_rate,
        "final_test_accuracy": history[-1]["test_accuracy"],
        "best_test_accuracy": max(item["test_accuracy"] for item in history),
        "training_seconds": round(training_seconds, 3),
        "export_seconds": round(export_seconds, 3),
        "total_seconds": round(time.perf_counter() - started, 3),
        "checkpoint": str(checkpoint.resolve()),
        "checkpoint_bytes": checkpoint.stat().st_size,
        "mindir": str(mindir.resolve()),
        "mindir_bytes": mindir.stat().st_size,
        "sample_true_label": int(test_y[0]),
        "eager_prediction": int(np.argmax(eager_logits, axis=1)[0]),
        "exported_prediction": int(np.argmax(exported_logits, axis=1)[0]),
        "export_max_abs_logit_diff": float(
            np.max(np.abs(eager_logits - exported_logits))
        ),
    }
    (args.output_dir / "run_summary.json").write_text(
        json.dumps(summary, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    print("RUN_SUMMARY")
    print(json.dumps(summary, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
