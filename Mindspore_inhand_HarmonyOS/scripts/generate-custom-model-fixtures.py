"""Generate the three project-authored TFLite sources used by Task 11.

The locked hashes are reproducible with CPython 3.11.7, TensorFlow/Keras 2.15.0,
NumPy 1.26.4, protobuf 4.25.9, flatbuffers 25.9.23, and ml-dtypes 0.2.0.
Other dependency versions must not silently replace the audited artifacts.
"""

import argparse
import hashlib
import os
from pathlib import Path

os.environ["TF_CPP_MIN_LOG_LEVEL"] = "3"

import tensorflow as tf


EXPECTED = {
    "custom_channel_mean.tflite": "99A725E615C3B6B64C015DCE2EFE5796DCA65DDA22DD6B5B1753F500447A9B7A",
    "custom_channel_mean_inverted.tflite": "AFC464560DFE364E68B7D83544FB45E141B5A471813166FA7FCEEC37166D47AD",
    "custom_channel_mean_non_finite.tflite": "C722CA178EBBAB5AD6ECDF4327B46FFD72E009EE62FC46E858C4D41DA03DA52D",
}


class ChannelMean(tf.Module):
    @tf.function(input_signature=[tf.TensorSpec([1, 224, 224, 3], tf.float32, name="image")])
    @tf.autograph.experimental.do_not_convert
    def __call__(self, image):
        return {
            "channel_means": tf.reduce_mean(image, axis=[1, 2], name="channel_means")
        }


class ChannelMeanInverted(tf.Module):
    @tf.function(input_signature=[tf.TensorSpec([1, 224, 224, 3], tf.float32, name="image")])
    @tf.autograph.experimental.do_not_convert
    def __call__(self, image):
        means = tf.reduce_mean(image, axis=[1, 2], name="channel_means")
        return {
            "inverted_channel_means": tf.subtract(
                tf.constant(1.0, tf.float32), means, name="inverted_channel_means"
            )
        }


class ChannelMeanNonFinite(tf.Module):
    @tf.function(input_signature=[tf.TensorSpec([1, 224, 224, 3], tf.float32, name="image")])
    @tf.autograph.experimental.do_not_convert
    def __call__(self, image):
        means = tf.reduce_mean(image, axis=[1, 2], name="channel_means")
        return {
            "non_finite_channel_means": tf.multiply(
                means,
                tf.constant(float("nan"), tf.float32),
                name="non_finite_channel_means",
            )
        }


def convert(module: tf.Module) -> bytes:
    concrete = module.__call__.get_concrete_function()
    converter = tf.lite.TFLiteConverter.from_concrete_functions([concrete], module)
    converter.optimizations = []
    return converter.convert()


def write_locked(output_dir: Path, name: str, content: bytes) -> None:
    digest = hashlib.sha256(content).hexdigest().upper()
    if digest != EXPECTED[name]:
        raise RuntimeError(f"{name} generated SHA-256 {digest}; expected {EXPECTED[name]}")
    output_dir.mkdir(parents=True, exist_ok=True)
    (output_dir / name).write_bytes(content)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output-dir", type=Path, default=Path("model_sources/custom_model"))
    args = parser.parse_args()
    if tf.__version__ != "2.15.0":
        raise RuntimeError(f"TensorFlow 2.15.0 is required; found {tf.__version__}")
    write_locked(args.output_dir, "custom_channel_mean.tflite", convert(ChannelMean()))
    write_locked(
        args.output_dir,
        "custom_channel_mean_inverted.tflite",
        convert(ChannelMeanInverted()),
    )
    write_locked(
        args.output_dir,
        "custom_channel_mean_non_finite.tflite",
        convert(ChannelMeanNonFinite()),
    )


if __name__ == "__main__":
    main()
