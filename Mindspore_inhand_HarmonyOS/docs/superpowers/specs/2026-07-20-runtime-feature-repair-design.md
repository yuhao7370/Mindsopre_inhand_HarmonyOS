# Runtime Feature Repair Design

## Scope

Repair the ten visible Experience features so each produces a real result from the current input. Fixed, random, or sample-only output is not a pass. Hidden Dance, Poetry, and Scene entries are outside this repair batch.

Progress is tracked in `docs/repair-status.md`. Each row records feature, phase, commit, dependency, model source/license/SHA-256, API 24 conversion, input/output contract, automated/simulator/device evidence, last error, and blocker. Phase moves only through `pending -> coding -> auto_pass -> emulator_pass -> device_pass -> done`; a failed check moves it to `blocked` with evidence. A feature is done only after its required checks pass. Each feature is enabled and committed separately with its tests and evidence.

## Chosen approach

Use the platform before adding code:

1. Fix the camera path by selecting an actual `CameraDevice`, querying its `NORMAL_PHOTO` output capability, choosing a supported preview profile, and creating the preview output with that profile.
2. Keep system MindSpore Lite as the default local inference runtime. Replace incompatible legacy `.ms` files only from licensed original ONNX, TFLite, TensorFlow, or MindIR assets converted reproducibly for API 24.
3. Keep the working MNN gesture runner. Do not build a second generic native runtime unless an API 24 MindSpore Lite spike proves unstable.
4. Use CoreVision on devices where the native capability exists. Pose, segmentation, and OCR may use bundled local models only when their source, redistribution license, conversion, tensor contract, and real-input accuracy all pass. An unsupported simulator result is never reported as success.
5. Run translation in a persistent executor that retains its models between requests and never executes model loading or decode steps on the UI path. Translation and live visual inference use separate serial executors so a long decode cannot block camera results.
6. Create result `PixelMap` objects on the UI side from current-generation output. Save is available only after that object exists and only one save may run at a time.

## Required spikes and stop conditions

- Convert a small licensed classification model and prove two distinct predictions in a persistent worker on API 24 x86_64, then arm64.
- Prove Pose, segmentation, and two-stage OCR independently before wiring their routes.
- Record source URL or commit, source and output SHA-256, license, converter version and SHA-256, command, input layout, normalization, output names, shapes, and dtypes.
- Reject any model with an unclear redistribution license, unsupported operator, unstable repeated prediction, or mismatched output contract.
- If MindSpore Lite cannot predict reliably off the UI path, use a minimal native asynchronous runner based on the existing MNN integration.

## Feature commit order

1. `fix(image-classification): enable verified camera and api24 model`
2. `fix(posenet): enable real pose inference`
3. `fix(portrait-segmentation): enable real segmentation and gated save`
4. `fix(gesture-recognition): verify still and live inference`
5. `fix(text-extraction): enable real ocr`
6. `fix(text-translation): move real translation off the ui path`
7. `fix(object-detection-photo): enable api24 still detection`
8. `fix(object-detection-realtime): enable verified live detection`
9. `fix(style-transfer): enable api24 models and gated save`
10. `fix(custom-model): enforce model input and output contracts`

Shared preparation commits may add dormant camera, conversion, executor, or status primitives, but may not change a visible route. Every feature commit must include its production change, focused check, route activation, runtime evidence, and status update.

## Verification

Every inference feature uses at least two materially different inputs and an objective oracle:

- Classification and scene-dependent gesture labels match labeled fixtures at top-1 or documented top-k.
- Pose keypoints match labeled visible joints within the documented normalized-distance tolerance.
- Segmentation foreground overlaps a labeled mask at the documented minimum IoU and rejects a no-person fixture.
- OCR meets the documented maximum character error rate on printed Chinese and English fixtures.
- Translation preserves fixture meaning and reaches the documented corpus score or approved sentence-level expected output.
- Object detection finds the labeled class and reaches the documented minimum box IoU and confidence.
- Style output differs from the content image by the documented pixel threshold and two style inputs produce measurably different outputs.
- Custom Model produces finite, non-empty, input-dependent values from the first output consumed by the runtime.

Threshold values and fixture hashes are recorded in the corresponding feature commit before its route is marked done. Live features also record frame hashes, results, and latency over a continuous run. Camera verification covers front/back selection and repeated capture. Save verification opens the resulting Gallery asset and checks it matches the preview. Custom Model accepts only the documented single NHWC float32 `[1,224,224,3]` input and a non-empty float32 first consumed output.

The final gate builds and installs the main HAP, runs repository checks and device tests, exercises all ten routes, verifies the worktree, and links every completed status row to its commit and evidence.
