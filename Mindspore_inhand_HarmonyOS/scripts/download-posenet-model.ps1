param(
  [string]$ConvertedModelPath = '',
  [switch]$Force
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$sourceUrl = 'https://tfhub.dev/google/lite-model/movenet/singlepose/lightning/tflite/float16/4?lite-format=tflite'
$sourcePath = Join-Path $repoRoot 'model_sources/posenet/movenet_singlepose_lightning_float16_v4.tflite'
$sourceDir = Split-Path -Parent $sourcePath
$expectedSourceSize = 4758512
$expectedSourceSha256 = '0FAC2226112D0371903CA86E3853CEC24EF603A0B2F96F589B180F0EBDD135AB'
$modelPath = Join-Path $repoRoot 'entry/src/main/resources/rawfile/model/movenet_singlepose_lightning_float16_v4.ms'
$modelDir = Split-Path -Parent $modelPath
$expectedModelSize = 9348680
$expectedModelSha256 = '972F3BE55A484B0A86A418693CF134C5BD5BD32B3418965891E7FF1DD2874677'
$sourceTmpPath = Join-Path $sourceDir "movenet_singlepose_lightning_float16_v4.tflite.download.$([System.Guid]::NewGuid().ToString('N'))"
$tmpPath = Join-Path $modelDir "movenet_singlepose_lightning_float16_v4.ms.download.$([System.Guid]::NewGuid().ToString('N'))"
$backupPath = "$tmpPath.backup"

New-Item -ItemType Directory -Force -Path $sourceDir, $modelDir | Out-Null

try {
  if ($Force -or -not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
    Invoke-WebRequest -Uri $sourceUrl -OutFile $sourceTmpPath
    if ((Get-Item -LiteralPath $sourceTmpPath).Length -ne $expectedSourceSize -or
        (Get-FileHash -LiteralPath $sourceTmpPath -Algorithm SHA256).Hash -cne $expectedSourceSha256) {
      throw 'Downloaded MoveNet FLOAT16 v4 TFLite does not match the pinned source bytes.'
    }
    if (Test-Path -LiteralPath $sourcePath) {
      [System.IO.File]::Replace($sourceTmpPath, $sourcePath, "$sourceTmpPath.backup")
      Remove-Item -LiteralPath "$sourceTmpPath.backup" -Force -ErrorAction SilentlyContinue
    } else {
      [System.IO.File]::Move($sourceTmpPath, $sourcePath)
    }
  }
  if ((Get-Item -LiteralPath $sourcePath).Length -ne $expectedSourceSize -or
      (Get-FileHash -LiteralPath $sourcePath -Algorithm SHA256).Hash -cne $expectedSourceSha256) {
    throw 'Tracked MoveNet TFLite source does not match the pinned contract.'
  }

  if (-not $ConvertedModelPath) {
    if (Test-Path -LiteralPath $modelPath -PathType Leaf) {
      if ((Get-Item -LiteralPath $modelPath).Length -eq $expectedModelSize -and
          (Get-FileHash -LiteralPath $modelPath -Algorithm SHA256).Hash -ceq $expectedModelSha256) {
        Write-Host "MoveNet source and converted model already verified: $modelPath"
        exit 0
      }
    }
    throw 'Pass -ConvertedModelPath after running scripts/convert-posenet-model.sh with the pinned MindSpore Lite 2.6.0 archive.'
  }

  Copy-Item -LiteralPath $ConvertedModelPath -Destination $tmpPath
  if ((Get-Item -LiteralPath $tmpPath).Length -ne $expectedModelSize) {
    throw "Converted MoveNet model has unexpected byte length."
  }
  if ((Get-FileHash -LiteralPath $tmpPath -Algorithm SHA256).Hash -cne $expectedModelSha256) {
    throw 'Converted MoveNet model SHA-256 does not match the pinned reproducible artifact.'
  }
  if (Test-Path -LiteralPath $modelPath) {
    [System.IO.File]::Replace($tmpPath, $modelPath, $backupPath)
  } else {
    [System.IO.File]::Move($tmpPath, $modelPath)
  }
  Write-Host "MoveNet model published: $modelPath ($expectedModelSize bytes)"
} catch {
  $failure = $_
  if ((Test-Path -LiteralPath $backupPath) -and -not (Test-Path -LiteralPath $modelPath)) {
    [System.IO.File]::Move($backupPath, $modelPath)
  }
  throw $failure
} finally {
  Remove-Item -LiteralPath $sourceTmpPath -Force -ErrorAction SilentlyContinue
  Remove-Item -LiteralPath $tmpPath -Force -ErrorAction SilentlyContinue
  if (Test-Path -LiteralPath $modelPath) {
    Remove-Item -LiteralPath $backupPath -Force -ErrorAction SilentlyContinue
  }
}
