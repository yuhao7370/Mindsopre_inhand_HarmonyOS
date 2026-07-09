$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$modelDir = Join-Path $repoRoot 'entry/src/main/resources/rawfile/model'
$modelNames = @('style_predict_quant.ms', 'style_transfer_quant.ms')
$minimumModelSize = 65536

foreach ($modelName in $modelNames) {
  $modelPath = Join-Path $modelDir $modelName
  if (-not (Test-Path -LiteralPath $modelPath)) {
    throw "Missing style transfer model: $modelPath. Run scripts/download-style-transfer-models.ps1 first."
  }

  $size = (Get-Item -LiteralPath $modelPath).Length
  if ($size -lt $minimumModelSize) {
    throw "Style transfer model is unexpectedly small: $modelName ($size bytes)"
  }

  Write-Host "$modelName verified: $modelPath ($size bytes)"
}
