import hashlib
import inspect
import json
import lzma
import os
import shutil
import struct
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

import sentencepiece

from tools.translation.build_translation_archive import build_tar
from tools.translation.export_marian_smoke import (
    LOCAL_LEARNING_LIMITATIONS,
    LOCAL_LEARNING_USER_AUTHORIZATION,
)
from tools.translation.tokenizer_generate_fixture import _normalize_with_map
from tools.translation.verify_translation_package import PackageError, verify_package
import tools.translation.generate_final_translation_package as package_generator

try:
    from tools.translation.generate_final_translation_package import (
        PackageGenerationError,
        generate_final_package,
    )
except ModuleNotFoundError as error:
    if error.name != "tools.translation.generate_final_translation_package":
        raise
    PackageGenerationError = RuntimeError
    generate_final_package = None


TOKENIZER = Path(os.environ["LOCALAPPDATA"]) / "MindsporeInhand/tokenizer-task5/source.spm"
REPOSITORY_ROOT = Path(__file__).resolve().parents[2]
TRUSTED_LICENSES = REPOSITORY_ROOT / "tools/translation/licenses/translation-runtime-LICENSES.md"
REAL_DECOMPRESSOR = (
    REPOSITORY_ROOT / "Mindspore_inhand_HarmonyOS/entry/libs/arm64-v8a/libtranslation_archive.so"
)
RAW_ASSETS = {
    "LICENSES.md",
    "SHA256SUMS",
    "manifest.json",
    "tokenizer.model",
    "tokenizer_runtime.json",
    "translation-models.tar.xz",
    "vocab.json",
}


def _sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _artifact(path):
    return {"path": path.name, "bytes": path.stat().st_size, "sha256": _sha256(path)}


def _canonical_json_bytes(value):
    return (json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":")) + "\n").encode("utf-8")


def _decode_codepoints(value):
    return "" if value == "-" else "".join(chr(int(item, 16)) for item in value.split(","))


class FinalTranslationPackageGeneratorTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.models = self.root / "models"
        self.models.mkdir()
        for index, name in enumerate(("encoder.ms", "decoder_prefill.ms", "decoder_step.ms"), 1):
            (self.models / name).write_bytes((name.encode("ascii") + b"\0") * index)
        self.tar = self.root / "translation-models.tar"
        member_manifest = build_tar(self.models, self.tar)
        self.archive = self.root / "translation-models.tar.xz"
        self.archive.write_bytes(
            lzma.compress(self.tar.read_bytes(), format=lzma.FORMAT_XZ, check=lzma.CHECK_CRC64, preset=9)
        )
        self.archive_manifest = {
            **member_manifest,
            "tar": {"size": self.tar.stat().st_size, "sha256": _sha256(self.tar)},
            "archive": {"size": self.archive.stat().st_size, "sha256": _sha256(self.archive)},
        }
        self.evidence_a = self.root / "archive-a.json"
        self.evidence_b = self.root / "archive-b.json"
        payload = json.dumps(self.archive_manifest, sort_keys=True)
        self.evidence_a.write_text(payload, encoding="utf-8")
        self.evidence_b.write_text(payload, encoding="utf-8")
        self.decompressor = REAL_DECOMPRESSOR
        self.licenses = TRUSTED_LICENSES
        self._write_provenance_reports(member_manifest)

    def tearDown(self):
        self.temp.cleanup()

    def _write_provenance_reports(self, member_manifest):
        self.training_report = self.root / "training-v1.json"
        self.training_report.write_bytes(b"{}\n")
        candidate = {
            "model_sha256": hashlib.sha256(b"approved student checkpoint").hexdigest(),
            "tokenizer_sha256": _sha256(TOKENIZER),
        }
        objective = {"distillation": "a" * 64, "training": "b" * 64}
        gate = {
            "schema_version": 1,
            "epoch2_allowed": True,
            "epoch2_launch_allowed": True,
            "epoch2_status": "authorized",
            "promotion_allowed": True,
            "candidate": candidate,
            "candidateEpoch": 1,
            "trainingReport": _artifact(self.training_report),
            "objectiveHashes": objective,
            "manualAsset": {"path": "manual-eval-v1.jsonl", "rows": 100, "bytes": 1, "sha256": "c" * 64},
            "manualResults": {"path": "manual-results-v1.json", "rows": 100, "bytes": 1, "sha256": "d" * 64},
            "manual": {},
            "flores": {},
        }
        self.quality_gate_report = self.root / "gate-v1.json"
        self.quality_gate_report.write_bytes(_canonical_json_bytes(gate))
        self.export_report = self.root / "export-report.json"
        self.export_report.write_bytes(b"{}\n")
        onnx_artifacts = {}
        for name in ("encoder.onnx", "decoder_prefill.onnx", "decoder_step.onnx"):
            path = self.root / name
            path.write_bytes(name.encode("ascii"))
            onnx_artifacts[name] = _artifact(path)
        approval = {
            "candidate": candidate,
            "candidateEpoch": 1,
            "objectiveHashes": objective,
            "trainingReport": _artifact(self.training_report),
            "qualityGateReport": _artifact(self.quality_gate_report),
        }
        conversion = {
            "schemaVersion": 1,
            "profile": "final",
            "approval": approval,
            "exportReport": _artifact(self.export_report),
            "onnxArtifacts": onnx_artifacts,
            "quantization": {"type": "WEIGHT_QUANT", "bitNum": 8, "minWeightSize": 0, "minWeightChannel": 0},
            "encoderParity": [
                {"name": "all-valid", "validTokens": 128, "elements": 32768, "maxAbs": 0.01, "meanAbs": 0.001},
                {"name": "half-padding", "validTokens": 64, "elements": 32768, "maxAbs": 0.01, "meanAbs": 0.001},
            ],
            "cacheLoopSteps": 100,
            "cacheLoopTokens": [0] * 101,
            "referenceCacheLoopTokens": [0] * 101,
            "expectedCacheLoopTokens": None,
            "argmaxAgreement": 1.0,
            "matchingTokens": 101,
            "models": member_manifest["members"],
        }
        self.conversion_report = self.root / "conversion-report.json"
        self.conversion_report.write_text(json.dumps(conversion), encoding="utf-8")

    def _generate(self, suffix):
        self.assertIsNotNone(generate_final_package)
        stage = self.root / f"stage-{suffix}"
        package_manifest = self.root / f"final-package-{suffix}.json"
        generate_final_package(
            tokenizer_model=TOKENIZER,
            archive=self.archive,
            archive_manifest_a=self.evidence_a,
            archive_manifest_b=self.evidence_b,
            decompressor=self.decompressor,
            licenses_source=self.licenses,
            quality_gate_report=self.quality_gate_report,
            conversion_report=self.conversion_report,
            stage_root=stage,
            package_manifest_path=package_manifest,
        )
        return stage, package_manifest

    def _refresh_checksums(self, stage):
        names = sorted(RAW_ASSETS - {"SHA256SUMS"})
        (stage / "SHA256SUMS").write_bytes(
            "".join("%s  %s\n" % (_sha256(stage / name).upper(), name) for name in names).encode("ascii")
        )

    def _refresh_package_assets(self, package_path, stage, decompressor=None):
        package = json.loads(package_path.read_text(encoding="utf-8"))
        decompressor = self.decompressor if decompressor is None else decompressor
        for asset in package["assets"]:
            path = decompressor if asset["role"] == "decompressor" else stage / asset["path"]
            asset["size"] = path.stat().st_size
            asset["sha256"] = _sha256(path)
        package_path.write_text(json.dumps(package), encoding="utf-8")
        return package

    def _copied_fixture(self, base_stage, base_package, suffix):
        stage = self.root / ("tampered-stage-" + suffix)
        shutil.copytree(base_stage, stage)
        package = self.root / ("tampered-package-" + suffix + ".json")
        shutil.copyfile(base_package, package)
        return stage, package

    def test_requires_fixed_substantive_license_and_provenance_inputs(self):
        parameters = inspect.signature(generate_final_package).parameters
        self.assertIn("quality_gate_report", parameters)
        self.assertIn("conversion_report", parameters)
        self.assertTrue(TRUSTED_LICENSES.is_file())
        canonical_license_bytes = getattr(package_generator, "_canonical_license_bytes", None)
        self.assertIsNotNone(canonical_license_bytes)
        crlf = self.root / "license-crlf.md"
        crlf.write_bytes(b"first\r\nsecond\r\n")
        self.assertEqual(canonical_license_bytes(crlf), b"first\nsecond\n")
        self.assertEqual(
            hashlib.sha256(canonical_license_bytes(TRUSTED_LICENSES)).hexdigest(),
            getattr(package_generator, "TRUSTED_LICENSES_SHA256", None),
        )
        notices = TRUSTED_LICENSES.read_text(encoding="utf-8")
        for required in (
            "Apache-2.0",
            "Helsinki-NLP/opus-mt_tiny_zho-eng",
            "SentencePiece",
            "XZ Utils 5.8.3",
        ):
            self.assertIn(required, notices)

    def test_rejects_unapproved_or_mismatched_quality_and_conversion_reports(self):
        original_gate = self.quality_gate_report.read_bytes()
        original_conversion = self.conversion_report.read_bytes()

        def gate_mutation(gate):
            gate["promotion_allowed"] = False

        def profile_mutation(conversion):
            conversion["profile"] = "prototype"

        def gate_artifact_mutation(conversion):
            conversion["approval"]["qualityGateReport"]["sha256"] = "0" * 64

        def candidate_mutation(conversion):
            conversion["approval"]["candidate"]["model_sha256"] = "1" * 64

        def model_mutation(conversion):
            conversion["models"][0]["sha256"] = "2" * 64

        cases = (
            ("promotion", "gate", gate_mutation, "promotion|quality"),
            ("profile", "conversion", profile_mutation, "profile|schema"),
            ("gate-artifact", "conversion", gate_artifact_mutation, "quality|artifact"),
            ("candidate", "conversion", candidate_mutation, "candidate"),
            ("model", "conversion", model_mutation, "model|archive"),
        )
        for index, (name, target, mutate, message) in enumerate(cases):
            with self.subTest(name=name):
                self.quality_gate_report.write_bytes(original_gate)
                self.conversion_report.write_bytes(original_conversion)
                path = self.quality_gate_report if target == "gate" else self.conversion_report
                value = json.loads(path.read_text(encoding="utf-8"))
                mutate(value)
                path.write_bytes(_canonical_json_bytes(value) if target == "gate" else json.dumps(value).encode("utf-8"))
                with self.assertRaisesRegex(PackageGenerationError, message):
                    self._generate("bad-report-%d" % index)

    def test_rejects_self_consistent_but_forged_conversion_metrics(self):
        original = self.conversion_report.read_bytes()

        def wrong_steps(value):
            value["cacheLoopSteps"] = 99

        def false_matching_count(value):
            value["referenceCacheLoopTokens"][-1] = 1

        def false_agreement(value):
            value["referenceCacheLoopTokens"][-1] = 1
            value["matchingTokens"] = 100
            value["argmaxAgreement"] = 1.0

        def non_finite_parity(value):
            value["encoderParity"][0]["maxAbs"] = float("nan")

        for name, mutate in (
            ("steps", wrong_steps),
            ("matching", false_matching_count),
            ("agreement", false_agreement),
            ("parity", non_finite_parity),
        ):
            with self.subTest(name=name):
                self.conversion_report.write_bytes(original)
                conversion = json.loads(original)
                mutate(conversion)
                self.conversion_report.write_text(json.dumps(conversion), encoding="utf-8")
                with self.assertRaisesRegex(PackageGenerationError, "metric|parity|cache|agreement"):
                    package_generator._approved_conversion(
                        self.quality_gate_report,
                        self.conversion_report,
                        self.archive_manifest,
                    )

    def test_final_package_retains_and_verifier_requires_approval_provenance(self):
        stage, package_path = self._generate("retained-provenance")
        package = json.loads(package_path.read_text(encoding="utf-8"))
        evidence = package["evidence"]
        self.assertEqual(set(evidence), {
            "sourceEvidence", "canonicalRebuild", "qualityGateReport", "conversionReport", "approval",
        })
        self.assertEqual(evidence["qualityGateReport"], _artifact(self.quality_gate_report))
        self.assertEqual(evidence["conversionReport"], _artifact(self.conversion_report))
        conversion = json.loads(self.conversion_report.read_text(encoding="utf-8"))
        self.assertEqual(evidence["approval"], {
            "candidate": conversion["approval"]["candidate"],
            "candidateEpoch": conversion["approval"]["candidateEpoch"],
            "objectiveHashes": conversion["approval"]["objectiveHashes"],
        })

        for field in ("qualityGateReport", "conversionReport", "approval"):
            with self.subTest(missing=field):
                mutated = json.loads(package_path.read_text(encoding="utf-8"))
                del mutated["evidence"][field]
                bad = self.root / ("missing-" + field + ".json")
                bad.write_text(json.dumps(mutated), encoding="utf-8")
                with self.assertRaisesRegex(PackageError, "evidence|provenance|approval|artifact"):
                    verify_package(bad, stage, self.decompressor)

        mutated = json.loads(package_path.read_text(encoding="utf-8"))
        mutated["evidence"]["approval"]["candidate"]["tokenizer_sha256"] = "0" * 64
        bad = self.root / "forged-approval.json"
        bad.write_text(json.dumps(mutated), encoding="utf-8")
        with self.assertRaisesRegex(PackageError, "approval|tokenizer|provenance"):
            verify_package(bad, stage, self.decompressor)

    def test_local_learning_package_retains_non_production_authorization_and_full_v5_evidence(self):
        conversion = json.loads(self.conversion_report.read_text(encoding="utf-8"))
        candidate = conversion["approval"]["candidate"]
        selection = {"optimizer_step": 18284, "adamw_step": 18279}
        selection_path = self.root / "selection.json"
        selection_path.write_bytes(_canonical_json_bytes(selection))
        candidate_files = {
            "base_revision.txt": {"path": "base_revision.txt", "bytes": 41, "sha256": "1" * 64},
            "config.json": {"path": "config.json", "bytes": 1, "sha256": "2" * 64},
            "generation_config.json": {"path": "generation_config.json", "bytes": 1, "sha256": "3" * 64},
            "model.safetensors": {"path": "model.safetensors", "bytes": 1, "sha256": candidate["model_sha256"]},
            "selection.json": _artifact(selection_path),
            "tokenizer.model": {"path": "tokenizer.model", "bytes": 1, "sha256": candidate["tokenizer_sha256"]},
        }
        root_path = self.root / "budget-root.json"
        root_path.write_bytes(b"{}\n")
        root_artifact = _artifact(root_path)
        training_budget_path = self.root / "v5-training-budget.json"
        training_budget_path.write_bytes(_canonical_json_bytes({"status": "completed"}))
        training_budget = _artifact(training_budget_path)
        terminal_path = self.root / "v5-terminal-v1.json"
        terminal_path.write_bytes(_canonical_json_bytes({
            "schema_version": 1,
            "stage": "translation_v5_original_bist_continuation",
            "status": "completed",
            "rootEvidence": root_artifact,
            "budgetReceipt": training_budget,
            "finalGlobalStep": 18284,
            "adamWStep": 18279,
            "candidate": {
                "globalStep": 18284,
                "adamWStep": 18279,
                "checkpoint": {"path": "checkpoint", "files": candidate_files},
            },
            "error": None,
        }))
        bist_output = self.root / "bist-test-outputs-v1.jsonl"
        bist_output.write_bytes(b"{}\n")
        manual_output = self.root / "manual-raw-results-v1.jsonl"
        manual_output.write_bytes(b"{}\n")
        final_budget_path = self.root / "evaluation-budget-terminal-v1.json"
        ledger = {
            "priorCumulativeSeconds": 28924.0,
            "evaluationActualSeconds": 10.0,
            "cumulativeActualSeconds": 28934.0,
            "totalBudgetSeconds": 43200.0,
            "remainingSeconds": 14266.0,
        }
        final_budget = {
            "schema_version": 1,
            "stage": "translation_v5_candidate_quality_evaluation",
            "status": "completed",
            "priorEvidence": training_budget,
            "rootEvidence": root_artifact,
            **ledger,
            "error": None,
        }
        final_budget_path.write_bytes(_canonical_json_bytes(final_budget))
        evaluation_path = self.root / "v5-candidate-quality-evaluation-v1.json"
        evaluation_path.write_bytes(_canonical_json_bytes({
            "schema_version": 1,
            "identity": "v5-final-candidate",
            "stage": "translation_v5_candidate_quality_evaluation",
            "status": "completed",
            "checkpoint": {
                "globalStep": 18284,
                "adamWStep": 18279,
                "files": candidate_files,
                "selection": selection,
            },
            "dataset": {
                "repo": "Mxode/BiST",
                "revision": "aca6be897afc319f779009379c8b849c1eb8d63e",
                "testRowsPerDirection": 5000,
            },
            "bistTest": {"zh-en": {"bleu": 1.0, "chrf2": 2.0}, "en-zh": {"bleu": 1.0, "chrf2": 2.0}},
            "manual": {"rows": 100, "mode": "raw-model-outputs-with-automatic-corruption-flags-only"},
            "decode": {"strategy": "greedy"},
            "runtime": {"device": "cuda"},
            "execution": {"evaluatorCodeSha256": "a" * 64},
            "priorEvidence": training_budget,
            "rootEvidence": root_artifact,
            "gpuLedger": final_budget,
            "peakCudaBytes": 1,
            "artifacts": {
                "bistTestOutputs": {**_artifact(bist_output), "rows": 10000},
                "manualRawResults": {**_artifact(manual_output), "rows": 100},
                "budgetReceipt": _artifact(final_budget_path),
            },
        }))
        evaluation_manifest_path = self.root / "v5-candidate-quality-manifest-v1.json"
        evaluation_manifest_path.write_bytes(_canonical_json_bytes({
            "schema_version": 1,
            "identity": "v5-final-candidate",
            "stage": "translation_v5_candidate_quality_evaluation",
            "inputs": {
                "evaluator_code": {"path": "evaluate_v5_candidate.py", "bytes": 1, "sha256": "a" * 64},
                "v5_terminal": _artifact(terminal_path),
                "v5_budget_terminal": training_budget,
                **{
                    "checkpoint_" + name.replace(".", "_"): record
                    for name, record in candidate_files.items()
                },
            },
            "outputs": {
                "bist_test_outputs": {**_artifact(bist_output), "rows": 10000},
                "manual_raw_results": {**_artifact(manual_output), "rows": 100},
                "budget_receipt": _artifact(final_budget_path),
                "quality_report": _artifact(evaluation_path),
            },
        }))
        authorization_path = self.root / "local-learning-authorization-v1.json"
        authorization = {
            "schemaVersion": 1,
            "releaseChannel": "local-learning",
            "productionPromotionAllowed": False,
            "userAuthorization": LOCAL_LEARNING_USER_AUTHORIZATION,
            "limitations": list(LOCAL_LEARNING_LIMITATIONS),
            "candidate": candidate,
            "candidateGlobalStep": 18284,
            "candidateAdamWStep": 18279,
            "evaluatorCodeSha256": "a" * 64,
            "v5Terminal": _artifact(terminal_path),
            "evaluationReport": _artifact(evaluation_path),
            "evaluationManifest": _artifact(evaluation_manifest_path),
            "budgetReceipt": _artifact(final_budget_path),
        }
        authorization_path.write_bytes(_canonical_json_bytes(authorization))
        local_approval = {
            **{name: authorization[name] for name in (
                "releaseChannel", "productionPromotionAllowed", "userAuthorization",
                "limitations", "candidate", "candidateGlobalStep", "candidateAdamWStep",
                "evaluatorCodeSha256", "v5Terminal", "evaluationReport", "evaluationManifest",
                "budgetReceipt",
            )},
            "authorizationReport": _artifact(authorization_path),
        }
        conversion["approval"] = local_approval
        self.conversion_report.write_text(json.dumps(conversion), encoding="utf-8")

        stage = self.root / "stage-local-learning"
        package_path = self.root / "local-learning-package.json"
        budget_result = {
            "artifact": _artifact(final_budget_path),
            "rootEvidence": root_artifact,
            "cumulativeActualSeconds": ledger["cumulativeActualSeconds"],
            "totalBudgetSeconds": ledger["totalBudgetSeconds"],
        }
        with mock.patch.multiple(
            "tools.translation.export_marian_smoke",
            V5_EVALUATOR_CODE_SHA256="a" * 64,
            V5_EVALUATION_REPORT_SHA256=_artifact(evaluation_path)["sha256"],
            V5_EVALUATION_MANIFEST_SHA256=_artifact(evaluation_manifest_path)["sha256"],
            V5_EVALUATION_BUDGET_SHA256=_artifact(final_budget_path)["sha256"],
        ), mock.patch(
            "tools.translation.export_marian_smoke.load_budget_evidence",
            return_value=budget_result,
        ):
            package = generate_final_package(
                tokenizer_model=TOKENIZER,
                archive=self.archive,
                archive_manifest_a=self.evidence_a,
                archive_manifest_b=self.evidence_b,
                decompressor=self.decompressor,
                licenses_source=self.licenses,
                quality_gate_report=None,
                local_learning_authorization=authorization_path,
                v5_terminal=terminal_path,
                evaluation_report=evaluation_path,
                evaluation_manifest=evaluation_manifest_path,
                budget_receipt=final_budget_path,
                budget_supporting_evidence=(training_budget_path, root_path),
                conversion_report=self.conversion_report,
                stage_root=stage,
                package_manifest_path=package_path,
            )
        self.assertEqual(package["evidence"]["approval"]["releaseChannel"], "local-learning")
        self.assertIs(package["evidence"]["approval"]["productionPromotionAllowed"], False)
        self.assertEqual(package["evidence"]["v5Terminal"], _artifact(terminal_path))
        self.assertEqual(package["evidence"]["evaluationReport"], _artifact(evaluation_path))
        self.assertEqual(package["evidence"]["evaluationManifest"], _artifact(evaluation_manifest_path))
        self.assertEqual(package["evidence"]["budgetReceipt"], _artifact(final_budget_path))

        package["evidence"]["approval"]["productionPromotionAllowed"] = True
        package_path.write_text(json.dumps(package), encoding="utf-8")
        with self.assertRaisesRegex(PackageError, "production|promotion|local-learning"):
            verify_package(package_path, stage, self.decompressor)

    def test_final_verifier_rebuilds_raw_assets_and_binds_archive_evidence(self):
        base_stage, base_package = self._generate("authentic-base")

        def runtime_mutation(stage, package):
            with (stage / "tokenizer_runtime.json").open("ab") as stream:
                stream.write(b"N\t41\t42\n")

        def vocabulary_mutation(stage, package):
            value = json.loads((stage / "vocab.json").read_text(encoding="utf-8"))
            value["invented"] = 32003
            (stage / "vocab.json").write_text(json.dumps(value), encoding="utf-8")

        def license_mutation(stage, package):
            (stage / "LICENSES.md").write_text("non-empty placeholder\n", encoding="utf-8")

        def checksum_mutation(stage, package):
            (stage / "SHA256SUMS").write_text("self-reported checksum\n", encoding="ascii")

        for name, mutate, message in (
            ("runtime", runtime_mutation, "tokenizer runtime|TTOK"),
            ("vocabulary", vocabulary_mutation, "vocabulary|vocab"),
            ("licenses", license_mutation, "license"),
            ("checksums", checksum_mutation, "checksum"),
        ):
            with self.subTest(name=name):
                stage, package = self._copied_fixture(base_stage, base_package, name)
                mutate(stage, package)
                if name != "checksums":
                    self._refresh_checksums(stage)
                self._refresh_package_assets(package, stage)
                with self.assertRaisesRegex(PackageError, message):
                    verify_package(package, stage, self.decompressor)

        for name, artifact, message in (
            ("different-evidence", "source", "evidence|rebuild"),
            ("archive-record", "archive", "archive|XZ"),
            ("tar-record", "tar", "TAR|tar"),
        ):
            with self.subTest(name=name):
                stage, package_path = self._copied_fixture(base_stage, base_package, name)
                package = json.loads(package_path.read_text(encoding="utf-8"))
                if artifact == "source":
                    package["evidence"]["sourceEvidence"]["archive"]["sha256"] = "0" * 64
                else:
                    record = {"size": 1, "sha256": "0" * 64}
                    package["evidence"]["sourceEvidence"][artifact] = record
                    package["evidence"]["canonicalRebuild"][artifact] = dict(record)
                package_path.write_text(json.dumps(package), encoding="utf-8")
                with self.assertRaisesRegex(PackageError, message):
                    verify_package(package_path, stage, self.decompressor)

        stage, package_path = self._copied_fixture(base_stage, base_package, "trailing-xz")
        archive = stage / "translation-models.tar.xz"
        with archive.open("ab") as stream:
            stream.write(b"trailing")
        runtime_path = stage / "manifest.json"
        runtime = json.loads(runtime_path.read_text(encoding="utf-8"))
        runtime["archive"].update({"size": archive.stat().st_size, "sha256": _sha256(archive)})
        runtime_path.write_text(json.dumps(runtime), encoding="utf-8")
        package = json.loads(package_path.read_text(encoding="utf-8"))
        archive_record = {"size": archive.stat().st_size, "sha256": _sha256(archive)}
        package["evidence"]["sourceEvidence"]["archive"] = archive_record
        package["evidence"]["canonicalRebuild"]["archive"] = dict(archive_record)
        package_path.write_text(json.dumps(package), encoding="utf-8")
        self._refresh_checksums(stage)
        self._refresh_package_assets(package_path, stage)
        with self.assertRaisesRegex(PackageError, "XZ|archive|stream|trailing"):
            verify_package(package_path, stage, self.decompressor)

    def test_final_verifier_requires_trusted_aarch64_elf_shared_object(self):
        base_stage, base_package = self._generate("native-base")

        def elf(machine):
            value = bytearray(64)
            value[:16] = b"\x7fELF\x02\x01\x01" + b"\0" * 9
            struct.pack_into("<HHI", value, 16, 3, machine, 1)
            return bytes(value)

        for name, machine, message in (
            ("x86", 62, "AArch64|ELF"),
            ("untrusted-arm64", 183, "trusted|build|manifest|hash"),
        ):
            with self.subTest(name=name):
                stage, package = self._copied_fixture(base_stage, base_package, name)
                native = self.root / name / "libtranslation_archive.so"
                native.parent.mkdir()
                native.write_bytes(elf(machine))
                self._refresh_package_assets(package, stage, native)
                with self.assertRaisesRegex(PackageError, message):
                    verify_package(package, stage, native)

    def test_generates_complete_deterministic_raw_assets_and_external_native_manifest(self):
        stage_a, package_a = self._generate("a")
        stage_b, package_b = self._generate("b")

        self.assertEqual({path.name for path in stage_a.iterdir()}, RAW_ASSETS)
        self.assertFalse((stage_a / "libtranslation_archive.so").exists())
        for name in RAW_ASSETS:
            self.assertEqual((stage_a / name).read_bytes(), (stage_b / name).read_bytes(), name)
        self.assertEqual(package_a.read_bytes(), package_b.read_bytes())

        runtime_lines = (stage_a / "tokenizer_runtime.json").read_text(encoding="ascii").splitlines()
        self.assertTrue(runtime_lines[0].startswith("TTOK1\t"))
        self.assertGreater(sum(line.startswith("N\t") for line in runtime_lines), 0)
        piece_lines = [line for line in runtime_lines if line.startswith("P\t")]
        self.assertEqual(len(piece_lines), 32000)
        self.assertEqual([int(line.split("\t", 2)[1]) for line in piece_lines], list(range(32000)))
        normalization_rules = {}
        for line in runtime_lines:
            if line.startswith("N\t"):
                _, source, target = line.split("\t")
                normalization_rules[_decode_codepoints(source)] = _decode_codepoints(target)
        processor = sentencepiece.SentencePieceProcessor(model_file=str(TOKENIZER))
        for source in ("ｅ́　ＡＢＣ  １２３", "Hello\t  world", "你好，世界！"):
            self.assertEqual(
                _normalize_with_map(source, normalization_rules, set()),
                processor.normalize(source),
            )

        vocabulary = json.loads((stage_a / "vocab.json").read_text(encoding="utf-8"))
        self.assertEqual(len(vocabulary), 32003)
        self.assertEqual(vocabulary["<pad>"], 32000)
        self.assertEqual(vocabulary["<2en>"], 32001)
        self.assertEqual(vocabulary["<2zh>"], 32002)

        runtime_manifest = json.loads((stage_a / "manifest.json").read_text(encoding="utf-8"))
        self.assertEqual([graph["file"] for graph in runtime_manifest["graphs"]], [
            "encoder.ms", "decoder_prefill.ms", "decoder_step.ms"
        ])
        self.assertEqual(runtime_manifest["archive"]["sha256"], _sha256(self.archive))

        package = json.loads(package_a.read_text(encoding="utf-8"))
        self.assertEqual(package["mode"], "final")
        self.assertEqual(package["allowances"], [])
        self.assertEqual([asset["path"] for asset in package["assets"]], sorted(RAW_ASSETS | {self.decompressor.name}))
        self.assertEqual(package["evidence"]["sourceEvidence"], package["evidence"]["canonicalRebuild"])
        verified = verify_package(package_a, stage_a, self.decompressor)
        self.assertEqual(verified["allowanceBytes"], 0)
        self.assertEqual(verified["totalBytes"], sum(asset["size"] for asset in package["assets"]))

        checksum_names = [line.split("  ", 1)[1] for line in (stage_a / "SHA256SUMS").read_text().splitlines()]
        self.assertEqual(checksum_names, sorted(RAW_ASSETS - {"SHA256SUMS"}))

    def test_direct_cli_help_is_runnable_from_repository_root(self):
        result = subprocess.run(
            [sys.executable, str(REPOSITORY_ROOT / "tools/translation/generate_final_translation_package.py"), "--help"],
            cwd=str(REPOSITORY_ROOT),
            capture_output=True,
            text=True,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("--decompressor", result.stdout)
        self.assertIn("--quality-gate-report", result.stdout)
        self.assertIn("--conversion-report", result.stdout)

    def test_rejects_archive_evidence_drift_before_writing_stage(self):
        self.assertIsNotNone(generate_final_package)
        drifted = json.loads(self.evidence_b.read_text(encoding="utf-8"))
        drifted["archive"]["sha256"] = "0" * 64
        self.evidence_b.write_text(json.dumps(drifted), encoding="utf-8")
        stage = self.root / "stage-drifted"

        with self.assertRaisesRegex(PackageGenerationError, "evidence|rebuild|differ"):
            generate_final_package(
                tokenizer_model=TOKENIZER,
                archive=self.archive,
                archive_manifest_a=self.evidence_a,
                archive_manifest_b=self.evidence_b,
                decompressor=self.decompressor,
                licenses_source=self.licenses,
                quality_gate_report=self.quality_gate_report,
                conversion_report=self.conversion_report,
                stage_root=stage,
                package_manifest_path=self.root / "final-package-drifted.json",
            )
        self.assertFalse(stage.exists())

    def test_rejects_symlink_stage_before_writing_target(self):
        self.assertIsNotNone(generate_final_package)
        stage = self.root / "stage-link"
        stage.mkdir()
        path_type = type(stage)
        original_is_symlink = path_type.is_symlink

        with mock.patch.object(
            path_type,
            "is_symlink",
            autospec=True,
            side_effect=lambda path: path == stage or original_is_symlink(path),
        ):
            with self.assertRaisesRegex(PackageGenerationError, "stage|symlink"):
                generate_final_package(
                    tokenizer_model=TOKENIZER,
                    archive=self.archive,
                    archive_manifest_a=self.evidence_a,
                    archive_manifest_b=self.evidence_b,
                    decompressor=self.decompressor,
                    licenses_source=self.licenses,
                    quality_gate_report=self.quality_gate_report,
                    conversion_report=self.conversion_report,
                    stage_root=stage,
                    package_manifest_path=self.root / "final-package-symlink.json",
                )
        self.assertEqual(list(stage.iterdir()), [])


if __name__ == "__main__":
    unittest.main()
