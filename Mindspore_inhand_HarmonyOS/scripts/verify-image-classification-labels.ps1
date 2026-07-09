$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$labelPath = Join-Path $repoRoot 'entry/src/main/resources/rawfile/labels/image_category_old.txt'

if (-not (Test-Path -LiteralPath $labelPath)) {
  throw "Missing image classification label rawfile: $labelPath"
}

$firstBytes = Get-Content -LiteralPath $labelPath -Encoding Byte -TotalCount 3
if ($firstBytes.Length -ge 3 -and $firstBytes[0] -eq 0xEF -and $firstBytes[1] -eq 0xBB -and $firstBytes[2] -eq 0xBF) {
  throw 'image_category_old.txt must be UTF-8 without BOM.'
}

$labels = @(Get-Content -LiteralPath $labelPath -Encoding UTF8)
if ($labels.Count -ne 1000) {
  throw "Expected 1000 image classification labels, got $($labels.Count)."
}

if ($labels[0] -ne 'tench') {
  throw "Expected first label tench, got $($labels[0])."
}

if ($labels[$labels.Count - 1] -ne 'toilet_tissue') {
  throw "Expected last label toilet_tissue, got $($labels[$labels.Count - 1])."
}

Write-Host "image_category_old labels verified: $($labels.Count) labels, $($labels[0]) ... $($labels[$labels.Count - 1])"
