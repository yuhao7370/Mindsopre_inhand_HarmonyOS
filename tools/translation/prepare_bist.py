#!/usr/bin/env python3
"""Prepare deterministic, verified BiST JSONL shards."""

import argparse
import hashlib
import json
import os
import shutil
import stat
import tempfile
import time
from pathlib import Path
from pathlib import PurePosixPath


DATASET_REPO = "Mxode/BiST"
DATASET_REVISION = "aca6be897afc319f779009379c8b849c1eb8d63e"
TOKENIZER_REPO = "Helsinki-NLP/opus-mt_tiny_zho-eng"
TOKENIZER_REVISION = "4ee3a9342aae4ca6fbae82c930b5dccff5dd68dd"
TOKENIZER_FILE = "source.spm"
TOKENIZER_SIZE = 755175
TOKENIZER_SHA256 = "e5528a5c3685d08f8868902d31febeb763eea8519f9997f43b05964b02554640"
SCHEMA = {"text_zh", "text_en"}
EXPECTED_PARQUET_SCHEMAS = {
    "zh-en": [
        {"name": "text_zh", "type": "string"},
        {"name": "text_en", "type": "string"},
        {"name": "length_zh", "type": "int64"},
        {"name": "length_en", "type": "int64"},
        {"name": "model", "type": "string"},
    ],
    "en-zh": [
        {"name": "text_en", "type": "string"},
        {"name": "text_zh", "type": "string"},
        {"name": "length_en", "type": "int64"},
        {"name": "length_zh", "type": "int64"},
        {"name": "model", "type": "string"},
    ],
}
SPLITS = ("train", "validation", "test")


class DatasetError(RuntimeError):
    pass


def _reject_existing_links(path, label):
    absolute = Path(path).absolute()
    current = Path(absolute.anchor)
    for part in absolute.parts[1:]:
        current /= part
        if not os.path.lexists(str(current)):
            break
        details = os.lstat(str(current))
        attributes = getattr(details, "st_file_attributes", 0)
        reparse_flag = getattr(stat, "FILE_ATTRIBUTE_REPARSE_POINT", 0x400)
        if os.name == "nt" and attributes & reparse_flag:
            raise DatasetError("%s contains a reparse point: %s" % (label, current.name))
        if stat.S_ISLNK(details.st_mode):
            raise DatasetError("%s contains a symlink: %s" % (label, current.name))


def _safe_child(root, relative, label):
    root = Path(root).absolute()
    relative = Path(relative)
    if relative.is_absolute() or ".." in relative.parts:
        raise DatasetError("%s path traversal is not allowed" % label)
    _reject_existing_links(root, label)
    resolved_root = root.resolve(strict=False)
    candidate = root / relative
    _reject_existing_links(candidate, label)
    resolved_candidate = candidate.resolve(strict=False)
    try:
        resolved_candidate.relative_to(resolved_root)
    except ValueError as error:
        raise DatasetError("%s resolves outside its root" % label) from error
    return resolved_candidate


def _safe_exact_path(path, label):
    path = Path(path).absolute()
    return _safe_child(path.parent, path.name, label)


class SentencePieceTextProcessor:
    def __init__(self, processor):
        self._processor = processor

    @classmethod
    def from_model(cls, model_path):
        try:
            import sentencepiece
        except ImportError as error:
            raise DatasetError("real mode requires the pinned sentencepiece dependency") from error
        return cls(sentencepiece.SentencePieceProcessor(model_file=str(model_path)))

    def normalize(self, text):
        # SentencePiece exposes model-backed nmt_nfkc output with escaped spaces.
        return self._processor.normalize(text).replace("▁", " ").strip()

    def encode(self, text, out_type=str):
        return self._processor.encode(text, out_type=out_type)


def _exact_keys(value, keys, label):
    if not isinstance(value, dict) or set(value) != set(keys):
        raise DatasetError("%s must contain exactly: %s" % (label, ", ".join(keys)))


def _sha256_shape(value, label):
    if not isinstance(value, str) or len(value) != 64:
        raise DatasetError("%s must be a lowercase SHA-256" % label)
    try:
        int(value, 16)
    except ValueError as error:
        raise DatasetError("%s must be a lowercase SHA-256" % label) from error
    if value != value.lower():
        raise DatasetError("%s must be a lowercase SHA-256" % label)


def load_config(path):
    try:
        config = json.loads(Path(path).read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise DatasetError("cannot read strict training config: %s" % error) from error
    _exact_keys(
        config,
        ("schema_version", "seed", "dataset", "tokenizer", "directions", "quotas", "token_bounds", "split"),
        "training config",
    )
    if config["schema_version"] != 1 or config["seed"] != 20260713:
        raise DatasetError("training config version or seed does not match v1")
    _exact_keys(config["dataset"], ("repo", "revision"), "dataset config")
    if config["dataset"] != {"repo": DATASET_REPO, "revision": DATASET_REVISION}:
        raise DatasetError("dataset repository/revision does not match the pin")
    _exact_keys(config["tokenizer"], ("repo", "revision", "file", "size", "sha256"), "tokenizer config")
    expected_tokenizer = {
        "repo": TOKENIZER_REPO,
        "revision": TOKENIZER_REVISION,
        "file": TOKENIZER_FILE,
        "size": TOKENIZER_SIZE,
        "sha256": TOKENIZER_SHA256,
    }
    if config["tokenizer"] != expected_tokenizer:
        raise DatasetError("tokenizer config does not match the immutable pin")
    _exact_keys(config["directions"], ("zh-en", "en-zh"), "directions config")
    expected_directions = {
        "zh-en": {"direction_id": 32001, "subset": "zh-en"},
        "en-zh": {"direction_id": 32002, "subset": "en-zh"},
    }
    if config["directions"] != expected_directions:
        raise DatasetError("direction ids/subsets do not match v1")
    if config["quotas"] != {"train": 90000, "validation": 5000, "test": 5000}:
        raise DatasetError("quotas do not match v1")
    if config["token_bounds"] != {"min": 3, "max": 120}:
        raise DatasetError("token bounds do not match v1")
    if config["split"] != {"buckets": 20, "test": [0], "validation": [1], "train": [2, 19]}:
        raise DatasetError("split config does not match v1")
    return config


def validate_source_manifest(manifest, config):
    _exact_keys(
        manifest,
        ("schema_version", "repo", "revision", "license", "dataset_card", "shards"),
        "source manifest",
    )
    if manifest["schema_version"] != 1:
        raise DatasetError("source manifest version must be 1")
    if manifest["repo"] != config["dataset"]["repo"] or manifest["revision"] != config["dataset"]["revision"]:
        raise DatasetError("source manifest repository/revision does not match config")
    if manifest["license"] != "cc-by-sa-4.0":
        raise DatasetError("source manifest license must match the pinned dataset card")
    _exact_keys(manifest["dataset_card"], ("path", "size", "sha256"), "dataset card")
    _sha256_shape(manifest["dataset_card"]["sha256"], "dataset card hash")
    if manifest["dataset_card"]["path"] != "README.md" or manifest["dataset_card"]["size"] <= 0:
        raise DatasetError("dataset card metadata is invalid")
    if not isinstance(manifest["shards"], list) or not manifest["shards"]:
        raise DatasetError("source manifest shards must be non-empty")
    previous = None
    subsets = set()
    for shard in manifest["shards"]:
        _exact_keys(shard, ("subset", "path", "size", "sha256"), "source shard")
        _sha256_shape(shard["sha256"], "source shard hash")
        if shard["size"] <= 0 or not shard["path"].endswith(".parquet"):
            raise DatasetError("source shard size/path is invalid")
        key = (shard["subset"], shard["path"])
        if previous is not None and key <= previous:
            raise DatasetError("source shards must be unique and sorted lexically per subset")
        previous = key
        subsets.add(shard["subset"])
    expected_subsets = {value["subset"] for value in config["directions"].values()}
    if subsets != expected_subsets:
        raise DatasetError("source manifest subsets do not match direction config")


def verify_file(path, expected_size, expected_sha256):
    path = Path(path)
    try:
        actual_size = path.stat().st_size
    except OSError as error:
        raise DatasetError("cannot read verified input %s: %s" % (path.name, error)) from error
    if actual_size != expected_size:
        raise DatasetError("verified input size mismatch for %s" % path.name)
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    if digest.hexdigest() != expected_sha256.lower():
        raise DatasetError("verified input SHA-256 mismatch for %s" % path.name)


def validate_parquet_schema(fields, subset):
    if fields != EXPECTED_PARQUET_SCHEMAS.get(subset):
        raise DatasetError("parquet schema differs from the pinned %s five-column allowlist" % subset)


def _schema_metadata(fields):
    encoded = json.dumps(fields, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
    return {"columns": fields, "canonical_sha256": hashlib.sha256(encoded).hexdigest()}


def _pyarrow_batches(path, subset, schema_sink=None):
    try:
        import pyarrow.parquet
    except ImportError as error:
        raise DatasetError("real mode requires the pinned pyarrow dependency") from error
    parquet = pyarrow.parquet.ParquetFile(str(path))
    fields = [{"name": field.name, "type": str(field.type)} for field in parquet.schema_arrow]
    validate_parquet_schema(fields, subset)
    if schema_sink is not None:
        schema_sink(_schema_metadata(fields))
    for batch in parquet.iter_batches(batch_size=4096, columns=["text_zh", "text_en"]):
        yield batch.to_pylist()


class HuggingFaceParquetProvider:
    def __init__(self, cache_dir, offline=False, downloader=None, batch_reader=None, verbose=False):
        self.cache_dir = Path(cache_dir)
        self.offline = offline
        self._downloader = downloader or self._hf_download
        self._batch_reader = batch_reader or _pyarrow_batches
        self._custom_batch_reader = batch_reader is not None
        self.verbose = verbose
        self.downloaded = []
        self.schema_metadata = {}

    @property
    def snapshot_root(self):
        return _safe_child(
            self.cache_dir, Path("Mxode--BiST") / DATASET_REVISION, "dataset snapshot"
        )

    def cache_path(self, shard):
        relative = PurePosixPath(shard["path"])
        if relative.is_absolute() or ".." in relative.parts or "\\" in shard["path"]:
            raise DatasetError("unsafe source shard path")
        return _safe_child(self.snapshot_root, Path(*relative.parts), "source shard cache")

    def _hf_download(self, shard, destination):
        try:
            from huggingface_hub import hf_hub_download
        except ImportError as error:
            raise DatasetError("real mode requires the pinned huggingface-hub dependency") from error
        downloaded = hf_hub_download(
            repo_id=DATASET_REPO,
            filename=shard["path"],
            repo_type="dataset",
            revision=DATASET_REVISION,
            local_dir=str(self.snapshot_root),
        )
        if Path(downloaded) != destination:
            destination.parent.mkdir(parents=True, exist_ok=True)
            if not destination.exists():
                raise DatasetError("Hugging Face download returned an unexpected cache path")

    def iter_batches(self, shard):
        path = self.cache_path(shard)
        if not path.exists():
            if self.offline:
                raise DatasetError("offline cache miss for %s" % shard["path"])
            if self.verbose:
                print("download %s (%d bytes)" % (shard["path"], shard["size"]), flush=True)
            path.parent.mkdir(parents=True, exist_ok=True)
            path = self.cache_path(shard)
            self._downloader(shard, path)
            self.downloaded.append(shard["path"])
        verify_file(path, shard["size"], shard["sha256"])
        if self.verbose:
            print("verified %s %s" % (shard["path"], shard["sha256"]), flush=True)
        if self._custom_batch_reader:
            yield from self._batch_reader(path)
        else:
            yield from self._batch_reader(
                path,
                shard["subset"],
                lambda metadata: self.schema_metadata.__setitem__(shard["path"], metadata),
            )


def _download_tokenizer(tokenizer, snapshot_root, destination):
    try:
        from huggingface_hub import hf_hub_download
    except ImportError as error:
        raise DatasetError("real mode requires the pinned huggingface-hub dependency") from error
    downloaded = hf_hub_download(
        repo_id=tokenizer["repo"],
        filename=tokenizer["file"],
        revision=tokenizer["revision"],
        local_dir=str(snapshot_root),
    )
    if not destination.exists() or Path(downloaded).name != destination.name:
        raise DatasetError("Hugging Face tokenizer download returned an unexpected cache path")


def ensure_tokenizer(tokenizer, cache_dir, offline=False, downloader=None):
    cache_dir = _safe_exact_path(cache_dir, "tokenizer cache")
    snapshot_root = _safe_child(
        cache_dir,
        Path(tokenizer["repo"].replace("/", "--")) / tokenizer["revision"],
        "tokenizer snapshot",
    )
    destination = _safe_child(snapshot_root, tokenizer["file"], "tokenizer model")
    if not destination.exists():
        if offline:
            raise DatasetError("offline cache miss for pinned SentencePiece model")
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination = _safe_child(snapshot_root, tokenizer["file"], "tokenizer model")
        (downloader or _download_tokenizer)(tokenizer, snapshot_root, destination)
    verify_file(destination, tokenizer["size"], tokenizer["sha256"])
    return destination


def verify_remote_revision(api, repo, revision, shards=None, configured_subsets=None):
    try:
        info = api.dataset_info(repo_id=repo, revision=revision, files_metadata=True)
    except Exception as error:
        raise DatasetError("cannot verify pinned remote dataset revision: %s" % error) from error
    if info.sha != revision:
        raise DatasetError("remote dataset revision resolved to %s, expected %s" % (info.sha, revision))
    if shards is not None:
        remote = {sibling.rfilename: sibling for sibling in info.siblings}
        subsets = set(configured_subsets or (shard["subset"] for shard in shards))
        expected_inventory = {
            subset: {shard["path"] for shard in shards if shard["subset"] == subset}
            for subset in subsets
        }
        remote_inventory = {
            subset: {
                sibling.rfilename
                for sibling in info.siblings
                if sibling.rfilename.startswith("data/%s/" % subset)
                and sibling.rfilename.endswith(".parquet")
            }
            for subset in subsets
        }
        if remote_inventory != expected_inventory:
            raise DatasetError("remote configured-subset parquet inventory differs from source manifest")
        for shard in shards:
            sibling = remote.get(shard["path"])
            lfs = None if sibling is None else sibling.lfs
            if (
                sibling is None
                or lfs is None
                or sibling.size != shard["size"]
                or lfs.size != shard["size"]
                or lfs.sha256 != shard["sha256"]
            ):
                raise DatasetError("remote LFS metadata differs for %s" % shard["path"])


def _canonical_text_bytes(path):
    canonical = Path(path).read_text(encoding="utf-8").replace("\r\n", "\n").replace("\r", "\n")
    return canonical.encode("utf-8")


def _file_sha256(path):
    return hashlib.sha256(_canonical_text_bytes(path)).hexdigest()


def build_result_manifest(
    config,
    source_manifest,
    preparation,
    config_path,
    script_path,
    source_manifest_path,
    repository_root,
):
    repository_root = Path(repository_root).resolve()
    source_manifest_path = Path(source_manifest_path).resolve()
    try:
        portable_source_path = source_manifest_path.relative_to(repository_root).as_posix()
    except ValueError as error:
        raise DatasetError("source manifest must be inside the repository") from error
    source_bytes = _canonical_text_bytes(source_manifest_path)
    return {
        "schema_version": 1,
        "dataset": config["dataset"],
        "source_manifest": {
            "path": portable_source_path,
            "bytes": len(source_bytes),
            "sha256": hashlib.sha256(source_bytes).hexdigest(),
        },
        "tokenizer": config["tokenizer"],
        "normalizer": {
            "name": "nmt_nfkc",
            "model_backed": True,
            "add_dummy_prefix": True,
            "remove_extra_whitespaces": True,
            "escape_whitespaces": True,
        },
        "seed": config["seed"],
        "directions": {
            direction: settings["direction_id"] for direction, settings in config["directions"].items()
        },
        "quotas": config["quotas"],
        "token_bounds": config["token_bounds"],
        "split": {
            "algorithm": 'sha256(utf8(source + "\\0" + target)); uint32_be(prefix) % 20',
            "buckets": config["split"],
        },
        "source_shards": preparation["consumed_shards"],
        "filtering": preparation["filtering"],
        "outputs": preparation["outputs"],
        "implementation": {
            "script": "prepare_bist.py",
            "script_sha256": _file_sha256(script_path),
            "config": "config/training-v1.json",
            "config_sha256": _file_sha256(config_path),
        },
        "provenance": {
            "license": source_manifest["license"],
            "dataset_card": source_manifest["dataset_card"],
            "limitations": (
                "BiST contains synthetic parallel rows; this manifest does not guarantee correctness, "
                "representativeness, fairness, or absence of bias."
            ),
        },
    }


def split_bucket(source, target):
    digest = hashlib.sha256((source + "\0" + target).encode("utf-8")).digest()
    return int.from_bytes(digest[:4], "big") % 20


def validate_source_row(row):
    if not isinstance(row, dict) or set(row) != SCHEMA:
        raise DatasetError("source schema must contain exactly text_zh and text_en")
    if not isinstance(row["text_zh"], str) or not isinstance(row["text_en"], str):
        raise DatasetError("source fields text_zh and text_en must be strings")
    return row["text_zh"], row["text_en"]


def normalize_pair(row, processor, min_tokens, max_tokens):
    text_zh, text_en = validate_source_row(row)
    normalized = tuple(processor.normalize(text).strip() for text in (text_zh, text_en))
    if not all(normalized):
        return None
    lengths = [len(processor.encode(text, out_type=str)) for text in normalized]
    if any(length < min_tokens or length > max_tokens for length in lengths):
        return None
    return normalized


def direction_row(pair, direction):
    if direction == "zh-en":
        source, target, direction_id = pair[0], pair[1], 32001
    elif direction == "en-zh":
        source, target, direction_id = pair[1], pair[0], 32002
    else:
        raise DatasetError("unsupported direction: %s" % direction)
    return {"source": source, "target": target, "direction_id": direction_id}


def serialize_row(row):
    if set(row) != {"source", "target", "direction_id"}:
        raise DatasetError("output row schema is invalid")
    ordered = {
        "source": row["source"],
        "target": row["target"],
        "direction_id": row["direction_id"],
    }
    return (json.dumps(ordered, ensure_ascii=False, separators=(",", ":")) + "\n").encode("utf-8")


def sort_shards(shards):
    for shard in shards:
        if not isinstance(shard.get("subset"), str) or not isinstance(shard.get("path"), str):
            raise DatasetError("each source shard needs string subset and path")
    return sorted(shards, key=lambda shard: (shard["subset"], shard["path"]))


def _split_name(bucket):
    if bucket == 0:
        return "test"
    if bucket == 1:
        return "validation"
    return "train"


def _direction_settings(config, direction):
    value = config["directions"][direction]
    if isinstance(value, int):
        return value, "default"
    return value["direction_id"], value["subset"]


def _artifact(path, count, relative_path):
    digest = hashlib.sha256()
    size = 0
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
            size += len(chunk)
    return {
        "path": relative_path,
        "count": count,
        "bytes": size,
        "sha256": digest.hexdigest(),
    }


def _prepare_into(provider, processor, shards, output_root, config):
    """Prepare from an injected batch provider; unit tests need no optional dependencies."""
    output_root = _safe_exact_path(output_root, "staged dataset output")
    output_root.mkdir(parents=True, exist_ok=True)
    output_root = _safe_exact_path(output_root, "staged dataset output")
    quotas = config["quotas"]
    min_tokens = config["token_bounds"]["min"]
    max_tokens = config["token_bounds"]["max"]
    ordered_shards = sort_shards(shards)
    outputs = {}
    filtering = {}
    consumed = {}
    paths_to_clean = []
    try:
        for direction in ("zh-en", "en-zh"):
            expected_id, subset = _direction_settings(config, direction)
            if expected_id != direction_row(("zh", "en"), direction)["direction_id"]:
                raise DatasetError("configured direction id does not match %s" % direction)
            direction_shards = [shard for shard in ordered_shards if shard["subset"] == subset]
            if not direction_shards:
                raise DatasetError("no source shards configured for %s subset %s" % (direction, subset))
            counts = {split: 0 for split in SPLITS}
            counters = {
                "rows_seen": 0,
                "empty_or_token_length": 0,
                "duplicate": 0,
                "split_full": 0,
                "accepted": 0,
            }
            seen = set()
            files = {}
            partials = {}
            for split in SPLITS:
                name = "%s.%s.jsonl" % (direction, split)
                partial = _safe_child(output_root, name + ".partial", "staged JSONL")
                final = _safe_child(output_root, name, "staged JSONL")
                paths_to_clean.extend((partial, final))
                partials[split] = partial
                files[split] = partial.open("wb")
            try:
                complete = False
                for shard in direction_shards:
                    consumed[shard["path"]] = {
                        "subset": shard["subset"],
                        "path": shard["path"],
                        "sha256": shard["sha256"].lower(),
                        "size": shard["size"],
                    }
                    for batch in provider.iter_batches(shard):
                        for source_row in batch:
                            counters["rows_seen"] += 1
                            pair = normalize_pair(source_row, processor, min_tokens, max_tokens)
                            if pair is None:
                                counters["empty_or_token_length"] += 1
                                continue
                            if pair in seen:
                                counters["duplicate"] += 1
                                continue
                            seen.add(pair)
                            row = direction_row(pair, direction)
                            split = _split_name(split_bucket(row["source"], row["target"]))
                            if counts[split] >= quotas[split]:
                                counters["split_full"] += 1
                                continue
                            files[split].write(serialize_row(row))
                            counts[split] += 1
                            counters["accepted"] += 1
                            if all(counts[name] == quotas[name] for name in SPLITS):
                                complete = True
                                break
                        if complete:
                            break
                    if complete:
                        break
                if not complete:
                    raise DatasetError("source exhausted before exact quotas for %s: %s" % (direction, counts))
            finally:
                for stream in files.values():
                    stream.close()
            for split in SPLITS:
                name = "%s.%s.jsonl" % (direction, split)
                final_path = _safe_child(output_root, name, "staged JSONL")
                os.replace(str(partials[split]), str(final_path))
                outputs[name] = _artifact(final_path, counts[split], name)
            filtering[direction] = counters
        schema_metadata = getattr(provider, "schema_metadata", {})
        for path, metadata in schema_metadata.items():
            if path in consumed:
                consumed[path]["parquet_schema"] = metadata
        return {
            "outputs": outputs,
            "filtering": filtering,
            "consumed_shards": [consumed[path] for path in sorted(consumed)],
        }
    except Exception:
        for path in paths_to_clean:
            try:
                _safe_child(output_root, path.name, "staged cleanup").unlink()
            except FileNotFoundError:
                pass
        raise


def publish_transaction(staging_root, publications, replace_func=os.replace):
    """Publish staged files with backups and rollback for flat-file consumers."""
    staging_root = _safe_exact_path(staging_root, "publication staging")
    backup_root = _safe_child(staging_root, ".publication-backup", "publication backup")
    backup_root.mkdir()
    states = []
    try:
        for index, (source, target) in enumerate(publications):
            try:
                relative_source = Path(source).resolve(strict=False).relative_to(staging_root)
            except ValueError as error:
                raise DatasetError("publication source is outside staging") from error
            source = _safe_child(staging_root, relative_source, "publication source")
            target = _safe_exact_path(target, "publication target")
            target.parent.mkdir(parents=True, exist_ok=True)
            target = _safe_exact_path(target, "publication target")
            backup = _safe_child(backup_root, "%06d.bak" % index, "publication backup")
            state = {"source": source, "target": target, "backup": backup, "backed": False, "published": False}
            states.append(state)
            if target.exists():
                replace_func(str(target), str(backup))
                state["backed"] = True
        for state in states:
            replace_func(str(state["source"]), str(state["target"]))
            state["published"] = True
    except Exception:
        rollback_errors = []
        for state in reversed(states):
            try:
                target = _safe_exact_path(state["target"], "publication rollback target")
                backup = _safe_child(backup_root, state["backup"].name, "publication rollback backup")
                if state["published"] and target.exists():
                    target.unlink()
                if state["backed"]:
                    os.replace(str(backup), str(target))
            except Exception as error:
                rollback_errors.append(error)
        if rollback_errors:
            raise DatasetError("publication failed and rollback was incomplete") from rollback_errors[0]
        shutil.rmtree(str(_safe_child(staging_root, backup_root.name, "publication backup cleanup")))
        raise
    shutil.rmtree(str(_safe_child(staging_root, backup_root.name, "publication backup cleanup")))


def _create_staging(output_root):
    output_root = _require_outside_repository(output_root, "dataset output")
    output_root.parent.mkdir(parents=True, exist_ok=True)
    output_root = _require_outside_repository(output_root, "dataset output")
    staging = Path(
        tempfile.mkdtemp(prefix=".%s.staging-" % output_root.name, dir=str(output_root.parent))
    )
    return output_root, _safe_exact_path(staging, "dataset staging")


def _cleanup_staging(staging):
    safe_staging = _safe_exact_path(staging, "dataset staging cleanup")
    shutil.rmtree(str(safe_staging), ignore_errors=True)


def prepare_from_provider(provider, processor, shards, output_root, config):
    """Prepare and atomically publish six files while preserving existing outputs on failure."""
    output_root, staging = _create_staging(output_root)
    try:
        preparation = _prepare_into(provider, processor, shards, staging, config)
        publications = [
            (staging / name, output_root / artifact["path"])
            for name, artifact in preparation["outputs"].items()
        ]
        publish_transaction(staging, publications)
        return preparation
    finally:
        _cleanup_staging(staging)


def publish_prepared_result(
    staging,
    output_root,
    result_manifest,
    preparation,
    result,
    replace_func=os.replace,
):
    staging = _safe_exact_path(staging, "dataset staging")
    output_root = _require_outside_repository(output_root, "dataset output")
    result_manifest = _safe_exact_path(result_manifest, "result manifest")
    staged_manifest = _safe_child(staging, ".bist-v1.json.staged", "staged result manifest")
    _write_json(staged_manifest, result)
    publications = [
        (
            _safe_child(staging, name, "staged JSONL"),
            _safe_child(output_root, artifact["path"], "published JSONL"),
        )
        for name, artifact in preparation["outputs"].items()
    ]
    publications.append((staged_manifest, result_manifest))
    publish_transaction(staging, publications, replace_func=replace_func)


def _load_source_manifest(path, config):
    try:
        manifest = json.loads(Path(path).read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise DatasetError("cannot read source manifest: %s" % error) from error
    validate_source_manifest(manifest, config)
    return manifest


def _require_outside_repository(path, label):
    repository = Path(__file__).resolve().parents[2]
    resolved = _safe_exact_path(path, label)
    if resolved == repository or repository in resolved.parents:
        raise DatasetError("%s must be outside the repository" % label)
    return resolved


def _write_json(path, value):
    path = _safe_exact_path(path, "JSON output")
    path.parent.mkdir(parents=True, exist_ok=True)
    path = _safe_exact_path(path, "JSON output")
    with path.open("w", encoding="utf-8", newline="\n") as stream:
        json.dump(value, stream, ensure_ascii=False, indent=2)
        stream.write("\n")


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", required=True, type=Path)
    parser.add_argument("--source-manifest", required=True, type=Path)
    parser.add_argument("--cache-dir", required=True, type=Path)
    parser.add_argument("--output-dir", required=True, type=Path)
    parser.add_argument("--tokenizer-cache-dir", required=True, type=Path)
    parser.add_argument("--result-manifest", required=True, type=Path)
    parser.add_argument("--offline", action="store_true")
    args = parser.parse_args(argv)
    args.cache_dir = _require_outside_repository(args.cache_dir, "dataset cache")
    args.tokenizer_cache_dir = _require_outside_repository(args.tokenizer_cache_dir, "tokenizer cache")
    args.output_dir = _require_outside_repository(args.output_dir, "dataset output")
    config = load_config(args.config)
    source_manifest = _load_source_manifest(args.source_manifest, config)
    if not args.offline:
        try:
            from huggingface_hub import HfApi
        except ImportError as error:
            raise DatasetError("real mode requires the pinned huggingface-hub dependency") from error
        verify_remote_revision(
            HfApi(),
            config["dataset"]["repo"],
            config["dataset"]["revision"],
            source_manifest["shards"],
            {settings["subset"] for settings in config["directions"].values()},
        )
        print("verified remote revision %s" % config["dataset"]["revision"], flush=True)
    started = time.monotonic()
    tokenizer_path = ensure_tokenizer(
        config["tokenizer"], args.tokenizer_cache_dir, offline=args.offline
    )
    processor = SentencePieceTextProcessor.from_model(tokenizer_path)
    provider = HuggingFaceParquetProvider(
        args.cache_dir, offline=args.offline, verbose=True
    )
    output_root, staging = _create_staging(args.output_dir)
    try:
        preparation = _prepare_into(
            provider, processor, source_manifest["shards"], staging, config
        )
        result = build_result_manifest(
            config,
            source_manifest,
            preparation,
            args.config,
            Path(__file__),
            args.source_manifest,
            Path(__file__).resolve().parents[2],
        )
        publish_prepared_result(
            staging, output_root, args.result_manifest, preparation, result
        )
    finally:
        _cleanup_staging(staging)
    downloaded_bytes = sum(
        shard["size"] for shard in source_manifest["shards"] if shard["path"] in provider.downloaded
    )
    print(
        json.dumps(
            {
                "result_manifest": str(args.result_manifest.resolve()),
                "downloaded_shards": len(provider.downloaded),
                "downloaded_bytes": downloaded_bytes,
                "consumed_shards": len(preparation["consumed_shards"]),
                "elapsed_seconds": round(time.monotonic() - started, 3),
            },
            sort_keys=True,
        ),
        flush=True,
    )


if __name__ == "__main__":
    try:
        main()
    except DatasetError as error:
        raise SystemExit("error: %s" % error)
