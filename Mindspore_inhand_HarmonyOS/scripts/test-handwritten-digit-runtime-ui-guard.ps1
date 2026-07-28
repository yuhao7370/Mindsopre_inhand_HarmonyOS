param(
  [string]$SourceRoot = (Join-Path $PSScriptRoot '..')
)

$ErrorActionPreference = 'Stop'
$SourceRoot = [IO.Path]::GetFullPath($SourceRoot)
$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ('mih-digit-runtime-' + [Guid]::NewGuid().ToString('N'))

function Read-Normalized([string]$Path) {
  return ([IO.File]::ReadAllText($Path)).Replace("`r`n", "`n").Replace("`r", "`n")
}

function Require-Text([string]$Text, [string]$Needle, [string]$Name) {
  if ($Text.IndexOf($Needle, [StringComparison]::Ordinal) -lt 0) {
    throw "Handwritten digit runtime guard missing $Name."
  }
}

function Section([string]$Text, [string]$Start, [string]$End) {
  $startAt = $Text.IndexOf($Start, [StringComparison]::Ordinal)
  $endAt = if ($startAt -ge 0) { $Text.IndexOf($End, $startAt + $Start.Length, [StringComparison]::Ordinal) } else { -1 }
  if ($startAt -lt 0 -or $endAt -le $startAt) { throw "Digit guard could not find section: $Start" }
  return $Text.Substring($startAt, $endAt - $startAt)
}

function Copy-Candidate([string]$Root) {
  foreach ($relative in @(
    'entry\src\main\ets\services\ai\AiService.ets',
    'entry\src\main\ets\services\ai\ImageClassificationRuntimeFactory.ets',
    'entry\src\main\ets\services\camera\LiveCameraService.ets',
    'entry\src\main\ets\services\picker\PickerService.ets',
    'entry\src\main\ets\features\runtime\FeatureWorkflowCatalog.ets',
    'entry\src\main\ets\pages\FeatureRuntimePage.ets',
    'scripts\build-hap.ps1'
  )) {
    $target = Join-Path $Root $relative
    [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($target)) | Out-Null
    [IO.File]::Copy((Join-Path $SourceRoot $relative), $target, $true)
  }
}

function Replace-Once([string]$Text, [string]$Before, [string]$After, [string]$Name) {
  $count = ([regex]::Matches($Text, [regex]::Escape($Before))).Count
  if ($count -ne 1) { throw "Digit guard fixture expected one $Name marker, found $count." }
  $at = $Text.IndexOf($Before, [StringComparison]::Ordinal)
  return $Text.Substring(0, $at) + $After + $Text.Substring($at + $Before.Length)
}

function Assert-Rejected([string]$Name, [string]$Relative, [string]$Before, [string]$After) {
  $fixture = Join-Path $tempRoot ([Guid]::NewGuid().ToString('N'))
  Copy-Candidate $fixture
  $path = Join-Path $fixture $Relative
  [IO.File]::WriteAllText($path, (Replace-Once (Read-Normalized $path) $Before $After $Name))
  $rejected = $false
  try { & $PSCommandPath -SourceRoot $fixture *> $null } catch { $rejected = $true }
  if (-not $rejected) { throw "Handwritten digit runtime guard accepted mutation: $Name" }
}

try {
  $ai = Read-Normalized (Join-Path $SourceRoot 'entry\src\main\ets\services\ai\AiService.ets')
  $factory = Read-Normalized (Join-Path $SourceRoot 'entry\src\main\ets\services\ai\ImageClassificationRuntimeFactory.ets')
  $camera = Read-Normalized (Join-Path $SourceRoot 'entry\src\main\ets\services\camera\LiveCameraService.ets')
  $picker = Read-Normalized (Join-Path $SourceRoot 'entry\src\main\ets\services\picker\PickerService.ets')
  $catalog = Read-Normalized (Join-Path $SourceRoot 'entry\src\main\ets\features\runtime\FeatureWorkflowCatalog.ets')
  $page = Read-Normalized (Join-Path $SourceRoot 'entry\src\main\ets\pages\FeatureRuntimePage.ets')
  $build = Read-Normalized (Join-Path $SourceRoot 'scripts\build-hap.ps1')

  Require-Text $ai "return this.recognizeDigit(inputs);" 'DefaultAiService digit dispatch'
  Require-Text $ai "kind: 'digitPredictions'" 'digit result data'
  Require-Text $ai "feature_runtime_digit_result_candidates" 'top-three rows'
  Require-Text $factory "handwrittenDigitService: createHarmonyHandwrittenDigitService(options)" 'runtime service factory'
  Require-Text $camera "aiMethod === 'recognizeDigit'" 'serial live loop eligibility'
  Require-Text $picker "isHandwrittenDigitWorkflow(workflow)" 'inline camera fallback'
  Require-Text $catalog "usesAndroidGestureLikeStillLayout" 'shared still layout predicate'
  Require-Text $catalog "isHandwrittenDigitWorkflow(workflow) && workflow?.liveMode" 'shared live layout predicate'
  Require-Text $page "usesAndroidGestureLikeStillLayout(workflowForRoute(this.routeName))" 'shared still builder selection'
  Require-Text $page "this.liveDigitOverlayValue()" 'live digit and confidence overlay'
  $digitStillPreview = Section $page '  gestureStillAndroidPreview() {' "`n`n  @Builder`n  gestureStillAndroidLayout()"
  Require-Text $digitStillPreview "if (this.liveCameraInputSelected || this.liveCameraActive) {`n        this.liveCameraSurfaceContent()" 'static inline camera surface'
  Require-Text $page "this.runtimeAiServiceSession.getOrCreate(workflow" 'route service session'
  Require-Text $build "test-handwritten-digit-runtime-ui-guard.ps1" 'build guard wire'

  [IO.Directory]::CreateDirectory($tempRoot) | Out-Null
  Assert-Rejected 'drop-dispatch' 'entry\src\main\ets\services\ai\AiService.ets' `
    'return this.recognizeDigit(inputs);' 'return this.detectGesture(inputs);'
  Assert-Rejected 'drop-result-rows' 'entry\src\main\ets\services\ai\AiService.ets' `
    "case 'digitPredictions':`n      return digitPredictionResultRows(data);" "case 'digitPredictions':`n      return [];"
  Assert-Rejected 'drop-runtime-factory' 'entry\src\main\ets\services\ai\ImageClassificationRuntimeFactory.ets' `
    'handwrittenDigitService: createHarmonyHandwrittenDigitService(options)' 'handwrittenDigitService: undefined'
  Assert-Rejected 'drop-live-loop' 'entry\src\main\ets\services\camera\LiveCameraService.ets' `
    "aiMethod === 'detectGesture' ||`n    aiMethod === 'recognizeDigit' ||" "aiMethod === 'detectGesture' ||"
  Assert-Rejected 'drop-still-builder-reuse' 'entry\src\main\ets\pages\FeatureRuntimePage.ets' `
    'usesAndroidGestureLikeStillLayout(workflowForRoute(this.routeName))' 'usesAndroidGestureStillLayout(workflowForRoute(this.routeName))'
  Assert-Rejected 'drop-static-inline-camera-surface' 'entry\src\main\ets\pages\FeatureRuntimePage.ets' `
    "if (this.liveCameraInputSelected || this.liveCameraActive) {`n        this.liveCameraSurfaceContent()" `
    "if (false) {`n        this.liveCameraSurfaceContent()"
  Assert-Rejected 'drop-session-cache' 'entry\src\main\ets\pages\FeatureRuntimePage.ets' `
    'await this.runtimeAiServiceSession.getOrCreate(workflow, () =>' 'await cachedRuntimeAiServiceForHarmonyResourceManager(workflow,'

  Write-Output 'Handwritten digit runtime UI guard mutation fixtures passed.'
} finally {
  if ([IO.Directory]::Exists($tempRoot)) { [IO.Directory]::Delete($tempRoot, $true) }
}
