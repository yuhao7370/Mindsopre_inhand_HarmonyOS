param(
  [string]$SourceRoot = ''
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'runtime-source-guard-helpers.ps1')

if ([string]::IsNullOrWhiteSpace($SourceRoot)) { $SourceRoot = Split-Path -Parent $PSScriptRoot }
$SourceRoot = [IO.Path]::GetFullPath($SourceRoot)
$runtimePagePath = Join-Path $SourceRoot 'entry/src/main/ets/pages/FeatureRuntimePage.ets'
$source = ([IO.File]::ReadAllText($runtimePagePath)).Replace("`r`n", "`n").Replace("`r", "`n")
$source = Remove-RuntimeSourceComments $source

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
$switchChain = Get-RuntimeOuterActionChain `
  $previewSlice `
  "Image\(\`$r\('app\.media\.front_back_switch'\)\)" `
  'Live-camera switch action'
Assert-RuntimeSemanticAction `
  $switchChain `
  "\.accessibilityText\(appString\('feature_runtime_switch_camera'\) as Resource\)" `
  'BUTTON' `
  'this\.switchLiveCamera\(\)' `
  'Live-camera switch action'

Write-Output 'Live-camera switch semantic wiring is present.'
