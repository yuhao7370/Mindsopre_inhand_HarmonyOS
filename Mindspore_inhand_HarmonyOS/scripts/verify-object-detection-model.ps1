$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$modelPath = Join-Path $repoRoot 'entry/src/main/resources/rawfile/model/ssd.ms'

if (-not (Test-Path -LiteralPath $modelPath)) {
  throw "Missing object detection model: $modelPath. Run scripts/download-object-detection-model.ps1 first."
}

$size = (Get-Item -LiteralPath $modelPath).Length
if ($size -lt 1048576) {
  throw "Object detection model is unexpectedly small: $size bytes"
}

Write-Host "ssd.ms verified: $modelPath ($size bytes)"
