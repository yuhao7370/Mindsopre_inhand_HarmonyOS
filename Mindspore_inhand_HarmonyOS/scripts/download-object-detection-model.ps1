param(
  [switch]$Force,
  [string]$Python = 'python',
  [string]$Converter = 'mnnconvert'
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$modelUrl = 'https://github.com/RangiLyu/nanodet/releases/download/v1.0.0-alpha-1/nanodet-plus-m_320.onnx'
$modelPath = Join-Path $repoRoot 'entry/src/main/resources/rawfile/model/nanodet_plus_m_320.mnn'
$modelDir = Split-Path -Parent $modelPath
$expectedOnnxSize = 4793615
$expectedOnnxSha256 = '4F12723CCE3D48E47CA92CB925BA74D97A965C069208EDCA660BBB9F7CE2C610'
$expectedModelSize = 4785492
$expectedModelSha256 = '8E0266D957F8CCA939952F4349639438967EB855FA2EDD1C430546EC0C447E9C'
$requestId = [System.Guid]::NewGuid().ToString('N')
$onnxPath = Join-Path $modelDir "nanodet-plus-m_320.onnx.download.$requestId"
$tmpPath = Join-Path $modelDir "nanodet_plus_m_320.mnn.download.$requestId"
$backupPath = "$tmpPath.backup"

New-Item -ItemType Directory -Force -Path $modelDir | Out-Null

if ((Test-Path -LiteralPath $modelPath) -and -not $Force) {
  & (Join-Path $PSScriptRoot 'verify-object-detection-model.ps1')
  exit 0
}

try {
  $mnnVersion = (& $Python -c "import MNN; print(MNN.__version__)" 2>&1 | Out-String).Trim()
  if ($LASTEXITCODE -ne 0 -or $mnnVersion -ne '3.6.0') {
    throw "MNN Python package 3.6.0 is required; detected '$mnnVersion'."
  }

  Write-Host "Downloading $modelUrl"
  Invoke-WebRequest -Uri $modelUrl -OutFile $onnxPath
  $downloadedOnnxSize = (Get-Item -LiteralPath $onnxPath).Length
  if ($downloadedOnnxSize -ne $expectedOnnxSize) {
    throw "Downloaded NanoDet ONNX has $downloadedOnnxSize bytes; expected $expectedOnnxSize bytes."
  }
  $downloadedOnnxSha256 = (Get-FileHash -LiteralPath $onnxPath -Algorithm SHA256).Hash
  if ($downloadedOnnxSha256 -cne $expectedOnnxSha256) {
    throw "Downloaded NanoDet ONNX SHA256 $downloadedOnnxSha256 does not match expected $expectedOnnxSha256."
  }

  $converterOutput = @(& $Converter -f ONNX --modelFile $onnxPath --MNNModel $tmpPath --bizCode MNN 2>&1)
  $converterExitCode = $LASTEXITCODE
  $convertedSuccessfully = ($converterOutput | Out-String).Contains('Converted Success!')
  $knownWindowsPostWriteExitCode = -1073741819
  if ($converterExitCode -ne 0 -and
      ($converterExitCode -ne $knownWindowsPostWriteExitCode -or -not $convertedSuccessfully)) {
    throw "MNN 3.6.0 conversion failed with exit code $converterExitCode.`n$($converterOutput -join [Environment]::NewLine)"
  }

  $convertedSize = (Get-Item -LiteralPath $tmpPath).Length
  if ($convertedSize -ne $expectedModelSize) {
    throw "Converted NanoDet MNN has $convertedSize bytes; expected $expectedModelSize bytes."
  }
  $convertedSha256 = (Get-FileHash -LiteralPath $tmpPath -Algorithm SHA256).Hash
  if ($convertedSha256 -cne $expectedModelSha256) {
    throw "Converted NanoDet MNN SHA256 $convertedSha256 does not match expected $expectedModelSha256."
  }
  if ($converterExitCode -eq $knownWindowsPostWriteExitCode) {
    Write-Warning "MNN 3.6.0 exited with the known Windows post-write access violation; exact output size and SHA-256 verified."
  }

  if (Test-Path -LiteralPath $modelPath) {
    [System.IO.File]::Replace($tmpPath, $modelPath, $backupPath)
  } else {
    [System.IO.File]::Move($tmpPath, $modelPath)
  }
  Write-Host "NanoDet MNN published: $modelPath ($convertedSize bytes)"
} catch {
  $failure = $_
  if ((Test-Path -LiteralPath $backupPath) -and -not (Test-Path -LiteralPath $modelPath)) {
    [System.IO.File]::Move($backupPath, $modelPath)
  }
  throw $failure
} finally {
  Remove-Item -LiteralPath $onnxPath -Force -ErrorAction SilentlyContinue
  Remove-Item -LiteralPath $tmpPath -Force -ErrorAction SilentlyContinue
  if (Test-Path -LiteralPath $modelPath) {
    Remove-Item -LiteralPath $backupPath -Force -ErrorAction SilentlyContinue
  }
}
