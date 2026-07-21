param(
  [switch]$Force,
  [string]$Python = 'python'
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'StyleTransferModelPairPublisher.psm1') -Force

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

$stablePaths = @($models | ForEach-Object { Join-Path $modelDir $_.Name })
if (-not $Force -and @($stablePaths | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf }).Count -eq 2) {
  Write-Host "Style-transfer model pair already exists: $modelDir"
  return
}

$sourceTmpPaths = @()
$candidatePaths = @()
try {
  foreach ($model in $models) {
    $requestId = [System.Guid]::NewGuid().ToString('N')
    $sourceTmpPath = Join-Path $modelDir "$($model.Name).source.download.$requestId"
    $tmpPath = Join-Path $modelDir "$($model.Name).download.$requestId"
    $sourceTmpPaths += $sourceTmpPath
    $candidatePaths += $tmpPath

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

  }

  Publish-StyleTransferModelPair -CandidatePaths $candidatePaths -StablePaths $stablePaths
  foreach ($modelPath in $stablePaths) {
    Write-Host "Style-transfer pair member published: $modelPath"
  }
} finally {
  foreach ($path in @($sourceTmpPaths + $candidatePaths)) {
    Remove-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue
  }
}
