param(
  [string]$SourceRoot = ''
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($SourceRoot)) { $SourceRoot = Split-Path -Parent $PSScriptRoot }
$SourceRoot = [IO.Path]::GetFullPath($SourceRoot)

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

$runtimeSource = ([IO.File]::ReadAllText((Join-Path $SourceRoot 'entry/src/main/ets/pages/FeatureRuntimePage.ets'))).
  Replace("`r`n", "`n").Replace("`r", "`n")
$runtimeHeader = SourceSlice $runtimeSource 'runtimeActionToolbar(showActions: boolean)' 'runtimeStatusBar()'
if ($runtimeHeader -notmatch "Image\(\`$r\('app\.media\.icon_back'\)\)" -or
  $runtimeHeader -notmatch '\.width\(48\)[\s\S]*?\.height\(48\)' -or
  $runtimeHeader -notmatch "\.accessibilityText\(\`$r\('app\.string\.action_back'\)\)" -or
  $runtimeHeader -notmatch 'router\.back\(\)' -or
  $runtimeHeader -match "Text\('<'\)") {
  throw 'Toolbar back action must keep its icon and handler in a localized 48vp semantic target.'
}

Write-Output 'Toolbar back action semantic wiring is present.'
