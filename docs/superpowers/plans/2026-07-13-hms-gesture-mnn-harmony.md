# HMS Gesture MNN HarmonyOS Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Run the original HMS `GestureDetector.ms` on HarmonyOS for still images and live camera frames, with ArkTS preprocessing, YOLOv3 decoding, NMS, Android category mapping, and existing overlays.

**Architecture:** A pinned CPU-only MNN OHOS library executes the original MNN FlatBuffer through a narrow asynchronous NAPI module. ArkTS owns image decode, RGBA→BGR/NCHW preprocessing, all YOLO postprocessing, service adaptation, and runtime/UI lifecycle. Existing `AndroidGestureModelRunner`, `GestureService`, live-frame mutual exclusion, and overlay rendering remain the public integration seam.

**Tech Stack:** HarmonyOS 6.1.1/API 24, ArkTS, ArkUI, Hypium, OHOS NDK/Clang 15.0.4, CMake/Ninja, MNN commit `785907a83194f6607762742adab86240582aa013`, PowerShell model guards.

## Global Constraints

- Gesture AAR SHA-256: `92FD6AE357E3C5B0407F8E0FED1644D7E01604F9399AF97F23E87C7D2F8CD01C`.
- `GestureDetector.ms` SHA-256: `A3440EF5B102BB9D25D984A8A2CA44EF4FC0557B65F0AC236176375FF9FFA5DA`.
- Model input is `data FLOAT32 [1,3,224,224]`, nearest resize, BGR, `/255`, direct stretch.
- Outputs are `layer89-conv-hand [1,60,7,7]`, `layer101-conv-hand [1,60,14,14]`, and `layer113-conv-hand [1,60,28,28]`.
- NMS IoU is `0.45`; still threshold is `0.6`; live threshold is `0.1`; do not add a business-level result count cap.
- MNN is CPU-only; OpenCL/Vulkan/ARM82/BF16/KleidiAI/MINI remain disabled.
- Model/runtime absence and tensor mismatch must fail honestly; never fall back to ImageNet classification.
- Preserve unrelated user changes, especially `docs/harmonyos-platform-differences.md`.

---

## File Structure

- `Mindspore_inhand_HarmonyOS/scripts/import-hms-gesture-model.ps1`: reproducibly download/extract or validate the AAR/model asset.
- `Mindspore_inhand_HarmonyOS/scripts/build-mnn-ohos.ps1`: build pinned arm64/x86_64 MNN artifacts and verify hashes/dependencies.
- `Mindspore_inhand_HarmonyOS/scripts/verify-hms-gesture-model.ps1`: guard model hash and packaged tensor manifest.
- `Mindspore_inhand_HarmonyOS/entry/src/main/resources/rawfile/models/gesture/`: model, manifest, provenance, and license notice.
- `Mindspore_inhand_HarmonyOS/entry/src/main/cpp/`: native build, NAPI session, and imported MNN headers/library wiring.
- `Mindspore_inhand_HarmonyOS/entry/src/main/cpp/types/libgesture_mnn/`: ArkTS declaration package.
- `Mindspore_inhand_HarmonyOS/entry/src/main/ets/services/ai/HmsGesturePreprocessor.ets`: image decode and input tensor generation.
- `Mindspore_inhand_HarmonyOS/entry/src/main/ets/services/ai/HmsGestureYoloDecoder.ets`: sigmoid, anchors, coordinate restoration, NMS, and sorting.
- `Mindspore_inhand_HarmonyOS/entry/src/main/ets/services/ai/HmsGestureModelDetector.ets`: NAPI/model adapter implementing `AndroidGestureModelDetector`.
- `Mindspore_inhand_HarmonyOS/entry/src/test/GestureModelUnit.test.ets`: focused host tests.
- `Mindspore_inhand_HarmonyOS/entry/src/test/List.test.ets`: register focused tests.
- `Mindspore_inhand_HarmonyOS/entry/src/ohosTest/ets/test/GestureNative.test.ets`: target-side model smoke.

### Task 1: Commit the Verified HMS Model Asset and Provenance Guard

**Files:**
- Create: `Mindspore_inhand_HarmonyOS/scripts/import-hms-gesture-model.ps1`
- Create: `Mindspore_inhand_HarmonyOS/scripts/verify-hms-gesture-model.ps1`
- Create: `Mindspore_inhand_HarmonyOS/entry/src/main/resources/rawfile/models/gesture/GestureDetector.ms`
- Create: `Mindspore_inhand_HarmonyOS/entry/src/main/resources/rawfile/models/gesture/manifest.json`
- Create: `Mindspore_inhand_HarmonyOS/entry/src/main/resources/rawfile/models/gesture/NOTICE.md`
- Create: `docs/model-provenance/hms-gesture-2.1.0.300.md`

**Interfaces:**
- Consumes: official AAR URL and the two fixed SHA-256 values.
- Produces: rawfile path `models/gesture/GestureDetector.ms` and a guard that exits nonzero on any mismatch.

- [ ] **Step 1: Write the failing asset guard**

Create `verify-hms-gesture-model.ps1` with the fixed contract:

```powershell
$ErrorActionPreference = 'Stop'
$model = Join-Path $PSScriptRoot '..\entry\src\main\resources\rawfile\models\gesture\GestureDetector.ms'
$expected = 'A3440EF5B102BB9D25D984A8A2CA44EF4FC0557B65F0AC236176375FF9FFA5DA'
if (-not (Test-Path -LiteralPath $model)) { throw "Missing HMS gesture model: $model" }
$actual = (Get-FileHash -LiteralPath $model -Algorithm SHA256).Hash
if ($actual -ne $expected) { throw "Gesture model hash mismatch: $actual" }
Write-Output 'HMS gesture model verified.'
```

- [ ] **Step 2: Run the guard to verify RED**

Run from repository root:

```powershell
& .\Mindspore_inhand_HarmonyOS\scripts\verify-hms-gesture-model.ps1
```

Expected: FAIL with `Missing HMS gesture model`.

- [ ] **Step 3: Add the import script and model metadata**

The import script must download AAR `2.1.0.300`, verify AAR hash, extract `assets/GestureDetector.ms`, verify model hash, and copy only the model to the rawfile path. Write `manifest.json` exactly with input/output names, shapes, thresholds, anchors, and hashes from the design spec. Write `NOTICE.md` and the provenance document with the private-learning restriction and upstream statement.

- [ ] **Step 4: Run the guard and inspect the model package**

```powershell
& .\Mindspore_inhand_HarmonyOS\scripts\import-hms-gesture-model.ps1
& .\Mindspore_inhand_HarmonyOS\scripts\verify-hms-gesture-model.ps1
```

Expected: both PASS and rawfile size `2269168` bytes.

- [ ] **Step 5: Commit**

```powershell
git add Mindspore_inhand_HarmonyOS/scripts/import-hms-gesture-model.ps1 `
  Mindspore_inhand_HarmonyOS/scripts/verify-hms-gesture-model.ps1 `
  Mindspore_inhand_HarmonyOS/entry/src/main/resources/rawfile/models/gesture `
  docs/model-provenance/hms-gesture-2.1.0.300.md
git commit -m "build: add verified HMS gesture model"
```

### Task 2: Reproduce the Pinned MNN OHOS Runtime

**Files:**
- Create: `Mindspore_inhand_HarmonyOS/scripts/build-mnn-ohos.ps1`
- Create: `Mindspore_inhand_HarmonyOS/entry/libs/arm64-v8a/libMNN.so`
- Create: `Mindspore_inhand_HarmonyOS/entry/src/main/cpp/include/MNN/` copied from the pinned commit
- Create: `Mindspore_inhand_HarmonyOS/entry/src/main/cpp/MNN_BUILD_MANIFEST.json`

**Interfaces:**
- Consumes: DevEco native SDK and pinned MNN commit.
- Produces: `libMNN.so` loadable by an OHOS NAPI shared library.

- [ ] **Step 1: Write the build-manifest verifier before the build script**

The script must validate commit, Clang version, ABI, CMake cache booleans, ELF target, DT_NEEDED set, and the known reference hash `A0D9F3...53A5`. A different hash is allowed only when the manifest records why toolchain inputs differ; ABI/dependency drift is never allowed.

- [ ] **Step 2: Run it to verify RED**

```powershell
& .\Mindspore_inhand_HarmonyOS\scripts\build-mnn-ohos.ps1 -VerifyOnly
```

Expected: FAIL because `entry/libs/arm64-v8a/libMNN.so` is absent.

- [ ] **Step 3: Implement the exact pinned build**

Use the CMake flags from the design spec, `OHOS_ARCH=arm64-v8a`, API 24, shared MNN, `c++_shared`, CPU-only, all optional backends and MINI off. Copy only `libMNN.so` and public inference headers into the project; do not vendor the entire MNN source tree.

- [ ] **Step 4: Verify the artifact**

```powershell
& .\Mindspore_inhand_HarmonyOS\scripts\build-mnn-ohos.ps1
& .\Mindspore_inhand_HarmonyOS\scripts\build-mnn-ohos.ps1 -VerifyOnly
```

Expected: AArch64 ELF, only `libc++_shared.so`/`libc.so` dependencies, size near 3.4 MB, verification PASS.

- [ ] **Step 5: Commit**

```powershell
git add Mindspore_inhand_HarmonyOS/scripts/build-mnn-ohos.ps1 `
  Mindspore_inhand_HarmonyOS/entry/libs/arm64-v8a/libMNN.so `
  Mindspore_inhand_HarmonyOS/entry/src/main/cpp/include/MNN `
  Mindspore_inhand_HarmonyOS/entry/src/main/cpp/MNN_BUILD_MANIFEST.json
git commit -m "build: vendor pinned MNN Harmony runtime"
```

### Task 3: Add the Narrow Asynchronous NAPI Session

**Files:**
- Create: `Mindspore_inhand_HarmonyOS/entry/src/main/cpp/CMakeLists.txt`
- Create: `Mindspore_inhand_HarmonyOS/entry/src/main/cpp/gesture_mnn_napi.cpp`
- Create: `Mindspore_inhand_HarmonyOS/entry/src/main/cpp/gesture_mnn_session.cpp`
- Create: `Mindspore_inhand_HarmonyOS/entry/src/main/cpp/gesture_mnn_session.h`
- Create: `Mindspore_inhand_HarmonyOS/entry/src/main/cpp/types/libgesture_mnn/index.d.ts`
- Create: `Mindspore_inhand_HarmonyOS/entry/src/main/cpp/types/libgesture_mnn/oh-package.json5`
- Modify: `Mindspore_inhand_HarmonyOS/entry/build-profile.json5`
- Modify: `Mindspore_inhand_HarmonyOS/entry/oh-package.json5`

**Interfaces:**
- Consumes: `Float32Array` with exactly `1*3*224*224` elements.
- Produces: `loadModel(modelBytes): GestureModelInfo`, `predict(input): Promise<GestureRawOutputs>`, `release(): void`.

- [ ] **Step 1: Define the ArkTS declaration first**

```ts
export interface GestureRawTensor {
  readonly name: string;
  readonly shape: number[];
  readonly data: ArrayBuffer;
}
export interface GestureRawOutputs { readonly tensors: GestureRawTensor[]; }
export interface GestureModelInfo { readonly inputName: string; readonly inputShape: number[]; }
export const loadModel: (modelBytes: Uint8Array) => GestureModelInfo;
export const predict: (input: Float32Array) => Promise<GestureRawOutputs>;
export const release: () => void;
```

- [ ] **Step 2: Add a native probe target and verify RED/GREEN at link time**

Configure imported `libMNN.so`, link `libace_napi.z.so`, build `libgesture_mnn.so`, and verify `readelf -d` shows `$ORIGIN` plus the expected dependencies. The NAPI module must reject wrong input length before scheduling work.

- [ ] **Step 3: Implement session ownership and async inference**

Copy and retain the supplied model bytes, create one `MNN::Interpreter` from that buffer, create one CPU `Session`, and protect it with a mutex. Use host NCHW tensors and `napi_create_async_work`; copy the JS input before the worker starts. Return the three named outputs as copied `ArrayBuffer`s. `release()` releases session, model, and retained bytes in that order and is idempotent.

- [ ] **Step 4: Build HAP to verify native packaging**

```powershell
& 'C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat' assembleHap --no-daemon
```

Expected: HAP contains `libgesture_mnn.so`, `libMNN.so`, and `GestureDetector.ms`; no unresolved native symbol.

- [ ] **Step 5: Commit**

```powershell
git add Mindspore_inhand_HarmonyOS/entry/src/main/cpp `
  Mindspore_inhand_HarmonyOS/entry/build-profile.json5 `
  Mindspore_inhand_HarmonyOS/entry/oh-package.json5
git commit -m "feat: add MNN gesture native bridge"
```

### Task 4: Implement ArkTS Preprocessing and YOLOv3 Postprocessing

**Files:**
- Create: `Mindspore_inhand_HarmonyOS/entry/src/main/ets/services/ai/HmsGesturePreprocessor.ets`
- Create: `Mindspore_inhand_HarmonyOS/entry/src/main/ets/services/ai/HmsGestureYoloDecoder.ets`
- Create: `Mindspore_inhand_HarmonyOS/entry/src/test/GestureModelUnit.test.ets`
- Modify: `Mindspore_inhand_HarmonyOS/entry/src/test/List.test.ets`

**Interfaces:**
- Produces: `gestureInputFromRgba(rgba,width,height): Float32Array` and `decodeHmsGestureOutputs(outputs, sourceWidth, sourceHeight, threshold): AndroidGestureModelDetection[]`.

- [ ] **Step 1: Write failing preprocessing golden tests**

Use a 2×2 RGBA fixture with distinct channels. Assert nearest-stretched indices, BGR plane ordering, `/255`, exact length `150528`, and no NaN/Inf.

- [ ] **Step 2: Write failing decoder tests**

Construct zero tensors plus one synthetic anchor/cell logit. Assert sigmoid decoding, source-coordinate restoration, category 14 fallback, class-local NMS at IoU 0.45, cross-class retention, and stable score/category/left/top ordering.

- [ ] **Step 3: Run RED**

```powershell
& 'C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat' test --no-daemon
```

Expected: compile/test failure because the two modules do not exist.

- [ ] **Step 4: Implement only the tested math**

Use these anchors in output order: stride 32 `105,101;133,135;174,150`, stride 16 `32,37;47,37;65,56`, stride 8 `19,19;25,27;35,26`. Compute `score=sigmoid(objectness)*sigmoid(classLogit)`, decode XY/WH with YOLOv3 equations, clip after restoring to source dimensions, and perform per-class NMS.

- [ ] **Step 5: Run GREEN and commit**

```powershell
& 'C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat' test --no-daemon
git add Mindspore_inhand_HarmonyOS/entry/src/main/ets/services/ai/HmsGesturePreprocessor.ets `
  Mindspore_inhand_HarmonyOS/entry/src/main/ets/services/ai/HmsGestureYoloDecoder.ets `
  Mindspore_inhand_HarmonyOS/entry/src/test/GestureModelUnit.test.ets `
  Mindspore_inhand_HarmonyOS/entry/src/test/List.test.ets
git commit -m "feat: decode HMS gesture YOLO outputs"
```

### Task 5: Implement the Production Gesture Detector and Factory Wiring

**Files:**
- Create: `Mindspore_inhand_HarmonyOS/entry/src/main/ets/services/ai/HmsGestureModelDetector.ets`
- Modify: `Mindspore_inhand_HarmonyOS/entry/src/main/ets/services/ai/GestureService.ets`
- Modify: `Mindspore_inhand_HarmonyOS/entry/src/main/ets/services/ai/ImageClassificationRuntimeFactory.ets`
- Modify: `Mindspore_inhand_HarmonyOS/entry/src/main/ets/services/ai/AiService.ets`
- Modify: `Mindspore_inhand_HarmonyOS/entry/src/main/ets/services/ai/RuntimeAiServiceSession.ets`
- Modify: `Mindspore_inhand_HarmonyOS/entry/src/test/GestureModelUnit.test.ets`
- Modify: `Mindspore_inhand_HarmonyOS/entry/src/test/LocalUnit.test.ets`

**Interfaces:**
- Implements: `AndroidGestureModelDetector.detectAndroidGestures(imageUri): Promise<AndroidGestureModelResult>`.
- Produces: a cached `AndroidGestureModelRunner` as the default `detectGesture` runtime.

- [ ] **Step 1: Write failing adapter tests with a fake native session**

Assert EXIF-aware pixel decode, preprocessing invocation, still threshold 0.6, source dimensions, native tensor-name validation, error propagation as `ok:false`, single model load, serialized inference, and idempotent `stop()`/session disposal.

- [ ] **Step 2: Write the failing factory test**

Change the current assertion that production gesture is unavailable. Assert `createRuntimeAiServiceForWorkflow(detectGesture)` invokes an injected fake HMS detector and returns `GESTURE_DETECTION_DONE`, without reading ImageNet labels.

- [ ] **Step 3: Run RED**

Run Hypium; expected failure is missing `HmsGestureModelDetector` and old factory behavior.

- [ ] **Step 4: Implement the adapter and replace the fallback**

Decode with `createPixelMapWithExifOrientation`, read RGBA, build the input tensor, call native `predict`, validate all three outputs, decode with 0.6, and return `AndroidGestureModelResult`. Extend runtime options with an injectable `androidGestureModelDetector`; default to the native implementation. Remove the production `ImageClassificationGestureRunner` path while retaining its class for explicit legacy tests only. Add idempotent `stop()` from detector→runner→service→`DefaultAiService`, and make `RuntimeAiServiceSession.invalidate()` call it before dropping the cached service.

- [ ] **Step 5: Run GREEN and commit**

```powershell
& 'C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat' test --no-daemon
git add Mindspore_inhand_HarmonyOS/entry/src/main/ets/services/ai `
  Mindspore_inhand_HarmonyOS/entry/src/test/GestureModelUnit.test.ets `
  Mindspore_inhand_HarmonyOS/entry/src/test/LocalUnit.test.ets
git commit -m "feat: wire HMS gesture model runtime"
```

### Task 6: Verify Live Camera Behavior, Golden Parity, and Final Packaging

**Files:**
- Modify: `Mindspore_inhand_HarmonyOS/entry/src/main/ets/pages/FeatureRuntimePage.ets`
- Create: `Mindspore_inhand_HarmonyOS/entry/src/ohosTest/ets/test/GestureNative.test.ets`
- Create: `Mindspore_inhand_HarmonyOS/entry/src/ohosTest/resources/rawfile/gesture/`
- Modify: `docs/harmonyos-platform-differences.md` only after preserving the existing user delta

**Interfaces:**
- Consumes: production `GestureRunner` and existing live generation/mutual-exclusion loop.
- Produces: verified still/live behavior and recorded Android/Harmony golden comparison.

- [ ] **Step 1: Add device smoke and golden comparison tests**

Load the real model, run a fixed raw image, assert output shapes, finite tensors, and at least one deterministic decoded result. Store Android baseline JSON with category, score, and rectangle for each golden asset.

- [ ] **Step 2: Verify live-specific contracts**

Assert live calls threshold 0.1, remains one-frame-at-a-time, drops busy frames, uses the latest generation, clears overlay on empty results, defaults to rear camera, and hides switch UI on single-camera devices. Update `gestureBoxStyle()` so front-camera live preview mirrors `left` as `100 - left - width`; still-image boxes remain unchanged.

- [ ] **Step 3: Run all guards, tests, and build**

```powershell
& .\Mindspore_inhand_HarmonyOS\scripts\verify-hms-gesture-model.ps1
Push-Location .\Mindspore_inhand_HarmonyOS
& 'C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat' test --no-daemon
& .\scripts\build-hap.ps1
Pop-Location
git diff --check
```

Expected: `Failure: 0, Error: 0`, HAP build PASS, model guard PASS, no whitespace errors.

- [ ] **Step 4: Install and exercise target behavior**

On the available emulator verify app launch and still-page error handling. On arm64 device verify still gallery, still camera, live rear/front switch, no-hand clearing, and at least one class from every Android category. For non-borderline golden detections require exact count/category/order, score error ≤0.02, box IoU ≥0.90.

- [ ] **Step 5: Commit**

```powershell
git add Mindspore_inhand_HarmonyOS/entry/src/ohosTest `
  Mindspore_inhand_HarmonyOS/entry/src/main/ets/pages/FeatureRuntimePage.ets `
  docs/harmonyos-platform-differences.md
git commit -m "test: verify HMS gesture parity on HarmonyOS"
```
