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
Assert-Contains $selector 'AppRoute.POSENET.name' 'selector must target only PoseNet still.'
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
  '.layoutWeight(1)',
  '.margin({ top: 14 })'
)) {
  Assert-Contains $builder $marker "dedicated builder is missing $marker."
}

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
Assert-Contains $buildScript 'check-posenet-still-layout-parity.ps1' 'build-hap must execute the guard.'

Write-Output 'PoseNet still layout parity guard passed.'
