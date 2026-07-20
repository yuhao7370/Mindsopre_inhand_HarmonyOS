$ErrorActionPreference = 'Stop'

$model = Join-Path $PSScriptRoot '..\entry\src\main\resources\rawfile\model\selfie_segmentation.mnn'
$notice = Join-Path $PSScriptRoot '..\entry\src\main\resources\rawfile\model\selfie_segmentation.NOTICE.md'
$license = Join-Path $PSScriptRoot '..\entry\src\main\resources\rawfile\model\LICENSE-Apache-2.0.txt'
$expectedSize = 446064
$expectedHash = '2EC8CB8940B42DE3F453EDFEBC0945905C81F2DD6C8A751128AAF6F98B8DB128'

foreach ($path in @($model, $notice, $license)) {
  if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
    throw "Portrait segmentation model provenance file is missing: $path"
  }
}

$actualSize = (Get-Item -LiteralPath $model).Length
if ($actualSize -ne $expectedSize) {
  throw "Portrait segmentation model size mismatch: expected $expectedSize, got $actualSize"
}
$actualHash = (Get-FileHash -LiteralPath $model -Algorithm SHA256).Hash
if ($actualHash -cne $expectedHash) {
  throw "Portrait segmentation model SHA-256 mismatch: expected $expectedHash, got $actualHash"
}

$noticeText = Get-Content -LiteralPath $notice -Raw
foreach ($marker in @(
  '9EE168EC7C8F2A16C56FE8E1CFBC514974CBBB7E434051B455635F1BD1462F5C',
  $expectedHash,
  'input_1',
  'activation_10',
  'Apache License 2.0'
)) {
  if (-not $noticeText.Contains($marker)) {
    throw "Portrait segmentation model notice is missing required provenance marker: $marker"
  }
}

Write-Host "Verified portrait segmentation model: bytes=$actualSize; sha256=$actualHash"
