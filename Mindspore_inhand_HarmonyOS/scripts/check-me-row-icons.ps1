$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$mediaPath = Join-Path $root 'entry/src/main/resources/base/media/me_version_v2.png'
$expectedHash = '6D956A28DACE944A329EBAE129264EB089D89D2C4018CD4B82642F50278035FF'

if (-not (Test-Path -LiteralPath $mediaPath)) {
  throw 'Missing Harmony Me flat version icon media: me_version_v2.png'
}

$actualHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $mediaPath).Hash
if ($actualHash -ne $expectedHash) {
  throw "Harmony Me flat version icon media hash mismatch. Expected $expectedHash, got $actualHash"
}

$mePageSource = Get-Content -Raw -Encoding UTF8 -LiteralPath (Join-Path $root 'entry/src/main/ets/pages/MePage.ets')
if ($mePageSource -notmatch "\`$r\('app\.media\.me_version_v2'\)") {
  throw "MePage must bind the Harmony flat version icon with `$r('app.media.me_version_v2')"
}
if ($mePageSource -match 'iconMediaResource\(item\.icon\)') {
  throw 'MePage must not restore legacy Me row icon rendering'
}
if ($mePageSource -match "iconMediaResource\('go'\)") {
  throw 'MePage must not restore the legacy Me chevron'
}

Write-Host 'Me page Harmony flat version icon contract is present'
