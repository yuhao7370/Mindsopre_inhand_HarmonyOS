param(
  [string]$SourceRoot = ''
)

$ErrorActionPreference = 'Stop'

function Get-NormalizedText([string]$Path) {
  return ([IO.File]::ReadAllText($Path)).Replace("`r`n", "`n").Replace("`r", "`n")
}

function Remove-ArkTsCommentsAndTemplateRaw([string]$Text) {
  $result = [Text.StringBuilder]::new($Text.Length)
  $state = 'code'
  $terminator = [char]0
  $escaped = $false
  $interpolationDepths = [Collections.Generic.List[int]]::new()
  for ($index = 0; $index -lt $Text.Length; $index++) {
    $current = $Text[$index]
    $next = if ($index + 1 -lt $Text.Length) { $Text[$index + 1] } else { [char]0 }
    if ($state -eq 'lineComment') {
      if ($current -eq [char]0x0A) { [void]$result.Append($current); $state = 'code' } else { [void]$result.Append(' ') }
      continue
    }
    if ($state -eq 'blockComment') {
      if ($current -eq [char]0x2A -and $next -eq [char]0x2F) {
        [void]$result.Append('  '); $index++; $state = 'code'
      } elseif ($current -eq [char]0x0A) { [void]$result.Append($current) } else { [void]$result.Append(' ') }
      continue
    }
    if ($state -eq 'quotedLiteral') {
      [void]$result.Append($current)
      if ($escaped) { $escaped = $false }
      elseif ($current -eq [char]0x5C) { $escaped = $true }
      elseif ($current -eq $terminator) { $state = 'code' }
      continue
    }
    if ($state -eq 'templateRaw') {
      if ($escaped) { [void]$result.Append(' '); $escaped = $false }
      elseif ($current -eq [char]0x5C) { [void]$result.Append(' '); $escaped = $true }
      elseif ($current -eq [char]0x0A) { [void]$result.Append($current) }
      elseif ($current -eq [char]0x60) { [void]$result.Append($current); $state = 'code' }
      elseif ($current -eq [char]0x24 -and $next -eq [char]0x7B) {
        [void]$result.Append('${'); $index++; $interpolationDepths.Add(1); $state = 'code'
      } else { [void]$result.Append(' ') }
      continue
    }
    if ($current -eq [char]0x2F -and $next -eq [char]0x2F) {
      [void]$result.Append('  '); $index++; $state = 'lineComment'
    } elseif ($current -eq [char]0x2F -and $next -eq [char]0x2A) {
      [void]$result.Append('  '); $index++; $state = 'blockComment'
    } elseif ($current -eq [char]0x27 -or $current -eq [char]0x22) {
      [void]$result.Append($current); $terminator = $current; $escaped = $false; $state = 'quotedLiteral'
    } elseif ($current -eq [char]0x60) {
      [void]$result.Append($current); $escaped = $false; $state = 'templateRaw'
    } elseif ($interpolationDepths.Count -gt 0 -and $current -eq [char]0x7B) {
      $last = $interpolationDepths.Count - 1; $interpolationDepths[$last]++; [void]$result.Append($current)
    } elseif ($interpolationDepths.Count -gt 0 -and $current -eq [char]0x7D) {
      $last = $interpolationDepths.Count - 1; $interpolationDepths[$last]--; [void]$result.Append($current)
      if ($interpolationDepths[$last] -eq 0) { $interpolationDepths.RemoveAt($last); $state = 'templateRaw' }
    } else { [void]$result.Append($current) }
  }
  return $result.ToString()
}

function Get-TextSection([string]$Text, [string]$Start, [string]$End, [string]$Description) {
  $startIndex = $Text.IndexOf($Start, [StringComparison]::Ordinal)
  $endIndex = if ($startIndex -ge 0) { $Text.IndexOf($End, $startIndex + $Start.Length, [StringComparison]::Ordinal) } else { -1 }
  if ($startIndex -lt 0 -or $endIndex -le $startIndex) {
    throw "Still scene parity guard failed: $Description was not found."
  }
  return $Text.Substring($startIndex, $endIndex - $startIndex)
}

function Test-CodeLine([string]$Text, [string]$Line) {
  return [regex]::IsMatch($Text, "(?m)^[\t ]*$([regex]::Escape($Line))[\t ]*$")
}

function Assert-CodeLine([string]$Text, [string]$Line, [string]$Message) {
  if (-not (Test-CodeLine $Text $Line)) { throw "Still scene parity guard failed: $Message" }
}

function Assert-CodeLineCount([string]$Text, [string]$Line, [int]$Expected, [string]$Message) {
  $actual = [regex]::Matches($Text, "(?m)^[\t ]*$([regex]::Escape($Line))[\t ]*$").Count
  if ($actual -ne $Expected) { throw "Still scene parity guard failed: $Message Expected $Expected, found $actual." }
}

function Assert-Contains([string]$Text, [string]$Marker, [string]$Message) {
  if (-not $Text.Contains($Marker)) { throw "Still scene parity guard failed: $Message" }
}

function Assert-Excludes([string]$Text, [string]$Marker, [string]$Message) {
  if ($Text.Contains($Marker)) { throw "Still scene parity guard failed: $Message ($Marker)." }
}

function Get-CodeLineIndex([string]$Text, [string]$Line, [int]$StartAt = 0) {
  $match = [regex]::new("^[\t ]*$([regex]::Escape($Line))[\t ]*$", [Text.RegularExpressions.RegexOptions]::Multiline).Match($Text, $StartAt)
  return $(if ($match.Success) { $match.Index } else { -1 })
}

if ([string]::IsNullOrWhiteSpace($SourceRoot)) { $SourceRoot = Split-Path -Parent $PSScriptRoot }
$SourceRoot = [IO.Path]::GetFullPath($SourceRoot)
$catalog = Remove-ArkTsCommentsAndTemplateRaw (Get-NormalizedText (Join-Path $SourceRoot 'entry\src\main\ets\features\runtime\FeatureWorkflowCatalog.ets'))
$page = Remove-ArkTsCommentsAndTemplateRaw (Get-NormalizedText (Join-Path $SourceRoot 'entry\src\main\ets\pages\FeatureRuntimePage.ets'))
$sceneService = Remove-ArkTsCommentsAndTemplateRaw (Get-NormalizedText (Join-Path $SourceRoot 'entry\src\main\ets\services\ai\SceneDetectionService.ets'))
$aiService = Remove-ArkTsCommentsAndTemplateRaw (Get-NormalizedText (Join-Path $SourceRoot 'entry\src\main\ets\services\ai\AiService.ets'))
$buildScript = Get-NormalizedText (Join-Path $SourceRoot 'scripts\build-hap.ps1')

$selector = Get-TextSection $catalog 'export function usesAndroidStillSceneLayout' `
  'export function stillSceneResultToastKey' 'exact still-scene selector'
Assert-CodeLine $selector 'return workflow?.routeName === AppRoute.SCENE_STILL.name;' `
  'selector must target only SCENE_STILL.'
if (([regex]::Matches($selector, 'AppRoute\.')).Count -ne 1) {
  throw 'Still scene parity guard failed: selector must contain exactly one route target.'
}

$toastPolicy = Get-TextSection $catalog 'export function stillSceneResultToastKey' `
  'export function shouldPreserveRuntimeTextResultOnAiResult' 'still-scene Toast policy'
Assert-Contains $toastPolicy 'usesAndroidStillSceneLayout(workflow)' 'Toast policy must be route-scoped.'
Assert-Contains $toastPolicy "resultCode === 'SCENE_DETECTION_FAILED'" 'only the empty-result code may Toast.'
Assert-Contains $toastPolicy "'feature_runtime_scene_failed'" 'empty results must use the existing failure Toast.'
Assert-Excludes $toastPolicy "resultCode === 'SCENE_DETECTION_RUNTIME_FAILED'" 'runtime failure must not map to a Toast'

$builder = Get-TextSection $page '  stillSceneAndroidLayout() {' `
  "`n`n  @Builder`n  portraitSegmentationAndroidLayout()" 'dedicated still-scene builder'
foreach ($line in @(
  'Stack({ alignContent: Alignment.TopStart }) {',
  'this.runtimeActionToolbar(false)',
  '.height(1)',
  ".backgroundColor('#E4E4E4')",
  '.height(376)',
  ".backgroundColor('#E6E6E6')",
  'if (this.imageInputUri.length > 0) {',
  'Image(this.imageInputUri)',
  '.width(266)',
  '.height(356)',
  '.objectFit(ImageFit.Fill)',
  "Image(`$r('app.media.icon_style'))",
  '.width(69.33)',
  '.height(56.33)',
  "Text(appString('workflow_summary_scene_still_android_prompt'))",
  '.fontSize(16)',
  "Button(appString('feature_input_photo_android'), { type: ButtonType.Normal })",
  ".onClick(() => this.prepareInput('photo'))",
  "Button(appString('feature_input_camera_android'), { type: ButtonType.Normal })",
  ".onClick(() => this.prepareInput('camera'))",
  "Button(appString('feature_runtime_go_live_android_hms'), { type: ButtonType.Normal })",
  'this.openStillSceneLiveRoute()',
  '.height(37)',
  '.margin({ top: 14 })',
  ".fontColor('#666666')",
  ".backgroundColor('#F4F3F8')",
  '.borderRadius(5)',
  '.enabled(!this.workflowRunning)',
  'Scroll() {',
  'ForEach(this.resultRows, (row: AiResultRow) => {',
  '.layoutWeight(1)',
  '.margin({ left: 20, right: 20, top: 14 })',
  'this.runtimePermissionRecoveryOverlay()',
  ".width('100%')",
  ".height('100%')",
  '.backgroundColor(Color.White)'
)) { Assert-CodeLine $builder $line "dedicated builder is missing executable line: $line." }
Assert-CodeLineCount $builder '.height(37)' 3 'all three actions must be 37vp high.'
Assert-CodeLineCount $builder '.enabled(!this.workflowRunning)' 3 'all three actions must visibly disable while running.'
Assert-CodeLineCount $builder ".fontColor('#666666')" 4 'prompt and all actions must use Android neutral foreground.'
Assert-CodeLineCount $builder ".backgroundColor('#F4F3F8')" 3 'all actions must use Android neutral background.'
Assert-CodeLineCount $builder '.borderRadius(5)' 3 'all actions must use Android 5vp radius.'
Assert-CodeLineCount $builder '.margin({ left: 20, right: 5 })' 1 'Photo must use Android 20/5 margins.'
Assert-CodeLineCount $builder '.margin({ left: 5, right: 5 })' 2 'Camera and Real-time must use Android 5/5 margins.'

$photo = Get-CodeLineIndex $builder ".onClick(() => this.prepareInput('photo'))"
$camera = Get-CodeLineIndex $builder ".onClick(() => this.prepareInput('camera'))" ($photo + 1)
$live = Get-CodeLineIndex $builder 'this.openStillSceneLiveRoute()' ($camera + 1)
if ($photo -lt 0 -or $camera -le $photo -or $live -le $camera) {
  throw 'Still scene parity guard failed: actions must be Photo, Camera, Real-time.'
}

foreach ($marker in @(
  'LoadingProgress', 'this.summaryKey', "'feature_runtime_inputs_title'", "'feature_runtime_permissions_title'",
  'Text(appString(this.statusKey))', 'this.resultRow(', "'feature_runtime_result_scenes'",
  "'feature_runtime_result_image'", "'feature_runtime_result_execution_time'", 'liveCamera',
  'sceneOverlayRows', 'segmentation', 'styledImage', 'objectDetection', 'runtimeActionToolbar(true)',
  'this.runPrimaryAction()', 'SaveButton(', 'resultImageSaveControl('
)) { Assert-Excludes $builder $marker 'dedicated builder contains forbidden generic/live/sibling UI' }

$pickController = Get-TextSection $page '  private prepareInput(' "`n`n  private async prepareInputAsync" 'shared input controller'
Assert-CodeLine $pickController 'if (!shouldAllowRuntimeInputChange(workflow, inputKind, this.workflowRunning)) {' `
  'photo/camera input controller must enforce the pure running policy.'
$pickResult = Get-TextSection $page '  private applyPickResult(' "`n`n  private aiRunInputs" 'accepted-input state flow'
Assert-CodeLine $pickResult 'if (!shouldPreserveRuntimeResultAfterInputReady(workflow, inputKind)) {' `
  'accepted photo/camera input must preserve prior still-scene rows through the pure policy.'
$liveWrapper = Get-TextSection $page '  private openStillSceneLiveRoute(): void {' `
  "`n`n  private openLinkedLiveRoute" 'route-only still-scene live wrapper'
Assert-CodeLine $liveWrapper 'if (this.workflowRunning) {' 'live wrapper must reject running-state calls.'
Assert-CodeLine $liveWrapper 'this.openLinkedLiveRoute();' 'live wrapper must reuse linked-live navigation.'

$run = Get-TextSection $page '  private async runWorkflowAsync(' "`n`n  private applyRuntimeFailure" 'run/permission flow'
Assert-CodeLine $run 'if (shouldClearRuntimeResultAtWorkflowStart(workflow)) {' `
  'run start must honor the still-scene no-clear policy.'
Assert-Contains $run 'shouldPreserveRuntimeTextResultOnAiResult(workflow, false)' `
  'permission denial must preserve the prior still-scene result.'
Assert-CodeLine $run 'await this.applyAiResult(result, runtimeRequestId);' 'run lifecycle must await result application.'
$failure = Get-TextSection $page '  private applyRuntimeFailure(): void {' `
  "`n`n  private async prepareLiveFrameImageInput" 'thrown-runtime failure flow'
Assert-Contains $failure 'shouldPreserveRuntimeTextResultOnAiResult(workflow, false)' `
  'thrown runtime failure must preserve the prior still-scene result.'
Assert-Excludes $failure 'showStillSceneFailureToastIfNeeded' 'thrown runtime failure must remain silent'
$apply = Get-TextSection $page '  private async applyAiResult(' `
  "`n`n  private showObjectPhotoFailureToastIfNeeded" 'AI result application'
Assert-CodeLine $apply 'this.resultRows = androidStillSceneResultRows(result.data.result);' `
  'successful current still-scene results must replace rows with the Android adapter.'
Assert-CodeLine $apply 'this.showStillSceneFailureToastIfNeeded(result.code);' `
  'completed AI results must reach the empty-only Toast policy.'
Assert-Contains $apply 'shouldPreserveRuntimeTextResultOnAiResult(workflow, result.ok)' `
  'failed results must preserve the prior text rows.'

$toastHelper = Get-TextSection $page '  private showStillSceneFailureToastIfNeeded(' `
  "`n`n  private showObjectPhotoFailureToastIfNeeded" 'still-scene Toast helper'
Assert-CodeLine $toastHelper 'const toastKey = stillSceneResultToastKey(workflowForRoute(this.routeName), resultCode);' `
  'Toast helper must use the route/code policy.'
Assert-CodeLine $toastHelper 'this.showRuntimeToast(toastKey);' 'mapped empty results must use the existing Toast path.'

$rowAdapter = Get-TextSection $aiService 'export function androidStillSceneResultRows(' `
  "`n`nfunction androidSceneScorePercent" 'Android still-scene row adapter'
foreach ($key in @('feature_runtime_result_scene_count', 'feature_runtime_scene_overlay_scene', 'feature_runtime_scene_overlay_score')) {
  Assert-Contains $rowAdapter $key "row adapter is missing exact row key: $key."
}
Assert-Excludes $rowAdapter 'feature_runtime_result_scenes' 'row adapter must not collapse Scene and Score rows'
Assert-Excludes $rowAdapter 'feature_runtime_result_image' 'row adapter must omit image path'
Assert-Excludes $rowAdapter 'feature_runtime_result_execution_time' 'row adapter must omit execution time'
Assert-Contains $aiService "'SCENE_DETECTION_FAILED'" 'AiService must retain the empty-result code.'
Assert-Contains $aiService "'SCENE_DETECTION_RUNTIME_FAILED'" 'AiService must expose a distinct runtime-failure code.'
Assert-Contains $sceneService "failureKind: scenes.length === 0 ? 'empty' : undefined" 'scene service must preserve empty-result provenance.'
Assert-Contains $sceneService "failureKind: 'runtime'" 'scene service must preserve runtime-failure provenance.'

$buildStart = $page.IndexOf('  build() {', [StringComparison]::Ordinal)
if ($buildStart -lt 0) { throw 'Still scene parity guard failed: top-level build was not found.' }
$buildSelection = $page.Substring($buildStart)
$stillSelector = '} else if (usesAndroidStillSceneLayout(workflowForRoute(this.routeName))) {'
$stillIndex = Get-CodeLineIndex $buildSelection $stillSelector
$fallbackIndex = Get-CodeLineIndex $buildSelection '} else {' ($stillIndex + 1)
if ($stillIndex -lt 0 -or $fallbackIndex -le $stillIndex) {
  throw 'Still scene parity guard failed: dedicated selector must precede generic fallback.'
}
Assert-CodeLine $buildSelection 'this.stillSceneAndroidLayout()' 'selector must render the dedicated builder.'

foreach ($call in @(
  "& (Join-Path `$PSScriptRoot 'check-still-scene-layout-parity.ps1')",
  "& (Join-Path `$PSScriptRoot 'test-still-scene-layout-parity-guard.ps1')"
)) {
  if (([regex]::Matches($buildScript, "(?m)^[\t ]*$([regex]::Escape($call))[\t ]*$")).Count -ne 1) {
    throw "Still scene parity guard failed: build-hap must execute exactly one top-level guard call: $call"
  }
}

Write-Output 'Still scene Android layout/state parity checks passed.'
