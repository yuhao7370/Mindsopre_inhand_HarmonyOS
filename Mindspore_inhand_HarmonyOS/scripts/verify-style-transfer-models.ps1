$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$modelDir = Join-Path $repoRoot 'entry/src/main/resources/rawfile/model'
$models = @(
  [pscustomobject]@{ Name = 'style_predict_fp16.mnn'; Bytes = 9354924; Sha256 = 'E23E713FA343B20B11110F8E02FFAA54E3E18B9CB17F26E42B3D7F32135144A6' },
  [pscustomobject]@{ Name = 'style_transform_fp16.mnn'; Bytes = 771144; Sha256 = '079005963B9EBA264BDEF0CD78921612A99344771AE31ACD0423A730D6FB9724' }
)

foreach ($model in $models) {
  $modelPath = Join-Path $modelDir $model.Name
  if (-not (Test-Path -LiteralPath $modelPath)) {
    throw "Missing style transfer model: $modelPath. Run scripts/download-style-transfer-models.ps1 first."
  }

  $actualModelSize = (Get-Item -LiteralPath $modelPath).Length
  if ($actualModelSize -ne $model.Bytes) {
    throw "$($model.Name) has unexpected size $actualModelSize bytes; expected $($model.Bytes) bytes."
  }

  $actualModelSha256 = (Get-FileHash -LiteralPath $modelPath -Algorithm SHA256).Hash
  if ($actualModelSha256 -cne $model.Sha256) {
    throw "$($model.Name) has unexpected SHA256 $actualModelSha256; expected $($model.Sha256)."
  }

  Write-Host "$($model.Name) verified: $modelPath ($actualModelSize bytes)"
}
