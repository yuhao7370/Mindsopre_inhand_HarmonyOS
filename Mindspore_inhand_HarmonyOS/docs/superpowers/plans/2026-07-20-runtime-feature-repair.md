# Runtime Feature Repair Implementation Plan

**Goal:** Make all ten visible Experience features produce input-dependent results, with one verified commit per feature and continuously updated evidence in `docs/repair-status.md`.

**Architecture:** Repair the native camera path first. Reuse the existing CoreVision, MindSpore Lite, and MNN service boundaries; replace only runtime-proven incompatible assets or runners. Keep translation persistent and off the UI path. Gate saving on a current result `PixelMap`.

**Toolchain:** ArkTS, HarmonyOS API 24 kits, Hvigor, PowerShell guards, HDC, DevEco emulator, existing MindSpore Lite and MNN integrations.

## Task 1: Restore the baseline gate

- Install the missing `sentencepiece` package into the Python selected by `scripts/verify-translation-model.ps1`.
- Run `scripts/build-hap.ps1`; record any next real failure without weakening a verifier.
- Update the status header. No source commit unless the repository itself lacks a reproducible requirement.

## Task 2: Image Classification

Files: `scripts/check-live-camera-device-profile.ps1`, `scripts/build-hap.ps1`, `entry/src/main/ets/services/camera/LiveCameraService.ets`, focused camera tests if needed, `docs/repair-status.md`.

1. Add a failing guard proving camera input uses an actual supported device and a queried preview profile.
2. Change the driver to select the requested-position device, query `NORMAL_PHOTO` output capability, choose its first supported preview profile, and use the profile overloads.
3. Build/install and test front/back continuous frames on the emulator.
4. Run classification with two labeled frames. Reuse the bundled model if it really loads and passes; only then start a licensed API24 conversion spike.
5. Update evidence and commit `fix(image-classification): enable verified camera and api24 model`.

## Task 3: PoseNet

Files: `PoseService.ets`, `ImageClassificationRuntimeFactory.ets`, focused tests/assets, `docs/repair-status.md`.

1. Add a failing labeled-keypoint check.
2. Test CoreVision after the camera repair. If unavailable, obtain and audit one licensed original pose model, convert it for API24, and add the minimum dedicated decoder.
3. Verify two poses and normalized keypoint tolerance on simulator; verify CoreVision/arm64 on device when required.
4. Commit `fix(posenet): enable real pose inference`.

## Task 4: Portrait Segmentation

Files: `SegmentationService.ets`, its factory wiring, `FeatureRuntimePage.ets`, save readiness helper/tests, fixtures, status.

1. Add failing mask-IoU, no-person, and save-readiness checks.
2. Use CoreVision when available; otherwise audit/convert one licensed segmentation model and decode its real mask.
3. Verify still/live foreground and saved Gallery image.
4. Commit `fix(portrait-segmentation): enable real segmentation and gated save`.

## Task 5: Gesture Recognition

Files: existing gesture service/native bridge and tests, labeled fixtures, status.

1. Add a failing positive/negative fixture oracle around the current MNN output.
2. Fix only observed preprocessing, label, threshold, or camera-frame defects.
3. Verify still and continuous live results change with gestures.
4. Commit `fix(gesture-recognition): verify still and live inference`.

## Task 6: Text Extraction

Files: `TextRecognitionService.ets`, factory wiring, OCR models/decoder only if required, fixtures, status.

1. Add failing Chinese/English character-error checks and visible error-state checks.
2. Test CoreVision; if unavailable, audit and prove a licensed text detector + recognizer + dictionary before wiring the two-stage pipeline.
3. Verify photo and camera text; never accept empty output as success.
4. Commit `fix(text-extraction): enable real ocr`.

## Task 7: Text Translation

Files: `MindSporeLiteTranslationRunner.ets`, runtime factory/page status handling, translation tests, status.

1. Add failing tests for model reuse, non-UI execution, stable error codes, repeated clicks, and non-dictionary sentences.
2. Move model creation and all decode steps to one persistent translation executor; return only transferable data.
3. Show failures instead of blank output and keep finite dictionary logic test-only.
4. Verify typed and OCR-sourced sentences while the UI remains responsive.
5. Commit `fix(text-translation): move real translation off the ui path`.

## Task 8: Object Detection (Photo)

Files: model acquisition/conversion scripts, `ObjectDetectionService.ets`, cache contract tests, fixtures, status.

1. Add failing API24 schema/tensor and labeled-box checks.
2. Replace the legacy SSD only from a licensed original model; pin provenance, converter, hashes, and exact outputs.
3. Verify class, confidence, and box IoU; reject an incompatible override without replacing a valid cache.
4. Commit `fix(object-detection-photo): enable api24 still detection`.

## Task 9: Object Detection (Real-time)

Files: live loop/page overlay tests and status; reuse the verified photo detector.

1. Add a failing frame/result sequencing check.
2. Fix only live throttling, frame capture, coordinate mapping, or stale-result defects.
3. Verify changing frame hashes and matching overlays over a continuous run.
4. Commit `fix(object-detection-realtime): enable verified live detection`.

## Task 10: Style Transfer

Files: model acquisition/conversion scripts, `StyleTransferService.ets`, result/save tests, fixtures, status.

1. Add failing two-model tensor, pixel-difference, distinct-style, and save-readiness checks.
2. Replace incompatible models only from licensed originals converted for API24.
3. Verify two styles, result dimensions, recovery, and one Gallery asset per save action.
4. Commit `fix(style-transfer): enable api24 models and gated save`.

## Task 11: Custom Model

Files: `ModelFileCacheService.ets`, `CustomModelService.ets`, picker/cache tests, compatible/incompatible fixtures, status.

1. Add failing checks for the existing input contract and the first runtime-consumed output.
2. Validate before atomic cache publication; preserve the last valid model on failure.
3. Verify DocumentPicker with a controlled model and two different images.
4. Commit `fix(custom-model): enforce model input and output contracts`.

## Task 12: Final gate

- Run `scripts/build-ai-runtime-acceptance.ps1` and `scripts/build-hap.ps1`.
- Install the produced HAP, exercise all ten routes, inspect logs, saved assets, and live-frame evidence.
- Confirm every status row is `done`, links its feature commit, and contains the required oracle evidence.
- Confirm `git status --short` is clean. Do not mark completion while any row is `pending`, `blocked`, or supported only by a static guard.
