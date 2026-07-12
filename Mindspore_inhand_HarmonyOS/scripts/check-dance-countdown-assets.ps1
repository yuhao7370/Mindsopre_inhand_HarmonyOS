$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$expected = @{
  'dance_countdown_three.png' = '06835D9A0318F7727A62F66A95FD52A7A3E2EC8ABC3F4E961FCD402CFD9DD957'
  'dance_countdown_two.png' = '0638B070457E062D8670246D57AD40FDEB316B2E9DB4F6D6D6F6DCF6D3E66DA4'
  'dance_countdown_one.png' = '618FD6C1B8AB3463DC1DE9EB9CB48D6926A7E81231D2D3E42904C4F6484BE936'
}

foreach ($name in $expected.Keys) {
  $path = Join-Path $root "entry/src/main/resources/base/media/$name"
  if (-not (Test-Path -LiteralPath $path)) {
    throw "Missing Android Dance countdown media: $name"
  }
  $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $path).Hash
  if ($hash -ne $expected[$name]) {
    throw "Android Dance countdown media hash mismatch for ${name}. Expected $($expected[$name]), got $hash"
  }
}

$dancePage = Get-Content -Raw -Encoding UTF8 -LiteralPath (Join-Path $root 'entry/src/main/ets/pages/DancePage.ets')
$dancePage = $dancePage -replace "`r`n", "`n"

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

$countdownMediaFunction = SourceSlice $dancePage 'private countdownMediaResource()' 'private startReferenceVideoFromBeginning()'
if ($countdownMediaFunction -notmatch "countdownText === '3'\) \{\s*return \`$r\('app\.media\.dance_countdown_three'\);\s*\}") {
  throw 'Dance countdownText 3 must map to dance_countdown_three'
}
if ($countdownMediaFunction -notmatch "countdownText === '2'\) \{\s*return \`$r\('app\.media\.dance_countdown_two'\);\s*\}") {
  throw 'Dance countdownText 2 must map to dance_countdown_two'
}
if ($countdownMediaFunction -notmatch "countdownText === '1'\) \{\s*return \`$r\('app\.media\.dance_countdown_one'\);\s*\}") {
  throw 'Dance countdownText 1 must map to dance_countdown_one'
}

$countdownOverlay = SourceSlice $dancePage "if (this.flowStage === 'countdown')" 'if (this.referenceVideoPreparing)'
if ($countdownOverlay -notmatch 'this\.countdownMediaResource\(\)' -or
  $countdownOverlay -notmatch '\.objectFit\(ImageFit\.Contain\)' -or
  $countdownOverlay -match 'Text\(this\.countdownText\)') {
  throw 'Dance countdown overlay must render Android countdown media instead of a text number'
}
if ($countdownOverlay -notmatch "Text\(appString\('dance_countdown'\)\)") {
  throw 'Dance countdown overlay must keep the localized countdown status text'
}

Write-Host 'Android Dance countdown media wiring is present'
