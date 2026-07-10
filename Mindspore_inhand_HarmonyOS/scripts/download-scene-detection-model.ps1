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
$expectedModelSha256 = '286F2C85249FD51F6C437986E1C2C1F4EC10358A9B0EB97C886F2DC1AC63ECD9'
$minimumModelSize = 1048576

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
  if ($downloadedSize -lt $minimumModelSize) {
    throw "Downloaded scene model is unexpectedly small: $downloadedSize bytes"
  }

  $downloadedHash = (Get-FileHash -LiteralPath $sourceModelPath -Algorithm SHA256).Hash
  if ($downloadedHash -ne $expectedModelSha256) {
    throw "Downloaded scene model SHA256 $downloadedHash does not match expected $expectedModelSha256."
  }

  Copy-Item -LiteralPath $sourceModelPath -Destination $modelPath -Force
  Write-Host "resnet18-place365.ms downloaded: $modelPath ($downloadedSize bytes)"
} finally {
  if (Test-Path -LiteralPath $tmpRoot) {
    Remove-Item -LiteralPath $tmpRoot -Recurse -Force
  }
}
