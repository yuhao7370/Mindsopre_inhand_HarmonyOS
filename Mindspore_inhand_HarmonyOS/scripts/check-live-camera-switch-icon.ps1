param(
  [string]$SourceRoot = ''
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($SourceRoot)) { $SourceRoot = Split-Path -Parent $PSScriptRoot }
$SourceRoot = [IO.Path]::GetFullPath($SourceRoot)
$runtimePagePath = Join-Path $SourceRoot 'entry/src/main/ets/pages/FeatureRuntimePage.ets'
$source = ([IO.File]::ReadAllText($runtimePagePath)).Replace("`r`n", "`n").Replace("`r", "`n")

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

$previewSlice = SourceSlice $source 'runtimeCameraSwitchAction()' 'runtimePermissionRecoveryOverlay()'
if ($previewSlice -notmatch "Image\(\`$r\('app\.media\.front_back_switch'\)\)") {
  throw 'FeatureRuntimePage must render the existing camera switch media'
}
if ($previewSlice -match "Button\(appString\('feature_runtime_switch_camera'\)\)") {
  throw 'FeatureRuntimePage must not render the live camera switch as a text button'
}
if ($previewSlice -notmatch '\.width\(48\)' -or $previewSlice -notmatch '\.height\(48\)' -or
  $previewSlice -notmatch "\.accessibilityText\(appString\('feature_runtime_switch_camera'\) as Resource\)") {
  throw 'FeatureRuntimePage live camera switch must use a localized 48vp semantic target'
}
if ($previewSlice -notmatch 'this\.switchLiveCamera\(\)') {
  throw 'FeatureRuntimePage live camera switch icon must keep the existing switch handler'
}

Write-Output 'Live-camera switch semantic wiring is present.'
