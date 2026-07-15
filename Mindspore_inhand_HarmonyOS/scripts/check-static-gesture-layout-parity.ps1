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
  '  gestureStillAndroidPreview() {' `
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

$runtimeFailure = Get-TextSection `
  $page `
  '  private applyRuntimeFailure(): void {' `
  "`n`n  private async prepareLiveFrameImageInput" `
  'runtime failure Toast call site'
Assert-Contains `
  $runtimeFailure `
  'this.showGestureStillFailureToastIfNeeded(false, this.statusKey);' `
  'runtime failures must keep Gesture Still Toast feedback.'

$aiResult = Get-TextSection `
  $page `
  '  private async applyAiResult(result: AiRunResult, runtimeRequestId: number): Promise<void> {' `
  "`n`n  private showGestureStillFailureToastIfNeeded" `
  'AI result Toast call site'
Assert-Contains `
  $aiResult `
  'this.showGestureStillFailureToastIfNeeded(result.ok, result.messageKey);' `
  'AI results must keep Gesture Still Toast feedback.'

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
