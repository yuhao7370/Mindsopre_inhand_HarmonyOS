$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$backIcon = Join-Path $root 'entry/src/main/resources/base/media/back.png'
$expectedHash = '92DCA8B4BC9A5D43267900AE7CFE90C1F6CF6DC6BCA36642422938837BB0AD08'

if (-not (Test-Path -LiteralPath $backIcon)) {
  throw 'Missing Android Intelligent Poetry back icon media: back.png'
}

$hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $backIcon).Hash
if ($hash -ne $expectedHash) {
  throw "Android Intelligent Poetry back icon media hash mismatch. Expected $expectedHash, got $hash"
}

$webPagePath = Join-Path $root 'entry/src/main/ets/pages/WebPage.ets'
$webPageSource = Get-Content -Raw -Encoding UTF8 -LiteralPath $webPagePath
if ($webPageSource -notmatch 'shouldUsePoetryBackIcon\(\)') {
  throw 'WebPage must gate the Android poetry back.png media to the Intelligent Poetry route'
}
$webPageGatedBackPattern = "if\s*\(this\.shouldUsePoetryBackIcon\(\)\)\s*\{\s*Image\(\`$r\('app\.media\.back'\)\)"
if ($webPageSource -notmatch $webPageGatedBackPattern) {
  throw 'WebPage must render the Android poetry back.png media inside the Intelligent Poetry route gate'
}

$posterPath = Join-Path $root 'entry/src/main/ets/pages/PoetryPosterPage.ets'
$posterSource = Get-Content -Raw -Encoding UTF8 -LiteralPath $posterPath
if ($posterSource -notmatch "Image\(\`$r\('app\.media\.back'\)\)") {
  throw 'PoetryPosterPage must render the Android poetry back.png media'
}

Write-Host 'Intelligent Poetry Android back icon media wiring is present'
