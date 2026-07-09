param(
  [switch]$Force
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$modelUrl = 'https://download.mindspore.cn/model_zoo/official/lite/mobilenetv2_imagenet/mobilenetv2.ms'
$modelPath = Join-Path $repoRoot 'entry/src/main/resources/rawfile/model/mobilenetv2.ms'
$modelDir = Split-Path -Parent $modelPath
$tmpPath = "$modelPath.download"

New-Item -ItemType Directory -Force -Path $modelDir | Out-Null

if ((Test-Path -LiteralPath $modelPath) -and -not $Force) {
  $size = (Get-Item -LiteralPath $modelPath).Length
  Write-Host "mobilenetv2.ms already exists: $modelPath ($size bytes)"
  exit 0
}

if (Test-Path -LiteralPath $tmpPath) {
  Remove-Item -LiteralPath $tmpPath -Force
}

Write-Host "Downloading $modelUrl"
Invoke-WebRequest -Uri $modelUrl -OutFile $tmpPath

$downloadedSize = (Get-Item -LiteralPath $tmpPath).Length
if ($downloadedSize -lt 1048576) {
  Remove-Item -LiteralPath $tmpPath -Force
  throw "Downloaded model is unexpectedly small: $downloadedSize bytes"
}

Move-Item -LiteralPath $tmpPath -Destination $modelPath -Force
Write-Host "mobilenetv2.ms downloaded: $modelPath ($downloadedSize bytes)"
