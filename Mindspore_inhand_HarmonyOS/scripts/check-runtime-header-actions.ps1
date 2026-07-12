$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$runtimePagePath = Join-Path $root 'entry/src/main/ets/pages/FeatureRuntimePage.ets'
$source = (Get-Content -Raw -Encoding UTF8 -LiteralPath $runtimePagePath) -replace "`r`n", "`n"

function AssertMediaHash([string] $mediaName, [string] $expectedHash) {
  $mediaPath = Join-Path $root "entry/src/main/resources/base/media/$mediaName"
  if (-not (Test-Path -LiteralPath $mediaPath)) {
    throw "Missing Android toolbar action media: $mediaName"
  }
  $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $mediaPath).Hash
  if ($hash -ne $expectedHash) {
    throw "Android toolbar action media hash mismatch for ${mediaName}. Expected $expectedHash, got $hash"
  }
}

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

function AssertToolbarIconAction([string] $slice, [string] $mediaName, [string] $handler, [string] $forbiddenHandler) {
  if ($slice -notmatch "Image\(\`$r\('app\.media\.${mediaName}'\)\)") {
    throw "FeatureRuntimePage title-row action must render Android $mediaName"
  }
  if ($slice -notmatch '\.width\(40\)' -or $slice -notmatch '\.height\(40\)' -or
    $slice -notmatch '\.width\(24\)' -or $slice -notmatch '\.height\(24\)' -or
    $slice -notmatch '\.objectFit\(ImageFit\.Contain\)') {
    throw "FeatureRuntimePage title-row $mediaName action must keep a 40x40vp touch target with a 24x24vp contained icon"
  }
  if ($slice -notmatch $handler -or $slice -match $forbiddenHandler) {
    throw "FeatureRuntimePage title-row $mediaName action must keep the correct click handler"
  }
}

AssertMediaHash 'icon_help.png' '79E9E918203DA389D16BFD029E79523D2D7CB13F7CD47DACC569F65817C39208'
AssertMediaHash 'icon_more.png' 'F647E1FB2759C2E0909D64C094D2D27114D6845436F1FE09551E9D429E25F9F5'

$headerSlice = SourceSlice $source 'Text(appString(this.titleKey))' "Column() {`n          Text(appString(this.summaryKey))"
if ($headerSlice -match "Button\(appString\('title_source'\)\)" -or
  $headerSlice -match "Button\(appString\('feature_runtime_help'\)\)") {
  throw 'FeatureRuntimePage must render Android toolbar action icons instead of text action buttons'
}

$helpStart = $headerSlice.IndexOf('if (this.helpContentKey !== undefined)')
$moreStart = $headerSlice.IndexOf('if (this.helpUrl.length > 0)')
if ($helpStart -lt 0 -or $moreStart -lt 0) {
  throw 'FeatureRuntimePage must keep both Help and More/Source toolbar action conditions in the title row'
}
if ($helpStart -gt $moreStart) {
  throw 'FeatureRuntimePage title-row toolbar actions must follow Android menu order: Help before More'
}

$helpActionSlice = $headerSlice.Substring($helpStart, $moreStart - $helpStart)
$moreActionSlice = $headerSlice.Substring($moreStart)
AssertToolbarIconAction $helpActionSlice 'icon_help' 'this\.showLocalHelpDialog\(\)' 'this\.openHelpPage\(\)'
AssertToolbarIconAction $moreActionSlice 'icon_more' 'this\.openHelpPage\(\)' 'this\.showLocalHelpDialog\(\)'

$summarySlice = SourceSlice $source "Column() {`n          Text(appString(this.summaryKey))" "Column() {`n          Text(appString('feature_runtime_inputs_title'))"
if ($summarySlice -match "Button\(appString\('title_source'\)\)" -or $summarySlice -match "Button\(appString\('feature_runtime_help'\)\)") {
  throw 'FeatureRuntimePage must not render Source/Help as body buttons below the summary card'
}

Write-Host 'Feature runtime Android toolbar action icons are present'
