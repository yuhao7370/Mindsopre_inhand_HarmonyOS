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

function AssertToolbarIconAction(
  [string]$slice,
  [string]$mediaName,
  [string]$semanticName,
  [string]$handler,
  [string]$forbiddenHandler
) {
  $chain = Get-RuntimeOuterActionChain `
    $slice `
    "Image\(\`$r\('app\.media\.${mediaName}'\)\)" `
    "Feature runtime $mediaName action"
  Assert-RuntimeSemanticAction `
    $chain `
    ([regex]::Escape($semanticName)) `
    'BUTTON' `
    $handler `
    "Feature runtime $mediaName action"
  if ($chain -match $forbiddenHandler) {
    throw "FeatureRuntimePage title-row $mediaName action must keep the correct click handler"
  }
}

$headerSlice = SourceSlice $source 'runtimeActionToolbar(showActions: boolean)' 'runtimeStatusBar()'
if ($headerSlice -match "Button\(appString\('title_source'\)\)" -or
  $headerSlice -match "Button\(appString\('feature_runtime_help'\)\)") {
  throw 'FeatureRuntimePage must render Android toolbar action icons instead of text action buttons'
}

$helpStart = $headerSlice.IndexOf('if (showActions && this.helpContentKey !== undefined)')
$moreStart = $headerSlice.IndexOf('if (showActions && this.helpUrl.length > 0)')
if ($helpStart -lt 0 -or $moreStart -lt 0) {
  throw 'FeatureRuntimePage must keep both Help and More/Source toolbar action conditions in the title row'
}
if ($helpStart -gt $moreStart) {
  throw 'FeatureRuntimePage title-row toolbar actions must preserve Help before More'
}

$helpActionSlice = $headerSlice.Substring($helpStart, $moreStart - $helpStart)
$moreActionSlice = $headerSlice.Substring($moreStart)
AssertToolbarIconAction $helpActionSlice 'icon_help' ".accessibilityText(appString('feature_runtime_help') as Resource)" 'this\.showLocalHelpDialog\(\)' 'this\.openHelpPage\(\)'
AssertToolbarIconAction $moreActionSlice 'icon_more' ".accessibilityText(`$r('app.string.action_more'))" 'this\.openHelpPage\(\)' 'this\.showLocalHelpDialog\(\)'

Write-Output 'Feature runtime toolbar semantic actions are present.'
