param(
  [switch]$Force
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$modelDir = Join-Path $repoRoot 'entry/src/main/resources/rawfile/model'
$minimumModelSize = 65536

$models = @(
  @{
    Name = 'style_predict_quant.ms'
    Url = 'https://download.mindspore.cn/model_zoo/official/lite/style_lite/style_predict_quant.ms'
  },
  @{
    Name = 'style_transfer_quant.ms'
    Url = 'https://download.mindspore.cn/model_zoo/official/lite/style_lite/style_transfer_quant.ms'
  }
)

New-Item -ItemType Directory -Force -Path $modelDir | Out-Null

foreach ($model in $models) {
  $modelPath = Join-Path $modelDir $model.Name
  $tmpPath = "$modelPath.download"

  if ((Test-Path -LiteralPath $modelPath) -and -not $Force) {
    $size = (Get-Item -LiteralPath $modelPath).Length
    Write-Host "$($model.Name) already exists: $modelPath ($size bytes)"
    continue
  }

  if (Test-Path -LiteralPath $tmpPath) {
    Remove-Item -LiteralPath $tmpPath -Force
  }

  Write-Host "Downloading $($model.Url)"
  Invoke-WebRequest -Uri $model.Url -OutFile $tmpPath

  $downloadedSize = (Get-Item -LiteralPath $tmpPath).Length
  if ($downloadedSize -lt $minimumModelSize) {
    Remove-Item -LiteralPath $tmpPath -Force
    throw "Downloaded model is unexpectedly small: $downloadedSize bytes"
  }

  Move-Item -LiteralPath $tmpPath -Destination $modelPath -Force
  Write-Host "$($model.Name) downloaded: $modelPath ($downloadedSize bytes)"
}
