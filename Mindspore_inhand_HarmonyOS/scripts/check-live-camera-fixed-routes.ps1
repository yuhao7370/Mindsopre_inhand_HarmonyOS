$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$workflowPath = Join-Path $root 'entry/src/main/ets/features/runtime/FeatureWorkflowCatalog.ets'
$runtimePagePath = Join-Path $root 'entry/src/main/ets/pages/FeatureRuntimePage.ets'
$dancePagePath = Join-Path $root 'entry/src/main/ets/pages/DancePage.ets'

$workflowSource = (Get-Content -Raw -Encoding UTF8 -LiteralPath $workflowPath) -replace "`r`n", "`n"
$runtimePageSource = (Get-Content -Raw -Encoding UTF8 -LiteralPath $runtimePagePath) -replace "`r`n", "`n"
$dancePageSource = (Get-Content -Raw -Encoding UTF8 -LiteralPath $dancePagePath) -replace "`r`n", "`n"

function SourceSlice([string] $text, [string] $startMarker, [string] $endMarker) {
  $start = $text.IndexOf($startMarker)
  if ($start -lt 0) {
    throw "Missing source marker: $startMarker"
  }
  $end = $text.IndexOf($endMarker, $start + $startMarker.Length)
  if ($end -lt 0) {
    throw "Missing source marker after ${startMarker}: $endMarker"
  }
  return $text.Substring($start, $end - $start)
}

if ($workflowSource -notmatch 'export function fixedLiveCameraPositionForWorkflow') {
  throw 'FeatureWorkflowCatalog must expose fixedLiveCameraPositionForWorkflow for Android fixed-camera routes'
}
if ($workflowSource -notmatch 'workflow\.routeName === AppRoute\.IMAGE_CAMERA\.name' -or
  $workflowSource -notmatch 'workflow\.routeName === AppRoute\.OBJECT_CAMERA\.name') {
  throw 'Image/Object Android camera workflows must be listed as fixed back-camera routes'
}

$rememberSlice = SourceSlice $workflowSource 'export function rememberedLiveCameraPositionForWorkflow' 'export function rememberLiveCameraPositionForRoute'
if ($rememberSlice -notmatch 'fixedLiveCameraPositionForWorkflow\(workflow\)') {
  throw 'rememberedLiveCameraPositionForWorkflow must prefer fixed Android camera positions over manual memory'
}

$rememberRouteSlice = SourceSlice $workflowSource 'export function rememberLiveCameraPositionForRoute' 'export function resetRememberedLiveCameraPositionsForTests'
if ($rememberRouteSlice -notmatch 'workflowForRoute\(routeName\)' -or
  $rememberRouteSlice -notmatch 'fixedLiveCameraPositionForWorkflow') {
  throw 'rememberLiveCameraPositionForRoute must skip storing manual switches for fixed Android camera routes'
}

$runtimeRefreshSlice = SourceSlice $runtimePageSource 'private refreshLiveCameraSwitchAvailability(): void' 'private autoStartLiveCameraIfNeeded(): void'
if ($runtimeRefreshSlice -notmatch 'fixedLiveCameraPositionForWorkflow\(workflowForRoute\(this\.routeName\)\)' -or
  $runtimeRefreshSlice -notmatch 'this\.liveCameraSwitchAvailable = false') {
  throw 'FeatureRuntimePage must disable the switch button for fixed Android camera routes'
}

if ($runtimePageSource -notmatch 'fixedLiveCameraPositionForWorkflow') {
  throw 'FeatureRuntimePage must import/use fixedLiveCameraPositionForWorkflow'
}

if ($dancePageSource -notmatch '@State liveCameraPosition: LiveCameraPosition = ''front''') {
  throw 'DancePage must keep the Android Dance front-camera default'
}
if ($dancePageSource -match 'liveCameraSwitchAvailable' -or
  $dancePageSource -match 'nextLiveCameraPosition' -or
  $dancePageSource -match 'feature_runtime_switch_camera') {
  throw 'DancePage must not expose camera switching because Android Dance fixes the front camera'
}

Write-Host 'Android fixed live-camera route parity is present'
