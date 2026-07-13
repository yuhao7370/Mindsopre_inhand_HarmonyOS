import hashlib
import json
import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace

from tools.translation.prepare_bist import (
    DatasetError,
    HuggingFaceParquetProvider,
    SentencePieceTextProcessor,
    _file_sha256,
    build_result_manifest,
    direction_row,
    load_config,
    ensure_tokenizer,
    normalize_pair,
    prepare_from_provider,
    serialize_row,
    sort_shards,
    split_bucket,
    validate_source_row,
    validate_source_manifest,
    validate_parquet_schema,
    verify_file,
    verify_remote_revision,
)


ROOT = Path(__file__).parent
CONFIG = ROOT / "config" / "training-v1.json"
SOURCE_MANIFEST = ROOT / "manifests" / "bist-source-v1.json"
RESULT_MANIFEST = ROOT / "manifests" / "bist-v1.json"


class FixtureProcessor:
    def __init__(self):
        self.normalized = []

    def normalize(self, text):
        self.normalized.append(text)
        return " ".join(text.replace("Ａ", "A").split())

    def encode(self, text, out_type=str):
        del out_type
        return text.split()


class FixtureProvider:
    def __init__(self, rows_by_path):
        self.rows_by_path = rows_by_path
        self.visited = []

    def iter_batches(self, shard):
        self.visited.append(shard["path"])
        yield self.rows_by_path[shard["path"]]


class RawSentencePieceProcessor:
    def normalize(self, text):
        return "▁A▁b▁c" if text else ""

    def encode(self, text, out_type=str):
        del out_type
        return text.split()


def row_for_bucket(bucket, index=0):
    while True:
        source = f"source words {index}"
        target = f"target words {index}"
        if split_bucket(source, target) == bucket:
            return {"text_zh": source, "text_en": target}
        index += 1


def row_for_direction_bucket(direction, bucket, index=0):
    while True:
        row = {"text_zh": f"source words {index}", "text_en": f"target words {index}"}
        mapped = direction_row((row["text_zh"], row["text_en"]), direction)
        if split_bucket(mapped["source"], mapped["target"]) == bucket:
            return row
        index += 1


class PrepareBistTest(unittest.TestCase):
    def test_implementation_hash_is_canonical_across_checkout_line_endings(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            lf = root / "lf.py"
            crlf = root / "crlf.py"
            lf.write_bytes(b"line one\nline two\n")
            crlf.write_bytes(b"line one\r\nline two\r\n")
            self.assertEqual(_file_sha256(lf), _file_sha256(crlf))

    def test_checked_in_manifests_pin_exact_real_result_without_machine_paths(self):
        config = load_config(CONFIG)
        source = json.loads(SOURCE_MANIFEST.read_text(encoding="utf-8"))
        validate_source_manifest(source, config)
        result = json.loads(RESULT_MANIFEST.read_text(encoding="utf-8"))
        self.assertEqual(
            set(result["outputs"]),
            {f"{direction}.{split}.jsonl" for direction in ("zh-en", "en-zh") for split in ("train", "validation", "test")},
        )
        for direction in ("zh-en", "en-zh"):
            for split, quota in config["quotas"].items():
                self.assertEqual(result["outputs"][f"{direction}.{split}.jsonl"]["count"], quota)
        self.assertEqual(len(result["source_shards"]), 4)
        self.assertTrue(all("parquet_schema" in shard for shard in result["source_shards"]))
        self.assertEqual(
            result["implementation"]["script_sha256"], _file_sha256(ROOT / "prepare_bist.py")
        )
        self.assertEqual(
            result["implementation"]["config_sha256"], _file_sha256(CONFIG)
        )
        encoded = json.dumps(result, ensure_ascii=False)
        self.assertNotIn("AppData", encoded)
        self.assertNotIn("timestamp", encoded)

    def test_t2_lock_is_separate_hashed_and_contains_only_dataset_runtime_roots(self):
        lock = (ROOT / "requirements-t2.lock.txt").read_text(encoding="utf-8")
        self.assertIn("huggingface-hub==0.27.1", lock)
        self.assertIn("pyarrow==17.0.0", lock)
        self.assertIn("sentencepiece==0.2.0", lock)
        self.assertIn("--hash=sha256:", lock)
        self.assertNotIn("torch==", lock)

    def test_sentencepiece_wrapper_deescapes_model_normalizer_whitespace(self):
        processor = SentencePieceTextProcessor(RawSentencePieceProcessor())
        self.assertEqual(processor.normalize("Ａ  b c"), "A b c")
        self.assertEqual(processor.encode("A b c", out_type=str), ["A", "b", "c"])

    def test_split_bucket_is_big_endian_sha_prefix(self):
        digest = hashlib.sha256("你好\0hello".encode("utf-8")).digest()
        self.assertEqual(split_bucket("你好", "hello"), int.from_bytes(digest[:4], "big") % 20)

    def test_normalization_uses_injected_model_seam_and_inclusive_piece_bounds(self):
        processor = FixtureProcessor()
        pair = normalize_pair(
            {"text_zh": "  Ａ b c  ", "text_en": " one two three "}, processor, 3, 3
        )
        self.assertEqual(pair, ("A b c", "one two three"))
        self.assertEqual(processor.normalized, ["  Ａ b c  ", " one two three "])
        self.assertIsNone(
            normalize_pair({"text_zh": "one two", "text_en": "one two three"}, processor, 3, 120)
        )
        self.assertIsNone(
            normalize_pair(
                {"text_zh": "one two three four", "text_en": "one two three"}, processor, 3, 3
            )
        )
        self.assertIsNone(normalize_pair({"text_zh": " ", "text_en": "one two three"}, processor, 3, 120))

    def test_direction_rows_are_not_swapped(self):
        pair = ("你好 世界 示例", "hello world example")
        self.assertEqual(
            direction_row(pair, "zh-en"),
            {"source": pair[0], "target": pair[1], "direction_id": 32001},
        )
        self.assertEqual(
            direction_row(pair, "en-zh"),
            {"source": pair[1], "target": pair[0], "direction_id": 32002},
        )
        with self.assertRaisesRegex(DatasetError, "direction"):
            direction_row(pair, "fr-en")

    def test_source_schema_is_exact_and_string_typed(self):
        self.assertEqual(
            validate_source_row({"text_zh": "中文", "text_en": "English"}), ("中文", "English")
        )
        for row in (
            {"text_zh": "中文"},
            {"text_zh": "中文", "text_en": 7},
            {"text_zh": "中文", "text_en": "English", "extra": "rejected"},
        ):
            with self.subTest(row=row), self.assertRaises(DatasetError):
                validate_source_row(row)

    def test_config_and_source_manifest_are_strict_and_pinned(self):
        config = {
            "schema_version": 1,
            "seed": 20260713,
            "dataset": {"repo": "Mxode/BiST", "revision": "aca6be897afc319f779009379c8b849c1eb8d63e"},
            "tokenizer": {
                "repo": "Helsinki-NLP/opus-mt_tiny_zho-eng",
                "revision": "4ee3a9342aae4ca6fbae82c930b5dccff5dd68dd",
                "file": "source.spm",
                "size": 755175,
                "sha256": "e5528a5c3685d08f8868902d31febeb763eea8519f9997f43b05964b02554640",
            },
            "directions": {
                "zh-en": {"direction_id": 32001, "subset": "zh-en"},
                "en-zh": {"direction_id": 32002, "subset": "en-zh"},
            },
            "quotas": {"train": 90000, "validation": 5000, "test": 5000},
            "token_bounds": {"min": 3, "max": 120},
            "split": {"buckets": 20, "test": [0], "validation": [1], "train": [2, 19]},
        }
        source = {
            "schema_version": 1,
            "repo": "Mxode/BiST",
            "revision": "aca6be897afc319f779009379c8b849c1eb8d63e",
            "license": "cc-by-sa-4.0",
            "dataset_card": {"path": "README.md", "size": 4662, "sha256": "a" * 64},
            "shards": [
                {"subset": "en-zh", "path": "data/en-zh/train-0.parquet", "size": 4, "sha256": "c" * 64},
                {"subset": "zh-en", "path": "data/zh-en/train-0.parquet", "size": 3, "sha256": "b" * 64},
            ],
        }
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            config_path = root / "config.json"
            config_path.write_text(json.dumps(config), encoding="utf-8")
            self.assertEqual(load_config(config_path), config)
            validate_source_manifest(source, config)
            config["unexpected"] = True
            config_path.write_text(json.dumps(config), encoding="utf-8")
            with self.assertRaises(DatasetError):
                load_config(config_path)
            config.pop("unexpected")
            source["revision"] = "0" * 40
            with self.assertRaises(DatasetError):
                validate_source_manifest(source, config)

    def test_file_verification_checks_exact_size_and_sha256(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "shard.parquet"
            path.write_bytes(b"verified")
            verify_file(path, len(b"verified"), hashlib.sha256(b"verified").hexdigest())
            with self.assertRaisesRegex(DatasetError, "size"):
                verify_file(path, 1, hashlib.sha256(b"verified").hexdigest())
            with self.assertRaisesRegex(DatasetError, "SHA-256"):
                verify_file(path, len(b"verified"), "0" * 64)

    def test_offline_provider_only_reads_verified_cache_and_never_downloads(self):
        payload = b"fixture parquet bytes"
        shard = {
            "subset": "zh-en",
            "path": "data/zh-en/train-0.parquet",
            "size": len(payload),
            "sha256": hashlib.sha256(payload).hexdigest(),
        }
        calls = []

        def forbidden_download(*args, **kwargs):
            calls.append((args, kwargs))
            raise AssertionError("offline provider touched network")

        def fixture_reader(path):
            self.assertEqual(path.read_bytes(), payload)
            yield [{"text_zh": "中 文 示例", "text_en": "an English example"}]

        with tempfile.TemporaryDirectory() as directory:
            provider = HuggingFaceParquetProvider(
                Path(directory), offline=True, downloader=forbidden_download, batch_reader=fixture_reader
            )
            path = provider.cache_path(shard)
            path.parent.mkdir(parents=True)
            path.write_bytes(payload)
            self.assertEqual(list(provider.iter_batches(shard))[0][0]["text_zh"], "中 文 示例")
            self.assertEqual(calls, [])
            path.write_bytes(b"corrupt")
            with self.assertRaises(DatasetError):
                list(provider.iter_batches(shard))

    def test_parquet_schema_allows_only_pinned_auxiliary_columns(self):
        schema = [
            {"name": "text_zh", "type": "string"},
            {"name": "text_en", "type": "string"},
            {"name": "length_zh", "type": "int64"},
            {"name": "length_en", "type": "int64"},
            {"name": "model", "type": "string"},
        ]
        validate_parquet_schema(schema, "zh-en")
        reverse_schema = [schema[1], schema[0], schema[3], schema[2], schema[4]]
        validate_parquet_schema(reverse_schema, "en-zh")
        for fields in (schema[:-1], schema + [{"name": "unknown", "type": "string"}]):
            with self.subTest(fields=fields), self.assertRaises(DatasetError):
                validate_parquet_schema(fields, "zh-en")
        with self.assertRaises(DatasetError):
            validate_parquet_schema(reverse_schema, "zh-en")

    def test_tokenizer_offline_cache_is_verified_without_network(self):
        payload = b"sentencepiece model"
        config = {
            "repo": "Helsinki-NLP/opus-mt_tiny_zho-eng",
            "revision": "4ee3a9342aae4ca6fbae82c930b5dccff5dd68dd",
            "file": "source.spm",
            "size": len(payload),
            "sha256": hashlib.sha256(payload).hexdigest(),
        }
        calls = []
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            expected = root / "Helsinki-NLP--opus-mt_tiny_zho-eng" / config["revision"] / "source.spm"
            expected.parent.mkdir(parents=True)
            expected.write_bytes(payload)
            actual = ensure_tokenizer(
                config,
                root,
                offline=True,
                downloader=lambda *args, **kwargs: calls.append((args, kwargs)),
            )
            self.assertEqual(actual, expected)
            self.assertEqual(calls, [])

    def test_remote_revision_must_resolve_to_exact_commit(self):
        shard = {"path": "data/dev.parquet", "size": 7, "sha256": "c" * 64}
        sibling = SimpleNamespace(
            rfilename=shard["path"], size=7, lfs=SimpleNamespace(size=7, sha256="c" * 64)
        )
        good = SimpleNamespace(
            dataset_info=lambda **kwargs: SimpleNamespace(sha=kwargs["revision"], siblings=[sibling])
        )
        verify_remote_revision(good, "Mxode/BiST", "a" * 40, [shard])
        bad = SimpleNamespace(dataset_info=lambda **kwargs: SimpleNamespace(sha="b" * 40))
        with self.assertRaisesRegex(DatasetError, "resolved"):
            verify_remote_revision(bad, "Mxode/BiST", "a" * 40)
        sibling.lfs.sha256 = "d" * 64
        with self.assertRaisesRegex(DatasetError, "metadata"):
            verify_remote_revision(good, "Mxode/BiST", "a" * 40, [shard])

    def test_result_manifest_is_machine_independent_and_pins_inputs(self):
        config = {
            "seed": 20260713,
            "dataset": {"repo": "Mxode/BiST", "revision": "a" * 40},
            "tokenizer": {
                "repo": "tokenizer",
                "revision": "b" * 40,
                "file": "source.spm",
                "size": 4,
                "sha256": "c" * 64,
            },
            "directions": {"zh-en": {"direction_id": 32001}, "en-zh": {"direction_id": 32002}},
            "quotas": {"train": 1, "validation": 1, "test": 1},
            "token_bounds": {"min": 3, "max": 120},
            "split": {"buckets": 20, "test": [0], "validation": [1], "train": [2, 19]},
        }
        source_manifest = {
            "license": "cc-by-sa-4.0",
            "dataset_card": {"path": "README.md", "size": 4, "sha256": "d" * 64},
        }
        preparation = {
            "outputs": {"zh-en.train.jsonl": {"path": "zh-en.train.jsonl", "count": 1}},
            "filtering": {"zh-en": {"accepted": 1}},
            "consumed_shards": [{"path": "data/zh-en/train-0.parquet", "size": 3, "sha256": "e" * 64}],
        }
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            config_path = root / "training-v1.json"
            script_path = root / "prepare_bist.py"
            config_path.write_text("config", encoding="utf-8")
            script_path.write_text("script", encoding="utf-8")
            result = build_result_manifest(config, source_manifest, preparation, config_path, script_path)
            encoded = json.dumps(result, ensure_ascii=False)
            self.assertNotIn(str(root), encoded)
            self.assertNotIn("timestamp", encoded)
            self.assertEqual(result["normalizer"]["name"], "nmt_nfkc")
            self.assertIn("synthetic", result["provenance"]["limitations"].lower())

    def test_shards_are_sorted_lexically_within_subset(self):
        shards = [
            {"subset": "zho-eng", "path": "data/zho-eng/part-10.parquet"},
            {"subset": "eng-zho", "path": "data/eng-zho/part-02.parquet"},
            {"subset": "zho-eng", "path": "data/zho-eng/part-01.parquet"},
            {"subset": "eng-zho", "path": "data/eng-zho/part-01.parquet"},
        ]
        self.assertEqual(
            [item["path"] for item in sort_shards(shards)],
            [
                "data/eng-zho/part-01.parquet",
                "data/eng-zho/part-02.parquet",
                "data/zho-eng/part-01.parquet",
                "data/zho-eng/part-10.parquet",
            ],
        )

    def test_serialization_is_fixed_utf8_lf_and_unescaped(self):
        row = {"target": "hello", "direction_id": 32001, "source": "你好"}
        encoded = serialize_row(row)
        self.assertEqual(encoded, '{"source":"你好","target":"hello","direction_id":32001}\n'.encode("utf-8"))
        self.assertEqual(hashlib.sha256(encoded).hexdigest(), hashlib.sha256(serialize_row(row)).hexdigest())

    def test_fixture_preparation_deduplicates_and_fills_exact_small_quotas(self):
        zh_rows = [row_for_direction_bucket("zh-en", bucket) for bucket in (2, 1, 0)]
        en_rows = [row_for_direction_bucket("en-zh", bucket, 100000) for bucket in (2, 1, 0)]
        rows = [zh_rows[0], dict(zh_rows[0])] + zh_rows[1:] + en_rows
        provider = FixtureProvider({"data/a.parquet": rows[:4], "data/z.parquet": rows[4:]})
        shards = [
            {"subset": "default", "path": "data/z.parquet", "sha256": "a" * 64, "size": 1},
            {"subset": "default", "path": "data/a.parquet", "sha256": "b" * 64, "size": 2},
        ]
        config = {
            "directions": {"zh-en": 32001, "en-zh": 32002},
            "quotas": {"train": 1, "validation": 1, "test": 1},
            "token_bounds": {"min": 3, "max": 120},
        }
        with tempfile.TemporaryDirectory() as directory:
            result = prepare_from_provider(provider, FixtureProcessor(), shards, Path(directory), config)
            self.assertEqual(
                provider.visited,
                ["data/a.parquet", "data/a.parquet", "data/z.parquet"],
            )
            self.assertEqual(result["filtering"]["zh-en"]["duplicate"], 1)
            self.assertEqual(result["filtering"]["en-zh"]["duplicate"], 1)
            for direction in ("zh-en", "en-zh"):
                for split in ("train", "validation", "test"):
                    artifact = result["outputs"][f"{direction}.{split}.jsonl"]
                    self.assertEqual(artifact["count"], 1)
                    path = Path(directory) / artifact["path"]
                    self.assertEqual(artifact["bytes"], path.stat().st_size)
                    self.assertEqual(artifact["sha256"], hashlib.sha256(path.read_bytes()).hexdigest())
                    record = json.loads(path.read_text(encoding="utf-8"))
                    self.assertEqual(list(record), ["source", "target", "direction_id"])

    def test_insufficient_rows_fail_without_partial_output_contract(self):
        provider = FixtureProvider({"data/only.parquet": [row_for_bucket(2)]})
        config = {
            "directions": {"zh-en": 32001, "en-zh": 32002},
            "quotas": {"train": 2, "validation": 1, "test": 1},
            "token_bounds": {"min": 3, "max": 120},
        }
        with tempfile.TemporaryDirectory() as directory:
            with self.assertRaisesRegex(DatasetError, "quotas"):
                prepare_from_provider(
                    provider,
                    FixtureProcessor(),
                    [{"subset": "default", "path": "data/only.parquet", "sha256": "a" * 64, "size": 1}],
                    Path(directory),
                    config,
                )


if __name__ == "__main__":
    unittest.main()
