# PoseNet Still Layout Android Parity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the generic HarmonyOS PoseNet still screen with Android's single-preview four-action layout while preserving the existing pose runtime.

**Architecture:** Add route-scoped pure policies to `FeatureWorkflowCatalog`, then select one dedicated builder in `FeatureRuntimePage`. Reuse the current bundled sample, pickers, auto-run path, request-current checks, permission recovery, pose coordinate calculations, and Live Skeleton route; add only PoseNet-still visual builders and Toast mapping.

**Tech Stack:** ArkTS, ArkUI, Hypium, PowerShell, Hvigor.

## Global Constraints

- Do not change pose models, native libraries, preprocessing, thresholds, service selection, or live-camera behavior.
- `AppRoute.POSENET` is the only workflow that may select the new layout or Toast policy.
- The page has one 1vp `#E4E4E4` divider, a weight-9 `#E6E6E6` preview, and a weight-1 Photo/Camera/Real-time/Detect row with a 14vp top margin.
- Detect restores the existing `initialPreviewActionForWorkflow()` sample and then runs the existing workflow.
- PoseNet-still overlay colors are `#00FF00` and `#FF0000`; shared Live Skeleton builders keep their current colors.
- Success, result failure, and runtime exception Toasts use the three exact Android-specific localization keys from the design; permission denial does not Toast.
- Real-device image, orientation, overlay-thickness, Toast, and picker checks remain deferred.

---

### Task 1: Add the PoseNet-only policy and localized feedback contract

**Files:**

- Modify: `Mindspore_inhand_HarmonyOS/entry/src/test/LocalUnit.test.ets`
- Modify: `Mindspore_inhand_HarmonyOS/entry/src/main/ets/features/runtime/FeatureWorkflowCatalog.ets`
- Modify: `Mindspore_inhand_HarmonyOS/entry/src/main/ets/common/i18n/AppStrings.ets`
- Modify: `Mindspore_inhand_HarmonyOS/entry/src/main/resources/base/element/string.json`
- Modify: `Mindspore_inhand_HarmonyOS/entry/src/main/resources/zh_CN/element/string.json`
- Modify: `Mindspore_inhand_HarmonyOS/entry/src/main/resources/en_US/element/string.json`

**Interfaces:**

- Produces: `usesAndroidPoseNetStillLayout(workflow: FeatureWorkflow | undefined): boolean`.
- Produces: `poseNetStillToastKey(workflow: FeatureWorkflow | undefined, resultOk: boolean): AppStringKey | undefined`.
- Produces localization keys `feature_runtime_pose_detect_android`, `feature_runtime_pose_detect_success_android`, and `feature_runtime_pose_detect_failed_android`.

- [ ] **Step 1: Add failing policy and localization tests**

Add these imports from `FeatureWorkflowCatalog` in `LocalUnit.test.ets`:

```ts
  poseNetStillToastKey,
  usesAndroidPoseNetStillLayout,
```

Add these cases beside the dedicated-layout tests:

```ts
    it('usesAndroidPoseNetStillLayoutOnlyForPoseNetStill', 0, () => {
      expect(featureWorkflows.length).assertEqual(16);
      featureWorkflows.forEach((workflow: FeatureWorkflow) => {
        expect(usesAndroidPoseNetStillLayout(workflow))
          .assertEqual(workflow.routeName === AppRoute.POSENET.name);
      });
      expect(usesAndroidPoseNetStillLayout(undefined)).assertFalse();
    });

    it('mapsAndroidPoseNetStillToastOnlyForPoseNetStill', 0, () => {
      featureWorkflows.forEach((workflow: FeatureWorkflow) => {
        const isPoseNetStill = workflow.routeName === AppRoute.POSENET.name;
        expect(poseNetStillToastKey(workflow, true)).assertEqual(
          isPoseNetStill ? 'feature_runtime_pose_detect_success_android' : undefined
        );
        expect(poseNetStillToastKey(workflow, false)).assertEqual(
          isPoseNetStill ? 'feature_runtime_pose_detect_failed_android' : undefined
        );
      });
      expect(poseNetStillToastKey(undefined, true)).assertUndefined();
      expect(poseNetStillToastKey(undefined, false)).assertUndefined();
      expect(hasAppStringKey('feature_runtime_pose_detect_android')).assertTrue();
      expect(hasAppStringKey('feature_runtime_pose_detect_success_android')).assertTrue();
      expect(hasAppStringKey('feature_runtime_pose_detect_failed_android')).assertTrue();
    });
```

- [ ] **Step 2: Run Hypium and record RED**

Run from `Mindspore_inhand_HarmonyOS`:

```powershell
$env:DEVECO_SDK_HOME='C:\Program Files\Huawei\DevEco Studio\sdk'
$env:PATH='C:\Program Files\Huawei\DevEco Studio\jbr\bin;' + $env:PATH
& 'C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat' test --no-daemon
```

Expected: FAIL during ArkTS compilation because the two catalog exports and three `AppStringKey` members do not exist.

- [ ] **Step 3: Implement the minimal pure policies**

Add this immediately before `usesAndroidGestureStillLayout()` in
`FeatureWorkflowCatalog.ets` so the selector and Toast policy stay one bounded
section:

```ts
export function usesAndroidPoseNetStillLayout(workflow: FeatureWorkflow | undefined): boolean {
  return workflow?.routeName === AppRoute.POSENET.name;
}

export function poseNetStillToastKey(
  workflow: FeatureWorkflow | undefined,
  resultOk: boolean
): AppStringKey | undefined {
  if (!usesAndroidPoseNetStillLayout(workflow)) {
    return undefined;
  }
  return resultOk ?
    'feature_runtime_pose_detect_success_android' :
    'feature_runtime_pose_detect_failed_android';
}
```

- [ ] **Step 4: Add the exact localized strings**

Add all three keys to the `AppStringKey` union, `appStringKeys`, and the `appString()` switch in `AppStrings.ets`. The switch arms are:

```ts
    case 'feature_runtime_pose_detect_android':
      return $r('app.string.feature_runtime_pose_detect_android');
    case 'feature_runtime_pose_detect_success_android':
      return $r('app.string.feature_runtime_pose_detect_success_android');
    case 'feature_runtime_pose_detect_failed_android':
      return $r('app.string.feature_runtime_pose_detect_failed_android');
```

Add these entries to both `base/element/string.json` and `zh_CN/element/string.json`:

```json
    { "name": "feature_runtime_pose_detect_android", "value": "检测" },
    { "name": "feature_runtime_pose_detect_success_android", "value": "检测成功" },
    { "name": "feature_runtime_pose_detect_failed_android", "value": "检测失败" },
```

Add these entries to `en_US/element/string.json`:

```json
    { "name": "feature_runtime_pose_detect_android", "value": "detect" },
    { "name": "feature_runtime_pose_detect_success_android", "value": "Detection succeeded" },
    { "name": "feature_runtime_pose_detect_failed_android", "value": "Detection failed" },
```

- [ ] **Step 5: Run localization guard and Hypium to GREEN**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\check-i18n-strings.ps1
& 'C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat' test --no-daemon
Get-Content .\entry\.test\default\intermediates\test\coverage_data\test_result.txt -Tail 1
```

Expected: localization guard PASS and `Tests run: 485, Failure: 0, Error: 0, Pass: 485, Ignore: 0`.

- [ ] **Step 6: Commit the policy contract**

```powershell
git add -- Mindspore_inhand_HarmonyOS/entry/src/test/LocalUnit.test.ets Mindspore_inhand_HarmonyOS/entry/src/main/ets/features/runtime/FeatureWorkflowCatalog.ets Mindspore_inhand_HarmonyOS/entry/src/main/ets/common/i18n/AppStrings.ets Mindspore_inhand_HarmonyOS/entry/src/main/resources/base/element/string.json Mindspore_inhand_HarmonyOS/entry/src/main/resources/zh_CN/element/string.json Mindspore_inhand_HarmonyOS/entry/src/main/resources/en_US/element/string.json
git commit -m "test: define android posenet still layout policy"
```

### Task 2: Build the dedicated page and regression guard

**Files:**

- Create: `Mindspore_inhand_HarmonyOS/scripts/check-posenet-still-layout-parity.ps1`
- Modify: `Mindspore_inhand_HarmonyOS/entry/src/main/ets/pages/FeatureRuntimePage.ets`
- Modify: `Mindspore_inhand_HarmonyOS/scripts/build-hap.ps1`
- Modify: `docs/harmonyos-platform-differences.md`

**Interfaces:**

- Consumes: `usesAndroidPoseNetStillLayout()`, `poseNetStillToastKey()`, and the three Task 1 localization keys.
- Produces: PoseNet-only `poseNetStillAndroidLayout()`, `runPoseNetSampleDetection()`, and current-result Toast wiring.

- [ ] **Step 1: Create the failing structural guard**

Create `scripts/check-posenet-still-layout-parity.ps1` with the same normalized-text and bounded-section helpers used by `check-static-gesture-layout-parity.ps1`. The assertions must be exactly:

```powershell
$ErrorActionPreference = 'Stop'

function Get-NormalizedText([string]$Path) {
  return (Get-Content -Raw -Encoding UTF8 -LiteralPath $Path).Replace("`r`n", "`n").Replace("`r", "`n")
}

function Get-TextSection([string]$Text, [string]$StartMarker, [string]$EndMarker, [string]$Description) {
  $start = $Text.IndexOf($StartMarker, [StringComparison]::Ordinal)
  $end = $Text.IndexOf($EndMarker, $start + $StartMarker.Length, [StringComparison]::Ordinal)
  if ($start -lt 0 -or $end -le $start) {
    throw "PoseNet still parity guard failed: $Description was not found."
  }
  return $Text.Substring($start, $end - $start)
}

function Assert-Contains([string]$Text, [string]$Marker, [string]$Message) {
  if (-not $Text.Contains($Marker)) {
    throw "PoseNet still parity guard failed: $Message"
  }
}

function Assert-Excludes([string]$Text, [string]$Marker, [string]$Message) {
  if ($Text.Contains($Marker)) {
    throw "PoseNet still parity guard failed: $Message ($Marker)."
  }
}

$root = Split-Path -Parent $PSScriptRoot
$catalog = Get-NormalizedText (Join-Path $root 'entry\src\main\ets\features\runtime\FeatureWorkflowCatalog.ets')
$selector = Get-TextSection $catalog 'export function usesAndroidPoseNetStillLayout' 'export function usesAndroidGestureStillLayout' 'PoseNet still selector'
Assert-Contains $selector 'return workflow?.routeName === AppRoute.POSENET.name;' 'selector must target only PoseNet still.'
Assert-Contains $selector 'poseNetStillToastKey' 'Toast policy must share the route boundary.'

$page = Get-NormalizedText (Join-Path $root 'entry\src\main\ets\pages\FeatureRuntimePage.ets')
$builder = Get-TextSection $page '  poseNetStillPoseLine(line: PoseLine) {' "`n`n  @Builder`n  gestureStillAndroidPreview()" 'dedicated PoseNet still builder'
foreach ($marker in @(
  'this.runtimeActionToolbar(false)',
  "this.prepareInput('photo')",
  "this.prepareInput('camera')",
  'this.openLinkedLiveRoute()',
  'this.runPoseNetSampleDetection()',
  "appString('feature_runtime_pose_detect_android')",
  'this.poseNetStillPoseLine(line)',
  'this.poseNetStillPosePoint(point)',
  "backgroundColor('#E6E6E6')",
  "backgroundColor('#00FF00')",
  "backgroundColor('#FF0000')",
  'this.runtimePermissionRecoveryOverlay()',
  '.layoutWeight(9)',
  '.margin({ top: 14 })'
)) {
  Assert-Contains $builder $marker "dedicated builder is missing $marker."
}

$actionRow = Get-TextSection $builder "        Row() {`n          Button(appString('feature_input_photo_android')" "      }`n      .width('100%')" 'PoseNet still action row'
$actionRowLayout = "        }`n        .width('100%')`n        .layoutWeight(1)`n        .margin({ top: 14 })`n        .alignItems(VerticalAlign.Center)"
Assert-Contains $actionRow $actionRowLayout 'action row must keep its Android width, weight, margin, and alignment.'

$dividerHeight = '.height(1)'
$dividerColor = ".backgroundColor('#E4E4E4')"
$dividerHeightCount = ($builder.Length - $builder.Replace($dividerHeight, '').Length) / $dividerHeight.Length
$dividerColorCount = ($builder.Length - $builder.Replace($dividerColor, '').Length) / $dividerColor.Length
if ($dividerHeightCount -ne 1 -or $dividerColorCount -ne 1) {
  throw 'PoseNet still parity guard failed: dedicated builder must keep exactly one Android divider.'
}

$photoIndex = $builder.IndexOf("Button(appString('feature_input_photo_android')", [StringComparison]::Ordinal)
$cameraIndex = $builder.IndexOf("Button(appString('feature_input_camera_android')", [StringComparison]::Ordinal)
$liveIndex = $builder.IndexOf("Button(appString('feature_runtime_go_live_android_hms')", [StringComparison]::Ordinal)
$detectIndex = $builder.IndexOf("Button(appString('feature_runtime_pose_detect_android')", [StringComparison]::Ordinal)
if ($photoIndex -lt 0 -or $cameraIndex -le $photoIndex -or $liveIndex -le $cameraIndex -or $detectIndex -le $liveIndex) {
  throw 'PoseNet still parity guard failed: actions must be Photo, Camera, Real-time, Detect.'
}

foreach ($marker in @(
  'this.summaryKey',
  'feature_runtime_inputs_title',
  'feature_runtime_permissions_title',
  'workflowResultTitleKey(',
  'this.resultRow(',
  'this.statusKey',
  'this.selectedInputSummary',
  'this.resultText',
  'this.posePreview(',
  'resultImageSaveControl(',
  'resultComponentImageSaveControl('
)) {
  Assert-Excludes $builder $marker 'dedicated builder contains generic card/result/save UI'
}

$detect = Get-TextSection $page '  private runPoseNetSampleDetection(): void {' "`n`n  private runPrimaryAction(): void" 'Detect sample handler'
Assert-Contains $detect 'initialPreviewActionForWorkflow(workflow)' 'Detect must resolve the existing bundled sample action.'
Assert-Contains $detect 'this.applyPickResult(' 'Detect must restore the sample through the existing input path.'
Assert-Contains $detect 'this.runWorkflow();' 'Detect must run the existing pose workflow.'

$runtimeFailure = Get-TextSection $page '  private applyRuntimeFailure(): void {' "`n`n  private async prepareLiveFrameImageInput" 'runtime failure Toast call site'
Assert-Contains $runtimeFailure 'this.showPoseNetStillToastIfNeeded(false);' 'runtime exceptions must show the PoseNet failure Toast.'

$aiResult = Get-TextSection $page '  private applyAiResult(result: AiRunResult, runtimeRequestId: number): void {' "`n`n  private showGestureStillFailureToastIfNeeded" 'AI result Toast call site'
Assert-Contains $aiResult 'this.showPoseNetStillToastIfNeeded(result.ok);' 'current PoseNet results must show success or failure Toast.'

$toast = Get-TextSection $page '  private showPoseNetStillToastIfNeeded' "`n`n  private clearRuntimeResultState" 'PoseNet Toast helper'
Assert-Contains $toast 'poseNetStillToastKey' 'Toast helper must use the pure route policy.'
Assert-Contains $toast 'this.showRuntimeToast(toastKey)' 'Toast helper must render the mapped key.'

$build = $page.Substring($page.IndexOf("`n  build() {", [StringComparison]::Ordinal))
$selectorIndex = $build.IndexOf('usesAndroidPoseNetStillLayout(workflowForRoute(this.routeName))', [StringComparison]::Ordinal)
$genericIndex = $build.IndexOf("    } else {`n      Scroll() {", [StringComparison]::Ordinal)
if ($selectorIndex -lt 0 -or $genericIndex -lt 0 -or $selectorIndex -ge $genericIndex) {
  throw 'PoseNet still parity guard failed: dedicated selector must precede the generic fallback.'
}

$buildScript = Get-NormalizedText (Join-Path $root 'scripts\build-hap.ps1')
$buildGuardCall = "& (Join-Path `$PSScriptRoot 'check-posenet-still-layout-parity.ps1')"
Assert-Contains "`n$buildScript`n" "`n$buildGuardCall`n" 'build-hap must execute the guard.'

Write-Output 'PoseNet still layout parity guard passed.'
```

- [ ] **Step 2: Run the guard and record RED**

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\check-posenet-still-layout-parity.ps1
```

Expected: FAIL because `poseNetStillAndroidPreview()` and the build branch do not exist.

- [ ] **Step 3: Wire the policies and Detect behavior into the page**

Import `poseNetStillToastKey` and `usesAndroidPoseNetStillLayout` in `FeatureRuntimePage.ets`.

Insert this method immediately before `runPrimaryAction()`:

```ts
  private runPoseNetSampleDetection(): void {
    const workflow = workflowForRoute(this.routeName);
    if (!usesAndroidPoseNetStillLayout(workflow)) {
      return;
    }
    const action = workflow === undefined ? undefined : initialPreviewActionForWorkflow(workflow);
    if (action === undefined) {
      return;
    }
    this.applyPickResult({ ok: true, uri: action.uri }, action.readyKey, action.inputKind, false);
    this.runWorkflow();
  }
```

Add `this.showPoseNetStillToastIfNeeded(false);` after the existing Gesture call in `applyRuntimeFailure()` and `this.showPoseNetStillToastIfNeeded(result.ok);` after the existing Gesture call in `applyAiResult()`. Add this method immediately after the Gesture Toast helper:

```ts
  private showPoseNetStillToastIfNeeded(resultOk: boolean): void {
    const toastKey = poseNetStillToastKey(workflowForRoute(this.routeName), resultOk);
    if (toastKey !== undefined) {
      this.showRuntimeToast(toastKey);
    }
  }
```

- [ ] **Step 4: Add the dedicated PoseNet still builders**

Insert these builders immediately before `gestureStillAndroidPreview()`:

```ts
  @Builder
  poseNetStillPoseLine(line: PoseLine) {
    Column() {
    }
    .width(this.percentLength(this.poseLineStyle(line).length))
    .height(3)
    .borderRadius(2)
    .backgroundColor('#00FF00')
    .position({
      x: this.percentLength(this.poseLineStyle(line).startX),
      y: this.percentLength(this.poseLineStyle(line).startY)
    })
    .rotate({
      x: 0,
      y: 0,
      z: 1,
      angle: this.poseLineStyle(line).angle,
      centerX: 0,
      centerY: 1.5
    })
  }

  @Builder
  poseNetStillPosePoint(point: PosePoint) {
    Column() {
    }
    .width(8)
    .height(8)
    .borderRadius(4)
    .backgroundColor('#FF0000')
    .position({
      x: this.percentLength(this.posePointStyle(point).x),
      y: this.percentLength(this.posePointStyle(point).y)
    })
  }

  @Builder
  poseNetStillAndroidPreview() {
    Stack({ alignContent: Alignment.TopStart }) {
      if (this.poseImageUri.length > 0 && this.posePoints.length > 0) {
        Stack({ alignContent: Alignment.TopStart }) {
          Image(this.poseImageUri)
            .orientation(this.poseImageOrientation)
            .width('100%')
            .height('100%')
            .objectFit(ImageFit.Fill)
          ForEach(this.poseLines(), (line: PoseLine) => {
            this.poseNetStillPoseLine(line)
          }, (line: PoseLine) => `${line.start.type}-${line.end.type}-${line.start.x}-${line.start.y}`)
          ForEach(this.visiblePosePoints(), (point: PosePoint) => {
            this.poseNetStillPosePoint(point)
          }, (point: PosePoint) => `${point.type}-${point.x}-${point.y}-${point.score}`)
        }
        .width('100%')
        .aspectRatio(this.poseAspectRatio())
        .clip(true)
      } else if (this.imageInputUri.length > 0) {
        Image(this.imageInputUri)
          .width('100%')
          .objectFit(ImageFit.Contain)
      }
    }
    .width('100%')
    .layoutWeight(9)
    .clip(true)
    .backgroundColor('#E6E6E6')
  }

  @Builder
  poseNetStillAndroidLayout() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column() {
        this.runtimeActionToolbar(false)
        Row() {
        }
        .width('100%')
        .height(1)
        .backgroundColor('#E4E4E4')
        this.poseNetStillAndroidPreview()
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
          Button(appString('feature_runtime_pose_detect_android'), { type: ButtonType.Normal })
            .layoutWeight(1)
            .height(37)
            .margin({ left: 5, right: 5 })
            .fontSize(14)
            .fontWeight(FontWeight.Normal)
            .fontColor('#666666')
            .backgroundColor('#F4F3F8')
            .borderRadius(5)
            .enabled(this.runActionEnabled())
            .onClick(() => this.runPoseNetSampleDetection())
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

In `build()`, add this branch immediately before the Gesture still branch:

```ts
    } else if (usesAndroidPoseNetStillLayout(workflowForRoute(this.routeName))) {
      this.poseNetStillAndroidLayout()
```

- [ ] **Step 5: Wire the guard and document the parity closure**

Add this line after the static Gesture guard in `scripts/build-hap.ps1`:

```powershell
& (Join-Path $PSScriptRoot 'check-posenet-still-layout-parity.ps1')
```

Append these bullets to the PoseNet section of
`docs/harmonyos-platform-differences.md`:

```markdown
- The still PoseNet route now uses Android's dedicated single-preview layout:
  Back/title toolbar, one divider, a weight-9 gray image/skeleton surface, and
  the weight-1 Photo, Camera, Real-time, Detect action row.
- Detect restores the packaged `posenet/skeleton_image.JPG` through the
  existing initial-preview contract before running the existing pose workflow.
  Photo and Camera keep automatic detection, and Real-time keeps the linked
  Live Skeleton route.
- Current PoseNet still results show localized Android-style success/failure
  Toasts. Permission denial remains on the recovery overlay. The dedicated
  route no longer renders generic summary, input, permission, URI, status,
  result, or debug cards.
- Real-device letterboxing, EXIF direction, overlay thickness, Toast display,
  and picker/camera feel remain deferred; models and inference code are
  unchanged.
```

- [ ] **Step 6: Run the focused guard and Hypium**

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\check-posenet-still-layout-parity.ps1
& 'C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat' test --no-daemon
Get-Content .\entry\.test\default\intermediates\test\coverage_data\test_result.txt -Tail 1
```

Expected: guard PASS and `Tests run: 485, Failure: 0, Error: 0, Pass: 485, Ignore: 0`.

- [ ] **Step 7: Run full acceptance and inspect scope**

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\build-ai-runtime-acceptance.ps1
git diff --check
git status --short
git diff --name-status HEAD
```

Expected: main HAP and ohosTest HAP BUILD SUCCESSFUL, AI runtime payload/native/model checks PASS, no whitespace errors, and no pose model/native/service files changed.

- [ ] **Step 8: Commit and request two-stage review**

```powershell
git add -- Mindspore_inhand_HarmonyOS/entry/src/main/ets/pages/FeatureRuntimePage.ets Mindspore_inhand_HarmonyOS/scripts/check-posenet-still-layout-parity.ps1 Mindspore_inhand_HarmonyOS/scripts/build-hap.ps1 docs/harmonyos-platform-differences.md
git commit -m "fix: match android posenet still layout"
```

Request one spec-compliance review and one whole-branch review. Fix all Critical and Important findings and any focused Minor regression-guard finding before merging to `master`.

### Task 3: Integrate and clean up

**Files:** None beyond merge metadata.

**Interfaces:**

- Consumes: reviewed Task 1 and Task 2 commits.
- Produces: verified `master` with no temporary worktree or feature branch.

- [ ] **Step 1: Merge the reviewed branch into `master`**

Use a fast-forward merge when `master` has not moved; otherwise use Git's normal merge only after confirming the intervening files do not conflict with the PoseNet scope.

- [ ] **Step 2: Re-run merged acceptance**

From `Mindspore_inhand_HarmonyOS` on `master`, run:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\check-posenet-still-layout-parity.ps1
& 'C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat' test --no-daemon
powershell -ExecutionPolicy Bypass -File .\scripts\build-ai-runtime-acceptance.ps1
git diff --check
```

Expected: guard PASS, 485/485 Hypium PASS, unified HAP acceptance PASS, and no whitespace errors.

- [ ] **Step 3: Remove the merged worktree and branch**

Use `git worktree remove`, `git worktree prune`, and `git branch -d`. If Windows long paths leave physical files after Git unregisters the worktree, verify the resolved path is under the repository `.worktrees` directory before deleting it with the Windows extended-length path API.

- [ ] **Step 4: Confirm final repository state**

```powershell
git worktree list --porcelain
git branch --format='%(refname:short)'
git status --short
git log -6 --oneline --decorate
```

Expected: only the main worktree remains, the temporary PoseNet branch is absent, `master` is clean, and the reviewed commits are reachable from `master`.
