$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$labelPath = Join-Path $repoRoot 'entry/src/main/resources/rawfile/labels/object_category.txt'

if (-not (Test-Path -LiteralPath $labelPath)) {
  throw "Missing object detection label rawfile: $labelPath"
}

$firstBytes = Get-Content -LiteralPath $labelPath -Encoding Byte -TotalCount 3
if ($firstBytes.Length -ge 3 -and $firstBytes[0] -eq 0xEF -and $firstBytes[1] -eq 0xBB -and $firstBytes[2] -eq 0xBF) {
  throw 'object_category.txt must be UTF-8 without BOM.'
}

$labels = @(Get-Content -LiteralPath $labelPath -Encoding UTF8)
if ($labels.Count -ne 81) {
  throw "Expected 81 object detection labels, got $($labels.Count)."
}

if ($labels[0] -ne 'background') {
  throw "Expected first label background, got $($labels[0])."
}

if ($labels[$labels.Count - 1] -ne 'toothbrush') {
  throw "Expected last label toothbrush, got $($labels[$labels.Count - 1])."
}

Write-Host "object_category labels verified: $($labels.Count) labels, $($labels[0]) ... $($labels[$labels.Count - 1])"
