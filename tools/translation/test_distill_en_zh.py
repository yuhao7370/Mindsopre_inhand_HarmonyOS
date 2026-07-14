import hashlib
import json
import tempfile
import unittest
from pathlib import Path

from tools.translation.distill_en_zh import (
    DistillationError,
    augment_distillation_manifest,
    build_fallback_preservation_sidecar,
    build_output_row,
    build_training_view_manifest,
    canonical_json_bytes,
    checked_generation_budget_snapshot,
    generation_budget_snapshot,
    load_distillation_config,
    materialize_training_view,
    reconcile_generation_progress,
    require_no_terminal_budget_journal,
    rescue_accumulation_groups,
    select_strict_rescue_best,
    select_probe_batch,
    source_target_corruption_reasons,
    validate_teacher_target,
    verify_completed_chunks,
    verify_final_audit_matches_chunks,
    verify_student_tokenizer_file,
    verify_teacher_files,
    validate_epoch2_gate,
    validate_generation_batch,
    write_chunk_atomic,
)
from tools.translation.train_rescue import _verify_rescue_view


ROOT = Path(__file__).parent
CONFIG = ROOT / "config" / "distillation-run-v4.json"
TEACHER_MANIFEST = ROOT / "manifests" / "opus-mt-en-zh-teacher-v1.json"


class FakeStudentProcessor:
    def encode(self, text, out_type=int):
        del out_type
        return list(range(len(text)))


class DistillationContractTest(unittest.TestCase):
    def test_v4_config_pins_teacher_generation_rescue_and_cumulative_gate(self):
        config = load_distillation_config(CONFIG)
        self.assertEqual(config["schema_version"], 4)
        self.assertEqual(
            config["teacher"],
            {
                "repo": "Helsinki-NLP/opus-mt-en-zh",
                "revision": "408d9bc410a388e1d9aef112a2daba955b945255",
                "license": "apache-2.0",
                "prefix": ">>cmn_Hans<<",
            },
        )
        self.assertEqual(
            config["generation"],
            {
                "precision": "fp16",
                "num_beams": 4,
                "do_sample": False,
                "renormalize_logits": True,
                "max_tokens": 128,
                "probe_rows": 128,
                "selected_batch": 64,
                "batch_candidates": [256, 128, 64, 32, 16, 8, 4, 2, 1],
            },
        )
        self.assertEqual(config["rescue_training"]["learning_rate"], 0.00001)
        self.assertEqual(config["rescue_training"]["warmup_optimizer_steps"], 100)
        self.assertEqual(config["rescue_training"]["max_epochs"], 2)
        self.assertEqual(
            config["validationPolicy"],
            {
                "teacherTargetValidation": "sourceTargetConservative",
                "originalFallbackValidation": "targetContractOnly",
                "originalPreservationWarnings": "sourceTargetConservativeAuditOnly",
                "hardFailDefinition": "teacherFailedAndOriginalTargetContractFailed",
                "rationale": "strict source-target regex can falsely reject valid dates and Chinese-number translations; original targets preserve the approved T2 corpus and warnings remain audit-only",
            },
        )
        self.assertEqual(config["budget"]["previous_gpu_seconds"], 13924.157)
        self.assertEqual(config["budget"]["total_gpu_seconds"], 43200)
        self.assertEqual(config["budget"]["rescue_reserve_seconds"], 2400)
        self.assertEqual(config["gpuLedger"]["probeActualSeconds"], 677.9)
        self.assertEqual(config["gpuLedger"]["measuredProbeEntriesSeconds"], 390.515)
        self.assertEqual(len(config["gpuLedger"]["probeEntries"]), 9)
        self.assertEqual(
            config["epoch2_gate"],
            {
                "en-zh_min_passed": 33,
                "en-zh_max_fatal": 2,
                "zh-en_min_passed": 32,
            },
        )
        for mutation in (
            {**config, "unknown": 1},
            {**config, "schema_version": True},
            {**config, "generation": {**config["generation"], "num_beams": 1}},
            {**config, "budget": {**config["budget"], "previous_gpu_seconds": 0}},
            {**config, "gpuLedger": {**config["gpuLedger"], "probeActualSeconds": 1}},
        ):
            with tempfile.TemporaryDirectory() as temporary:
                path = Path(temporary) / "config.json"
                path.write_text(json.dumps(mutation), encoding="utf-8")
                with self.assertRaises(DistillationError):
                    load_distillation_config(path)

    def test_teacher_inventory_requires_exact_pinned_files_sizes_and_hashes(self):
        manifest = json.loads(TEACHER_MANIFEST.read_text(encoding="utf-8"))
        self.assertEqual(manifest["revision"], "408d9bc410a388e1d9aef112a2daba955b945255")
        self.assertEqual(manifest["license"], "apache-2.0")
        weights = next(item for item in manifest["files"] if item["path"] == "pytorch_model.bin")
        self.assertEqual(weights["bytes"], 312087009)
        self.assertEqual(
            weights["sha256"],
            "69a1d6ec829cee349360b3b677ac0aa99a7d88822d1a6578370029efffdca3f5",
        )
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            files = []
            for name, payload in (("a.json", b"{}\n"), ("source.spm", b"spm")):
                (root / name).write_bytes(payload)
                files.append(
                    {
                        "path": name,
                        "bytes": len(payload),
                        "sha256": hashlib.sha256(payload).hexdigest(),
                    }
                )
            local = {"schema_version": 1, "repo": "x/y", "revision": "a" * 40, "license": "apache-2.0", "files": files}
            self.assertEqual(len(verify_teacher_files(root, local)), 2)
            (root / "source.spm").write_bytes(b"changed")
            with self.assertRaises(DistillationError):
                verify_teacher_files(root, local)

    def test_teacher_targets_fail_closed_for_empty_controls_length_and_repetition(self):
        processor = FakeStudentProcessor()
        self.assertEqual(validate_teacher_target("这是可用译文。", processor), [0, 1, 2, 3, 4, 5, 6])
        for value in ("", "   ", "坏\u0007文本", "测" * 127, "重复" * 20):
            with self.assertRaises(DistillationError):
                validate_teacher_target(value, processor)

    def test_numeric_and_url_corruption_is_fatal_but_latin_residue_is_not(self):
        self.assertEqual(source_target_corruption_reasons("OpenAI has 3 files.", "OpenAI 有 3 个文件。"), [])
        self.assertEqual(source_target_corruption_reasons("Meet at 7:50.", "请在 7: 50 见面。"), [])
        self.assertEqual(source_target_corruption_reasons("After 3:00.", "在 3: 之后。"), ["number"])
        self.assertEqual(
            source_target_corruption_reasons("Open https://example.com/a.", "打开https://example.com/b。"),
            ["url"],
        )
        fallback = build_output_row(
            0,
            "Open https://example.com/a.",
            "打开https://example.com/b。",
            FakeStudentProcessor(),
            original_target="打开 https://example.com/a。",
        )
        self.assertEqual(fallback["target_origin"], "original_fallback")
        self.assertEqual(fallback["target"], "打开 https://example.com/a。")
        self.assertIn("url", fallback["target_reason"])

    def test_chunk_rows_preserve_source_index_hash_order_and_resume_exactly(self):
        processor = FakeStudentProcessor()
        sources = [
            {"source": "one", "target": "一", "direction_id": 32002},
            {"source": "two", "target": "二", "direction_id": 32002},
            {"source": "three", "target": "三", "direction_id": 32002},
        ]
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source_path = root / "en-zh.train.jsonl"
            with source_path.open("w", encoding="utf-8", newline="\n") as stream:
                stream.write(
                    "".join(json.dumps(row, separators=(",", ":")) + "\n" for row in sources)
                )
            chunks = root / "chunks"
            first = [build_output_row(index, sources[index]["source"], target, processor) for index, target in ((0, "甲"), (1, "乙"))]
            second = [build_output_row(2, "three", "丙", processor)]
            write_chunk_atomic(chunks / "00000000.jsonl", first)
            write_chunk_atomic(chunks / "00000002.jsonl", second)
            verified = verify_completed_chunks(source_path, chunks, processor, expected_source_rows=3)
            self.assertEqual(verified["completed_rows"], 3)
            self.assertEqual(verified["next_index"], 3)
            self.assertEqual(verified["source_sha256"], hashlib.sha256(source_path.read_bytes()).hexdigest())
            changed = json.loads((chunks / "00000002.jsonl").read_text(encoding="utf-8"))
            changed["source_sha256"] = "0" * 64
            (chunks / "00000002.jsonl").write_text(json.dumps(changed) + "\n", encoding="utf-8")
            with self.assertRaises(DistillationError):
                verify_completed_chunks(source_path, chunks, processor, expected_source_rows=3)

    def test_resume_rebuilds_stale_ahead_or_missing_progress_from_verified_chunks(self):
        processor = FakeStudentProcessor()
        config = load_distillation_config(CONFIG)
        sources = [
            {"source": "one", "target": "一", "direction_id": 32002},
            {"source": "two", "target": "二", "direction_id": 32002},
            {"source": "three", "target": "三", "direction_id": 32002},
        ]
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source_path = root / "source.jsonl"
            source_path.write_bytes(b"".join(canonical_json_bytes(row) for row in sources))
            chunks = root / "chunks"
            write_chunk_atomic(chunks / "00000000.jsonl", [
                build_output_row(index, row["source"], row["target"], processor)
                for index, row in enumerate(sources[:2])
            ])
            progress_path = root / "progress-v1.json"
            for saved_rows in (0, 3):
                progress_path.write_bytes(canonical_json_bytes({
                    "completed_rows": saved_rows,
                    "generation_gpu_seconds": 12.5,
                    "selected_batch": 64,
                    "wall_seconds": 13.0,
                    "source_sha256": hashlib.sha256(source_path.read_bytes()).hexdigest(),
                    "teacher_prefix_ids": [5],
                }))
                rebuilt = reconcile_generation_progress(
                    config, source_path, chunks, processor, progress_path, 64, expected_rows=3
                )
                self.assertEqual(rebuilt["completed_rows"], 2)
                self.assertEqual(rebuilt["generation_gpu_seconds"], 12.5)
                self.assertEqual(json.loads(progress_path.read_text(encoding="utf-8")), rebuilt)
            progress_path.unlink()
            with self.assertRaises(DistillationError):
                reconcile_generation_progress(
                    config, source_path, chunks, processor, progress_path, 64, expected_rows=3
                )
            progress_path.write_bytes(b"{")
            with self.assertRaises(DistillationError):
                reconcile_generation_progress(
                    config, source_path, chunks, processor, progress_path, 64, expected_rows=3
                )
            progress_path.unlink()
            empty_chunks = root / "empty-chunks"
            rebuilt = reconcile_generation_progress(
                config, source_path, empty_chunks, processor, progress_path, 64, expected_rows=3
            )
            self.assertEqual(rebuilt["completed_rows"], 0)

            write_chunk_atomic(chunks / "00000002.jsonl", [
                build_output_row(2, sources[2]["source"], sources[2]["target"], processor)
            ])
            final_path = root / "final.jsonl"
            final_bytes = b"".join(path.read_bytes() for path in sorted(chunks.glob("*.jsonl")))
            final_path.write_bytes(final_bytes)
            full = verify_final_audit_matches_chunks(
                source_path, chunks, final_path, processor, expected_rows=3
            )
            self.assertEqual(full["rows"], 3)
            for broken in (final_bytes[:-1], final_bytes + final_bytes.splitlines(keepends=True)[0], final_bytes + b"{}\n"):
                final_path.write_bytes(broken)
                with self.assertRaises(DistillationError):
                    verify_final_audit_matches_chunks(
                        source_path, chunks, final_path, processor, expected_rows=3
                    )

    def test_chunk_verification_rejects_gap_extra_and_corruption(self):
        processor = FakeStudentProcessor()
        sources = [
            {"source": "one", "target": "一", "direction_id": 32002},
            {"source": "two", "target": "二", "direction_id": 32002},
        ]
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source_path = root / "source.jsonl"
            source_path.write_bytes(b"".join(canonical_json_bytes(row) for row in sources))
            for label, name, row in (
                ("gap", "00000001.jsonl", build_output_row(1, "two", "二", processor)),
                ("extra", "00000000.jsonl", build_output_row(2, "extra", "额外", processor)),
                ("corrupt", "00000000.jsonl", {**build_output_row(0, "one", "一", processor), "source_sha256": "0" * 64}),
            ):
                chunks = root / label
                write_chunk_atomic(chunks / name, [row])
                with self.assertRaises(DistillationError):
                    verify_completed_chunks(source_path, chunks, processor, expected_source_rows=2)

    def test_gpu_ledger_gate_uses_actual_probes_generation_and_reserve(self):
        config = load_distillation_config(CONFIG)
        snapshot = generation_budget_snapshot(config, 1000.0)
        self.assertEqual(snapshot["baselineGpuSeconds"], 13924.157)
        self.assertEqual(snapshot["probeAndLoadActualSeconds"], 677.9)
        self.assertEqual(snapshot["generationActualSeconds"], 1000.0)
        self.assertEqual(snapshot["rescueReserveSeconds"], 2400.0)
        self.assertAlmostEqual(snapshot["cumulativeWithReserveSeconds"], 18002.057)
        with self.assertRaises(DistillationError):
            generation_budget_snapshot(config, 27000.0)

    def test_generation_budget_overrun_is_journaled_and_blocks_resume(self):
        config = load_distillation_config(CONFIG)
        objective_hashes = {"config": "a" * 64, "source": "b" * 64}
        cursor = {"completed_rows": 512, "attempted_end": 1024}
        with tempfile.TemporaryDirectory() as temporary:
            terminal = Path(temporary) / "budget-terminal-v1.json"
            with self.assertRaises(DistillationError):
                checked_generation_budget_snapshot(
                    config, 27000.0, terminal, objective_hashes, cursor
                )
            payload = json.loads(terminal.read_text(encoding="utf-8"))
            self.assertEqual(payload["measured_gpu_seconds"], 27000.0)
            self.assertEqual(payload["cursor"], cursor)
            self.assertEqual(terminal.read_bytes(), canonical_json_bytes(payload))
            with self.assertRaises(DistillationError):
                require_no_terminal_budget_journal(
                    terminal,
                    "teacher_generation",
                    objective_hashes,
                    {"completed_rows", "attempted_end"},
                )

    def test_student_tokenizer_file_requires_pinned_sha_before_runtime_load(self):
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "tokenizer.model"
            path.write_bytes(b"pinned-tokenizer")
            digest = hashlib.sha256(path.read_bytes()).hexdigest()
            self.assertEqual(verify_student_tokenizer_file(path, digest)[1], digest)
            with self.assertRaises(DistillationError):
                verify_student_tokenizer_file(path, "0" * 64)

    def test_probe_selects_largest_successful_batch_and_only_catches_oom(self):
        calls = []

        def attempt(batch):
            calls.append(batch)
            if batch > 16:
                raise RuntimeError("CUDA out of memory")
            return {"elapsed_seconds": 8.0, "peak_cuda_bytes": 123}

        result = select_probe_batch([64, 32, 16, 8], attempt)
        self.assertEqual(result["selected_batch"], 16)
        self.assertEqual(calls, [64, 32, 16])
        self.assertEqual(result["attempts"][0]["status"], "oom")
        with self.assertRaises(RuntimeError):
            select_probe_batch([1], lambda unused: (_ for _ in ()).throw(RuntimeError("bad model")))
        config = load_distillation_config(CONFIG)
        self.assertEqual(validate_generation_batch(config, 64), 64)
        with self.assertRaises(DistillationError):
            validate_generation_batch(config, 128)

    def test_training_view_is_exact_ordered_and_epoch2_gate_is_immutable(self):
        processor = FakeStudentProcessor()
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            audit = root / "audit.jsonl"
            rows = [
                build_output_row(0, "one", "甲", processor),
                build_output_row(1, "two 2", "错误 3", processor, original_target="正确 2"),
            ]
            with audit.open("wb") as stream:
                for row in rows:
                    stream.write((json.dumps(row, ensure_ascii=False, sort_keys=True, separators=(",", ":")) + "\n").encode("utf-8"))
            result = materialize_training_view(audit, root / "train.jsonl", expected_rows=2)
            self.assertEqual(result["teacher"], 1)
            self.assertEqual(result["original_fallback"], 1)
            training = [json.loads(line) for line in (root / "train.jsonl").read_text(encoding="utf-8").splitlines()]
            self.assertEqual(training, [
                {"direction_id": 32002, "source": "one", "target": "甲"},
                {"direction_id": 32002, "source": "two 2", "target": "正确 2"},
            ])
            manifest = build_training_view_manifest(audit, root / "train.jsonl", result)
            self.assertEqual(manifest["audit"]["path"], "audit.jsonl")
            self.assertEqual(manifest["output"]["path"], "train.jsonl")
            self.assertEqual(manifest["output"]["sha256"], result["sha256"])
            self.assertEqual(manifest["target_origins"], {"teacher": 1, "original_fallback": 1})
        self.assertTrue(validate_epoch2_gate({
            "zh-en": {"passed": 32, "fatal_corruptions": 9},
            "en-zh": {"passed": 33, "fatal_corruptions": 2},
        }))
        self.assertFalse(validate_epoch2_gate({
            "zh-en": {"passed": 31, "fatal_corruptions": 0},
            "en-zh": {"passed": 50, "fatal_corruptions": 0},
        }))

    def test_fallback_preservation_warnings_are_audit_only_and_manifested(self):
        processor = FakeStudentProcessor()
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            audit = root / "audit.jsonl"
            rows = [
                build_output_row(0, "plain", "正常", processor),
                build_output_row(1, "Keep 2", "错误 3", processor, original_target="保留"),
                build_output_row(
                    2,
                    "Open https://a.example/x",
                    "打开 https://b.example/x",
                    processor,
                    original_target="打开",
                ),
            ]
            audit.write_bytes(b"".join(canonical_json_bytes(row) for row in rows))
            sidecar = root / "fallback-preservation-warnings-v1.jsonl"
            result = build_fallback_preservation_sidecar(audit, sidecar)
            self.assertEqual(result["rows"], 2)
            self.assertEqual(result["fallbackWithPreservationWarnings"], 2)
            self.assertEqual(result["number"], 1)
            self.assertEqual(result["url"], 1)
            warning_rows = [json.loads(line) for line in sidecar.read_text(encoding="utf-8").splitlines()]
            self.assertEqual(warning_rows[0]["originalPreservationWarnings"], ["number"])
            self.assertEqual(warning_rows[1]["originalPreservationWarnings"], ["url"])

            output_bytes = audit.stat().st_size
            output_sha256 = hashlib.sha256(audit.read_bytes()).hexdigest()
            manifest_path = root / "distillation-manifest-v1.json"
            manifest_path.write_bytes(canonical_json_bytes({
                "output": {"path": audit.name, "rows": 3, "bytes": output_bytes, "sha256": output_sha256},
                "target_origins": {"teacher": 1, "original_fallback": 2, "hard_fail": 0},
            }))
            finalized = augment_distillation_manifest(
                load_distillation_config(CONFIG), audit, manifest_path, sidecar
            )
            self.assertEqual(finalized["validationPolicy"]["originalFallbackValidation"], "targetContractOnly")
            self.assertEqual(finalized["fallbackPreservationWarnings"]["number"], 1)
            self.assertEqual(finalized["fallbackPreservationWarnings"]["url"], 1)

    def test_rescue_accumulation_keeps_effective_128_and_best_is_strict(self):
        groups, dropped = rescue_accumulation_groups(list(range(5626)), 4)
        self.assertEqual(len(groups), 1406)
        self.assertTrue(all(len(group) == 4 for group in groups))
        self.assertEqual(dropped, [5624, 5625])
        self.assertEqual(
            select_strict_rescue_best(3.7039, [(500, 3.8), (1000, 3.7039), (1406, 3.69)]),
            (1406, 3.69),
        )
        self.assertIsNone(select_strict_rescue_best(3.7039, [(500, 3.8), (1000, 3.7039)]))

    def test_rescue_view_verification_returns_complete_cache_artifact(self):
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "en-zh.rescue.train.jsonl"
            rows = [
                {"direction_id": 32002, "source": "one", "target": "一"},
                {"direction_id": 32002, "source": "two", "target": "二"},
            ]
            path.write_bytes(b"".join(
                (json.dumps(row, ensure_ascii=False, sort_keys=True, separators=(",", ":")) + "\n").encode("utf-8")
                for row in rows
            ))
            artifact = _verify_rescue_view(path, expected_rows=2)
            self.assertEqual(artifact["path"], path.name)
            self.assertEqual(artifact["count"], 2)
            self.assertEqual(artifact["bytes"], path.stat().st_size)
            self.assertEqual(artifact["sha256"], hashlib.sha256(path.read_bytes()).hexdigest())


if __name__ == "__main__":
    unittest.main()
