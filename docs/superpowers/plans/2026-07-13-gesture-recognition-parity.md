# Gesture Recognition Parity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the unavailable/ImageNet gesture path with a real on-device ArkTS/MindSpore Lite pipeline that detects up to three hands and returns the Android HMS 14 gesture categories for still images and live camera frames.

**Architecture:** Reuse the existing `GestureRunner`, `AndroidGestureModelRunner`, runtime page, live frame loop, generation checks, overlays, and i18n labels. Add focused ArkTS modules for geometry, image input, three-model inference, and temporal state; production factory constructs these modules only after fixed models and a manifest pass conversion, hash, tensor, license, and device smoke gates.

**Tech Stack:** HarmonyOS 6.1.1 API 24, ArkTS, `@kit.ImageKit`, `@kit.CoreFileKit`, `@kit.MindSporeLiteKit`, Hypium, PowerShell model guards, offline Python model training/conversion tools.

## Global Constraints

- Runtime preprocessing, postprocessing, NMS, ROI calculation, normalization, tracking, smoothing, service orchestration, and UI integration are ArkTS.
- Category indices are fixed: `ONE=0`, `SECOND=1`, `THREE=2`, `FOUR=3`, `FIVE=4`, `SIX=5`, `SEVEN=6`, `EIGHT=7`, `NINE=8`, `DISS=9`, `FIST=10`, `GOOD=11`, `HEART=12`, `OK=13`.
- Each result includes category, display label, confidence, and original-image pixel rectangle; one frame returns at most three hands.
- No hand or low-confidence input returns an empty detection list, never a foreground pseudo-box or ImageNet alias.
- Models are fixed-shape MindSpore Lite `.ms` files with SHA-256, tensor contracts, label order, source, and redistribution license recorded in `gesture_manifest.json`.
- A model is not wired into production until conversion and API 24 device smoke tests pass.
- Offline held-out macro accuracy is at least 90%; every category recall is at least 75% with subjects isolated between train and test sets.
- Target-device median end-to-end live-frame latency is at most 500 ms with no overlapping frame inference.
- Host Hypium proves pure ArkTS math and fake-model orchestration; it does not count as proof that a real model loads or runs on a device.
- Existing page live loop and request generations remain the only scheduler; no second frame queue is introduced.

---

### Task 1: Establish model provenance, conversion, and build gates

**Files:**
- Create: `model_tools/gesture/download_sources.ps1`
- Create: `model_tools/gesture/convert_models.py`
- Create: `model_tools/gesture/README.md`
- Create: `model_tools/gesture/THIRD_PARTY_NOTICES.md`
- Create: `Mindspore_inhand_HarmonyOS/entry/src/main/resources/rawfile/model/gesture_manifest.json`
- Create: `Mindspore_inhand_HarmonyOS/entry/src/main/resources/rawfile/labels/gesture_category.txt`
- Create: `Mindspore_inhand_HarmonyOS/scripts/verify-gesture-models.ps1`
- Modify: `Mindspore_inhand_HarmonyOS/scripts/ensure-mindspore-models.ps1`
- Modify: `Mindspore_inhand_HarmonyOS/scripts/check-model-label-guards.ps1`

**Interfaces:**
- Consumes: licensed palm detector and 21-landmark TFLite sources plus the project 14-class classifier export.
- Produces: `gesture_palm_detection.ms`, `gesture_hand_landmark.ms`, `gesture_classifier_14.ms`, exact manifest, labels, and build-stopping verification.

- [ ] **Step 1: Add the fixed label contract and failing verifier**

Write `gesture_category.txt` as exactly:

```text
ONE
SECOND
THREE
FOUR
FIVE
SIX
SEVEN
EIGHT
NINE
DISS
FIST
GOOD
HEART
OK
```

`verify-gesture-models.ps1` reads the manifest, requires three model entries, verifies each rawfile exists, compares byte size and SHA-256, and compares the 14 label lines exactly. It also requires non-empty `sourceUrl`, `sourceVersion`, `license`, `inputShape`, `outputShapes`, `dtype`, and `normalization` fields. It prints only file name and expected/actual hash on failure.

- [ ] **Step 2: Run the verifier to establish RED**

```powershell
Set-Location Mindspore_inhand_HarmonyOS
.\scripts\verify-gesture-models.ps1
```

Expected: nonzero exit naming the first missing `.ms` file.

- [ ] **Step 3: Download immutable model sources and record hashes**

`download_sources.ps1` downloads versioned palm and landmark TFLite assets into `model_tools/gesture/cache`, computes SHA-256 with `Get-FileHash`, and writes `source-lock.json`. The script refuses redirects to a different host and refuses to overwrite a file whose existing hash differs. `THIRD_PARTY_NOTICES.md` records repository, model card, exact asset URL, version, and redistribution license separately from the source-code license.

- [ ] **Step 4: Convert in a supported MindSpore Lite tool environment**

`convert_models.py` accepts only these explicit arguments:

```text
--palm-tflite <path>
--landmark-tflite <path>
--classifier-mindir <path>
--output-dir <rawfile/model directory>
--manifest <gesture_manifest.json>
```

Use `mindspore_lite.Converter` with `FmkType.TFLITE` for palm/landmark and `FmkType.MINDIR` for the classifier. After conversion, load each output through the converter environment, inspect input/output names, shapes and dtypes, calculate SHA-256, and atomically write the final manifest. This Windows host currently has no converter, WSL, or Docker, so execute this step in a supported Linux/Python environment and copy only verified outputs back; do not install an unpinned converter into the app project.

- [ ] **Step 5: Attach verification to the existing model chain**

Call `verify-gesture-models.ps1` from `ensure-mindspore-models.ps1` after the other model downloads. Extend `check-model-label-guards.ps1` so it requires both the verifier call and `labels/gesture_category.txt` reference.

- [ ] **Step 6: Run GREEN and commit model metadata/scripts**

```powershell
.\scripts\verify-gesture-models.ps1
.\scripts\check-model-label-guards.ps1
git add scripts/verify-gesture-models.ps1 scripts/ensure-mindspore-models.ps1 scripts/check-model-label-guards.ps1 entry/src/main/resources/rawfile/labels/gesture_category.txt entry/src/main/resources/rawfile/model/gesture_manifest.json ..\model_tools\gesture
git commit -m "build: verify gesture model bundle"
```

Expected: both scripts pass only when the three verified model files exist. Keep generated `.ms` files ignored if the existing download/build pattern is retained.

---

### Task 2: Implement pure ArkTS gesture geometry

**Files:**
- Create: `Mindspore_inhand_HarmonyOS/entry/src/main/ets/services/ai/gesture/GestureGeometry.ets`
- Create: `Mindspore_inhand_HarmonyOS/entry/src/test/GesturePipeline.test.ets`
- Modify: `Mindspore_inhand_HarmonyOS/entry/src/test/List.test.ets`

**Interfaces:**
- Consumes: detector candidates and landmark arrays in normalized model coordinates.
- Produces: letterbox transforms, IoU/NMS, rotated ROI, landmark normalization, and original-image rectangles for the detector.

- [ ] **Step 1: Register a focused failing test suite**

Add `gesturePipelineTest()` to `List.test.ets`. Define tests for these exact exports:

```ts
export interface GesturePoint { readonly x: number; readonly y: number; readonly z: number; }
export interface GestureBox { readonly left: number; readonly top: number; readonly right: number; readonly bottom: number; readonly score: number; }
export interface GestureLetterbox { readonly scale: number; readonly padX: number; readonly padY: number; readonly sourceWidth: number; readonly sourceHeight: number; }
export interface GestureRotatedRoi { readonly centerX: number; readonly centerY: number; readonly width: number; readonly height: number; readonly radians: number; }

export function gestureIoU(left: GestureBox, right: GestureBox): number;
export function gestureNms(boxes: Array<GestureBox>, threshold: number, limit: number): Array<GestureBox>;
export function restoreGestureBox(box: GestureBox, transform: GestureLetterbox): GestureBox;
export function gestureRotatedRoi(box: GestureBox, wrist: GesturePoint, middleMcp: GesturePoint): GestureRotatedRoi;
export function normalizeGestureLandmarks(points: Array<GesturePoint>, handedness: number): Array<number>;
```

Use numeric fixtures proving IoU 0/1/partial overlap, descending score NMS, limit 3, landscape/portrait padding reversal, ROI angle from wrist to middle MCP, 63 normalized values, wrist at origin, scale invariance, and left-hand mirroring.

- [ ] **Step 2: Run RED**

```powershell
& 'C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat' test --no-daemon
```

Expected: compile failure because `GestureGeometry.ets` does not exist.

- [ ] **Step 3: Implement the formulas without dependencies**

Clamp boxes to the source bounds, calculate intersection from max-left/top and min-right/bottom, sort a copy of candidates by score, and suppress IoU above the threshold. `normalizeGestureLandmarks()` subtracts wrist point 0, mirrors x for left hand, divides all coordinates by the maximum 3D wrist-to-MCP distance across points 5, 9, 13, and 17, and returns an empty array for fewer than 21 points or zero scale.

- [ ] **Step 4: Run GREEN and commit**

```powershell
& 'C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat' test --no-daemon
git add entry/src/main/ets/services/ai/gesture/GestureGeometry.ets entry/src/test/GesturePipeline.test.ets entry/src/test/List.test.ets
git commit -m "feat: add gesture geometry pipeline"
```

Expected: zero Hypium failures/errors.

---

### Task 3: Add strict three-model tensor contracts

**Files:**
- Create: `Mindspore_inhand_HarmonyOS/entry/src/main/ets/services/ai/gesture/GestureModelRuntime.ets`
- Create: `Mindspore_inhand_HarmonyOS/entry/src/main/ets/services/ai/gesture/MindSporeGestureDetector.ets`
- Modify: `Mindspore_inhand_HarmonyOS/entry/src/test/GesturePipeline.test.ets`

**Interfaces:**
- Consumes: three verified rawfile model buffers and manifest tensor shapes.
- Produces: `MindSporeGestureDetector implements AndroidGestureModelDetector` and a fakeable `GestureTensorModel` boundary.

- [ ] **Step 1: Write failing fake-model tensor tests**

Define and fake:

```ts
export interface GestureTensorOutput {
  readonly name: string;
  readonly shape: Array<number>;
  readonly values: Array<number>;
}

export interface GestureTensorModel {
  predict(input: ArrayBuffer): Promise<Array<GestureTensorOutput>>;
  stop(): void;
}

export interface GestureModelSet {
  readonly palm: GestureTensorModel;
  readonly landmark: GestureTensorModel;
  readonly classifier: GestureTensorModel;
}

export interface GestureImageFrame {
  readonly width: number;
  readonly height: number;
  readonly rgba: Uint8Array;
  release(): Promise<void>;
}

export interface GestureInputPreprocessor {
  decode(imageUri: string): Promise<GestureImageFrame>;
}

export interface GestureModelManifest {
  readonly palmScoreThreshold: number;
  readonly landmarkPresenceThreshold: number;
  readonly classifierScoreThreshold: number;
  readonly nmsThreshold: number;
  readonly maxHands: number;
}

export interface MindSporeGestureDetectorOptions {
  readonly resourceManager: RawfileContentReader;
  readonly liveMode: boolean;
  readonly models?: GestureModelSet;
  readonly preprocessor?: GestureInputPreprocessor;
  readonly manifest?: GestureModelManifest;
}
```

Test exact palm output names/shapes, landmark `21 x 3` plus presence and handedness, classifier output length 14, NaN rejection, unknown/missing output rejection, category index preservation, and stop propagation to all three models.

- [ ] **Step 2: Run RED**

Run Hypium. Expected: missing runtime types.

- [ ] **Step 3: Implement the strict system model adapter**

`MindSporeGestureTensorModel` caches one `mindSporeLite.Model`, calls `loadModelFromBuffer(..., mindSporeLiteCpuContext())`, verifies input count/shape/dtype against the manifest before `setData`, calls `predict`, copies each output to `Float32Array`, and validates output names/shapes before returning. It never silently truncates a tensor.

- [ ] **Step 4: Implement detector orchestration against fakes**

`MindSporeGestureDetector.detectAndroidGestures(imageUri)` executes palm once, filters at the manifest threshold, applies NMS and limit 3, executes landmark and classifier per surviving ROI, rejects presence below threshold, and returns `AndroidGestureModelResult` with original-image boxes. Return zero gestures for no hand; throw stable typed errors for model contract and inference failures.

- [ ] **Step 5: Run GREEN and commit**

```powershell
& 'C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat' test --no-daemon
git add entry/src/main/ets/services/ai/gesture/GestureModelRuntime.ets entry/src/main/ets/services/ai/gesture/MindSporeGestureDetector.ets entry/src/test/GesturePipeline.test.ets
git commit -m "feat: add strict gesture model runtime"
```

---

### Task 4: Decode once and implement still-image preprocessing

**Files:**
- Create: `Mindspore_inhand_HarmonyOS/entry/src/main/ets/services/ai/gesture/HarmonyGestureInputPreprocessor.ets`
- Modify: `Mindspore_inhand_HarmonyOS/entry/src/main/ets/services/ai/gesture/MindSporeGestureDetector.ets`
- Modify: `Mindspore_inhand_HarmonyOS/entry/src/test/GesturePipeline.test.ets`

**Interfaces:**
- Consumes: image URI and model input specifications.
- Produces: EXIF-correct RGBA source plus normalized palm and rotated hand ROI buffers.

- [ ] **Step 1: Write failing pixel fixture tests**

Use a synthetic 4x3 RGBA buffer. Assert nearest/bilinear sample coordinates, RGB channel order, normalization, letterbox padding value, rotated ROI corners, and deterministic output buffer lengths. Add a fake decoder test proving one image decode per frame and cleanup in both success and inference failure paths.

- [ ] **Step 2: Run RED**

Run Hypium. Expected: missing preprocessor exports.

- [ ] **Step 3: Implement one-decode preprocessing**

Open the URI through `fileIo`, create an `ImageSource`, apply the existing `createPixelMapWithExifOrientation()`, read RGBA once, record corrected width/height, and release `PixelMap`, `ImageSource`, and file in `finally`. Pure ArkTS sampling creates the palm tensor and each rotated ROI tensor from the same RGBA array; do not create another `PixelMap` per hand.

- [ ] **Step 4: Complete fake static end-to-end test**

Feed two palm boxes, two valid landmark results, and classifier maxima 0 and 13. Assert two `AndroidGestureModelDetection` results, exact categories `ONE` and `OK`, scores, corrected source size, and bounded source-pixel rectangles. Add no-hand and four-hand fixtures; the latter returns three highest-score hands.

- [ ] **Step 5: Run GREEN and commit**

```powershell
& 'C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat' test --no-daemon
git add entry/src/main/ets/services/ai/gesture/HarmonyGestureInputPreprocessor.ets entry/src/main/ets/services/ai/gesture/MindSporeGestureDetector.ets entry/src/test/GesturePipeline.test.ets
git commit -m "feat: preprocess HarmonyOS gesture frames"
```

---

### Task 5: Replace the production factory dead end

**Files:**
- Modify: `Mindspore_inhand_HarmonyOS/entry/src/main/ets/services/ai/GestureService.ets`
- Modify: `Mindspore_inhand_HarmonyOS/entry/src/main/ets/services/ai/ImageClassificationRuntimeFactory.ets`
- Modify: `Mindspore_inhand_HarmonyOS/entry/src/main/ets/services/ai/AiService.ets`
- Modify: `Mindspore_inhand_HarmonyOS/entry/src/main/ets/common/i18n/AppStrings.ets`
- Modify: `Mindspore_inhand_HarmonyOS/entry/src/main/resources/base/element/string.json`
- Modify: `Mindspore_inhand_HarmonyOS/entry/src/main/resources/en_US/element/string.json`
- Modify: `Mindspore_inhand_HarmonyOS/entry/src/main/resources/zh_CN/element/string.json`
- Modify: `Mindspore_inhand_HarmonyOS/entry/src/test/LocalUnit.test.ets`

**Interfaces:**
- Consumes: `MindSporeGestureDetector`, `AndroidGestureModelRunner`, existing gesture workflow.
- Produces: default still/live services that use the real detector and preserve diagnostic errors.

- [ ] **Step 1: Write failing default-factory tests**

Assert `cachedRuntimeAiServiceForWorkflow(gestureWorkflow, reader)` no longer returns an empty `DefaultAiService`. With injected model/preprocessor fakes, run the service and assert a real gesture result reaches `AiGestureData`. Assert production construction never instantiates `ImageClassificationGestureRunner` or reads `mobilenetv2.ms` for `detectGesture`.

- [ ] **Step 2: Run RED**

Run Hypium. Expected: default gesture workflow returns `feature_runtime_gesture_runner_unavailable`.

- [ ] **Step 3: Wire the detector through the existing boundary**

Change the `detectGesture` branch in `cachedRuntimeAiServiceForWorkflow()` to call `createRuntimeAiServiceForWorkflow()`. Change `createHarmonyLocalGestureService(options, workflow)` to load the gesture manifest/model rawfiles and construct:

```ts
new GestureService({
  runner: new AndroidGestureModelRunner(
    new MindSporeGestureDetector({
      resourceManager: options.resourceManager,
      liveMode: workflow.liveMode
    })
  )
})
```

Retain `options.gestureRunner` injection first. Remove `trustedGestureModelLabels` from production decision-making; keep legacy code only if existing tests still require it outside the default path.

- [ ] **Step 4: Preserve stable error diagnostics**

Extend `GestureResult` with optional `errorCode` whose values distinguish `MODEL_MISSING`, `MODEL_HASH_MISMATCH`, `MODEL_INCOMPATIBLE`, `IMAGE_DECODE_FAILED`, and `INFERENCE_FAILED`. Map each to a localized message. `GestureService` returns an empty list plus the correct error; it does not turn every exception into the same unavailable state.

- [ ] **Step 5: Run guards/tests and commit**

```powershell
.\scripts\check-i18n-strings.ps1
& 'C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat' test --no-daemon
git add entry/src/main/ets/services/ai/GestureService.ets entry/src/main/ets/services/ai/ImageClassificationRuntimeFactory.ets entry/src/main/ets/services/ai/AiService.ets entry/src/main/ets/common/i18n/AppStrings.ets entry/src/main/resources/base/element/string.json entry/src/main/resources/en_US/element/string.json entry/src/main/resources/zh_CN/element/string.json entry/src/test/LocalUnit.test.ets
git commit -m "feat: enable production gesture detector"
```

Expected: no unavailable result when verified model fakes are injected; failure cases remain diagnostic.

---

### Task 6: Add live tracking and category smoothing without another scheduler

**Files:**
- Create: `Mindspore_inhand_HarmonyOS/entry/src/main/ets/services/ai/gesture/GestureTemporalState.ets`
- Modify: `Mindspore_inhand_HarmonyOS/entry/src/main/ets/services/ai/gesture/MindSporeGestureDetector.ets`
- Modify: `Mindspore_inhand_HarmonyOS/entry/src/main/ets/services/ai/GestureService.ets`
- Modify: `Mindspore_inhand_HarmonyOS/entry/src/main/ets/services/ai/AiService.ets`
- Modify: `Mindspore_inhand_HarmonyOS/entry/src/main/ets/services/ai/RuntimeAiServiceSession.ets`
- Modify: `Mindspore_inhand_HarmonyOS/entry/src/test/GesturePipeline.test.ets`
- Modify: `Mindspore_inhand_HarmonyOS/entry/src/test/LocalUnit.test.ets`

**Interfaces:**
- Consumes: current timestamp, last landmark/box/category results, `liveMode`.
- Produces: ROI reuse, periodic palm redetection, score smoothing, and deterministic reset.

- [ ] **Step 1: Write failing temporal tests**

Test first frame requires palm detection; stable landmarks reuse ROI for four frames; the fifth frame redetects; low presence immediately redetects; exponential category smoothing keeps a stable class across one noisy frame; three consecutive low-confidence frames clear the hand; `reset()` clears all tracks; and still mode always runs a full detection.

- [ ] **Step 2: Run RED**

Run Hypium. Expected: missing temporal state class.

- [ ] **Step 3: Implement the minimum state machine**

Use one state object per detector, at most three tracks, redetect interval 5 processed frames, smoothing alpha 0.6, and clear-after count 3. Match detections to tracks greedily by highest IoU above 0.3. These constants live in the manifest/config object so device calibration changes values without changing algorithms.

- [ ] **Step 4: Integrate state reset into lifecycle**

Expose idempotent `stop()` on detector, `AndroidGestureModelRunner`, `GestureService`, and `DefaultAiService`. `RuntimeAiServiceSession.invalidate()` must clear its cached promise then stop the resolved service; add a test for route exit and camera-switch invalidation. If the translation plan already added the generic service stop chain, extend that implementation instead of creating a second lifecycle path. The page already invalidates its session on route exit/camera switch, so do not edit `FeatureRuntimePage.ets` unless the integration test proves the call is absent.

- [ ] **Step 5: Run GREEN and commit**

```powershell
& 'C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat' test --no-daemon
git add entry/src/main/ets/services/ai/gesture/GestureTemporalState.ets entry/src/main/ets/services/ai/gesture/MindSporeGestureDetector.ets entry/src/main/ets/services/ai/GestureService.ets entry/src/main/ets/services/ai/AiService.ets entry/src/main/ets/services/ai/RuntimeAiServiceSession.ets entry/src/test/GesturePipeline.test.ets entry/src/test/LocalUnit.test.ets
git commit -m "feat: track live hand gestures"
```

---

### Task 7: Train and enforce the 14-category classifier metrics

**Files:**
- Create: `model_tools/gesture/train_export_evaluate.py`
- Create: `model_tools/gesture/test_train_export_evaluate.py`
- Modify: `model_tools/gesture/README.md`
- Modify: `Mindspore_inhand_HarmonyOS/entry/src/main/resources/rawfile/model/gesture_manifest.json`

**Interfaces:**
- Consumes: rows containing subject ID, category 0-13, handedness, and 63 normalized landmark floats.
- Produces: trained MindIR/classifier `.ms`, metrics JSON, confusion matrix CSV, and manifest classifier hash.

- [ ] **Step 1: Write failing Python data/metric tests**

Using `unittest`, verify subject IDs never cross train/test splits, all 14 classes are required, label order matches `gesture_category.txt`, normalization matches ArkTS fixtures, macro accuracy below 0.90 exits nonzero, any per-class recall below 0.75 exits nonzero, and acceptable synthetic predictions exit zero.

- [ ] **Step 2: Run RED**

```powershell
python -m unittest discover -s .\model_tools\gesture -p 'test_*.py' -v
```

Expected: import failure because the training/evaluation module does not exist.

- [ ] **Step 3: Implement deterministic data split, training, and export**

Use a fixed seed, group split by subject, a compact `63 -> 64 ReLU -> 32 ReLU -> 14` classifier, class-balanced batches, early stopping on validation macro accuracy, and export the best weights to MindIR. Emit `metrics.json` with sample counts, subject counts, overall/macro accuracy, and all per-class recalls. Never synthesize missing categories.

- [ ] **Step 4: Convert, evaluate, verify, and commit metadata**

Run training on the curated dataset, convert through Task 1, then:

```powershell
python -m unittest discover -s .\model_tools\gesture -p 'test_*.py' -v
.\Mindspore_inhand_HarmonyOS\scripts\verify-gesture-models.ps1
```

Expected: Python tests pass, metrics meet both gates, and model hashes/tensor contracts pass. Commit source/tooling/metrics and manifest, not private subject images.

---

### Task 8: Add API 24 model smoke tests and device acceptance

**Files:**
- Create: `Mindspore_inhand_HarmonyOS/entry/src/ohosTest/ets/test/GestureModel.test.ets`
- Modify: `Mindspore_inhand_HarmonyOS/entry/src/ohosTest/ets/test/List.test.ets`
- Add: `Mindspore_inhand_HarmonyOS/entry/src/ohosTest/resources/rawfile/gesture_golden.jpg`
- Modify: `docs/harmonyos-platform-differences.md`

**Interfaces:**
- Consumes: real rawfile models, one licensed golden image, signed test HAP, API 24 device.
- Produces: load/inference/category/box/latency evidence on the target runtime.

- [ ] **Step 1: Add the device test suite**

The suite loads all three models through the production classes, asserts manifest shapes/dtypes, runs the golden image, checks expected category and broad rectangle tolerance, and records initialization plus inference milliseconds. Add a 20-frame loop that asserts no simultaneous inference and computes median latency.

- [ ] **Step 2: Build test HAPs**

```powershell
& 'C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat' assembleHap --mode module -p product=default -p module=entry@ohosTest --no-daemon
```

Expected: main and test HAPs assemble successfully. Signing must be configured outside tracked files.

- [ ] **Step 3: Run on a connected target**

```powershell
& 'C:\Program Files\Huawei\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe' list targets
hdc shell aa test -b com.yuhaofeng.mih -m entry_test -s unittest OpenHarmonyTestRunner -w 120000
```

Expected: a real target is listed, device tests pass, and median live-frame inference is at most 500 ms.

- [ ] **Step 4: Manual parity matrix**

On the signed app verify all 14 categories in still and live modes, one and two hands, portrait/landscape, front/back cameras, bright/dim backgrounds, no-hand clearing, camera switch reset, and page-exit cancellation. Save only aggregate results and non-sensitive test identifiers in the platform-differences document.

- [ ] **Step 5: Commit device tests and evidence**

```powershell
git add entry/src/ohosTest/ets/test/GestureModel.test.ets entry/src/ohosTest/ets/test/List.test.ets entry/src/ohosTest/resources/rawfile/gesture_golden.jpg ..\docs\harmonyos-platform-differences.md
git commit -m "test: verify gesture models on HarmonyOS"
```

---

### Task 9: Full regression and artifact audit

**Files:**
- Modify: `docs/harmonyos-platform-differences.md`

**Interfaces:**
- Consumes: all gesture tasks.
- Produces: final build, model, HAP, test, and device evidence without overstating incomplete gates.

- [ ] **Step 1: Run all host checks**

```powershell
Set-Location Mindspore_inhand_HarmonyOS
& 'C:\Program Files\Huawei\DevEco Studio\tools\ohpm\bin\ohpm.bat' install
& 'C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat' test --no-daemon
.\scripts\verify-gesture-models.ps1
.\scripts\check-model-label-guards.ps1
.\scripts\build-hap.ps1
git diff --check
Get-FileHash .\entry\build\default\outputs\default\entry-default-unsigned.hap -Algorithm SHA256
```

Expected: zero unit failures/errors, all model/static guards pass, `BUILD SUCCESSFUL`, whitespace check passes, and the final HAP hash/size are recorded.

- [ ] **Step 2: Audit every completion gate**

Confirm three `.ms` hashes and tensor shapes, all 14 labels, offline accuracy/recall, signed target installation, still/live device tests, latency, no overlapping inference, and honest errors for missing/corrupt models. Any missing evidence remains explicitly incomplete; host tests alone cannot close device or accuracy gates.

- [ ] **Step 3: Commit the verified status**

```powershell
git add ..\docs\harmonyos-platform-differences.md
git commit -m "docs: record gesture parity verification"
```
