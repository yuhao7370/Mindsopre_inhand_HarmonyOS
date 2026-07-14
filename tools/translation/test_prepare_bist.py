import hashlib
import json
import os
import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest import mock

from tools.translation.prepare_bist import (
    DatasetError,
    HuggingFaceParquetProvider,
    SentencePieceTextProcessor,
    _file_sha256,
    _safe_child,
    build_result_manifest,
    direction_row,
    load_config,
    main,
    ensure_tokenizer,
    normalize_pair,
    prepare_from_provider,
    publish_prepared_result,
    publish_transaction,
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
    def _run_main_with_manifest_publish_failure(self, root, fail_restore):
        output = root / "published"
        output.mkdir()
        names = [
            f"{direction}.{split}.jsonl"
            for direction in ("zh-en", "en-zh")
            for split in ("train", "validation", "test")
        ]
        expected = {}
        outputs = {}
        for index, name in enumerate(names):
            payload = f"old-{index}".encode()
            (output / name).write_bytes(payload)
            expected[name] = payload
            outputs[name] = {"path": name}
        result_manifest = root / "bist-v1.json"
        expected_manifest = b"old-manifest"
        result_manifest.write_bytes(expected_manifest)

        def prepare(_provider, _processor, _shards, staging, _config):
            for index, name in enumerate(names):
                (staging / name).write_bytes(f"new-{index}".encode())
            return {"outputs": outputs, "consumed_shards": []}

        real_replace = os.replace
        publish_calls = 0

        def fail_manifest_publish(source, destination):
            nonlocal publish_calls
            publish_calls += 1
            if publish_calls == 14:
                raise OSError("injected manifest publish failure")
            real_replace(source, destination)

        real_publish_transaction = publish_transaction

        def inject_publish(staging, publications, replace_func=None):
            del replace_func
            return real_publish_transaction(
                staging, publications, replace_func=fail_manifest_publish
            )

        restore_calls = 0

        def restore(source, destination):
            nonlocal restore_calls
            restore_calls += 1
            if fail_restore and restore_calls == 1:
                raise OSError("injected backup restore failure")
            real_replace(source, destination)

        arguments = [
            "--config", str(root / "config.json"),
            "--source-manifest", str(root / "source.json"),
            "--cache-dir", str(root / "cache"),
            "--output-dir", str(output),
            "--tokenizer-cache-dir", str(root / "tokenizer"),
            "--result-manifest", str(result_manifest),
            "--offline",
        ]
        with mock.patch(
                    "tools.translation.prepare_bist.load_config",
                    return_value={"tokenizer": {}},
                ), \
                mock.patch(
                    "tools.translation.prepare_bist._load_source_manifest",
                    return_value={"shards": []},
                ), \
                mock.patch("tools.translation.prepare_bist.ensure_tokenizer", return_value=root / "source.spm"), \
                mock.patch(
                    "tools.translation.prepare_bist.SentencePieceTextProcessor.from_model",
                    return_value=object(),
                ), \
                mock.patch(
                    "tools.translation.prepare_bist.HuggingFaceParquetProvider",
                    return_value=SimpleNamespace(downloaded=set()),
                ), \
                mock.patch("tools.translation.prepare_bist._prepare_into", side_effect=prepare), \
                mock.patch(
                    "tools.translation.prepare_bist.build_result_manifest",
                    return_value={"schema_version": 1},
                ), \
                mock.patch(
                    "tools.translation.prepare_bist.publish_transaction",
                    side_effect=inject_publish,
                ), \
                mock.patch("tools.translation.prepare_bist.os.replace", side_effect=restore):
            try:
                main(arguments)
            except Exception as error:
                return error, output, result_manifest, expected, expected_manifest
        self.fail("injected publication failure did not raise")

    def test_implementation_hash_is_canonical_across_checkout_line_endings(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            lf = root / "lf.py"
            crlf = root / "crlf.py"
            lf.write_bytes(b"line one\nline two\n")
            crlf.write_bytes(b"line one\r\nline two\r\n")
            self.assertEqual(_file_sha256(lf), _file_sha256(crlf))

    def test_safe_child_rejects_traversal_and_nested_symlink_or_reparse_point(self):
        with tempfile.TemporaryDirectory() as directory:
            base = Path(directory)
            root = base / "root"
            outside = base / "outside"
            root.mkdir()
            outside.mkdir()
            with self.assertRaisesRegex(DatasetError, "traversal"):
                _safe_child(root, "../outside/file", "fixture")
            link = root / "linked"
            try:
                link.symlink_to(outside, target_is_directory=True)
            except OSError as error:
                if os.name != "nt":
                    self.skipTest("symlink creation unavailable: %s" % error)
                link.mkdir()
                real_lstat = os.lstat

                def reparse_lstat(path):
                    details = real_lstat(path)
                    attributes = getattr(details, "st_file_attributes", 0)
                    if os.path.normcase(os.path.abspath(path)) == os.path.normcase(str(link.absolute())):
                        attributes |= 0x400
                    return SimpleNamespace(st_mode=details.st_mode, st_file_attributes=attributes)

                with mock.patch("tools.translation.prepare_bist.os.lstat", side_effect=reparse_lstat):
                    with self.assertRaisesRegex(DatasetError, "reparse"):
                        _safe_child(root, "linked/file", "fixture")
                return
            expected_kind = "reparse" if os.name == "nt" else "symlink"
            with self.assertRaisesRegex(DatasetError, expected_kind):
                _safe_child(root, "linked/file", "fixture")

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
            result["source_manifest"],
            {
                "path": "tools/translation/manifests/bist-source-v1.json",
                "bytes": 5198,
                "sha256": "a39804b4f5d884e624b7c4748a2582bfe4133e9f04463bf3578d468fa1d8c4e4",
            },
        )
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
            self.assertEqual(actual, expected.resolve())
            self.assertEqual(calls, [])

    def test_remote_revision_must_resolve_to_exact_commit(self):
        def shard(subset, name, marker):
            return {"subset": subset, "path": f"data/{subset}/{name}.parquet", "size": 7, "sha256": marker * 64}

        def sibling(item):
            return SimpleNamespace(
                rfilename=item["path"],
                size=item["size"],
                lfs=SimpleNamespace(size=item["size"], sha256=item["sha256"]),
            )

        en = shard("en-zh", "dev", "c")
        zh = shard("zh-en", "dev", "d")
        arxiv = SimpleNamespace(
            rfilename="data/en-zh(arxiv_abstract)/extra.parquet",
            size=9,
            lfs=SimpleNamespace(size=9, sha256="f" * 64),
        )
        good = SimpleNamespace(
            dataset_info=lambda **kwargs: SimpleNamespace(
                sha=kwargs["revision"], siblings=[sibling(en), sibling(zh), arxiv]
            )
        )
        verify_remote_revision(good, "Mxode/BiST", "a" * 40, [en, zh], {"en-zh", "zh-en"})
        bad = SimpleNamespace(dataset_info=lambda **kwargs: SimpleNamespace(sha="b" * 40))
        with self.assertRaisesRegex(DatasetError, "resolved"):
            verify_remote_revision(bad, "Mxode/BiST", "a" * 40)
        changed = sibling(en)
        changed.lfs.sha256 = "e" * 64
        drift = SimpleNamespace(
            dataset_info=lambda **kwargs: SimpleNamespace(sha=kwargs["revision"], siblings=[changed, sibling(zh)])
        )
        with self.assertRaisesRegex(DatasetError, "metadata"):
            verify_remote_revision(drift, "Mxode/BiST", "a" * 40, [en, zh], {"en-zh", "zh-en"})

    def test_remote_inventory_rejects_manifest_missing_or_remote_extra_configured_shard(self):
        def item(path, marker):
            return {"subset": path.split("/")[1], "path": path, "size": 7, "sha256": marker * 64}

        def sibling(shard):
            return SimpleNamespace(
                rfilename=shard["path"],
                size=shard["size"],
                lfs=SimpleNamespace(size=shard["size"], sha256=shard["sha256"]),
            )

        en = item("data/en-zh/dev.parquet", "a")
        zh = item("data/zh-en/dev.parquet", "b")
        extra = item("data/en-zh/train-0.parquet", "c")
        api = SimpleNamespace(
            dataset_info=lambda **kwargs: SimpleNamespace(
                sha=kwargs["revision"], siblings=[sibling(en), sibling(zh), sibling(extra)]
            )
        )
        with self.assertRaisesRegex(DatasetError, "inventory"):
            verify_remote_revision(api, "Mxode/BiST", "a" * 40, [en, zh], {"en-zh", "zh-en"})
        missing_remote = SimpleNamespace(
            dataset_info=lambda **kwargs: SimpleNamespace(
                sha=kwargs["revision"], siblings=[sibling(en), sibling(zh)]
            )
        )
        with self.assertRaisesRegex(DatasetError, "inventory"):
            verify_remote_revision(
                missing_remote, "Mxode/BiST", "a" * 40, [en, zh, extra], {"en-zh", "zh-en"}
            )

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
            source_path = root / "tools" / "translation" / "manifests" / "bist-source-v1.json"
            source_path.parent.mkdir(parents=True)
            source_path.write_text("source manifest\n", encoding="utf-8")
            result = build_result_manifest(
                config,
                source_manifest,
                preparation,
                config_path,
                script_path,
                source_path,
                root,
            )
            encoded = json.dumps(result, ensure_ascii=False)
            self.assertNotIn(str(root), encoded)
            self.assertNotIn("timestamp", encoded)
            self.assertEqual(result["normalizer"]["name"], "nmt_nfkc")
            self.assertIn("synthetic", result["provenance"]["limitations"].lower())
            self.assertEqual(result["source_manifest"]["path"], "tools/translation/manifests/bist-source-v1.json")

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

    def test_failed_second_direction_preserves_existing_six_file_publication(self):
        zh_rows = [row_for_direction_bucket("zh-en", bucket) for bucket in (2, 1, 0)]
        provider = FixtureProvider(
            {
                "data/zh.parquet": zh_rows,
                "data/en.parquet": [row_for_direction_bucket("en-zh", 2, 100000)],
            }
        )
        shards = [
            {"subset": "en-zh", "path": "data/en.parquet", "sha256": "a" * 64, "size": 1},
            {"subset": "zh-en", "path": "data/zh.parquet", "sha256": "b" * 64, "size": 1},
        ]
        config = {
            "directions": {
                "zh-en": {"direction_id": 32001, "subset": "zh-en"},
                "en-zh": {"direction_id": 32002, "subset": "en-zh"},
            },
            "quotas": {"train": 1, "validation": 1, "test": 1},
            "token_bounds": {"min": 3, "max": 120},
        }
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / "published"
            output.mkdir()
            names = [
                f"{direction}.{split}.jsonl"
                for direction in ("zh-en", "en-zh")
                for split in ("train", "validation", "test")
            ]
            expected = {}
            for index, name in enumerate(names):
                payload = f"old-{index}\n".encode()
                (output / name).write_bytes(payload)
                expected[name] = payload
            with self.assertRaisesRegex(DatasetError, "quotas"):
                prepare_from_provider(provider, FixtureProcessor(), shards, output, config)
            self.assertEqual({name: (output / name).read_bytes() for name in names}, expected)
            self.assertEqual(list(output.parent.glob(".published.staging-*")), [])

    def test_publish_failure_rolls_back_every_replaced_target(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            staging = root / "staging"
            target = root / "target"
            staging.mkdir()
            target.mkdir()
            publications = []
            expected = {}
            for index in range(3):
                name = f"artifact-{index}"
                (staging / name).write_bytes(f"new-{index}".encode())
                payload = f"old-{index}".encode()
                destination = target / name
                destination.write_bytes(payload)
                expected[name] = payload
                publications.append((staging / name, destination))
            calls = 0

            def fail_once(source, destination):
                nonlocal calls
                calls += 1
                if calls == 5:
                    raise OSError("injected publish failure")
                os.replace(source, destination)

            with self.assertRaisesRegex(OSError, "injected"):
                publish_transaction(staging, publications, replace_func=fail_once)
            self.assertEqual({name: (target / name).read_bytes() for name in expected}, expected)
            self.assertFalse((staging / ".publication-backup").exists())

    def test_result_manifest_publish_failure_rolls_back_old_manifest_and_six_jsonl(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            staging = root / "staging"
            output = root / "output"
            staging.mkdir()
            output.mkdir()
            names = [
                f"{direction}.{split}.jsonl"
                for direction in ("zh-en", "en-zh")
                for split in ("train", "validation", "test")
            ]
            expected = {}
            outputs = {}
            for index, name in enumerate(names):
                (staging / name).write_bytes(f"new-{index}".encode())
                payload = f"old-{index}".encode()
                (output / name).write_bytes(payload)
                expected[name] = payload
                outputs[name] = {"path": name}
            result_manifest = root / "bist-v1.json"
            expected_manifest = b"old-manifest"
            result_manifest.write_bytes(expected_manifest)
            calls = 0

            def fail_manifest_publish(source, destination):
                nonlocal calls
                calls += 1
                if calls == 14:
                    raise OSError("injected manifest publish failure")
                os.replace(source, destination)

            with self.assertRaisesRegex(OSError, "manifest publish"):
                publish_prepared_result(
                    staging,
                    output,
                    result_manifest,
                    {"outputs": outputs},
                    {"schema_version": 1},
                    replace_func=fail_manifest_publish,
                )
            self.assertEqual({name: (output / name).read_bytes() for name in names}, expected)
            self.assertEqual(result_manifest.read_bytes(), expected_manifest)

    def test_incomplete_rollback_preserves_recovery_directory_and_backup(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            error, output, result_manifest, expected, expected_manifest = (
                self._run_main_with_manifest_publish_failure(root, fail_restore=True)
            )
            self.assertIsInstance(error, DatasetError)
            recovery = error.recovery_path
            self.assertIn(str(recovery), str(error))
            self.assertTrue(recovery.is_dir())
            self.assertFalse(result_manifest.exists())
            self.assertEqual((recovery / "000006.bak").read_bytes(), expected_manifest)
            self.assertEqual(
                {name: (output / name).read_bytes() for name in expected}, expected
            )

    def test_complete_rollback_still_cleans_staging(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            error, output, result_manifest, expected, expected_manifest = (
                self._run_main_with_manifest_publish_failure(root, fail_restore=False)
            )
            self.assertRegex(str(error), "manifest publish")
            self.assertEqual(
                {name: (output / name).read_bytes() for name in expected}, expected
            )
            self.assertEqual(result_manifest.read_bytes(), expected_manifest)
            self.assertEqual(list(root.glob(".published.staging-*")), [])


if __name__ == "__main__":
    unittest.main()
