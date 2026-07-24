param(
  [string]$SourceRoot = ''
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'runtime-source-guard-helpers.ps1')

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
$runtimeSource = Remove-RuntimeSourceComments $runtimeSource
$runtimeHeader = SourceSlice $runtimeSource 'runtimeActionToolbar(showActions: boolean)' 'runtimeStatusBar()'
$backChain = Get-RuntimeOuterActionChain `
  $runtimeHeader `
  "Image\(\`$r\('app\.media\.icon_back'\)\)" `
  'Toolbar back action'
Assert-RuntimeSemanticAction `
  $backChain `
  "\.accessibilityText\(\`$r\('app\.string\.action_back'\)\)" `
  'BACK_BUTTON' `
  'router\.back\(\)' `
  'Toolbar back action'

Write-Output 'Toolbar back action semantic wiring is present.'
