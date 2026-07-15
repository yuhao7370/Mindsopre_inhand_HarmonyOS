# Static Gesture Android Layout Parity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give `/hms/StillHandGestureAnalyseActivity` its Android production layout without changing the current HMS MNN inference chain.

**Architecture:** Add two pure route policies to the workflow catalog, select one dedicated builder before the generic runtime fallback, and reuse the existing still-image, gesture-result, overlay, permission, and linked-live-route state. A build-wired PowerShell guard protects the exact dedicated layout and failure-feedback boundary.

**Tech Stack:** HarmonyOS ArkTS/ArkUI, Hypium, PowerShell, Hvigor, MNN C++/NAPI runtime retained unchanged.

## Global Constraints

- Only `AppRoute.GESTURE_STILL` may use the new dedicated layout.
- Keep the exact packaged HMS `GestureDetector.ms`, `libgesture_mnn.so`, MNN preprocessing, thresholds, YOLO decode, NMS, and category mapping unchanged.
- Keep Photo and Camera automatic inference, picker cancellation, permission recovery, request generation, session reuse, and live-route navigation unchanged.
- The visible order is toolbar, two 1vp `#E4E4E4` dividers, weight-9 `#E6E6E6` preview, then weight-1 Photo/Camera/Real-time actions.
- The preview uses the byte-identical `app.media.icon_style`, the existing Android prompt, a 50vp image inset, and the existing gesture rectangle/label builders.
- Failed current Gesture Still requests show the existing localized message as a Toast; successful, stale, cancelled, live, and unrelated workflow results do not.
- Do not add MediaPipe, online translation, another gesture model, a dependency, or a broad `FeatureRuntimePage` refactor.
- Real-device crop, orientation, font metrics, detection accuracy, and overlay tuning remain deferred.

---

### Task 1: Static Gesture Dedicated Layout And Guard

**Files:**
- Modify: `Mindspore_inhand_HarmonyOS/entry/src/main/ets/features/runtime/FeatureWorkflowCatalog.ets`
- Modify: `Mindspore_inhand_HarmonyOS/entry/src/test/LocalUnit.test.ets`
- Modify: `Mindspore_inhand_HarmonyOS/entry/src/main/ets/pages/FeatureRuntimePage.ets`
- Create: `Mindspore_inhand_HarmonyOS/scripts/check-static-gesture-layout-parity.ps1`
- Modify: `Mindspore_inhand_HarmonyOS/scripts/build-hap.ps1`
- Modify: `docs/harmonyos-platform-differences.md`
- Test: `Mindspore_inhand_HarmonyOS/entry/src/test/LocalUnit.test.ets`
- Test: `Mindspore_inhand_HarmonyOS/scripts/check-static-gesture-layout-parity.ps1`

**Interfaces:**
- Consumes: `FeatureWorkflow`, `AppRoute.GESTURE_STILL`, existing `prepareInput()`, `openLinkedLiveRoute()`, `runtimePermissionRecoveryOverlay()`, gesture image/result state, `gestureAspectRatio()`, `visibleGestureDetections()`, `gestureBox()`, and `showRuntimeToast()`.
- Produces: `usesAndroidGestureStillLayout(workflow): boolean`, `shouldShowGestureStillFailureToast(workflow, resultOk): boolean`, and the `gestureStillAndroidLayout()` page builder.

- [ ] **Step 1: Add failing pure-policy tests**

Add both imports beside the existing layout selectors in `LocalUnit.test.ets`:

```typescript
  shouldShowGestureStillFailureToast,
  usesAndroidGestureStillLayout,
```

Add these tests beside the Text Recognition/Text Translation selector tests:

```typescript
    it('usesAndroidGestureStillLayoutOnlyForStaticGesture', 0, () => {
      expect(featureWorkflows.length).assertEqual(16);
      featureWorkflows.forEach((workflow: FeatureWorkflow) => {
        expect(usesAndroidGestureStillLayout(workflow))
          .assertEqual(workflow.routeName === AppRoute.GESTURE_STILL.name);
      });
      expect(usesAndroidGestureStillLayout(undefined)).assertFalse();
    });

    it('showsAndroidGestureFailureToastOnlyForFailedStaticGesture', 0, () => {
      featureWorkflows.forEach((workflow: FeatureWorkflow) => {
        expect(shouldShowGestureStillFailureToast(workflow, false))
          .assertEqual(workflow.routeName === AppRoute.GESTURE_STILL.name);
        expect(shouldShowGestureStillFailureToast(workflow, true)).assertFalse();
      });
      expect(shouldShowGestureStillFailureToast(undefined, false)).assertFalse();
      expect(shouldShowGestureStillFailureToast(undefined, true)).assertFalse();
    });
```

- [ ] **Step 2: Run Hypium to verify RED**

Run from `Mindspore_inhand_HarmonyOS`:

```powershell
$env:DEVECO_SDK_HOME='C:\Program Files\Huawei\DevEco Studio\sdk'
$env:PATH='C:\Program Files\Huawei\DevEco Studio\jbr\bin;' + $env:PATH
& cmd.exe /d /c '"C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat" test --no-daemon 2>&1'
```

Expected: FAIL because `usesAndroidGestureStillLayout` and
`shouldShowGestureStillFailureToast` are not exported yet.

- [ ] **Step 3: Add the failing structural guard and build wiring**

Create `scripts/check-static-gesture-layout-parity.ps1` with this complete
content:

```powershell
$ErrorActionPreference = 'Stop'

function Get-NormalizedText([string]$Path) {
  return (Get-Content -Raw -Encoding UTF8 -LiteralPath $Path).Replace("`r`n", "`n").Replace("`r", "`n")
}

function Get-TextSection(
  [string]$Text,
  [string]$StartMarker,
  [string]$EndMarker,
  [string]$Description
) {
  $start = $Text.IndexOf($StartMarker, [StringComparison]::Ordinal)
  $end = $Text.IndexOf($EndMarker, $start + $StartMarker.Length, [StringComparison]::Ordinal)
  if ($start -lt 0 -or $end -le $start) {
    throw "Static gesture parity guard failed: $Description was not found."
  }
  return $Text.Substring($start, $end - $start)
}

function Assert-Contains([string]$Text, [string]$Marker, [string]$Message) {
  if (-not $Text.Contains($Marker)) {
    throw "Static gesture parity guard failed: $Message"
  }
}

function Assert-Excludes([string]$Text, [string]$Marker, [string]$Message) {
  if ($Text.Contains($Marker)) {
    throw "Static gesture parity guard failed: $Message ($Marker)."
  }
}

$root = Split-Path -Parent $PSScriptRoot
$catalog = Get-NormalizedText (Join-Path $root 'entry\src\main\ets\features\runtime\FeatureWorkflowCatalog.ets')
$selector = Get-TextSection `
  $catalog `
  'export function usesAndroidGestureStillLayout' `
  'export function runtimeInputKindsForWorkflow' `
  'static gesture selector'
Assert-Contains $selector 'AppRoute.GESTURE_STILL.name' 'selector must target Gesture Still.'
Assert-Contains $selector 'shouldShowGestureStillFailureToast' 'failure Toast policy must share the route boundary.'

$page = Get-NormalizedText (Join-Path $root 'entry\src\main\ets\pages\FeatureRuntimePage.ets')
$builder = Get-TextSection `
  $page `
  '  gestureStillAndroidLayout() {' `
  "`n`n  @Builder`n  textRecognitionAndroidLayout()" `
  'dedicated static gesture builder'

foreach ($marker in @(
  'this.runtimeActionToolbar(false)',
  "Image(`$r('app.media.icon_style'))",
  "appString('workflow_summary_gesture_still_android_prompt')",
  "this.prepareInput('photo')",
  "this.prepareInput('camera')",
  'this.openLinkedLiveRoute()',
  'this.runtimePermissionRecoveryOverlay()',
  '.padding(50)',
  '.layoutWeight(9)',
  '.layoutWeight(1)'
)) {
  Assert-Contains $builder $marker "dedicated builder is missing $marker."
}

$dividerHeight = '.height(1)'
$dividerHeightCount = ($builder.Length - $builder.Replace($dividerHeight, '').Length) / $dividerHeight.Length
$dividerColor = ".backgroundColor('#E4E4E4')"
$dividerColorCount = ($builder.Length - $builder.Replace($dividerColor, '').Length) / $dividerColor.Length
if ($dividerHeightCount -ne 2 -or $dividerColorCount -ne 2) {
  throw 'Static gesture parity guard failed: dedicated builder must keep exactly two Android dividers.'
}

$photoIndex = $builder.IndexOf("Button(appString('feature_input_photo_android')", [StringComparison]::Ordinal)
$cameraIndex = $builder.IndexOf("Button(appString('feature_input_camera_android')", [StringComparison]::Ordinal)
$liveIndex = $builder.IndexOf("Button(appString('feature_runtime_go_live_android_hms')", [StringComparison]::Ordinal)
if ($photoIndex -lt 0 -or $cameraIndex -le $photoIndex -or $liveIndex -le $cameraIndex) {
  throw 'Static gesture parity guard failed: actions must be Photo, Camera, Real-time.'
}

foreach ($marker in @(
  'this.summaryKey',
  'feature_runtime_inputs_title',
  'feature_runtime_permissions_title',
  'workflowResultTitleKey(',
  'this.resultRow(',
  'this.resultText',
  'this.gesturePreview(',
  'resultImageSaveControl(',
  'resultComponentImageSaveControl('
)) {
  Assert-Excludes $builder $marker 'dedicated builder contains generic card/result/save UI'
}

$failureMethod = Get-TextSection `
  $page `
  '  private showGestureStillFailureToastIfNeeded' `
  "`n`n  private clearRuntimeResultState" `
  'Gesture Still failure feedback'
Assert-Contains $failureMethod 'shouldShowGestureStillFailureToast' 'failure helper must use the pure route policy.'
Assert-Contains $failureMethod 'this.showRuntimeToast(messageKey)' 'failed Gesture Still results must show a Toast.'

$build = $page.Substring($page.IndexOf("`n  build() {", [StringComparison]::Ordinal))
$selectorIndex = $build.IndexOf('usesAndroidGestureStillLayout(workflowForRoute(this.routeName))', [StringComparison]::Ordinal)
$genericIndex = $build.IndexOf("    } else {`n      Scroll() {", [StringComparison]::Ordinal)
if ($selectorIndex -lt 0 -or $genericIndex -lt 0 -or $selectorIndex -ge $genericIndex) {
  throw 'Static gesture parity guard failed: dedicated selector must precede the generic fallback.'
}

$buildScript = Get-NormalizedText (Join-Path $root 'scripts\build-hap.ps1')
Assert-Contains $buildScript "check-static-gesture-layout-parity.ps1" 'build-hap must execute the guard.'

Write-Output 'Static gesture layout parity guard passed.'
```

Add this line after the other runtime layout guards in `scripts/build-hap.ps1`:

```powershell
& (Join-Path $PSScriptRoot 'check-static-gesture-layout-parity.ps1')
```

- [ ] **Step 4: Run the structural guard to verify RED**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\check-static-gesture-layout-parity.ps1
```

Expected: FAIL with `static gesture selector was not found`.

- [ ] **Step 5: Implement the pure route and failure policies**

Add these functions immediately before `runtimeInputKindsForWorkflow()` in
`FeatureWorkflowCatalog.ets`:

```typescript
export function usesAndroidGestureStillLayout(workflow: FeatureWorkflow | undefined): boolean {
  return workflow?.routeName === AppRoute.GESTURE_STILL.name;
}

export function shouldShowGestureStillFailureToast(
  workflow: FeatureWorkflow | undefined,
  resultOk: boolean
): boolean {
  return usesAndroidGestureStillLayout(workflow) && !resultOk;
}
```

- [ ] **Step 6: Implement route-specific failure feedback**

Import `shouldShowGestureStillFailureToast` and
`usesAndroidGestureStillLayout` from `FeatureWorkflowCatalog.ets` in
`FeatureRuntimePage.ets`.

At the end of `applyRuntimeFailure()`, add:

```typescript
    this.showGestureStillFailureToastIfNeeded(false, this.statusKey);
```

At the end of `applyAiResult()`, add:

```typescript
    this.showGestureStillFailureToastIfNeeded(result.ok, result.messageKey);
```

Add this helper immediately after `applyAiResult()`:

```typescript
  private showGestureStillFailureToastIfNeeded(resultOk: boolean, messageKey: AppStringKey): void {
    if (shouldShowGestureStillFailureToast(workflowForRoute(this.routeName), resultOk)) {
      this.showRuntimeToast(messageKey);
    }
  }
```

- [ ] **Step 7: Implement the dedicated ArkUI screen**

Add these builders immediately before `textRecognitionAndroidLayout()`:

```typescript
  @Builder
  gestureStillAndroidPreview() {
    Stack({ alignContent: Alignment.Center }) {
      if (this.gestureImageUri.length > 0 && this.visibleGestureDetections().length > 0) {
        Stack({ alignContent: Alignment.TopStart }) {
          Image(this.gestureImageUri)
            .orientation(this.gestureImageOrientation)
            .width('100%')
            .height('100%')
            .objectFit(ImageFit.Fill)
          ForEach(this.visibleGestureDetections(), (gesture: GestureDetection) => {
            this.gestureBox(gesture)
          }, (gesture: GestureDetection) =>
            `${gesture.category}-${gesture.score}-${gesture.rect?.left}-${gesture.rect?.top}`)
        }
        .width('100%')
        .aspectRatio(this.gestureAspectRatio())
        .clip(true)
      } else if (this.imageInputUri.length > 0) {
        Image(this.imageInputUri)
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Contain)
      } else {
        Column() {
          Image($r('app.media.icon_style'))
            .width(69.33)
            .height(56.33)
            .objectFit(ImageFit.Contain)
          Text(appString('workflow_summary_gesture_still_android_prompt'))
            .fontSize(16)
            .fontColor('#666666')
            .textAlign(TextAlign.Center)
            .margin({ top: 10 })
        }
        .alignItems(HorizontalAlign.Center)
      }
    }
    .width('100%')
    .layoutWeight(9)
    .padding(50)
    .clip(true)
    .backgroundColor('#E6E6E6')
  }

  @Builder
  gestureStillAndroidLayout() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column() {
        this.runtimeActionToolbar(false)
        Row() {
        }
        .width('100%')
        .height(1)
        .backgroundColor('#E4E4E4')
        Row() {
        }
        .width('100%')
        .height(1)
        .backgroundColor('#E4E4E4')
        this.gestureStillAndroidPreview()
        Row() {
          Button(appString('feature_input_photo_android'), { type: ButtonType.Normal })
            .layoutWeight(1)
            .height(37)
            .margin({ left: 20, right: 5 })
            .fontSize(14)
            .fontWeight(FontWeight.Normal)
            .fontColor('#666666')
            .backgroundColor('#F4F3F8')
            .borderRadius(5)
            .onClick(() => this.prepareInput('photo'))
          Button(appString('feature_input_camera_android'), { type: ButtonType.Normal })
            .layoutWeight(1)
            .height(37)
            .margin({ left: 5, right: 5 })
            .fontSize(14)
            .fontWeight(FontWeight.Normal)
            .fontColor('#666666')
            .backgroundColor('#F4F3F8')
            .borderRadius(5)
            .onClick(() => this.prepareInput('camera'))
          Button(appString('feature_runtime_go_live_android_hms'), { type: ButtonType.Normal })
            .layoutWeight(1)
            .height(37)
            .margin({ left: 5, right: 5 })
            .fontSize(14)
            .fontWeight(FontWeight.Normal)
            .fontColor('#666666')
            .backgroundColor('#F4F3F8')
            .borderRadius(5)
            .onClick(() => this.openLinkedLiveRoute())
        }
        .width('100%')
        .layoutWeight(1)
        .margin({ top: 14 })
        .alignItems(VerticalAlign.Center)
      }
      .width('100%')
      .height('100%')
      .backgroundColor(Color.White)
      this.runtimePermissionRecoveryOverlay()
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.White)
  }
```

Select it in `build()` after Text Recognition and before Portrait/live/generic
branches:

```typescript
    } else if (usesAndroidGestureStillLayout(workflowForRoute(this.routeName))) {
      this.gestureStillAndroidLayout()
```

- [ ] **Step 8: Document the completed platform boundary**

Add this bullet to the Gesture Recognition section of
`docs/harmonyos-platform-differences.md` after the still-route auto-run bullet:

```markdown
- The static Gesture route now uses the Android production screen structure:
  the Back/title toolbar, double divider, weighted gray image/overlay surface,
  original empty-state icon and prompt, and Photo/Camera/Real-time action row.
  It no longer exposes the shared Inputs, Permissions, URI, runtime metadata,
  or duplicate result cards. Failed current requests retain Android-style
  visible Toast feedback while continuing to use the HMS MNN detector.
```

- [ ] **Step 9: Run focused GREEN verification**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\check-static-gesture-layout-parity.ps1
$env:DEVECO_SDK_HOME='C:\Program Files\Huawei\DevEco Studio\sdk'
$env:PATH='C:\Program Files\Huawei\DevEco Studio\jbr\bin;' + $env:PATH
& cmd.exe /d /c '"C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat" test --no-daemon 2>&1'
```

Expected: guard passes and Hypium reports zero failures/errors with 475 total
tests (473 baseline plus the two new selector/feedback cases).

- [ ] **Step 10: Run repository and package acceptance**

Verify the asset remains byte-identical, then run diff and full package gates:

```powershell
$androidIcon = '..\Mindspore_inhand\hms\src\main\res\drawable-xxhdpi\icon_style.png'
$harmonyIcon = '.\entry\src\main\resources\base\media\icon_style.png'
if ((Get-FileHash -Algorithm SHA256 $androidIcon).Hash -ne (Get-FileHash -Algorithm SHA256 $harmonyIcon).Hash) {
  throw 'icon_style.png differs from Android.'
}
git diff --check
powershell -ExecutionPolicy Bypass -File .\scripts\build-ai-runtime-acceptance.ps1
```

Expected: identical hashes, no whitespace errors, main HAP and `ohosTest` HAP
build successfully, native-contract checks pass, and package inspection finds
the HMS gesture plus local translation assets/libraries.

- [ ] **Step 11: Commit the implementation**

```powershell
git add -- `
  entry/src/main/ets/features/runtime/FeatureWorkflowCatalog.ets `
  entry/src/test/LocalUnit.test.ets `
  entry/src/main/ets/pages/FeatureRuntimePage.ets `
  scripts/check-static-gesture-layout-parity.ps1 `
  scripts/build-hap.ps1 `
  ../docs/harmonyos-platform-differences.md
git commit -m "fix: match android static gesture layout"
```

Expected: one focused implementation commit; `git status --short` is empty.
