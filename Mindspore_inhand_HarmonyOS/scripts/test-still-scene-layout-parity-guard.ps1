$ErrorActionPreference = 'Stop'

$guardPath = Join-Path $PSScriptRoot 'check-still-scene-layout-parity.ps1'
$tempParent = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd(
  [IO.Path]::DirectorySeparatorChar,
  [IO.Path]::AltDirectorySeparatorChar
)
$tempRoot = [IO.Path]::GetFullPath((Join-Path $tempParent ("mindspore-still-scene-guard-" + [guid]::NewGuid().ToString('N'))))
$tempPrefix = $tempParent + [IO.Path]::DirectorySeparatorChar
$utf8 = [Text.UTF8Encoding]::new($false)
if (-not $tempRoot.StartsWith($tempPrefix, [StringComparison]::OrdinalIgnoreCase)) {
  throw 'Still scene guard fixture refused an unsafe temporary path.'
}

function Normalize-Newlines([string]$Text) {
  return $Text.Replace("`r`n", "`n").Replace("`r", "`n")
}

function Write-FixtureFile([string]$Root, [string]$RelativePath, [string]$Text) {
  $path = Join-Path $Root $RelativePath
  [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($path)) | Out-Null
  $crlf = (Normalize-Newlines $Text).Replace("`n", "`r`n")
  [IO.File]::WriteAllText($path, $crlf, $utf8)
}

function New-ValidFixture([string]$Root) {
  Write-FixtureFile $Root 'entry\src\main\ets\features\runtime\FeatureWorkflowCatalog.ets' @'
export function usesAndroidStillSceneLayout(workflow: FeatureWorkflow | undefined): boolean {
  return workflow?.routeName === AppRoute.SCENE_STILL.name;
}

export function stillSceneResultToastKey(workflow: FeatureWorkflow | undefined, resultCode: string): AppStringKey | undefined {
  return usesAndroidStillSceneLayout(workflow) && resultCode === 'SCENE_DETECTION_FAILED' ?
    'feature_runtime_scene_failed' : undefined;
}

export function shouldPreserveRuntimeTextResultOnAiResult(workflow: FeatureWorkflow | undefined, resultOk: boolean): boolean {
  return usesAndroidStillSceneLayout(workflow) && !resultOk;
}
'@

  Write-FixtureFile $Root 'entry\src\main\ets\services\ai\SceneDetectionService.ets' @'
function emptySceneResult(): SceneDetectionResult {
  const scenes: Array<SceneDetection> = [];
  return {
    ok: false,
    scenes: scenes,
    failureKind: scenes.length === 0 ? 'empty' : undefined,
    executionMs: 0
  };
}

function runtimeSceneResult(): SceneDetectionResult {
  return {
    ok: false,
    scenes: [],
    failureKind: 'runtime',
    executionMs: 0
  };
}
'@

  Write-FixtureFile $Root 'entry\src\main\ets\services\ai\AiService.ets' @'
type AiRunCode = 'SCENE_DETECTION_FAILED' | 'SCENE_DETECTION_RUNTIME_FAILED';

class DefaultAiService {
  private async detectScene(inputs: AiRunInputs): Promise<AiRunResult> {
    const result: SceneDetectionResult = await this.sceneDetectionService.detectScenes(inputs.imageUri ?? '');
    return {
      ok: false,
      code: result.failureKind === 'runtime' ?
        'SCENE_DETECTION_RUNTIME_FAILED' : 'SCENE_DETECTION_FAILED',
      aiMethod: 'detectScene'
    };
  }

  private async detectPose(inputs: AiRunInputs): Promise<AiRunResult> {
    return { ok: false };
  }
}

export function androidStillSceneResultRows(result: SceneDetectionResult): Array<AiRunResultRow> {
  const rows: Array<AiRunResultRow> = [
    resultRow('feature_runtime_result_scene_count', `${result.scenes.length}`)
  ];
  result.scenes.forEach((scene: SceneDetection) => {
    rows.push(resultRow('feature_runtime_scene_overlay_scene', scene.label));
    rows.push(resultRow('feature_runtime_scene_overlay_score', androidSceneScorePercent(scene.score)));
  });
  return rows;
}

function androidSceneScorePercent(score: number): string {
  return `${score}`;
}

export function sceneDetectionOverlayRows(result: SceneDetectionResult): Array<SceneDetectionOverlayRow> {
  return [];
}
'@

  Write-FixtureFile $Root 'entry\src\main\ets\pages\FeatureRuntimePage.ets' @'
  private prepareInput(inputKind: FeatureInputKind): void {
    const requestId = ++this.inputPreparationRequestId;
    this.prepareInputAsync(inputKind, false, requestId);
  }

  private async prepareInputAsync(inputKind: FeatureInputKind, initialPick: boolean, requestId: number): Promise<void> {
    const workflow = workflowForRoute(this.routeName);
    if (!shouldAllowRuntimeInputChange(workflow, inputKind, this.workflowRunning)) {
      return;
    }
  }

  private async cacheAndApplyPickedModelFile(): Promise<void> {
  }

  private applyPickResult(inputKind: FeatureInputKind): void {
    const workflow = workflowForRoute(this.routeName);
    if (!shouldPreserveRuntimeResultAfterInputReady(workflow, inputKind)) {
      this.resultRows = [];
    }
  }

  private aiRunInputs(): AiRunInputs {
    return {};
  }

  private async runWorkflowAsync(runtimeRequestId: number): Promise<void> {
    const workflow = workflowForRoute(this.routeName);
    if (shouldClearRuntimeResultAtWorkflowStart(workflow)) {
      this.resultRows = [];
    }
    if (!permission.ok) {
      if (!shouldPreserveRuntimeTextResultOnAiResult(workflow, false)) {
        this.resultRows = [];
      }
      return;
    }
    await this.applyAiResult(result, runtimeRequestId);
  }

  private applyRuntimeFailure(): void {
    const workflow = workflowForRoute(this.routeName);
    if (!shouldPreserveRuntimeTextResultOnAiResult(workflow, false)) {
      this.resultRows = [];
    }
  }

  private async prepareLiveFrameImageInput(): Promise<void> {
  }

  private async applyAiResult(result: AiRunResult, runtimeRequestId: number): Promise<void> {
    const workflow = workflowForRoute(this.routeName);
    if (!shouldPreserveRuntimeTextResultOnAiResult(workflow, result.ok)) {
      this.resultRows = [];
    }
    if (usesAndroidStillSceneLayout(workflow) && result.ok && result.data?.kind === 'scenes') {
      this.resultRows = androidStillSceneResultRows(result.data.result);
    }
    if (!this.shouldPreserveVisualResultsOnAiResult(result)) {
    }
    this.showStillSceneFailureToastIfNeeded(result.code);
  }

  private showStillSceneFailureToastIfNeeded(resultCode: string): void {
    const toastKey = stillSceneResultToastKey(workflowForRoute(this.routeName), resultCode);
    if (toastKey !== undefined) {
      this.showRuntimeToast(toastKey);
    }
  }

  private showObjectPhotoFailureToastIfNeeded(resultOk: boolean): void {
  }

  private openStillSceneLiveRoute(): void {
    if (this.workflowRunning) {
      return;
    }
    this.openLinkedLiveRoute();
  }

  private openLinkedLiveRoute(): void {
  }

  @Builder
  stillSceneAndroidLayout() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column() {
        this.runtimeActionToolbar(false)
        Row() {
        }
        .width('100%')
        .height(1)
        .backgroundColor('#E4E4E4')
        Stack({ alignContent: Alignment.Center }) {
          if (this.imageInputUri.length > 0) {
            Image(this.imageInputUri)
              .width(266)
              .height(356)
              .objectFit(ImageFit.Fill)
          } else {
            Column({ space: 10 }) {
              Image($r('app.media.icon_style'))
                .width(69.33)
                .height(56.33)
              Text(appString('workflow_summary_scene_still_android_prompt'))
                .fontSize(16)
                .fontColor('#666666')
            }
          }
        }
        .width('100%')
        .height(376)
        .backgroundColor('#E6E6E6')
        Row() {
          Button(appString('feature_input_photo_android'), { type: ButtonType.Normal })
            .layoutWeight(1)
            .height(37)
            .margin({ left: 20, right: 5 })
            .fontColor('#666666')
            .backgroundColor('#F4F3F8')
            .borderRadius(5)
            .enabled(!this.workflowRunning)
            .onClick(() => this.prepareInput('photo'))
          Button(appString('feature_input_camera_android'), { type: ButtonType.Normal })
            .layoutWeight(1)
            .height(37)
            .margin({ left: 5, right: 5 })
            .fontColor('#666666')
            .backgroundColor('#F4F3F8')
            .borderRadius(5)
            .enabled(!this.workflowRunning)
            .onClick(() => this.prepareInput('camera'))
          Button(appString('feature_runtime_go_live_android_hms'), { type: ButtonType.Normal })
            .layoutWeight(1)
            .height(37)
            .margin({ left: 5, right: 5 })
            .fontColor('#666666')
            .backgroundColor('#F4F3F8')
            .borderRadius(5)
            .enabled(!this.workflowRunning)
            .onClick(() => {
              this.openStillSceneLiveRoute()
            })
        }
        .width('100%')
        .margin({ top: 14 })
        Scroll() {
          Column() {
            ForEach(this.resultRows, (row: AiRunResultRow) => {
              Text() {
                Span(appString(row.labelKey))
                Span('\uFF1A')
                Span(this.resultRowValue(row))
              }
              .fontSize(14)
              .fontColor(Color.Black)
            })
          }
        }
        .layoutWeight(1)
        .margin({ left: 20, right: 20, top: 14 })
      }
      .width('100%')
      .height('100%')
      .backgroundColor(Color.White)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.White)
  }

  @Builder
  portraitSegmentationAndroidLayout() {
  }

  @Builder
  runtimeLayoutContent() {
    if (false) {
    } else if (usesAndroidStillSceneLayout(workflowForRoute(this.routeName))) {
      this.stillSceneAndroidLayout()
    } else if (usesAndroidPortraitSegmentationLayout(workflowForRoute(this.routeName))) {
      this.portraitSegmentationAndroidLayout()
    } else {
      Scroll() {
      }
    }
  }
'@

  Write-FixtureFile $Root 'scripts\build-hap.ps1' @'
& (Join-Path $PSScriptRoot 'check-still-scene-layout-parity.ps1')
& (Join-Path $PSScriptRoot 'test-still-scene-layout-parity-guard.ps1')
'@
}

function Copy-Fixture([string]$Source, [string]$Destination) {
  [IO.Directory]::CreateDirectory($Destination) | Out-Null
  [IO.Directory]::GetFiles($Source, '*', [IO.SearchOption]::AllDirectories) | ForEach-Object {
    $relative = $_.Substring($Source.Length).TrimStart('\', '/')
    $target = Join-Path $Destination $relative
    [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($target)) | Out-Null
    [IO.File]::Copy($_, $target, $true)
  }
}

function Replace-Once([string]$Path, [string]$Before, [string]$After) {
  $text = Normalize-Newlines ([IO.File]::ReadAllText($Path))
  $Before = Normalize-Newlines $Before
  $After = Normalize-Newlines $After
  $first = $text.IndexOf($Before, [StringComparison]::Ordinal)
  if ($first -lt 0 -or $text.IndexOf($Before, $first + $Before.Length, [StringComparison]::Ordinal) -ge 0) {
    throw "Still scene guard fixture expected one mutation target: $Before"
  }
  [IO.File]::WriteAllText(
    $Path,
    $text.Substring(0, $first) + $After + $text.Substring($first + $Before.Length),
    $utf8
  )
}

function Assert-MutationRejected([string]$ValidRoot, [string]$Name, [string]$RelativePath, [string]$Before, [string]$After) {
  $root = Join-Path $tempRoot $Name
  Copy-Fixture $ValidRoot $root
  Replace-Once (Join-Path $root $RelativePath) $Before $After
  $failed = $false
  try { & $guardPath -SourceRoot $root | Out-Null } catch { $failed = $true }
  if (-not $failed) { throw "Still scene guard fixture accepted mutation: $Name" }
}

try {
  $validRoot = Join-Path $tempRoot 'valid'
  New-ValidFixture $validRoot
  & $guardPath -SourceRoot $validRoot | Out-Null

  $catalogPath = 'entry\src\main\ets\features\runtime\FeatureWorkflowCatalog.ets'
  $pagePath = 'entry\src\main\ets\pages\FeatureRuntimePage.ets'
  $scenePath = 'entry\src\main\ets\services\ai\SceneDetectionService.ets'
  $aiPath = 'entry\src\main\ets\services\ai\AiService.ets'
  $buildPath = 'scripts\build-hap.ps1'

  Assert-MutationRejected $validRoot 'wrong-selector' $catalogPath `
    'return workflow?.routeName === AppRoute.SCENE_STILL.name;' `
    'return workflow?.routeName === AppRoute.SCENE_LIVE.name;'
  Assert-MutationRejected $validRoot 'selector-string-decoy' $catalogPath `
    'return workflow?.routeName === AppRoute.SCENE_STILL.name;' `
    "const selectorDecoy = 'return workflow?.routeName === AppRoute.SCENE_STILL.name;'; return false;"
  Assert-MutationRejected $validRoot 'toolbar-comment-decoy' $pagePath `
    'this.runtimeActionToolbar(false)' `
    '// this.runtimeActionToolbar(false)'
  Assert-MutationRejected $validRoot 'wrong-preview-dimensions' $pagePath `
    ".width(266)`r`n              .height(356)" `
    ".width(265)`n              .height(355)"
  Assert-MutationRejected $validRoot 'wrong-frame-color' $pagePath `
    ".backgroundColor('#E6E6E6')" `
    ".backgroundColor('#E5E5E5')"
  Assert-MutationRejected $validRoot 'wrong-prompt-color' $pagePath `
    "Text(appString('workflow_summary_scene_still_android_prompt'))`n                .fontSize(16)`n                .fontColor('#666666')" `
    "Text(appString('workflow_summary_scene_still_android_prompt'))`n                .fontSize(16)`n                .fontColor('#333333')"
  Assert-MutationRejected $validRoot 'wrong-photo-margin' $pagePath `
    '.margin({ left: 20, right: 5 })' `
    '.margin({ left: 5, right: 5 })'
  Assert-MutationRejected $validRoot 'wrong-action-order' $pagePath `
    ".onClick(() => this.prepareInput('photo'))" `
    ".onClick(() => this.prepareInput('camera'))"
  Assert-MutationRejected $validRoot 'missing-running-disable' $pagePath `
    ".enabled(!this.workflowRunning)`n            .onClick(() => this.prepareInput('photo'))" `
    ".enabled(true)`n            .onClick(() => this.prepareInput('photo'))"
  Assert-MutationRejected $validRoot 'missing-live-handler-guard' $pagePath `
    "if (this.workflowRunning) {`n      return;`n    }`n    this.openLinkedLiveRoute();" `
    'this.openLinkedLiveRoute();'
  Assert-MutationRejected $validRoot 'missing-input-handler-policy' $pagePath `
    'if (!shouldAllowRuntimeInputChange(workflow, inputKind, this.workflowRunning)) {' `
    'if (false) {'
  Assert-MutationRejected $validRoot 'sibling-sync-input-semantics' $pagePath `
    'const requestId = ++this.inputPreparationRequestId;' `
    "if (!shouldAllowRuntimeInputChange(workflowForRoute(this.routeName), inputKind, this.workflowRunning)) { return; }`n    const requestId = ++this.inputPreparationRequestId;"
  Assert-MutationRejected $validRoot 'generic-loading-injected' $pagePath `
    'this.runtimeActionToolbar(false)' `
    "this.runtimeActionToolbar(false)`n      LoadingProgress()"
  Assert-MutationRejected $validRoot 'combined-scene-rows' $aiPath `
    "rows.push(resultRow('feature_runtime_scene_overlay_scene', scene.label));" `
    "rows.push(resultRow('feature_runtime_result_scenes', scene.label));"
  Assert-MutationRejected $validRoot 'missing-android-colon' $pagePath `
    "Span('\uFF1A')" `
    "Span('')"
  Assert-MutationRejected $validRoot 'missing-runtime-provenance' $scenePath `
    "failureKind: 'runtime'" `
    "failureKind: 'empty'"
  Assert-MutationRejected $validRoot 'runtime-provenance-string-decoy' $scenePath `
    "failureKind: 'runtime',`n    executionMs: 0" `
    "failureKind: 'empty',`n    provenanceDecoy: \"failureKind: 'runtime',\",`n    executionMs: 0"
  Assert-MutationRejected $validRoot 'missing-permission-preservation' $pagePath `
    "if (!permission.ok) {`n      if (!shouldPreserveRuntimeTextResultOnAiResult(workflow, false)) {" `
    "if (!permission.ok) {`n      if (true) {"
  Assert-MutationRejected $validRoot 'permission-preservation-string-decoy' $pagePath `
    "if (!permission.ok) {`n      if (!shouldPreserveRuntimeTextResultOnAiResult(workflow, false)) {" `
    "if (!permission.ok) {`n      const preservationDecoy = 'if (!shouldPreserveRuntimeTextResultOnAiResult(workflow, false)) {';`n      if (true) {"
  Assert-MutationRejected $validRoot 'runtime-failure-toasts' $catalogPath `
    "resultCode === 'SCENE_DETECTION_FAILED'" `
    "resultCode === 'SCENE_DETECTION_RUNTIME_FAILED'"
  Assert-MutationRejected $validRoot 'throw-toast-injected' $pagePath `
    "if (!shouldPreserveRuntimeTextResultOnAiResult(workflow, false)) {`n      this.resultRows = [];`n    }`n  }`n`n  private async prepareLiveFrameImageInput" `
    "if (!shouldPreserveRuntimeTextResultOnAiResult(workflow, false)) {`n      this.resultRows = [];`n    }`n    this.showStillSceneFailureToastIfNeeded('SCENE_DETECTION_RUNTIME_FAILED');`n  }`n`n  private async prepareLiveFrameImageInput"
  Assert-MutationRejected $validRoot 'missing-successful-row-replacement' $pagePath `
    'this.resultRows = androidStillSceneResultRows(result.data.result);' `
    "const rowDecoy = 'this.resultRows = androidStillSceneResultRows(result.data.result);';"
  Assert-MutationRejected $validRoot 'ungated-successful-row-replacement' $pagePath `
    "if (usesAndroidStillSceneLayout(workflow) && result.ok && result.data?.kind === 'scenes') {" `
    'if (true) {'
  Assert-MutationRejected $validRoot 'swapped-still-scene-builder' $pagePath `
    "} else if (usesAndroidStillSceneLayout(workflowForRoute(this.routeName))) {`n      this.stillSceneAndroidLayout()`n    } else if (usesAndroidPortraitSegmentationLayout(workflowForRoute(this.routeName))) {`n      this.portraitSegmentationAndroidLayout()" `
    "} else if (usesAndroidStillSceneLayout(workflowForRoute(this.routeName))) {`n      this.portraitSegmentationAndroidLayout()`n    } else if (usesAndroidPortraitSegmentationLayout(workflowForRoute(this.routeName))) {`n      this.stillSceneAndroidLayout()"
  Assert-MutationRejected $validRoot 'missing-production-build-wire' $buildPath `
    "& (Join-Path `$PSScriptRoot 'check-still-scene-layout-parity.ps1')" `
    "# & (Join-Path `$PSScriptRoot 'check-still-scene-layout-parity.ps1')"
  Assert-MutationRejected $validRoot 'nested-production-build-wire' $buildPath `
    "& (Join-Path `$PSScriptRoot 'check-still-scene-layout-parity.ps1')" `
    "function Invoke-StillSceneGuard {`n  & (Join-Path `$PSScriptRoot 'check-still-scene-layout-parity.ps1')`n}"
  Assert-MutationRejected $validRoot 'herestring-fixture-build-wire' $buildPath `
    "& (Join-Path `$PSScriptRoot 'test-still-scene-layout-parity-guard.ps1')" `
    "`$guardDecoy = @'`n& (Join-Path `$PSScriptRoot 'test-still-scene-layout-parity-guard.ps1')`n'@"

  Write-Output 'Still scene layout parity guard mutation fixtures passed.'
} finally {
  if ([IO.Directory]::Exists($tempRoot)) {
    $resolved = [IO.Path]::GetFullPath($tempRoot)
    if (-not $resolved.StartsWith($tempPrefix, [StringComparison]::OrdinalIgnoreCase)) {
      throw 'Still scene guard fixture refused unsafe cleanup.'
    }
    [IO.Directory]::Delete($resolved, $true)
  }
}
