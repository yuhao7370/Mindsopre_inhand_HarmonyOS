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
$buildScriptPath = Join-Path $SourceRoot 'scripts\build-hap.ps1'
$buildScript = Get-NormalizedText $buildScriptPath

$selector = Get-TextSection $catalog 'export function usesAndroidStillSceneLayout' `
  'export function stillSceneResultToastKey' 'exact still-scene selector'
Assert-CodeLine $selector 'return workflow?.routeName === AppRoute.SCENE_STILL.name;' `
  'selector must target only SCENE_STILL.'
if (([regex]::Matches($selector, 'AppRoute\.')).Count -ne 1) {
  throw 'Still scene parity guard failed: selector must contain exactly one route target.'
}

$toastPolicy = Get-TextSection $catalog 'export function stillSceneResultToastKey' `
  'export function shouldPreserveRuntimeTextResultOnAiResult' 'still-scene Toast policy'
Assert-CodeLine $toastPolicy "return usesAndroidStillSceneLayout(workflow) && resultCode === 'SCENE_DETECTION_FAILED' ?" `
  'Toast policy must be exact-route and empty-code-only.'
Assert-CodeLine $toastPolicy "'feature_runtime_scene_failed' : undefined;" `
  'empty results must use the existing failure Toast.'
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
  'ForEach(this.resultRows, (row: AiRunResultRow) => {',
  'Text() {',
  'Span(appString(row.labelKey))',
  "Span('\uFF1A')",
  'Span(this.resultRowValue(row))',
  '.fontSize(14)',
  '.layoutWeight(1)',
  '.margin({ left: 20, right: 20, top: 14 })',
  ".width('100%')",
  ".height('100%')",
  '.backgroundColor(Color.White)'
)) { Assert-CodeLine $builder $line "dedicated builder is missing executable line: $line." }
Assert-Excludes $builder '.margin({ left: 4 })' 'result text must not add spacing around the Android full-width colon'
Assert-Excludes $builder '.margin({ bottom: 8 })' 'result lines must not add spacing absent from Android TextView output'
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

$pickWrapper = Get-TextSection $page '  private prepareInput(' "`n`n  private async prepareInputAsync" 'shared input wrapper'
Assert-Excludes $pickWrapper 'shouldAllowRuntimeInputChange' `
  'synchronous wrapper must preserve sibling request-id invalidation semantics'
$pickController = Get-TextSection $page '  private async prepareInputAsync(' `
  "`n`n  private async cacheAndApplyPickedModelFile" 'shared async input controller'
Assert-CodeLine $pickController 'if (!shouldAllowRuntimeInputChange(workflow, inputKind, this.workflowRunning)) {' `
  'photo/camera input controller must enforce the pure running policy before its first await.'
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
Assert-CodeLine $run 'if (!shouldPreserveRuntimeTextResultOnAiResult(workflow, false)) {' `
  'permission denial must preserve the prior still-scene result.'
Assert-CodeLine $run 'await this.applyAiResult(result, runtimeRequestId);' 'run lifecycle must await result application.'
$failure = Get-TextSection $page '  private applyRuntimeFailure(): void {' `
  "`n`n  private async prepareLiveFrameImageInput" 'thrown-runtime failure flow'
Assert-CodeLine $failure 'if (!shouldPreserveRuntimeTextResultOnAiResult(workflow, false)) {' `
  'thrown runtime failure must preserve the prior still-scene result.'
Assert-Excludes $failure 'showStillSceneFailureToastIfNeeded' 'thrown runtime failure must remain silent'
$apply = Get-TextSection $page '  private async applyAiResult(' `
  "`n`n  private showObjectPhotoFailureToastIfNeeded" 'AI result application'
Assert-CodeLine $apply "if (usesAndroidStillSceneLayout(workflow) && result.ok && result.data?.kind === 'scenes') {" `
  'Android row replacement must be gated to successful still-scene scene data.'
$stillResult = Get-TextSection $apply `
  "    if (usesAndroidStillSceneLayout(workflow) && result.ok && result.data?.kind === 'scenes') {" `
  "`n    if (!this.shouldPreserveVisualResultsOnAiResult(result)) {" 'successful still-scene row replacement'
Assert-CodeLine $stillResult 'this.resultRows = androidStillSceneResultRows(result.data.result);' `
  'successful current still-scene results must replace rows with the Android adapter.'
Assert-CodeLine $apply 'this.showStillSceneFailureToastIfNeeded(result.code);' `
  'completed AI results must reach the empty-only Toast policy.'
Assert-CodeLine $apply 'if (!shouldPreserveRuntimeTextResultOnAiResult(workflow, result.ok)) {' `
  'failed results must preserve the prior text rows.'

$toastHelper = Get-TextSection $page '  private showStillSceneFailureToastIfNeeded(' `
  "`n`n  private showObjectPhotoFailureToastIfNeeded" 'still-scene Toast helper'
Assert-CodeLine $toastHelper 'const toastKey = stillSceneResultToastKey(workflowForRoute(this.routeName), resultCode);' `
  'Toast helper must use the route/code policy.'
Assert-CodeLine $toastHelper 'this.showRuntimeToast(toastKey);' 'mapped empty results must use the existing Toast path.'

$rowAdapter = Get-TextSection $aiService 'export function androidStillSceneResultRows(' `
  "`n`nfunction androidSceneScorePercent" 'Android still-scene row adapter'
foreach ($line in @(
  'resultRow(''feature_runtime_result_scene_count'', `${result.scenes.length}`)',
  "rows.push(resultRow('feature_runtime_scene_overlay_scene', scene.label));",
  "rows.push(resultRow('feature_runtime_scene_overlay_score', androidSceneScorePercent(scene.score)));"
)) {
  Assert-CodeLine $rowAdapter $line "row adapter is missing executable Android row line: $line."
}
Assert-Excludes $rowAdapter 'feature_runtime_result_scenes' 'row adapter must not collapse Scene and Score rows'
Assert-Excludes $rowAdapter 'feature_runtime_result_image' 'row adapter must omit image path'
Assert-Excludes $rowAdapter 'feature_runtime_result_execution_time' 'row adapter must omit execution time'
$detectScene = Get-TextSection $aiService '  private async detectScene(' "`n`n  private async detectPose" 'scene AI result mapping'
Assert-CodeLine $detectScene "code: result.failureKind === 'runtime' ?" `
  'AiService must branch scene failure code on runtime provenance.'
Assert-CodeLine $detectScene "'SCENE_DETECTION_RUNTIME_FAILED' : 'SCENE_DETECTION_FAILED'," `
  'AiService must expose distinct runtime and empty result codes.'
Assert-CodeLine $sceneService "failureKind: scenes.length === 0 ? 'empty' : undefined," `
  'scene service must preserve empty-result provenance.'
Assert-CodeLine $sceneService "failureKind: 'runtime'," `
  'scene service must preserve runtime-failure provenance.'

$buildStart = $page.IndexOf(
  "  @Builder`n  runtimeLayoutContent() {",
  [StringComparison]::Ordinal
)
if ($buildStart -lt 0) { throw 'Still scene parity guard failed: runtime layout selector was not found.' }
$buildSelection = $page.Substring($buildStart)
$stillSelector = '} else if (usesAndroidStillSceneLayout(workflowForRoute(this.routeName))) {'
$stillIndex = Get-CodeLineIndex $buildSelection $stillSelector
$portraitSelector = '} else if (usesAndroidPortraitSegmentationLayout(workflowForRoute(this.routeName))) {'
$portraitIndex = Get-CodeLineIndex $buildSelection $portraitSelector ($stillIndex + 1)
$fallbackIndex = Get-CodeLineIndex $buildSelection '} else {' ($portraitIndex + 1)
if ($stillIndex -lt 0 -or $portraitIndex -le $stillIndex -or $fallbackIndex -le $portraitIndex) {
  throw 'Still scene parity guard failed: dedicated selector must precede generic fallback.'
}
$stillBranch = $buildSelection.Substring($stillIndex, $portraitIndex - $stillIndex)
Assert-CodeLine $stillBranch 'this.stillSceneAndroidLayout()' 'selector must render the dedicated builder.'
$branchBuilderCalls = [regex]::Matches($stillBranch, '(?m)^[\t ]*this\.\w+AndroidLayout\(\)[\t ]*$')
if ($branchBuilderCalls.Count -ne 1 -or $branchBuilderCalls[0].Value.Trim() -ne 'this.stillSceneAndroidLayout()') {
  throw 'Still scene parity guard failed: still-scene selector must not render a sibling builder.'
}

foreach ($call in @(
  "& (Join-Path `$PSScriptRoot 'check-still-scene-layout-parity.ps1')",
  "& (Join-Path `$PSScriptRoot 'test-still-scene-layout-parity-guard.ps1')"
)) {
  if (([regex]::Matches($buildScript, "(?m)^[\t ]*$([regex]::Escape($call))[\t ]*$")).Count -ne 1) {
    throw "Still scene parity guard failed: build-hap must execute exactly one top-level guard call: $call"
  }
}
$tokens = $null
$parseErrors = $null
$ast = [Management.Automation.Language.Parser]::ParseFile($buildScriptPath, [ref]$tokens, [ref]$parseErrors)
if ($parseErrors.Count -ne 0) { throw 'Still scene parity guard failed: build-hap.ps1 must parse cleanly.' }
foreach ($call in @(
  "& (Join-Path `$PSScriptRoot 'check-still-scene-layout-parity.ps1')",
  "& (Join-Path `$PSScriptRoot 'test-still-scene-layout-parity-guard.ps1')"
)) {
  $topLevel = @($ast.EndBlock.Statements | Where-Object {
      $_.Extent.Text.Replace("`r`n", "`n").Trim() -eq $call
    })
  if ($topLevel.Count -ne 1) {
    throw "Still scene parity guard failed: build-hap must execute one top-level guard call: $call"
  }
}

Write-Output 'Still scene Android layout/state parity checks passed.'
