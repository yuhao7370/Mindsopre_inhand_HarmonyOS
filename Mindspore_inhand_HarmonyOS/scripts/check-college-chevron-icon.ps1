$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$chevronIcon = Join-Path $root 'entry/src/main/resources/base/media/me_go.png'
$expectedHash = 'EECDAC679EC9E327F16C350789C201DF9D04442FBAD670E2CA65685E957C37EE'

if (-not (Test-Path -LiteralPath $chevronIcon)) {
  throw 'Missing Android College row chevron media: me_go.png'
}

$hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $chevronIcon).Hash
if ($hash -ne $expectedHash) {
  throw "Android College row chevron media hash mismatch. Expected $expectedHash, got $hash"
}

$collegePagePath = Join-Path $root 'entry/src/main/ets/pages/CollegePage.ets'
$source = (Get-Content -Raw -Encoding UTF8 -LiteralPath $collegePagePath) -replace "`r`n", "`n"

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

$actionSlice = SourceSlice $source 'Text(appString(collegeAdapterViewTitleKey))' "if (item.quickActions)"
if ($actionSlice -notmatch "Image\(\`$r\('app\.media\.me_go'\)\)") {
  throw 'CollegePage must render the Android me_go.png chevron next to the adapter title'
}
if ($actionSlice -match "Text\('>'\)") {
  throw "CollegePage must not use a text '>' placeholder for the row chevron"
}
if ($actionSlice -notmatch '\.width\(6\)' -or $actionSlice -notmatch '\.height\(12\)') {
  throw 'CollegePage Android chevron icon must keep the adapter row 6x12vp visual size'
}

Write-Host 'College Android row chevron media wiring is present'
