$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$mediaDir = Join-Path $root 'entry/src/main/resources/base/media'

$expectedHashes = [ordered]@{
  'me_share.png' = '95C12ACD6FFBF7BDA8F6E6C8F5438F13D31389E8A22C611231510755372B37C9'
  'me_qr_code.png' = '15456929980BFB40FE1F8ED62E96EA867B8C762CCD2C0B330B782F800723846B'
  'me_up.png' = '18E8D0462F965B04896752FD656C9117E650604C866524030F33B8717D8FD8CE'
  'me_official.png' = '3C496A489593D0074C451B9C7325769B5E804E54F581C40A33FEEEA27FF13568'
  'me_official_code.png' = '3FA6EFE5B54EC2E344BA35B44C564B90E5BFA3D4E6F90A5DCE25B83D873D253E'
  'me_qa.png' = '0E9314E2D0BB444E05B09FFE925C5D60DF603C8F42F99E532358D3ABE31A66D9'
  'me_version.png' = '7BB0B79F917662499646C5CE66D9AE0C261B3813757A7D70E940E58BFC8D6DD8'
  'me_go.png' = 'EECDAC679EC9E327F16C350789C201DF9D04442FBAD670E2CA65685E957C37EE'
}

foreach ($fileName in $expectedHashes.Keys) {
  $path = Join-Path $mediaDir $fileName
  if (-not (Test-Path -LiteralPath $path)) {
    throw "Missing Android Me row icon media: $fileName"
  }
  $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $path).Hash
  if ($hash -ne $expectedHashes[$fileName]) {
    throw "Android Me row icon media hash mismatch for $fileName. Expected $($expectedHashes[$fileName]), got $hash"
  }
}

$iconSource = Get-Content -Raw -Encoding UTF8 -LiteralPath (Join-Path $root 'entry/src/main/ets/common/icons/IconSymbols.ets')
$mediaByToken = @{
  share = 'me_share'
  qr = 'me_qr_code'
  star = 'me_up'
  official = 'me_official'
  code = 'me_official_code'
  feedback = 'me_qa'
  version = 'me_version'
  go = 'me_go'
}
foreach ($token in $mediaByToken.Keys) {
  $media = $mediaByToken[$token]
  if ($iconSource -notmatch "case '$token':\s*\r?\n\s*return '$media';") {
    throw "IconSymbols is missing Android Me media-name mapping for token '$token' -> '$media'"
  }
  if ($iconSource -notmatch "\`$r\('app\.media\.$media'\)") {
    throw "IconSymbols is missing Android Me media resource for token '$token' -> $media"
  }
}

$mePageSource = Get-Content -Raw -Encoding UTF8 -LiteralPath (Join-Path $root 'entry/src/main/ets/pages/MePage.ets')
if ($mePageSource -notmatch 'iconMediaResource\(item\.icon\)') {
  throw "MePage must render Me row icons with Android PNG media resources"
}
if ($mePageSource -notmatch "iconMediaResource\('go'\)") {
  throw "MePage must render the Android Me chevron icon with me_go.png"
}

Write-Host 'Me page Android row icon media wiring is present'
