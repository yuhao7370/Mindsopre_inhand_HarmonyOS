$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$runtimePagePath = Join-Path $root 'entry/src/main/ets/pages/FeatureRuntimePage.ets'
$source = (Get-Content -Raw -Encoding UTF8 -LiteralPath $runtimePagePath) -replace "`r`n", "`n"

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

$headerSlice = SourceSlice $source 'Text(appString(this.titleKey))' "Column() {`n          Text(appString(this.summaryKey))"
if ($headerSlice -notmatch "Button\(appString\('title_source'\)\)") {
  throw 'FeatureRuntimePage must render the Android Source toolbar action in the title row'
}
if ($headerSlice -notmatch "Button\(appString\('feature_runtime_help'\)\)") {
  throw 'FeatureRuntimePage must render the Android Help toolbar action in the title row'
}
$sourceButtonSlice = SourceSlice $headerSlice "Button(appString('title_source'))" "Button(appString('feature_runtime_help'))"
if ($sourceButtonSlice -notmatch 'this\.openHelpPage\(\)' -or $sourceButtonSlice -match 'this\.showLocalHelpDialog\(\)') {
  throw 'FeatureRuntimePage title-row Source action must use the existing Source handler'
}
$helpButtonStart = $headerSlice.IndexOf("Button(appString('feature_runtime_help'))")
if ($helpButtonStart -lt 0) {
  throw 'FeatureRuntimePage must render the Android Help toolbar action in the title row'
}
$helpButtonSlice = $headerSlice.Substring($helpButtonStart)
if ($helpButtonSlice -notmatch 'this\.showLocalHelpDialog\(\)' -or $helpButtonSlice -match 'this\.openHelpPage\(\)') {
  throw 'FeatureRuntimePage title-row Help action must use the existing local Help handler'
}

$summarySlice = SourceSlice $source "Column() {`n          Text(appString(this.summaryKey))" "Column() {`n          Text(appString('feature_runtime_inputs_title'))"
if ($summarySlice -match "Button\(appString\('title_source'\)\)" -or $summarySlice -match "Button\(appString\('feature_runtime_help'\)\)") {
  throw 'FeatureRuntimePage must not render Source/Help as body buttons below the summary card'
}

Write-Host 'Feature runtime Android toolbar Source/Help action placement is present'
