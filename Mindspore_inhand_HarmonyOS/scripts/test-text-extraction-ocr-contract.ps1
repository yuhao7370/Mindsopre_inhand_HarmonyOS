Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$required = @(
  'entry\src\main\resources\rawfile\models\ocr\ppocrv3_det.mnn',
  'entry\src\main\resources\rawfile\models\ocr\ppocrv3_rec.mnn',
  'entry\src\main\resources\rawfile\models\ocr\ppocr_keys_v1.txt',
  'entry\src\main\resources\rawfile\models\ocr\NOTICE.md',
  'entry\src\ohosTest\resources\rawfile\fixtures\ocr\english.png',
  'entry\src\ohosTest\resources\rawfile\fixtures\ocr\chinese.png',
  'entry\src\ohosTest\resources\rawfile\fixtures\ocr\multiline.png',
  'entry\src\ohosTest\resources\rawfile\fixtures\ocr\manifest.json'
)

foreach ($relativePath in $required) {
  if (-not (Test-Path -LiteralPath (Join-Path $root $relativePath))) {
    throw "Missing verified OCR contract asset: $relativePath"
  }
}

$manifest = Get-Content -LiteralPath (Join-Path $root 'entry\src\ohosTest\resources\rawfile\fixtures\ocr\manifest.json') -Raw | ConvertFrom-Json
if ($manifest.maximumCharacterErrorRate -gt 0.10 -or $manifest.fixtures.Count -ne 3) {
  throw 'OCR fixture oracle must contain Chinese, English, and multiline samples with CER <= 0.10.'
}
foreach ($fixture in $manifest.fixtures) {
  if ([string]::IsNullOrWhiteSpace($fixture.groundTruth) -or [string]::IsNullOrWhiteSpace($fixture.sha256)) {
    throw 'OCR fixture ground truth and SHA-256 are required.'
  }
  $actual = (Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $root "entry\src\ohosTest\resources\rawfile\fixtures\ocr\$($fixture.file)")).Hash
  if ($actual -ne $fixture.sha256) {
    throw "OCR fixture hash mismatch: $($fixture.file)"
  }
}

$notice = Get-Content -LiteralPath (Join-Path $root 'entry\src\main\resources\rawfile\models\ocr\NOTICE.md') -Raw
$ocrAssets = @(
  @{ File = 'ppocrv3_det.mnn'; Sha256 = '4C49C41D6675BDCC25718E976D0EB3A9560BF030FAA79E20B51378CA98480FB2' },
  @{ File = 'ppocrv3_rec.mnn'; Sha256 = '2B67F7CA600FFFAE2CB3243B1661458109060BC9BCFD978E25CE39A22170FA3B' },
  @{ File = 'ppocr_keys_v1.txt'; Sha256 = '28B2362AD4AB2DC38769AA72FEB535E3A9DDB3FD2A7585A05920E6393B1DC7F7' }
)
foreach ($asset in $ocrAssets) {
  if (-not $notice.Contains($asset.File) -or -not $notice.Contains($asset.Sha256)) {
    throw "OCR NOTICE is missing documented SHA-256: $($asset.File)"
  }
  $actual = (Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $root "entry\src\main\resources\rawfile\models\ocr\$($asset.File)")).Hash
  if ($actual -cne $asset.Sha256) {
    throw "OCR asset hash mismatch: $($asset.File)"
  }
}

Write-Output 'OCR asset, fixture, and CER contract passed.'
