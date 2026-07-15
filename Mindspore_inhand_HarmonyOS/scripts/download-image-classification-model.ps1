param(
  [switch]$Force
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$modelUrl = 'https://download.mindspore.cn/model_zoo/official/lite/mobilenetv2_imagenet/mobilenetv2.ms'
$modelPath = Join-Path $repoRoot 'entry/src/main/resources/rawfile/model/mobilenetv2.ms'
$modelDir = Split-Path -Parent $modelPath
$expectedModelSize = 14014408
$expectedModelSha256 = 'F88C8C410D1148F5614994038680C245E1788C80E578D093E536572D08ECC514'
$tmpPath = Join-Path $modelDir "mobilenetv2.ms.download.$([System.Guid]::NewGuid().ToString('N'))"
$backupPath = "$tmpPath.backup"

New-Item -ItemType Directory -Force -Path $modelDir | Out-Null

if ((Test-Path -LiteralPath $modelPath) -and -not $Force) {
  $size = (Get-Item -LiteralPath $modelPath).Length
  Write-Host "mobilenetv2.ms already exists: $modelPath ($size bytes)"
  exit 0
}

try {
  Write-Host "Downloading $modelUrl"
  Invoke-WebRequest -Uri $modelUrl -OutFile $tmpPath

  $downloadedSize = (Get-Item -LiteralPath $tmpPath).Length
  if ($downloadedSize -ne $expectedModelSize) {
    throw "Downloaded mobilenetv2.ms has $downloadedSize bytes; expected $expectedModelSize bytes."
  }
  $downloadedSha256 = (Get-FileHash -LiteralPath $tmpPath -Algorithm SHA256).Hash
  if ($downloadedSha256 -cne $expectedModelSha256) {
    throw "Downloaded mobilenetv2.ms SHA256 $downloadedSha256 does not match expected $expectedModelSha256."
  }

  if (Test-Path -LiteralPath $modelPath) {
    [System.IO.File]::Replace($tmpPath, $modelPath, $backupPath)
  } else {
    [System.IO.File]::Move($tmpPath, $modelPath)
  }
  Write-Host "mobilenetv2.ms downloaded: $modelPath ($downloadedSize bytes)"
} catch {
  $failure = $_
  if ((Test-Path -LiteralPath $backupPath) -and -not (Test-Path -LiteralPath $modelPath)) {
    [System.IO.File]::Move($backupPath, $modelPath)
  }
  throw $failure
} finally {
  Remove-Item -LiteralPath $tmpPath -Force -ErrorAction SilentlyContinue
  if (Test-Path -LiteralPath $modelPath) {
    Remove-Item -LiteralPath $backupPath -Force -ErrorAction SilentlyContinue
  }
}
