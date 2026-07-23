$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$backIcon = Join-Path $root 'entry/src/main/resources/base/media/icon_back.png'
$expectedHash = '56140C75C3A9555F31358356936184912ED320C6214A7C63953ED07C76AA9DD2'

if (-not (Test-Path -LiteralPath $backIcon)) {
  throw 'Missing Android toolbar back icon media: icon_back.png'
}

$hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $backIcon).Hash
if ($hash -ne $expectedHash) {
  throw "Android toolbar back icon media hash mismatch. Expected $expectedHash, got $hash"
}

function ReadSource([string] $relativePath) {
  return (Get-Content -Raw -Encoding UTF8 -LiteralPath (Join-Path $root $relativePath)) -replace "`r`n", "`n"
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

function AssertIconImage([string] $slice) {
  if ($slice -notmatch '\.width\(11\)' -or $slice -notmatch '\.height\(22\)' -or
    $slice -notmatch '\.objectFit\(ImageFit\.Contain\)') {
    throw 'Toolbar back icon must render as an 11x22vp contained media image'
  }
}

function AssertBackTouchTarget([string] $slice) {
  if ($slice -notmatch '\.width\(40\)' -or $slice -notmatch '\.height\(40\)' -or
    $slice -notmatch 'router\.back\(\)') {
    throw 'Toolbar back action must keep the 40x40vp touch target and router.back handler'
  }
}

$runtimeSource = ReadSource 'entry/src/main/ets/pages/FeatureRuntimePage.ets'
$runtimeHeader = SourceSlice $runtimeSource 'Row() {' "Text(appString(this.titleKey))"
if ($runtimeHeader -notmatch "Image\(\`$r\('app\.media\.icon_back'\)\)" -or
  $runtimeHeader -match "Text\('<'\)" -or
  $runtimeHeader -notmatch 'router\.back\(\)') {
  throw 'FeatureRuntimePage must render Android icon_back.png for the toolbar back action'
}

AssertIconImage $runtimeHeader
AssertBackTouchTarget $runtimeHeader

Write-Host 'Android toolbar back icon wiring is present'
