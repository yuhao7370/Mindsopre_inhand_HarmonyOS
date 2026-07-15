param(
  [string]$SourceRoot = ''
)

$ErrorActionPreference = 'Stop'

function Get-NormalizedText([string]$Path) {
  return (Get-Content -Raw -Encoding UTF8 -LiteralPath $Path).Replace("`r`n", "`n").Replace("`r", "`n")
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

function Get-TextSection([string]$Text, [string]$StartMarker, [string]$EndMarker, [string]$Description) {
  $start = $Text.IndexOf($StartMarker, [StringComparison]::Ordinal)
  $end = if ($start -ge 0) { $Text.IndexOf($EndMarker, $start + $StartMarker.Length, [StringComparison]::Ordinal) } else { -1 }
  if ($start -lt 0 -or $end -le $start) {
    throw "Still segmentation parity guard failed: $Description was not found."
  }
  return $Text.Substring($start, $end - $start)
}

function Test-CodeLine([string]$Text, [string]$Line) {
  return [regex]::IsMatch($Text, "(?m)^[\t ]*$([regex]::Escape($Line))[\t ]*$")
}

function Assert-CodeLine([string]$Text, [string]$Line, [string]$Message) {
  if (-not (Test-CodeLine $Text $Line)) { throw "Still segmentation parity guard failed: $Message" }
}

function Assert-CodeLineCount([string]$Text, [string]$Line, [int]$Expected, [string]$Message) {
  $actual = [regex]::Matches($Text, "(?m)^[\t ]*$([regex]::Escape($Line))[\t ]*$").Count
  if ($actual -ne $Expected) { throw "Still segmentation parity guard failed: $Message Expected $Expected, found $actual." }
}

function Assert-Contains([string]$Text, [string]$Marker, [string]$Message) {
  if (-not $Text.Contains($Marker)) { throw "Still segmentation parity guard failed: $Message" }
}

function Assert-Excludes([string]$Text, [string]$Marker, [string]$Message) {
  if ($Text.Contains($Marker)) { throw "Still segmentation parity guard failed: $Message ($Marker)." }
}

function Get-CodeLineIndex([string]$Text, [string]$Line, [int]$StartAt = 0) {
  $match = [regex]::new("^[\t ]*$([regex]::Escape($Line))[\t ]*$", [Text.RegularExpressions.RegexOptions]::Multiline).Match($Text, $StartAt)
  return $(if ($match.Success) { $match.Index } else { -1 })
}

if ([string]::IsNullOrWhiteSpace($SourceRoot)) { $SourceRoot = Split-Path -Parent $PSScriptRoot }
$SourceRoot = [IO.Path]::GetFullPath($SourceRoot)
$catalog = Remove-ArkTsCommentsAndTemplateRaw (Get-NormalizedText (Join-Path $SourceRoot 'entry\src\main\ets\features\runtime\FeatureWorkflowCatalog.ets'))
$page = Remove-ArkTsCommentsAndTemplateRaw (Get-NormalizedText (Join-Path $SourceRoot 'entry\src\main\ets\pages\FeatureRuntimePage.ets'))
$build = Remove-ArkTsCommentsAndTemplateRaw (Get-NormalizedText (Join-Path $SourceRoot 'scripts\build-hap.ps1'))

$selector = Get-TextSection $catalog 'export function usesAndroidStillSegmentationLayout' `
  'export function stillSegmentationResultToastKey' 'exact still-segmentation selector'
Assert-CodeLine $selector 'return workflow?.routeName === AppRoute.SEGMENTATION_STILL.name;' `
  'selector must target only SEGMENTATION_STILL.'
if (([regex]::Matches($selector, 'AppRoute\.')).Count -ne 1) {
  throw 'Still segmentation parity guard failed: selector must contain exactly one route target.'
}

$toastPolicy = Get-TextSection $catalog 'export function stillSegmentationResultToastKey' `
  'export function styleTransferStyleSelectionToastKey' 'still-segmentation Toast policy'
Assert-Contains $toastPolicy 'usesAndroidStillSegmentationLayout(workflow) && !resultOk' `
  'failure Toast policy must be exact-route and failure-only.'
Assert-Contains $toastPolicy "'feature_runtime_segmentation_failed'" `
  'failure Toast policy must use the existing segmentation-failed key.'

$builder = Get-TextSection $page '  stillSegmentationAndroidLayout() {' `
  "`n`n  @Builder`n  customModelAndroidLayout()" 'dedicated still-segmentation builder'
foreach ($line in @(
  'Stack({ alignContent: Alignment.TopStart }) {',
  'this.runtimeActionToolbar(false)',
  '.height(1)',
  ".backgroundColor('#E4E4E4')",
  'if (this.imageInputUri.length > 0) {',
  'Image(this.imageInputUri)',
  "Image(`$r('app.media.icon_default'))",
  'if (this.segmentationForegroundPixelMap !== undefined) {',
  'Image(this.segmentationForegroundPixelMap)',
  '.objectFit(ImageFit.Contain)',
  '.layoutWeight(4)',
  '.margin({ top: 20 })',
  "Button(appString(workflowInputLabelKey(workflowForRoute(this.routeName), 'photo')), { type: ButtonType.Normal })",
  ".onClick(() => this.prepareInput('photo'))",
  "Button(appString(workflowInputLabelKey(workflowForRoute(this.routeName), 'camera')), { type: ButtonType.Normal })",
  ".onClick(() => this.prepareInput('camera'))",
  'Button(appString(workflowGoLiveLabelKey(workflowForRoute(this.routeName))), { type: ButtonType.Normal })',
  'this.openStillSegmentationLiveRoute()',
  'SaveButton({',
  '.enabled(!this.workflowRunning)',
  'this.saveStillSegmentationResultImage()',
  "this.statusKey = 'feature_runtime_save_image_failed';",
  'this.showRuntimeToast(this.statusKey);',
  '.height(37)',
  '.margin({ top: 14 })',
  '.backgroundColor(Color.Black)',
  'this.runtimePermissionRecoveryOverlay()',
  ".width('100%')",
  ".height('100%')"
)) { Assert-CodeLine $builder $line "dedicated builder is missing executable line: $line." }
Assert-CodeLineCount $builder '.layoutWeight(4)' 2 'source and foreground previews must have equal Android weight.'
Assert-CodeLineCount $builder "Image(`$r('app.media.icon_default'))" 2 'both empty previews must use icon_default.'
Assert-CodeLineCount $builder '.enabled(!this.workflowRunning)' 4 'all four bottom actions must be disabled while running.'

$photo = Get-CodeLineIndex $builder ".onClick(() => this.prepareInput('photo'))"
$camera = Get-CodeLineIndex $builder ".onClick(() => this.prepareInput('camera'))" ($photo + 1)
$live = Get-CodeLineIndex $builder 'this.openStillSegmentationLiveRoute()' ($camera + 1)
$save = Get-CodeLineIndex $builder 'SaveButton({' ($live + 1)
if ($photo -lt 0 -or $camera -le $photo -or $live -le $camera -or $save -le $live) {
  throw 'Still segmentation parity guard failed: bottom actions must be Photo, Camera, Real-time, Save.'
}

foreach ($marker in @(
  'this.summaryKey',
  "'feature_runtime_inputs_title'",
  'this.permissionKinds',
  'this.resultRows',
  'this.resultText',
  'this.segmentationRectangles',
  'this.segmentationBackgroundImageUri',
  'this.filePreview(',
  'this.runWorkflow()',
  'this.showLocalHelpDialog()',
  'this.openHelpPage()'
)) { Assert-Excludes $builder $marker 'dedicated builder must not expose generic/overlay actions' }

$buildSelection = Get-TextSection $page '  build() {' "`n    } else {`n      Scroll()" 'top-level layout selection'
Assert-Contains $buildSelection 'usesAndroidStillSegmentationLayout(workflowForRoute(this.routeName))' `
  'top-level build must select the exact still-segmentation layout before fallback.'
Assert-Contains $buildSelection 'this.stillSegmentationAndroidLayout()' `
  'top-level build must call the dedicated still-segmentation builder.'

$pick = Get-TextSection $page '  private applyPickResult(' "`n`n  private aiRunInputs" 'picked-input state path'
Assert-Contains $pick 'usesAndroidStillSegmentationLayout(workflow)' `
  'accepted still photo/camera input must be route-scoped.'
Assert-Contains $pick 'this.segmentationForegroundPixelMapOwner.invalidatePendingReplacement();' `
  'accepted still input must invalidate pending foreground conversion without clearing the owner.'

$run = Get-TextSection $page '  private async runWorkflowAsync(' "`n`n  private applyRuntimeFailure" 'workflow execution path'
Assert-Contains $run "shouldPreserveRuntimeVisualResultOnAiResult(workflow, false, '')" `
  'permission denial must preserve the still foreground through the shared policy.'
$apply = Get-TextSection $page '  private async applyAiResult(' "`n`n  private showObjectPhotoFailureToastIfNeeded" 'AI result application'
Assert-CodeLine $apply 'await this.updateSegmentationPreview(result, runtimeRequestId);' `
  'still foreground conversion must participate in the running lifecycle.'
Assert-CodeLine $apply 'this.showStillSegmentationFailureToastIfNeeded(result.ok);' `
  'failed AI results must surface the route-scoped Toast.'
$failure = Get-TextSection $page '  private applyRuntimeFailure(): void {' "`n`n  private async prepareLiveFrameImageInput" 'thrown-run failure path'
Assert-CodeLine $failure 'this.showStillSegmentationFailureToastIfNeeded(false);' `
  'thrown runs must surface the route-scoped Toast.'

$segmentation = Get-TextSection $page '  private async updateSegmentationPreview(' "`n`n  private updatePosePreview" 'segmentation foreground update path'
Assert-Contains $segmentation "data === undefined || data.kind !== 'segmentation' || !result.ok" `
  'segmentation preview must reject non-success/non-segmentation results.'
Assert-Contains $segmentation 'usesAndroidStillSegmentationLayout(workflow)' `
  'zero-rectangle and awaited behavior must be exact-route scoped.'
Assert-CodeLine $segmentation 'await foregroundUpdate;' `
  'still foreground conversion must be awaited.'
Assert-CodeLine $segmentation 'const pixelMap = await styleTransferPixelMapFromRgbaOutput(rgba, width, height);' `
  'foreground PixelMap conversion must not be fire-and-forget.'
Assert-Contains $segmentation 'this.segmentationForegroundPixelMapOwner.accept(requestId, pixelMap)' `
  'foreground replacement must use the atomic owner.'
Assert-Contains $segmentation 'this.segmentationForegroundPixelMapOwner.invalidatePendingReplacement();' `
  'stale/current-failure paths must invalidate pending ownership.'
Assert-Contains $segmentation 'this.showStillSegmentationFailureToastIfNeeded(false);' `
  'current invalid/rejected foreground must Toast failure.'

$saveWrapper = Get-TextSection $page '  private saveStillSegmentationResultImage(): void {' `
  "`n`n  private async saveResultComponentImageAsync" 'still-segmentation save wrapper'
Assert-CodeLineCount $saveWrapper 'if (this.workflowRunning) {' 2 `
  'save entry and async wrapper must both reject running-state calls.'
Assert-CodeLine $saveWrapper 'await this.saveResultPixelMapAsync(this.segmentationForegroundPixelMap);' `
  'save wrapper must save the currently owned foreground.'
Assert-CodeLine $saveWrapper 'this.showRuntimeToast(this.statusKey);' `
  'save wrapper must Toast missing/success/failure status.'

Assert-CodeLine $build "& (Join-Path `$PSScriptRoot 'check-still-segmentation-layout-parity.ps1')" `
  'build-hap.ps1 must execute the production parity guard.'
Assert-CodeLine $build "& (Join-Path `$PSScriptRoot 'test-still-segmentation-layout-parity-guard.ps1')" `
  'build-hap.ps1 must execute the mutation fixture suite.'

Write-Host 'Still image segmentation Android layout/state parity checks passed.'
