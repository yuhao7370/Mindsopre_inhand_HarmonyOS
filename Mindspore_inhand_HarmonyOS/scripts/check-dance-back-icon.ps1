$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$danceBack = Join-Path $root 'entry/src/main/resources/base/media/dance_back.png'
$expectedHash = '1C4AA86F929946DD40355594D0B17CB12AD2478BDEB521ACB4FB1C660E0B218B'

if (-not (Test-Path -LiteralPath $danceBack)) {
  throw 'Missing Android Dance back icon media: dance_back.png'
}

$hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $danceBack).Hash
if ($hash -ne $expectedHash) {
  throw "Android Dance back icon media hash mismatch. Expected $expectedHash, got $hash"
}

$dancePage = Get-Content -Raw -Encoding UTF8 -LiteralPath (Join-Path $root 'entry/src/main/ets/pages/DancePage.ets')
$dancePage = $dancePage -replace "`r`n", "`n"

$start = $dancePage.IndexOf('@Builder' + "`n" + '  header()')
if ($start -lt 0) {
  throw 'Missing DancePage header builder'
}
$end = $dancePage.IndexOf('@Builder' + "`n" + '  referenceVideoPanel()', $start)
if ($end -lt 0) {
  throw 'Missing DancePage header end marker'
}
$header = $dancePage.Substring($start, $end - $start)

if ($header -notmatch "Image\(\`$r\('app\.media\.dance_back'\)\)" -or
  $header -match "Text\('<'\)") {
  throw 'DancePage header must render Android dance_back.png instead of a text back marker'
}
if ($header -notmatch '\.width\(40\)' -or $header -notmatch '\.height\(40\)' -or
  $header -notmatch '\.objectFit\(ImageFit\.Contain\)' -or
  $header -notmatch 'router\.back\(\)') {
  throw 'DancePage back icon must keep the 40x40vp header slot and router.back handler'
}

Write-Host 'Android Dance back icon wiring is present'
