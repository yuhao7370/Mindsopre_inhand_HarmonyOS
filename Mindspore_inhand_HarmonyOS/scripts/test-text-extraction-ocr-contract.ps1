Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$required = @(
  'entry\src\main\resources\rawfile\models\ocr\ppocrv3_det.mnn',
  'entry\src\main\resources\rawfile\models\ocr\ppocrv3_rec.mnn',
  'entry\src\main\resources\rawfile\models\ocr\ppocr_keys_v1.txt',
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

Write-Output 'OCR asset, fixture, and CER contract passed.'
