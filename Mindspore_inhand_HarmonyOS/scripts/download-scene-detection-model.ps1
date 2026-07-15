param(
  [switch]$Force
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$modelRepo = 'https://gitee.com/harmonyos_samples/MSLiteSceneRecognition.git'
$modelCommit = 'af40795ebb2a295d87cd6dcd1383782a78776cda'
$modelPath = Join-Path $repoRoot 'entry/src/main/resources/rawfile/model/resnet18-place365.ms'
$modelDir = Split-Path -Parent $modelPath
$tmpRoot = Join-Path ([System.IO.Path]::GetTempPath()) "MSLiteSceneRecognition-model-$([System.Guid]::NewGuid().ToString('N'))"
$sourceModelPath = Join-Path $tmpRoot 'entry/src/main/resources/rawfile/resnet18-place365.ms'
$expectedModelSize = 45448504
$expectedModelSha256 = '286F2C85249FD51F6C437986E1C2C1F4EC10358A9B0EB97C886F2DC1AC63ECD9'
$tmpPath = Join-Path $modelDir "resnet18-place365.ms.download.$([System.Guid]::NewGuid().ToString('N'))"
$backupPath = "$tmpPath.backup"

New-Item -ItemType Directory -Force -Path $modelDir | Out-Null

if ((Test-Path -LiteralPath $modelPath) -and -not $Force) {
  $size = (Get-Item -LiteralPath $modelPath).Length
  Write-Host "resnet18-place365.ms already exists: $modelPath ($size bytes)"
  exit 0
}

try {
  New-Item -ItemType Directory -Force -Path $tmpRoot | Out-Null

  Write-Host "Fetching $modelRepo at $modelCommit"
  git -C $tmpRoot init | Out-Null
  git -C $tmpRoot remote add origin $modelRepo
  git -C $tmpRoot fetch --depth 1 origin $modelCommit
  git -C $tmpRoot checkout --detach FETCH_HEAD | Out-Null

  $actualCommit = git -C $tmpRoot rev-parse HEAD
  if ($actualCommit -ne $modelCommit) {
    throw "Fetched unexpected MSLiteSceneRecognition commit $actualCommit; expected $modelCommit."
  }

  if (!(Test-Path -LiteralPath $sourceModelPath)) {
    throw "Could not find resnet18-place365.ms in cloned MSLiteSceneRecognition sample."
  }

  $downloadedSize = (Get-Item -LiteralPath $sourceModelPath).Length
  if ($downloadedSize -ne $expectedModelSize) {
    throw "Downloaded resnet18-place365.ms has $downloadedSize bytes; expected $expectedModelSize bytes."
  }

  $downloadedHash = (Get-FileHash -LiteralPath $sourceModelPath -Algorithm SHA256).Hash
  if ($downloadedHash -cne $expectedModelSha256) {
    throw "Downloaded scene model SHA256 $downloadedHash does not match expected $expectedModelSha256."
  }

  Copy-Item -LiteralPath $sourceModelPath -Destination $tmpPath
  $stagedSize = (Get-Item -LiteralPath $tmpPath).Length
  $stagedHash = (Get-FileHash -LiteralPath $tmpPath -Algorithm SHA256).Hash
  if ($stagedSize -ne $expectedModelSize -or $stagedHash -cne $expectedModelSha256) {
    throw "Staged resnet18-place365.ms failed exact byte verification."
  }

  if (Test-Path -LiteralPath $modelPath) {
    [System.IO.File]::Replace($tmpPath, $modelPath, $backupPath)
  } else {
    [System.IO.File]::Move($tmpPath, $modelPath)
  }
  Write-Host "resnet18-place365.ms downloaded: $modelPath ($downloadedSize bytes)"
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
  if (Test-Path -LiteralPath $tmpRoot) {
    Remove-Item -LiteralPath $tmpRoot -Recurse -Force
  }
}
