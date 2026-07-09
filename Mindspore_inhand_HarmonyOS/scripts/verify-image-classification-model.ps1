$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$modelPath = Join-Path $repoRoot 'entry/src/main/resources/rawfile/model/mobilenetv2.ms'

if (-not (Test-Path -LiteralPath $modelPath)) {
  throw "Missing image classification model rawfile: $modelPath. Run scripts/download-image-classification-model.ps1 first."
}

$size = (Get-Item -LiteralPath $modelPath).Length
if ($size -lt 1048576) {
  throw "mobilenetv2.ms is unexpectedly small: $size bytes"
}

Write-Host "mobilenetv2.ms verified: $size bytes"
