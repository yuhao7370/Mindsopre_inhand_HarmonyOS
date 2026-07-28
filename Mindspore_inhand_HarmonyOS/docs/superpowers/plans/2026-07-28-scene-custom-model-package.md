# Scene Detection And Custom Model Package Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restore Scene Detection and Custom Model in the experience center, then let a user import a validated ZIP package, detect image or text input from the manifest plus real MindSpore Lite tensors, run one on-device forward pass, and show decoded output.

**Architecture:** Keep the existing routes, picker, `DefaultAiService`, and `FeatureRuntimePage`. Add one pure package-contract module for parsing, tensor checks, preprocessing, and output decoding, plus one HarmonyOS package service for ZIP extraction, hashing, MindSpore Lite loading, and atomic publication. The custom page reads the validated package descriptor and switches between image controls and a text field.

**Tech Stack:** ArkTS, HarmonyOS NEXT APIs (`@kit.CoreFileKit`, `@ohos.zlib`, `@kit.CryptoArchitectureKit`, `@kit.ImageKit`, `@kit.MindSporeLiteKit`), MindSpore Lite `.ms`, Hvigor LocalUnit/OHOS tests, HDC.

## Global Constraints

- ZIP package version is exactly `1`; root `manifest.json` and `model.ms` are required.
- ZIP size is at most 256 MiB; reported and extracted size are each at most 512 MiB.
- Package paths are root-only and reject `/`, `\`, `..`, drive letters, absolute paths, and symbolic links.
- Every manifest-declared asset is verified by lower-case SHA-256 before publication.
- `input.kind` is only `image` or `text`; the manifest and real model tensors must agree.
- Image tensors support `FLOAT32` or `UINT8`, `NHWC` or `NCHW`, `RGB` or `BGR`, and `fit` or `fill`.
- Text tensors support `INT32 [1, sequenceLength]`, input IDs, and an optional attention mask using the bundled TTOK tokenizer.
- `output.kind` is only `classification`, `text`, or `raw`; text logits are capped at 32 MiB.
- Inference is one forward pass only; no autoregressive token loop.
- A failed replacement keeps the previous valid package and the current user input.
- UI follows `AGENTS.md`: native title bar, 16vp page margins, single-column form, readable states, no third-party UI library.
- Each independently usable change receives its own commit.

---

### Task 1: Restore The Two Advanced Vision Entries

**Files:**
- Modify: `entry/src/test/LocalUnit.test.ets`
- Modify: `entry/src/main/ets/common/data/FeatureCatalog.ets`

**Interfaces:**
- Consumes: `experienceSections`, `visibleExperienceSections`.
- Produces: visible items with IDs `scene` and `custom` under `advanced-vision`.

- [ ] **Step 1: Write the failing visibility test**

Add a LocalUnit case which finds both IDs in `visibleExperienceSections` and asserts:

```ts
expect(scene?.visibleByDefault).assertTrue();
expect(custom?.visibleByDefault).assertTrue();
expect(visibleAdvanced?.items.some(item => item.id === 'scene')).assertTrue();
expect(visibleAdvanced?.items.some(item => item.id === 'custom')).assertTrue();
```

- [ ] **Step 2: Run LocalUnit and verify RED**

Run:

```powershell
$env:DEVECO_SDK_HOME='F:\Program Files\Huawei\DevEco Studio\sdk'
& 'F:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat' --mode module -p module=entry@default -p product=default -p buildMode=test -p coverage=false -p testType=LocalUnit test
```

Expected: the new assertions fail because both values are `false`.

- [ ] **Step 3: Make both entries visible**

Change only the two catalog records:

```ts
{ id: 'scene', title: 'Scene Detection', titleKey: 'title_scene_detection', icon: 'scene',
  routeName: AppRoute.SCENE_STILL.name, visibleByDefault: true }
{ id: 'custom', title: 'Custom Model', titleKey: 'title_custom_model', icon: 'model',
  routeName: AppRoute.CUSTOM_MODEL.name, visibleByDefault: true }
```

- [ ] **Step 4: Run LocalUnit and verify GREEN**

Run the Step 2 command. Expected: exit code `0`.

- [ ] **Step 5: Commit**

```powershell
git add entry/src/test/LocalUnit.test.ets entry/src/main/ets/common/data/FeatureCatalog.ets
git commit -m "feat(ui): show scene and custom model entries"
```

---

### Task 2: Parse And Validate Package Contracts

**Files:**
- Create: `entry/src/main/ets/services/ai/CustomModelPackage.ets`
- Create: `entry/src/test/CustomModelPackage.test.ets`
- Modify: `entry/src/test/List.test.ets`

**Interfaces:**
- Produces:

```ts
export type CustomModelInputKind = 'image' | 'text';
export type CustomModelOutputKind = 'classification' | 'text' | 'raw';
export interface CustomModelTensorContract {
  readonly name: string;
  readonly dtype: string;
  readonly shape: Array<number>;
  readonly format?: string;
}
export interface CustomModelTensorMetadata {
  readonly name: string;
  readonly dtype: string;
  readonly shape: Array<number>;
  readonly format: string;
  readonly elementNum: number;
  readonly dataSize: number;
}
export interface CustomModelAssetRef {
  readonly file: string;
  readonly sha256: string;
}
export interface CustomModelImageInput {
  readonly width: number;
  readonly height: number;
  readonly layout: 'NHWC' | 'NCHW';
  readonly color: 'RGB' | 'BGR';
  readonly resize: 'fit' | 'fill';
  readonly mean: Array<number>;
  readonly std: Array<number>;
}
export interface CustomModelTextInput {
  readonly tokenizer: CustomModelAssetRef;
  readonly maxTokens: number;
  readonly padId: number;
  readonly unkId: number;
  readonly bosId: number;
  readonly eosId: number;
  readonly inputIdsTensor: string;
  readonly attentionMaskTensor?: string;
}
export interface CustomModelPackageManifest {
  readonly version: 1;
  readonly name: string;
  readonly model: CustomModelAssetRef;
  readonly input: {
    readonly kind: CustomModelInputKind;
    readonly tensors: Array<CustomModelTensorContract>;
    readonly image?: CustomModelImageInput;
    readonly text?: CustomModelTextInput;
  };
  readonly output: {
    readonly kind: CustomModelOutputKind;
    readonly tensor: CustomModelTensorContract;
    readonly labels?: CustomModelAssetRef;
    readonly tokenizer?: CustomModelAssetRef;
    readonly topK?: number;
  };
}
export function parseCustomModelPackageManifest(text: string): CustomModelPackageManifest;
export function validateCustomModelTensorContract(
  manifest: CustomModelPackageManifest,
  inputs: Array<CustomModelTensorMetadata>,
  outputs: Array<CustomModelTensorMetadata>
): void;
export function customModelDeclaredFiles(manifest: CustomModelPackageManifest): Array<string>;
```

- [ ] **Step 1: Write failing parser tests**

Use literal JSON fixtures and assert that a valid image package and a valid text package parse, while these cases throw: version `2`, unknown kind, `../model.ms`, `nested/model.ms`, uppercase/short digest, zero dimension, missing tokenizer for text, invalid `std`, and output tensor mismatch.

Representative expected behavior:

```ts
expect(parseCustomModelPackageManifest(validImageManifest).input.kind).assertEqual('image');
expect(() => parseCustomModelPackageManifest(parentPathManifest)).assertThrow();
expect(() => validateCustomModelTensorContract(textManifest, imageInputs, textOutputs)).assertThrow();
```

- [ ] **Step 2: Run LocalUnit and verify RED**

Run the Task 1 LocalUnit command. Expected: compilation fails because `CustomModelPackage.ets` exports do not exist.

- [ ] **Step 3: Implement the minimum strict parser**

In `CustomModelPackage.ets`, use `JSON.parse`, explicit `typeof`/array checks, and small helpers:

```ts
const SHA256 = /^[0-9a-f]{64}$/;
const MAX_ZIP_BYTES = 256 * 1024 * 1024;
const MAX_EXTRACTED_BYTES = 512 * 1024 * 1024;
const MAX_TEXT_LOGITS_BYTES = 32 * 1024 * 1024;

function assertRootFileName(value: string): void {
  if (value.length === 0 || value.includes('/') || value.includes('\\') ||
    value.includes('..') || /^[A-Za-z]:/.test(value)) {
    throw new Error('Package assets must be root files.');
  }
}
```

Parse only the version-1 fields from the confirmed spec. Match tensor names, dtype, shape, format, element count, and data size exactly; reject unsupported ranks or dtypes instead of inferring.

- [ ] **Step 4: Run LocalUnit and verify GREEN**

Run the Task 1 LocalUnit command. Expected: exit code `0`.

- [ ] **Step 5: Commit**

```powershell
git add entry/src/main/ets/services/ai/CustomModelPackage.ets entry/src/test/CustomModelPackage.test.ets entry/src/test/List.test.ets
git commit -m "feat(custom-model): validate package contracts"
```

---

### Task 3: Import ZIPs Safely And Preserve The Last Valid Package

**Files:**
- Create: `entry/src/main/ets/services/ai/CustomModelPackageService.ets`
- Modify: `entry/src/main/ets/services/picker/PickerService.ets`
- Modify: `entry/src/main/ets/services/picker/ModelFileCacheService.ets`
- Modify: `entry/src/test/CustomModelPackage.test.ets`

**Interfaces:**
- Consumes: Task 2 manifest parser and tensor validator.
- Produces:

```ts
export interface CustomModelPackageDescriptor {
  readonly rootDir: string;
  readonly modelPath: string;
  readonly manifest: CustomModelPackageManifest;
  readonly inputKind: CustomModelInputKind;
  readonly inputSummary: string;
  readonly outputSummary: string;
}
export interface CustomModelPackageImportResult {
  readonly ok: boolean;
  readonly descriptor?: CustomModelPackageDescriptor;
  readonly messageKey: AppStringKey;
}
export class CustomModelPackageService {
  importPackage(sourceUri: string, cacheDir: string): Promise<CustomModelPackageImportResult>;
  loadCurrentPackage(cacheDir: string): Promise<CustomModelPackageDescriptor | undefined>;
}
```

- [ ] **Step 1: Write failing publication-state tests**

Use a fake filesystem/backend with a valid package `A`, then an invalid package `B`. Assert:

```ts
expect((await service.importPackage(validZip, cacheDir)).ok).assertTrue();
expect((await service.importPackage(badHashZip, cacheDir)).ok).assertFalse();
expect((await service.loadCurrentPackage(cacheDir))?.manifest.name).assertEqual('A');
```

Also assert ZIP >256 MiB, original size >512 MiB, missing files, nested entries, extra files, symlinks, and bad SHA-256 are rejected.

- [ ] **Step 2: Run LocalUnit and verify RED**

Run the Task 1 LocalUnit command. Expected: compilation fails because `CustomModelPackageService` does not exist.

- [ ] **Step 3: Implement native import and atomic publication**

Use platform APIs only:

1. `fileIo.stat(sourceUri)` for compressed size.
2. `zlib.getOriginalSize(sourceUri)` before extraction.
3. Copy to a request-specific directory under `cacheDir/custom-model-package/`.
4. `zlib.decompressFile(zipPath, tempDir, { ignoreError: false })`.
5. Enumerate extracted entries, reject directories beyond the root and symbolic links, and sum actual bytes.
6. Read `manifest.json`, verify the exact allowlist and SHA-256 with `cryptoFramework.createMd('SHA256')`.
7. Load `model.ms` with `mindSporeLite.loadModelFromFile`, map real input/output tensors, and call Task 2 validation.
8. Rename the validated temporary directory to `current-next`, then replace the `current` pointer/descriptor only after every check succeeds.
9. Delete the request directory on failure and leave `current` untouched.

Update the custom-model picker suffix to `.zip`; keep `.ms`/`.mnn` behavior unchanged for other routes. Extend `ModelFileCacheResult` with optional `customModelPackage` metadata rather than creating a second page-level cache path.

- [ ] **Step 4: Run LocalUnit and verify GREEN**

Run the Task 1 LocalUnit command. Expected: exit code `0`.

- [ ] **Step 5: Commit**

```powershell
git add entry/src/main/ets/services/ai/CustomModelPackageService.ets entry/src/main/ets/services/picker/PickerService.ets entry/src/main/ets/services/picker/ModelFileCacheService.ets entry/src/test/CustomModelPackage.test.ets
git commit -m "feat(custom-model): import validated model packages"
```

---

### Task 4: Preprocess Inputs, Run The Real Model, And Decode Outputs

**Files:**
- Modify: `entry/src/main/ets/services/ai/CustomModelPackage.ets`
- Modify: `entry/src/main/ets/services/ai/CustomModelPackageService.ets`
- Modify: `entry/src/main/ets/services/ai/HarmonyCustomModelInputPreprocessor.ets`
- Modify: `entry/src/main/ets/services/ai/CustomModelService.ets`
- Modify: `entry/src/main/ets/services/ai/AiService.ets`
- Modify: `entry/src/test/CustomModelPackage.test.ets`
- Modify: `entry/src/test/LocalUnit.test.ets`

**Interfaces:**
- Produces:

```ts
export interface CustomModelRunInput {
  readonly imageUri?: string;
  readonly text?: string;
}
export interface CustomModelRunResult {
  readonly ok: boolean;
  readonly executionMs: number;
  readonly output: Array<number>;
  readonly displayText: string;
  readonly outputKind: CustomModelOutputKind;
}
export function imageTensorFromRgba(
  rgba: Uint8Array,
  width: number,
  height: number,
  manifest: CustomModelPackageManifest
): ArrayBuffer;
export function encodeCustomModelText(
  text: string,
  tokenizerTable: string,
  manifest: CustomModelPackageManifest
): Map<string, ArrayBuffer>;
export function decodeCustomModelOutput(
  manifest: CustomModelPackageManifest,
  outputs: Array<CustomModelTensorValue>,
  labels: Array<string>,
  tokenizerTable: string
): string;
```

- [ ] **Step 1: Write failing pure transformation tests**

Use hand-derived fixtures:

- A 2×1 RGBA image must produce exact RGB/BGR values for NHWC and NCHW.
- `FLOAT32` applies `(channel / 255 - mean) / std`; `UINT8` preserves bytes.
- `fit` pads and `fill` crops without changing aspect ratio.
- TTOK text produces fixed `INT32 [1,N]` input IDs and optional mask.
- Classification returns literal Top-K labels/scores.
- Text token IDs and logits decode until EOS and skip PAD/BOS.
- Raw output includes name/dtype/shape/count and rejects NaN/Infinity/empty values.
- Float text logits above 32 MiB are rejected before reading.

- [ ] **Step 2: Run LocalUnit and verify RED**

Run the Task 1 LocalUnit command. Expected: the new transform/decode functions are missing.

- [ ] **Step 3: Implement manifest-driven preprocessing and single-pass inference**

Reuse the existing EXIF-corrected `PixelMap` path and MindSpore Lite serialization queue. Replace the fixed 224×224 assumptions only for ZIP packages:

```ts
const model = await mindSporeLite.loadModelFromFile(descriptor.modelPath, mindSporeLiteCpuContext());
const inputs = model.getInputs();
// Set each named image or text buffer.
const outputs = await model.predict(inputs);
// Decode exactly once according to manifest.output.kind.
```

For text, reuse the project TTOK2 parsing/encoding rules by extracting only the shared table parser needed by both translation and custom-model code; do not infer a tokenizer from model names. `DefaultAiService.runCustomModel` must select `inputs.imageUri` or `inputs.text` from `descriptor.inputKind`, and use `displayText` instead of the old “first 10 values” summary.

- [ ] **Step 4: Run LocalUnit and verify GREEN**

Run the Task 1 LocalUnit command. Expected: exit code `0`.

- [ ] **Step 5: Commit**

```powershell
git add entry/src/main/ets/services/ai/CustomModelPackage.ets entry/src/main/ets/services/ai/CustomModelPackageService.ets entry/src/main/ets/services/ai/HarmonyCustomModelInputPreprocessor.ets entry/src/main/ets/services/ai/CustomModelService.ets entry/src/main/ets/services/ai/AiService.ets entry/src/test/CustomModelPackage.test.ets entry/src/test/LocalUnit.test.ets
git commit -m "feat(custom-model): run image and text model packages"
```

---

### Task 5: Switch The Page To The Detected Input Type

**Files:**
- Modify: `entry/src/main/ets/features/runtime/FeatureWorkflowCatalog.ets`
- Modify: `entry/src/main/ets/pages/FeatureRuntimePage.ets`
- Modify: `entry/src/main/ets/common/i18n/AppStrings.ets`
- Modify: `entry/src/main/resources/base/element/string.json`
- Modify: `entry/src/main/resources/zh_CN/element/string.json`
- Modify: `entry/src/main/resources/en_US/element/string.json`
- Modify: `entry/src/test/LocalUnit.test.ets`
- Modify: `scripts/check-custom-model-layout-parity.ps1`
- Modify: `scripts/test-custom-model-layout-guard.ps1`
- Modify: `scripts/check-runtime-hidden-model-ui.ps1`
- Modify: `scripts/test-runtime-hidden-model-ui-guard.ps1`

**Interfaces:**
- Consumes: `ModelFileCacheResult.customModelPackage`, Task 4 `CustomModelRunInput`.
- Produces: page state `customModelInputKind`, `customModelName`, `customModelInputSummary`, `customModelOutputSummary`, plus:

```ts
export function customModelVisibleInputs(kind: CustomModelInputKind): Array<FeatureInputKind>;
export function customModelCanExecute(
  kind: CustomModelInputKind,
  modelPath: string,
  imageUri: string,
  text: string
): boolean;
```

- [ ] **Step 1: Write failing state and layout tests**

Add tests for page helper behavior:

```ts
expect(customModelVisibleInputs('image')).assertDeepEquals(['photo', 'camera']);
expect(customModelVisibleInputs('text')).assertDeepEquals(['text']);
expect(customModelCanExecute('image', modelPath, imageUri, '')).assertTrue();
expect(customModelCanExecute('text', modelPath, '', 'hello')).assertTrue();
expect(customModelCanExecute('text', modelPath, '', '   ')).assertFalse();
```

Add state tests proving successful package replacement clears old input/result, failed replacement preserves them, and inference failure preserves the current input.

- [ ] **Step 2: Run LocalUnit and UI guards to verify RED**

Run the Task 1 LocalUnit command and:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/test-custom-model-layout-guard.ps1
powershell -ExecutionPolicy Bypass -File scripts/test-runtime-hidden-model-ui-guard.ps1
```

Expected: new assertions fail against the fixed image-only/hidden-model behavior.

- [ ] **Step 3: Implement the native dynamic form**

Keep the existing single `Scroll` and title bar. Render in this order:

1. “选择模型包” ZIP button.
2. A plain information group with model name, input type/tensors, and output type.
3. Image: existing album and camera buttons plus preview; Text: existing multiline `TextArea`.
4. One primary execute button, disabled until the detected input is ready.
5. Loading/error/retry and decoded output text.

On a valid new package, set package metadata and clear `imageInputUri`, `userText`, and result fields. On an invalid package, show the specific error without changing package or input state. Remove guards which assert Custom Model remains hidden, but retain all guards for unrelated hidden features.

- [ ] **Step 4: Run LocalUnit, i18n, and UI guards to verify GREEN**

Run:

```powershell
$env:DEVECO_SDK_HOME='F:\Program Files\Huawei\DevEco Studio\sdk'
& 'F:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat' --mode module -p module=entry@default -p product=default -p buildMode=test -p coverage=false -p testType=LocalUnit test
powershell -ExecutionPolicy Bypass -File scripts/check-i18n-strings.ps1
powershell -ExecutionPolicy Bypass -File scripts/test-custom-model-layout-guard.ps1
powershell -ExecutionPolicy Bypass -File scripts/test-runtime-hidden-model-ui-guard.ps1
```

Expected: every command exits `0`.

- [ ] **Step 5: Commit**

```powershell
git add entry/src/main/ets/features/runtime/FeatureWorkflowCatalog.ets entry/src/main/ets/pages/FeatureRuntimePage.ets entry/src/main/ets/common/i18n/AppStrings.ets entry/src/main/resources/base/element/string.json entry/src/main/resources/zh_CN/element/string.json entry/src/main/resources/en_US/element/string.json entry/src/test/LocalUnit.test.ets scripts/check-custom-model-layout-parity.ps1 scripts/test-custom-model-layout-guard.ps1 scripts/check-runtime-hidden-model-ui.ps1 scripts/test-runtime-hidden-model-ui-guard.ps1
git commit -m "feat(custom-model): adapt page to package input type"
```

---

### Task 6: Add Real Image And Text Packages, Build, And Verify On The Emulator

**Files:**
- Modify: `scripts/generate-custom-model-fixtures.py`
- Modify: `scripts/convert-custom-model-fixtures.sh`
- Modify: `scripts/verify-custom-model-fixtures.ps1`
- Create: `model_sources/custom_model/package_image/manifest.json`
- Create: `model_sources/custom_model/package_image/labels.txt`
- Create: `model_sources/custom_model/package_text/manifest.json`
- Create: `model_sources/custom_model/package_text/labels.txt`
- Create: `model_sources/custom_model/package_text/tokenizer.ttok`
- Create: `entry/src/main/resources/rawfile/model/custom_image_package.zip`
- Create: `entry/src/main/resources/rawfile/model/custom_text_package.zip`
- Modify: `entry/src/ohosTest/ets/test/CustomModelNative.test.ets`
- Modify: `entry/src/ohosTest/ets/test/List.test.ets`

**Interfaces:**
- Consumes: complete import and runtime path from Tasks 2–5.
- Produces: two deterministic fixtures used by native tests and manual package selection.

- [ ] **Step 1: Write failing native package tests**

The native test must import each rawfile ZIP through `CustomModelPackageService` and assert:

```ts
expect(imageDescriptor.inputKind).assertEqual('image');
expect(maxAbsoluteDifference(red.output, blue.output) > 0.9).assertTrue();
expect(textDescriptor.inputKind).assertEqual('text');
expect(firstText.displayText === secondText.displayText).assertFalse();
expect((await service.importPackage(corruptPackage, cacheDir)).ok).assertFalse();
expect((await service.loadCurrentPackage(cacheDir))?.manifest.name).assertEqual(textDescriptor.manifest.name);
```

- [ ] **Step 2: Run OHOS test build and verify RED**

Run:

```powershell
$env:DEVECO_SDK_HOME='F:\Program Files\Huawei\DevEco Studio\sdk'
& 'F:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat' --mode module -p module=entry@ohosTest -p product=default -p buildMode=test assembleHap
```

Expected: fixture rawfiles are missing.

- [ ] **Step 3: Generate and package deterministic fixtures**

Extend the existing TensorFlow fixture generator with:

- Image model: existing channel-mean model, classification labels `red`, `green`, `blue`.
- Text model: `INT32 [1,8]` input with deterministic two-class logits based on token IDs.

Convert with the existing pinned MindSpore Lite 2.6.0 Linux converter. Generate manifests after conversion, calculate lower-case SHA-256 for `model.ms`, `labels.txt`, and `tokenizer.ttok`, and create root-only ZIPs. Update the verification script with exact file hashes and run it.

- [ ] **Step 4: Run full automated verification**

Run:

```powershell
$env:DEVECO_SDK_HOME='F:\Program Files\Huawei\DevEco Studio\sdk'
& 'F:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat' --mode module -p module=entry@default -p product=default -p buildMode=test -p coverage=false -p testType=LocalUnit test
powershell -ExecutionPolicy Bypass -File scripts/verify-custom-model-fixtures.ps1
powershell -ExecutionPolicy Bypass -File scripts/build-hap.ps1
```

Expected: every command exits `0`; output HAP is `entry/build/default/outputs/default/entry-default-unsigned.hap`.

- [ ] **Step 5: Install and verify through native HDC interaction**

Use:

```powershell
$hdc='F:\Program Files\Huawei\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe'
& $hdc tconn 127.0.0.1:5555
& $hdc install -r 'entry\build\default\outputs\default\entry-default-unsigned.hap'
& $hdc shell aa force-stop com.mindspore.hmsapp
& $hdc shell aa start -a EntryAbility -b com.mindspore.hmsapp
```

Then use HDC `uitest dumpLayout`, `uitest uiInput click`, and `snapshot_display` rather than Computer Use. Capture evidence that:

- Advanced Vision shows Scene Detection and Custom Model.
- Scene Detection opens and its album route is enabled.
- Image package selection exposes photo/camera controls and produces input-dependent labels.
- Text package selection exposes a text field and produces input-dependent labels.
- Long output scrolls without being obscured by the floating bottom navigation.

- [ ] **Step 6: Commit**

```powershell
git add scripts/generate-custom-model-fixtures.py scripts/convert-custom-model-fixtures.sh scripts/verify-custom-model-fixtures.ps1 model_sources/custom_model/package_image model_sources/custom_model/package_text entry/src/main/resources/rawfile/model/custom_image_package.zip entry/src/main/resources/rawfile/model/custom_text_package.zip entry/src/ohosTest/ets/test/CustomModelNative.test.ets entry/src/ohosTest/ets/test/List.test.ets
git commit -m "test(custom-model): add image and text package fixtures"
```

---

## Final Verification

- [ ] Re-read `docs/superpowers/specs/2026-07-28-scene-custom-model-package-design.md` and check every requirement against Tasks 1–6.
- [ ] Run fresh LocalUnit, fixture verification, HAP build, install, native-touch flows, and screenshots.
- [ ] Inspect `git status --short` and confirm only intended project files are committed.
- [ ] Merge the isolated feature branch into `master` without staging the user's pre-existing `.gitignore` or untracked artifacts.
