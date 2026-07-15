$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$modelDir = Join-Path $repoRoot 'entry/src/main/resources/rawfile/model'
$models = @(
  [pscustomobject]@{ Name = 'style_predict_quant.ms'; Bytes = 3022576; Sha256 = '6737696ACC9B2F3ACF7460FEE986614B0107DF347EC9947D9D346D085AFCFBCC' },
  [pscustomobject]@{ Name = 'style_transfer_quant.ms'; Bytes = 256864; Sha256 = 'AEB4963C3906B90F9480E96CC29C39F6BC9CF9DE1ED84C370308E5A0B5B82682' }
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
