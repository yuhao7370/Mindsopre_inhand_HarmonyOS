param(
  [switch]$Force,
  [string]$Python = 'python'
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$modelDir = Join-Path $repoRoot 'entry/src/main/resources/rawfile/model'
$models = @(
  [pscustomobject]@{
    Name = 'style_predict_fp16.mnn'
    Url = 'https://tfhub.dev/google/lite-model/magenta/arbitrary-image-stylization-v1-256/fp16/prediction/1?lite-format=tflite'
    SourceBytes = 4708350
    SourceSha256 = 'DF9578B4141EF1D826F33B5F8E6E8E31BDBBB507B4E1F7CCBD2547AC1299DA42'
    StableUuid = 'df9578b4-141e-f1d8-26f3-3b5f8e6e8e31'
    Bytes = 9354924
    Sha256 = 'E23E713FA343B20B11110F8E02FFAA54E3E18B9CB17F26E42B3D7F32135144A6'
  },
  [pscustomobject]@{
    Name = 'style_transform_fp16.mnn'
    Url = 'https://tfhub.dev/google/lite-model/magenta/arbitrary-image-stylization-v1-256/fp16/transfer/1?lite-format=tflite'
    SourceBytes = 422086
    SourceSha256 = '53B5243ED5AA33E408DB7976C8A8E51A90A0F7708FD122A31428CD00FBDF6AA6'
    StableUuid = '53b5243e-d5aa-33e4-08db-7976c8a8e51a'
    Bytes = 771144
    Sha256 = '079005963B9EBA264BDEF0CD78921612A99344771AE31ACD0423A730D6FB9724'
  }
)

$mnnPackage = & $Python -m pip show MNN 2>$null | Out-String
if ($LASTEXITCODE -ne 0 -or $mnnPackage -notmatch '(?m)^Version:\s*3\.6\.0\s*$') {
  throw 'MNN Python package 3.6.0 is required: python -m pip install MNN==3.6.0'
}

New-Item -ItemType Directory -Force -Path $modelDir | Out-Null

foreach ($model in $models) {
  $modelPath = Join-Path $modelDir $model.Name
  $requestId = [System.Guid]::NewGuid().ToString('N')
  $sourceTmpPath = Join-Path $modelDir "$($model.Name).source.download.$requestId"
  $tmpPath = Join-Path $modelDir "$($model.Name).download.$requestId"
  $backupPath = "$tmpPath.backup"

  if ((Test-Path -LiteralPath $modelPath) -and -not $Force) {
    Write-Host "$($model.Name) already exists: $modelPath"
    continue
  }

  try {
    Write-Host "Downloading audited TFLite source: $($model.Url)"
    Invoke-WebRequest -Uri $model.Url -OutFile $sourceTmpPath
    if ((Get-Item -LiteralPath $sourceTmpPath).Length -ne $model.SourceBytes) {
      throw "Downloaded source for $($model.Name) has an unexpected byte length."
    }
    if ((Get-FileHash -LiteralPath $sourceTmpPath -Algorithm SHA256).Hash -cne $model.SourceSha256) {
      throw "Downloaded source for $($model.Name) has an unexpected SHA-256."
    }

    & $Python -m MNN.tools.mnnconvert -f TFLITE --modelFile $sourceTmpPath --MNNModel $tmpPath --bizCode MNN
    if ($LASTEXITCODE -ne 0) { throw "MNN conversion failed for $($model.Name)." }

    # MNN 3.6.0 emits a random 36-byte mnn_uuid at bytes 72..107. Replace only
    # that metadata with a source-hash-derived UUID so the audited artifact is reproducible.
    $converted = [IO.File]::ReadAllBytes($tmpPath)
    $randomUuid = [Text.Encoding]::ASCII.GetString($converted, 72, 36)
    if ($randomUuid -notmatch '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$') {
      throw "Converted $($model.Name) does not contain the expected MNN UUID metadata."
    }
    $stableUuid = [Text.Encoding]::ASCII.GetBytes($model.StableUuid)
    [Array]::Copy($stableUuid, 0, $converted, 72, 36)
    [IO.File]::WriteAllBytes($tmpPath, $converted)

    if ((Get-Item -LiteralPath $tmpPath).Length -ne $model.Bytes) {
      throw "Converted $($model.Name) has an unexpected byte length."
    }
    if ((Get-FileHash -LiteralPath $tmpPath -Algorithm SHA256).Hash -cne $model.Sha256) {
      throw "Converted $($model.Name) differs from the audited MNN artifact."
    }

    if (Test-Path -LiteralPath $modelPath) {
      [System.IO.File]::Replace($tmpPath, $modelPath, $backupPath)
    } else {
      [System.IO.File]::Move($tmpPath, $modelPath)
    }
    Write-Host "$($model.Name) published: $modelPath"
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
}
