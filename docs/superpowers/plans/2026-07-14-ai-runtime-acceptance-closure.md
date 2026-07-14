# AI Runtime Acceptance Closure Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the remaining placeholder device test with meaningful HMS gesture and local translation runtime acceptance coverage, then verify the assembled main/test HAP pair contains the correct code, models, and native libraries.

**Architecture:** Keep production inference code unchanged unless a test exposes a real lifecycle defect. Add one dependency-free PowerShell HAP structure guard, one repository-owned hand-image fixture that feeds the existing gesture preprocessor and MNN test, and one `ohosTest` that initializes the packaged translation archive and both translation directions through the production runner. The test feature HAP stays small and is verified as paired with the main HAP instead of duplicating main-module model assets.

**Tech Stack:** ArkTS, Hypium, HarmonyOS API 24, MindSpore Lite, MNN NAPI, PowerShell 5+, Windows `tar`, Python 3.9 `unittest`, Hvigor/DevEco Studio.

## Global Constraints

- Scope remains local Chinese to English and English to Chinese translation only.
- No server, network fallback, new model, training continuation, or new package dependency.
- The current translation package remains `local-learning-only-not-production-approved`; this work must not change `productionPromotionAllowed` to `true`.
- Real-device execution is deferred. `ohosTest` compilation and packaging are evidence; they are not reported as executed tests.
- The main HAP owns gesture/translation models and native libraries. The `entry_test` HAP must not duplicate them.
- The hand image is generated specifically for this repository, used only as a preprocessing/runtime fixture, and is not a gesture-class gold label.
- Preserve unrelated user changes and the existing `codex/gesture-translation-parity` worktree.

---

## File Structure

- `Mindspore_inhand_HarmonyOS/scripts/verify-ai-runtime-haps.ps1`: inspect exact main-HAP AI assets and validate the test-HAP module pairing.
- `Mindspore_inhand_HarmonyOS/scripts/test-verify-ai-runtime-haps.ps1`: dependency-free temporary-HAP contract tests for the guard.
- `Mindspore_inhand_HarmonyOS/scripts/build-ai-runtime-acceptance.ps1`: assemble both HAPs and invoke the shared guard.
- `Mindspore_inhand_HarmonyOS/scripts/build-hap.ps1`: keep existing preflight checks and add post-assembly main-HAP inspection.
- `Mindspore_inhand_HarmonyOS/entry/src/ohosTest/resources/rawfile/fixtures/gesture/open_palm.png`: repository-owned gesture preprocessing fixture.
- `Mindspore_inhand_HarmonyOS/entry/src/test/GestureImageFixture.ets`: generated 32 by 32 RGBA representation used by host Hypium tests.
- `tools/gesture/generate-hms-gesture-fixture.ps1`: deterministically derive the ArkTS RGBA fixture from the PNG without adding a Python imaging dependency.
- `docs/model-provenance/hms-gesture-test-fixture.md`: generation prompt, dimensions, SHA-256, and non-gold-label limitation.
- `Mindspore_inhand_HarmonyOS/entry/src/ohosTest/ets/test/GestureNative.test.ets`: decode the PNG, preprocess it, and feed it to the real MNN session.
- `Mindspore_inhand_HarmonyOS/entry/src/ohosTest/ets/test/TranslationNative.test.ets`: initialize the packaged translation archive and run both directions.
- `Mindspore_inhand_HarmonyOS/entry/src/ohosTest/ets/test/List.test.ets`: register the two real native suites only.
- `tools/translation/test_project_translation_guard.py`: statically reject reintroduction of the template test or loss of translation-suite registration.
- `docs/harmonyos-platform-differences.md`: replace the now-obsolete “gesture runner unavailable” and dictionary-only translation status with the current local-model state.

### Task 1: Guard The Assembled Main/Test HAP Structure

**Files:**
- Create: `Mindspore_inhand_HarmonyOS/scripts/verify-ai-runtime-haps.ps1`
- Create: `Mindspore_inhand_HarmonyOS/scripts/test-verify-ai-runtime-haps.ps1`
- Modify: `Mindspore_inhand_HarmonyOS/scripts/build-hap.ps1`

**Interfaces:**
- Produces: `verify-ai-runtime-haps.ps1 -MainHapPath .\entry\build\default\outputs\default\entry-default-unsigned.hap [-OhosTestHapPath .\entry\build\default\outputs\ohosTest\entry-ohosTest-unsigned.hap]`.
- Consumes: Windows `tar`, the assembled HAP paths, and JSON stored at `module.json` / `pack.info`.
- Required main entries: exact model metadata, model archives, and `arm64-v8a` AI libraries listed below.
- Required test identity: module `entry_test`, main element `TestAbility`, bundle match, paired `entry` summary, compiled `ets/modules.abc`, and the gesture fixture rawfile.

- [ ] **Step 1: Write the failing PowerShell guard contract test**

Create `test-verify-ai-runtime-haps.ps1`. It creates temporary ZIP-format HAP fixtures with `Compress-Archive` and invokes the not-yet-created guard. The valid main fixture contains these exact entries:

```powershell
$mainEntries = @(
  'module.json',
  'resources/rawfile/models/gesture/GestureDetector.ms',
  'resources/rawfile/models/gesture/manifest.json',
  'resources/rawfile/models/gesture/NOTICE.md',
  'resources/rawfile/models/translation/translation-models.tar.xz',
  'resources/rawfile/models/translation/tokenizer.model',
  'resources/rawfile/models/translation/tokenizer_runtime.json',
  'resources/rawfile/models/translation/vocab.json',
  'resources/rawfile/models/translation/manifest.json',
  'resources/rawfile/models/translation/SHA256SUMS',
  'resources/rawfile/models/translation/LICENSES.md',
  'libs/arm64-v8a/libgesture_mnn.so',
  'libs/arm64-v8a/libMNN.so',
  'libs/arm64-v8a/libtranslation_archive.so'
)
```

The valid test fixture contains `module.json`, `pack.info`, `ets/modules.abc`, and `resources/rawfile/fixtures/gesture/open_palm.png`. Use these canonical JSON payloads:

```powershell
$testModule = @{
  app = @{ bundleName = 'com.yuhaofeng.mih' }
  module = @{ name = 'entry_test'; mainElement = 'TestAbility'; type = 'feature' }
} | ConvertTo-Json -Depth 8 -Compress
$testPack = @{
  summary = @{
    app = @{ bundleName = 'com.yuhaofeng.mih' }
    modules = @(
      @{ distro = @{ moduleName = 'entry_test'; moduleType = 'feature' } },
      @{ distro = @{ moduleName = 'entry'; moduleType = 'entry' } }
    )
  }
} | ConvertTo-Json -Depth 8 -Compress
```

Require the valid pair to succeed. Require rejection after removing one main entry, after changing `entry_test` to another name, after removing the paired `entry` module, and after adding a copied model path under `resources/rawfile/models/` to the test HAP. Each rejection helper must fail if the guard unexpectedly returns success.

- [ ] **Step 2: Run the guard test and verify RED**

Run from `Mindspore_inhand_HarmonyOS`:

```powershell
& .\scripts\test-verify-ai-runtime-haps.ps1
```

Expected: FAIL because `verify-ai-runtime-haps.ps1` does not exist.

- [ ] **Step 3: Implement the minimal HAP guard**

Create `verify-ai-runtime-haps.ps1` with this public contract and fail-closed archive helpers:

```powershell
param(
  [Parameter(Mandatory = $true)][string]$MainHapPath,
  [string]$OhosTestHapPath = ''
)
$ErrorActionPreference = 'Stop'

function Get-HapEntries([string]$Path) {
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    throw "HAP does not exist: $Path"
  }
  $entries = @(& tar -tf $Path)
  if ($LASTEXITCODE -ne 0) { throw "Unable to list HAP: $Path" }
  return $entries
}

function Read-HapJson([string]$Path, [string]$Entry) {
  $text = (& tar -xOf $Path $Entry | Out-String)
  if ($LASTEXITCODE -ne 0) { throw "Unable to read $Entry from $Path" }
  return $text | ConvertFrom-Json
}

function Assert-ExactEntries([string[]]$Entries, [string[]]$Required, [string]$Label) {
  $missing = @($Required | Where-Object { $Entries -notcontains $_ })
  if ($missing.Count -ne 0) { throw "$Label is missing: $($missing -join ', ')" }
}
```

Use the exact `$mainEntries` array from Step 1. When `OhosTestHapPath` is supplied, verify its four required entries, reject any entry beginning with `resources/rawfile/models/`, reject the three AI library names, parse `module.json` and `pack.info`, and require:

```powershell
$module.app.bundleName -eq $pack.summary.app.bundleName
$module.module.name -eq 'entry_test'
$module.module.mainElement -eq 'TestAbility'
@($pack.summary.modules | Where-Object { $_.distro.moduleName -eq 'entry_test' }).Count -eq 1
@($pack.summary.modules | Where-Object { $_.distro.moduleName -eq 'entry' }).Count -eq 1
```

Print one success line with both verified paths.

- [ ] **Step 4: Attach main-HAP inspection to the existing build entry point**

After successful `assembleHap` in `build-hap.ps1`, resolve the output and call the guard:

```powershell
$mainHap = Join-Path $PSScriptRoot '..\entry\build\default\outputs\default\entry-default-unsigned.hap'
& (Join-Path $PSScriptRoot 'verify-ai-runtime-haps.ps1') -MainHapPath $mainHap
```

Do not change the existing model/source preflight order.

- [ ] **Step 5: Verify GREEN on fixtures and the real main HAP**

```powershell
& .\scripts\test-verify-ai-runtime-haps.ps1
& .\scripts\build-hap.ps1
```

Expected: the negative fixture cases are rejected, the fixture test exits 0, translation package verification succeeds, real HAP inspection succeeds, and Hvigor reports `BUILD SUCCESSFUL`.

- [ ] **Step 6: Commit Task 1**

```powershell
git add Mindspore_inhand_HarmonyOS/scripts/verify-ai-runtime-haps.ps1 `
  Mindspore_inhand_HarmonyOS/scripts/test-verify-ai-runtime-haps.ps1 `
  Mindspore_inhand_HarmonyOS/scripts/build-hap.ps1
git commit -m "test: verify AI runtime HAP structure"
```

### Task 2: Add A Real Hand-Image Preprocessing Fixture

**Files:**
- Create: `Mindspore_inhand_HarmonyOS/entry/src/ohosTest/resources/rawfile/fixtures/gesture/open_palm.png`
- Create: `Mindspore_inhand_HarmonyOS/entry/src/test/GestureImageFixture.ets`
- Create: `tools/gesture/generate-hms-gesture-fixture.ps1`
- Create: `docs/model-provenance/hms-gesture-test-fixture.md`
- Modify: `Mindspore_inhand_HarmonyOS/entry/src/test/GestureModelUnit.test.ets`
- Modify: `Mindspore_inhand_HarmonyOS/entry/src/ohosTest/ets/test/GestureNative.test.ets`

**Interfaces:**
- Produces: `openPalmGestureFixtureRgba(): Uint8Array`, width `32`, height `32`, and rawfile path `fixtures/gesture/open_palm.png`.
- Consumes: production `gestureInputFromRgba()` and the existing real `HmsGestureNativeSession`.
- Fixture status: preprocessing/runtime input only; no expected gesture class or box.

- [ ] **Step 1: Add the failing host fixture test**

Import the not-yet-generated fixture in `GestureModelUnit.test.ets` and add:

```typescript
it('preprocessesGeneratedOpenPalmFixtureDeterministically', 0, () => {
  const rgba = openPalmGestureFixtureRgba();
  const first = gestureInputFromRgba(rgba, openPalmGestureFixtureWidth, openPalmGestureFixtureHeight);
  const second = gestureInputFromRgba(rgba, openPalmGestureFixtureWidth, openPalmGestureFixtureHeight);
  expect(first.length).assertEqual(3 * 224 * 224);
  expect(second.length).assertEqual(first.length);
  for (let index = 0; index < first.length; index++) {
    expect(Number.isFinite(first[index])).assertTrue();
    expect(first[index] >= 0 && first[index] <= 1).assertTrue();
    expect(second[index]).assertEqual(first[index]);
  }
});
```

- [ ] **Step 2: Run the focused host test and verify RED**

```powershell
$env:DEVECO_SDK_HOME='C:\Program Files\Huawei\DevEco Studio\sdk'
$env:PATH='C:\Program Files\Huawei\DevEco Studio\jbr\bin;'+$env:PATH
& cmd.exe /d /c '"C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat" test --no-daemon 2>&1'
```

Expected: compile failure because `GestureImageFixture.ets` is absent.

- [ ] **Step 3: Generate and record the image fixture**

Use the image-generation skill with this exact prompt and save the result as `open_palm.png`:

> Square documentary test photograph, one adult human hand showing an open palm with five separated fingers, hand centered and fully inside frame, plain medium-gray background, even diffuse light, no text, no jewelry, no extra hands, no cropped fingers, natural skin texture, front-facing camera, high contrast between hand and background.

Create `generate-hms-gesture-fixture.ps1`. It loads the PNG through `System.Drawing.Bitmap`, draws it into a 32 by 32 ARGB bitmap, emits RGBA values in row-major order, and writes a UTF-8-no-BOM ArkTS file. Use this implementation core:

```powershell
param(
  [Parameter(Mandatory = $true)][string]$InputPath,
  [Parameter(Mandatory = $true)][string]$OutputPath
)
$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$inputFull = [IO.Path]::GetFullPath($InputPath)
$outputFull = [IO.Path]::GetFullPath($OutputPath)
if (-not $outputFull.StartsWith("$repoRoot\", [StringComparison]::OrdinalIgnoreCase)) {
  throw 'Fixture output must stay inside the repository.'
}
Add-Type -AssemblyName System.Drawing
$source = New-Object System.Drawing.Bitmap($inputFull)
$scaled = New-Object System.Drawing.Bitmap(32, 32, [Drawing.Imaging.PixelFormat]::Format32bppArgb)
try {
  if ($source.Width -le 0 -or $source.Height -le 0) { throw 'Fixture image dimensions are invalid.' }
  $graphics = [Drawing.Graphics]::FromImage($scaled)
  try {
    $graphics.CompositingMode = [Drawing.Drawing2D.CompositingMode]::SourceCopy
    $graphics.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
    $graphics.PixelOffsetMode = [Drawing.Drawing2D.PixelOffsetMode]::Half
    $graphics.DrawImage($source, 0, 0, 32, 32)
  } finally {
    $graphics.Dispose()
  }
  $values = [Collections.Generic.List[int]]::new()
  for ($y = 0; $y -lt 32; $y++) {
    for ($x = 0; $x -lt 32; $x++) {
      $pixel = $scaled.GetPixel($x, $y)
      $values.Add($pixel.R); $values.Add($pixel.G); $values.Add($pixel.B); $values.Add($pixel.A)
    }
  }
  if ($values.Count -ne 4096 -or @($values | Where-Object { $_ -lt 0 -or $_ -gt 255 }).Count -ne 0) {
    throw 'Generated RGBA fixture is invalid.'
  }
  $rows = [Collections.Generic.List[string]]::new()
  for ($offset = 0; $offset -lt $values.Count; $offset += 32) {
    $end = [Math]::Min($offset + 31, $values.Count - 1)
    $rows.Add('  ' + (($values[$offset..$end] | ForEach-Object { $_.ToString() }) -join ', ') + ',')
  }
  $content = @(
    'export const openPalmGestureFixtureWidth: number = 32;',
    'export const openPalmGestureFixtureHeight: number = 32;',
    'const openPalmGestureFixtureValues: Array<number> = [',
    ($rows -join "`n"),
    '];',
    'export function openPalmGestureFixtureRgba(): Uint8Array {',
    '  return new Uint8Array(openPalmGestureFixtureValues);',
    '}',
    ''
  ) -join "`n"
  [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($outputFull)) | Out-Null
  [IO.File]::WriteAllText($outputFull, $content, [Text.UTF8Encoding]::new($false))
} finally {
  $scaled.Dispose()
  $source.Dispose()
}
```

The script must check that input dimensions are positive, output contains exactly `32 * 32 * 4` bytes, every byte is within 0 through 255, and the destination stays inside the repository path supplied by the caller. Run:

```powershell
& .\tools\gesture\generate-hms-gesture-fixture.ps1 `
  -InputPath .\Mindspore_inhand_HarmonyOS\entry\src\ohosTest\resources\rawfile\fixtures\gesture\open_palm.png `
  -OutputPath .\Mindspore_inhand_HarmonyOS\entry\src\test\GestureImageFixture.ets
Get-FileHash -Algorithm SHA256 .\Mindspore_inhand_HarmonyOS\entry\src\ohosTest\resources\rawfile\fixtures\gesture\open_palm.png
```

Record the actual prompt, dimensions, SHA-256 returned by `Get-FileHash`, generation date, and “not a recognition gold label” limitation in `hms-gesture-test-fixture.md`.

- [ ] **Step 4: Feed the decoded PNG to the real MNN device test**

In `GestureNative.test.ets`, import `image` from `@kit.ImageKit` and `gestureInputFromRgba`. Add a helper that loads `fixtures/gesture/open_palm.png` from the test `ResourceManager`, copies its `Uint8Array` into an exact `ArrayBuffer`, creates an `ImageSource`, creates an RGBA-8888 `PixelMap`, reads pixels, calls the production preprocessor, and releases both image objects in nested `finally` blocks.

Replace the zero-filled input in `loadsRealModelAndProducesDeterministicFiniteOutputs` with that helper's result:

```typescript
const input = await loadOpenPalmGestureInput(resourceManager);
expect(input.length).assertEqual(1 * 3 * 224 * 224);
const firstOutputs = await session.predict(input);
const secondOutputs = await session.predict(input);
assertExactFiniteOutputs(firstOutputs, secondOutputs);
```

Do not add an expected class, score, or bounding box.

- [ ] **Step 5: Verify host GREEN and test-HAP compilation**

```powershell
& cmd.exe /d /c '"C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat" test --no-daemon 2>&1'
& cmd.exe /d /c '"C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat" assembleHap --mode module -p product=default -p module=entry@ohosTest --no-daemon 2>&1'
& .\scripts\verify-ai-runtime-haps.ps1 `
  -MainHapPath .\entry\build\default\outputs\default\entry-default-unsigned.hap `
  -OhosTestHapPath .\entry\build\default\outputs\ohosTest\entry-ohosTest-unsigned.hap
```

Expected: all host cases pass, the `ohosTest` HAP builds, and the guard confirms the fixture rawfile plus main/test pairing. Do not report the device suite as executed.

- [ ] **Step 6: Commit Task 2**

```powershell
git add Mindspore_inhand_HarmonyOS/entry/src/ohosTest/resources/rawfile/fixtures/gesture/open_palm.png `
  Mindspore_inhand_HarmonyOS/entry/src/test/GestureImageFixture.ets `
  tools/gesture/generate-hms-gesture-fixture.ps1 `
  docs/model-provenance/hms-gesture-test-fixture.md `
  Mindspore_inhand_HarmonyOS/entry/src/test/GestureModelUnit.test.ets `
  Mindspore_inhand_HarmonyOS/entry/src/ohosTest/ets/test/GestureNative.test.ets
git commit -m "test: exercise gesture runtime with image fixture"
```

### Task 3: Replace The Placeholder With Packaged Translation Runtime Coverage

**Files:**
- Create: `Mindspore_inhand_HarmonyOS/entry/src/ohosTest/ets/test/TranslationNative.test.ets`
- Modify: `Mindspore_inhand_HarmonyOS/entry/src/ohosTest/ets/test/List.test.ets`
- Delete: `Mindspore_inhand_HarmonyOS/entry/src/ohosTest/ets/test/Ability.test.ets`
- Modify: `tools/translation/test_project_translation_guard.py`

**Interfaces:**
- Consumes: `HarmonyRawfileContentReader`, `productionTranslationModelBundleFactory`, `createHarmonyTextTranslationService`, and `resetTranslationModelCacheForTests`.
- Produces: one device test that initializes the real archive and deterministically runs both Android-compatible directions.
- Fixed inputs: `请把门关上。` to English and `Do not delete this folder.` to Chinese. These are smoke inputs, not wording gold assertions.

- [ ] **Step 1: Add the failing source-registration regression test**

Add this case to `ProjectTranslationGuardTest`:

```python
def test_ohos_translation_native_suite_replaces_template_test(self):
    test_root = ROOT / "Mindspore_inhand_HarmonyOS" / "entry" / "src" / "ohosTest" / "ets" / "test"
    self.assertFalse((test_root / "Ability.test.ets").exists())
    translation = (test_root / "TranslationNative.test.ets").read_text(encoding="utf-8")
    suite = (test_root / "List.test.ets").read_text(encoding="utf-8")
    self.assertIn("productionTranslationModelBundleFactory", translation)
    self.assertIn("createHarmonyTextTranslationService", translation)
    self.assertIn("resetTranslationModelCacheForTests", translation)
    self.assertIn("translationNativeTest();", suite)
    self.assertNotIn("abilityTest", suite)
```

- [ ] **Step 2: Run the focused Python test and verify RED**

```powershell
$env:PYTHONPATH=(Get-Location).Path
& 'C:\Users\yuhaofeng\miniconda3\python.exe' -m unittest `
  tools.translation.test_project_translation_guard.ProjectTranslationGuardTest.test_ohos_translation_native_suite_replaces_template_test
```

Expected: FAIL because the template exists and the translation native test does not.

- [ ] **Step 3: Implement the translation native smoke test**

Create `TranslationNative.test.ets` with one suite. Its core is:

```typescript
const appContext = abilityDelegatorRegistry.getAbilityDelegator().getAppContext();
const reader = new HarmonyRawfileContentReader(appContext.resourceManager);
const cacheRoot = `${appContext.cacheDir}/translation-ohos-test`;
const bundleFactory = productionTranslationModelBundleFactory({
  resourceManager: reader,
  cacheRoot: cacheRoot
});
const bundle = await bundleFactory();
try {
  const service = await createHarmonyTextTranslationService({
    resourceManager: reader,
    translationModelResourceManager: reader,
    translationModelCacheRoot: cacheRoot,
    translationModelBundleFactory: async () => bundle
  });
  const zhFirst = await service.translateText('请把门关上。');
  const zhSecond = await service.translateText('请把门关上。');
  const enFirst = await service.translateText('Do not delete this folder.');
  const enSecond = await service.translateText('Do not delete this folder.');

  expect(zhFirst.ok).assertTrue();
  expect(zhFirst.targetLanguage).assertEqual('en');
  expect(zhFirst.runtimeSource).assertEqual('localModel');
  expect(zhFirst.translatedText.trim().length > 0).assertTrue();
  expect(zhSecond.translatedText).assertEqual(zhFirst.translatedText);
  expect(enFirst.ok).assertTrue();
  expect(enFirst.targetLanguage).assertEqual('zh');
  expect(enFirst.runtimeSource).assertEqual('localModel');
  expect(enFirst.translatedText.trim().length > 0).assertTrue();
  expect(enSecond.translatedText).assertEqual(enFirst.translatedText);
} finally {
  resetTranslationModelCacheForTests();
  await bundle.session.close();
}
```

Use imports from the existing production files; do not expose a test-only production API. Delete `Ability.test.ets`. Replace its import/call in `List.test.ets` with `translationNativeTest` while retaining `gestureNativeTest`.

- [ ] **Step 4: Verify source GREEN and compile the device suite**

```powershell
$env:PYTHONPATH=(Get-Location).Path
& 'C:\Users\yuhaofeng\miniconda3\python.exe' -m unittest `
  tools.translation.test_project_translation_guard.ProjectTranslationGuardTest.test_ohos_translation_native_suite_replaces_template_test
Set-Location .\Mindspore_inhand_HarmonyOS
& cmd.exe /d /c '"C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat" assembleHap --mode module -p product=default -p module=entry@ohosTest --no-daemon 2>&1'
```

Expected: focused Python test passes and Hvigor reports `BUILD SUCCESSFUL`. Record the device test as compiled/not executed.

- [ ] **Step 5: Commit Task 3**

```powershell
git add tools/translation/test_project_translation_guard.py `
  Mindspore_inhand_HarmonyOS/entry/src/ohosTest/ets/test/List.test.ets `
  Mindspore_inhand_HarmonyOS/entry/src/ohosTest/ets/test/TranslationNative.test.ets
git rm Mindspore_inhand_HarmonyOS/entry/src/ohosTest/ets/test/Ability.test.ets
git commit -m "test: cover packaged local translation runtime"
```

### Task 4: Add One Acceptance Build And Correct The Port Status

**Files:**
- Create: `Mindspore_inhand_HarmonyOS/scripts/build-ai-runtime-acceptance.ps1`
- Modify: `docs/harmonyos-platform-differences.md`

**Interfaces:**
- Produces: one command that builds/verifies the main HAP, builds the `entry@ohosTest` HAP, then validates their pairing.
- Documents: gesture and translation are real local runtime chains with deferred device/quality acceptance, not unavailable/dictionary-only fallbacks.

- [ ] **Step 1: Write the acceptance build script**

Create `build-ai-runtime-acceptance.ps1`:

```powershell
$ErrorActionPreference = 'Stop'
$env:DEVECO_SDK_HOME = 'C:\Program Files\Huawei\DevEco Studio\sdk'
$env:PATH = 'C:\Program Files\Huawei\DevEco Studio\jbr\bin;' + $env:PATH

& (Join-Path $PSScriptRoot 'build-hap.ps1')
$hvigor = 'C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat'
& cmd.exe /d /c "`"$hvigor`" assembleHap --mode module -p product=default -p module=entry@ohosTest --no-daemon 2>&1"
if ($LASTEXITCODE -ne 0) {
  throw "hvigor entry@ohosTest assembleHap failed with exit code $LASTEXITCODE"
}

$mainHap = Join-Path $PSScriptRoot '..\entry\build\default\outputs\default\entry-default-unsigned.hap'
$testHap = Join-Path $PSScriptRoot '..\entry\build\default\outputs\ohosTest\entry-ohosTest-unsigned.hap'
& (Join-Path $PSScriptRoot 'verify-ai-runtime-haps.ps1') `
  -MainHapPath $mainHap -OhosTestHapPath $testHap
```

- [ ] **Step 2: Correct the platform-differences status**

Update the gesture section to state that the exact HMS `GestureDetector.ms` is packaged, runs through MNN C++/NAPI, and is wired to still/live flows; retain the explicit missing real-image accuracy, performance, and device-stability evidence.

Update the translation section to state that the finite dictionary is no longer the production default: the package contains encoder/prefill/step graphs, tokenizer, archive extraction, greedy KV-cache decode, typed text plus OCR inputs, and no network permission. Retain `manual-quality-gate-not-passed`, `local-learning-only-not-production-approved`, and device-not-validated limitations.

Update the verification section with these exact distinctions:

- Hypium host tests are runnable on the workstation.
- Python model/package tests are runnable on the workstation.
- main and `ohosTest` HAPs are assembled and structurally inspected.
- `GestureNative.test.ets` and `TranslationNative.test.ets` are compiled into the test HAP but not executed without a device/emulator.

- [ ] **Step 3: Run focused verification**

From the repository root:

```powershell
& .\Mindspore_inhand_HarmonyOS\scripts\test-verify-ai-runtime-haps.ps1
$env:PYTHONPATH=(Get-Location).Path
& 'C:\Users\yuhaofeng\miniconda3\python.exe' -m unittest tools.translation.test_project_translation_guard
Set-Location .\Mindspore_inhand_HarmonyOS
& cmd.exe /d /c '"C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat" test --no-daemon 2>&1'
& .\scripts\build-ai-runtime-acceptance.ps1
```

Expected: package-guard fixtures pass, project translation guard passes, every Hypium host case passes, both HAPs build, and final package inspection passes.

- [ ] **Step 4: Run full translation verification**

From the repository root:

```powershell
$repo=(Get-Location).Path
$site=Join-Path $env:TEMP 'translation-t1-final\venv\Lib\site-packages'
$sacre=Join-Path $env:TEMP 'translation-tools\sacrebleu-2.4.3'
$env:PYTHONPATH=$repo+';'+$site+';'+$sacre
& 'C:\Users\yuhaofeng\miniconda3\python.exe' -m unittest discover -s tools\translation -p 'test_*.py'
```

Expected: all tests pass; the count is at least 167 after adding the new guard case.

- [ ] **Step 5: Commit Task 4**

```powershell
git add Mindspore_inhand_HarmonyOS/scripts/build-ai-runtime-acceptance.ps1 `
  docs/harmonyos-platform-differences.md
git diff --cached --check
git commit -m "build: close AI runtime acceptance workflow"
```

- [ ] **Step 6: Perform final clean-tree verification**

```powershell
git status --short --branch
git log --oneline --decorate -8
Get-FileHash -Algorithm SHA256 `
  .\Mindspore_inhand_HarmonyOS\entry\build\default\outputs\default\entry-default-unsigned.hap
Get-FileHash -Algorithm SHA256 `
  .\Mindspore_inhand_HarmonyOS\entry\build\default\outputs\ohosTest\entry-ohosTest-unsigned.hap
```

Expected: `master` or the isolated implementation branch is clean, all four implementation commits are present, and both HAP hashes are recorded in the handoff. Do not claim device execution.
