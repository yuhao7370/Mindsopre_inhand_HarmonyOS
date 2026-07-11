$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot

function Assert-ObjectDetectionLabels {
  param(
    [string] $RelativePath,
    [int] $ExpectedCount,
    [string] $ExpectedFirst,
    [string] $ExpectedLast
  )

  $labelPath = Join-Path $repoRoot "entry/src/main/resources/rawfile/$RelativePath"

  if (-not (Test-Path -LiteralPath $labelPath)) {
    throw "Missing object detection label rawfile: $labelPath"
  }

  $firstBytes = Get-Content -LiteralPath $labelPath -Encoding Byte -TotalCount 3
  if ($firstBytes.Length -ge 3 -and $firstBytes[0] -eq 0xEF -and $firstBytes[1] -eq 0xBB -and $firstBytes[2] -eq 0xBF) {
    throw "$RelativePath must be UTF-8 without BOM."
  }

  $labels = @(Get-Content -LiteralPath $labelPath -Encoding UTF8)
  if ($labels.Count -ne $ExpectedCount) {
    throw "Expected $ExpectedCount object detection labels in $RelativePath, got $($labels.Count)."
  }

  if ($ExpectedFirst.Length -gt 0 -and $labels[0] -ne $ExpectedFirst) {
    throw "Expected first label $ExpectedFirst in $RelativePath, got $($labels[0])."
  }

  if ($ExpectedLast.Length -gt 0 -and $labels[$labels.Count - 1] -ne $ExpectedLast) {
    throw "Expected last label $ExpectedLast in $RelativePath, got $($labels[$labels.Count - 1])."
  }

  Write-Host "$RelativePath verified: $($labels.Count) labels"
}

Assert-ObjectDetectionLabels 'labels/object_category.txt' 81 'background' 'toothbrush'
Assert-ObjectDetectionLabels 'labels/zh_CN/object_category.txt' 81 '' ''
