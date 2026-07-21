$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$modelRoot = Join-Path $projectRoot 'entry/src/main/resources/rawfile/model'
$sourceRoot = Join-Path $projectRoot 'model_sources/custom_model'

$models = @(
  [pscustomobject]@{ Name = 'custom_channel_mean.ms'; Bytes = 600; Sha256 = 'DB1A0A273DA0658155473FB391E95D027D0D5606C72FB2FFB18BFAE0FDC85409' },
  [pscustomobject]@{ Name = 'custom_channel_mean_inverted.ms'; Bytes = 800; Sha256 = '7EB540E46CE1437FB3004CAB1AF80BBAEBE2D83355923DA4432006482EA336D9' },
  [pscustomobject]@{ Name = 'custom_channel_mean_non_finite.ms'; Bytes = 800; Sha256 = 'C8087D8D7C94CD3BB92F872BC0665CABC0BB343A6C0D16B276FC4659C4AE0957' }
)
$sources = @(
  [pscustomobject]@{ Name = 'custom_channel_mean.tflite'; Bytes = 948; Sha256 = '99A725E615C3B6B64C015DCE2EFE5796DCA65DDA22DD6B5B1753F500447A9B7A' },
  [pscustomobject]@{ Name = 'custom_channel_mean_inverted.tflite'; Bytes = 1180; Sha256 = 'AFC464560DFE364E68B7D83544FB45E141B5A471813166FA7FCEEC37166D47AD' },
  [pscustomobject]@{ Name = 'custom_channel_mean_non_finite.tflite'; Bytes = 1184; Sha256 = 'C722CA178EBBAB5AD6ECDF4327B46FFD72E009EE62FC46E858C4D41DA03DA52D' }
)

foreach ($contract in $models) {
  $modelPath = Join-Path $modelRoot $contract.Name
  if (-not (Test-Path -LiteralPath $modelPath -PathType Leaf)) {
    throw "Missing Custom Model fixture: $modelPath"
  }
  if ((Get-Item -LiteralPath $modelPath).Length -ne $contract.Bytes) {
    throw "$($contract.Name) has an unexpected byte length."
  }
  if ((Get-FileHash -LiteralPath $modelPath -Algorithm SHA256).Hash -cne $contract.Sha256) {
    throw "$($contract.Name) has an unexpected SHA-256."
  }
}

foreach ($contract in $sources) {
  $sourcePath = Join-Path $sourceRoot $contract.Name
  if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
    throw "Missing Custom Model TFLite source: $sourcePath"
  }
  if ((Get-Item -LiteralPath $sourcePath).Length -ne $contract.Bytes) {
    throw "$($contract.Name) has an unexpected byte length."
  }
  if ((Get-FileHash -LiteralPath $sourcePath -Algorithm SHA256).Hash -cne $contract.Sha256) {
    throw "$($contract.Name) has an unexpected SHA-256."
  }
}

Write-Host 'Custom Model source and MindSpore Lite fixture hashes verified.'
