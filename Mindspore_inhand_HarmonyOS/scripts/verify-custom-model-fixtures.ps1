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
  [pscustomobject]@{ Name = 'custom_channel_mean_non_finite.tflite'; Bytes = 1184; Sha256 = 'C722CA178EBBAB5AD6ECDF4327B46FFD72E009EE62FC46E858C4D41DA03DA52D' },
  [pscustomobject]@{ Name = 'custom_text_classifier.tflite'; Bytes = 1800; Sha256 = '24F70321EE950765DEC2AEEDD722989D27D878646484A6C2F3A34F911417E991' }
)
$packageFiles = @(
  [pscustomobject]@{ Name = 'package_image/manifest.json'; Bytes = 608; Sha256 = 'FB6CA7750108A250C73E012337A11B69C356FB204D617F4082C490B785F45928' },
  [pscustomobject]@{ Name = 'package_image/model.ms'; Bytes = 600; Sha256 = 'DB1A0A273DA0658155473FB391E95D027D0D5606C72FB2FFB18BFAE0FDC85409' },
  [pscustomobject]@{ Name = 'package_image/labels.txt'; Bytes = 15; Sha256 = '9FEC8B87D457CDAB76088586670CBCC3B6F5F39EF95B320C07F4EC2B539C2BE4' },
  [pscustomobject]@{ Name = 'package_text/manifest.json'; Bytes = 698; Sha256 = 'A9C9CF7A7F80E750A33AC38693C8FE83D7CD32A93B798EE2607A54CE68F6D9C1' },
  [pscustomobject]@{ Name = 'package_text/model.ms'; Bytes = 1568; Sha256 = '25E35BA4F0AC6B2B03212463AAAF7ED38D91ADC2C051C22AB996DA7E4CDC9616' },
  [pscustomobject]@{ Name = 'package_text/labels.txt'; Bytes = 11; Sha256 = '05D0289DE2955DE2DB74DE252F42E4FCA15F90313DC0F79310CC3F3CDC3D3493' },
  [pscustomobject]@{ Name = 'package_text/tokenizer.ttok'; Bytes = 387; Sha256 = '67A878144B949ECC33BF122B213B654690D3002CEC5BAA5DDF08321A70AE9048' }
)
$packages = @(
  [pscustomobject]@{ Name = 'custom_image_package.zip'; Bytes = 1024; Sha256 = 'BAC3A321D4B0D3C631FE71BE30F3D85A459BB90C9A9F1EF169D417A00F458BDB' },
  [pscustomobject]@{ Name = 'custom_text_package.zip'; Bytes = 1620; Sha256 = '06075F09DB7602412656F16F9CE45CA2EF4D63ECA54D98FCD86BDE4B97221087' }
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

foreach ($contract in $packageFiles) {
  $path = Join-Path $sourceRoot $contract.Name
  if ((Get-Item -LiteralPath $path).Length -ne $contract.Bytes -or
    (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -cne $contract.Sha256) {
    throw "$($contract.Name) differs from the locked package source."
  }
}
foreach ($contract in $packages) {
  $path = Join-Path $modelRoot $contract.Name
  if ((Get-Item -LiteralPath $path).Length -ne $contract.Bytes -or
    (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -cne $contract.Sha256) {
    throw "$($contract.Name) differs from the reproducible package."
  }
}

Write-Host 'Custom Model sources, models, and package hashes verified.'
