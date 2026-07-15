param(
  [switch]$Force
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$modelUrl = 'https://download.mindspore.cn/model_zoo/official/lite/ssd_mobilenetv2_lite/ssd.ms'
$modelPath = Join-Path $repoRoot 'entry/src/main/resources/rawfile/model/ssd.ms'
$modelDir = Split-Path -Parent $modelPath
$expectedModelSize = 17515528
$expectedModelSha256 = '0AAB891E297109836120F4F0A43C1547F813D4B530948F2926DE171FFF91B553'
$tmpPath = Join-Path $modelDir "ssd.ms.download.$([System.Guid]::NewGuid().ToString('N'))"
$backupPath = "$tmpPath.backup"

New-Item -ItemType Directory -Force -Path $modelDir | Out-Null

if ((Test-Path -LiteralPath $modelPath) -and -not $Force) {
  $size = (Get-Item -LiteralPath $modelPath).Length
  Write-Host "ssd.ms already exists: $modelPath ($size bytes)"
  exit 0
}

try {
  Write-Host "Downloading $modelUrl"
  Invoke-WebRequest -Uri $modelUrl -OutFile $tmpPath

  $downloadedSize = (Get-Item -LiteralPath $tmpPath).Length
  if ($downloadedSize -ne $expectedModelSize) {
    throw "Downloaded ssd.ms has $downloadedSize bytes; expected $expectedModelSize bytes."
  }
  $downloadedSha256 = (Get-FileHash -LiteralPath $tmpPath -Algorithm SHA256).Hash
  if ($downloadedSha256 -cne $expectedModelSha256) {
    throw "Downloaded ssd.ms SHA256 $downloadedSha256 does not match expected $expectedModelSha256."
  }

  if (Test-Path -LiteralPath $modelPath) {
    [System.IO.File]::Replace($tmpPath, $modelPath, $backupPath)
  } else {
    [System.IO.File]::Move($tmpPath, $modelPath)
  }
  Write-Host "ssd.ms downloaded: $modelPath ($downloadedSize bytes)"
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
