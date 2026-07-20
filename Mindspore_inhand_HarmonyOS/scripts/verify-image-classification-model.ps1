$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$modelPath = Join-Path $repoRoot 'entry/src/main/resources/rawfile/model/mobilenetv2.ms'
$expectedModelSize = 13988384
$expectedModelSha256 = '5A7CCD53BF92D8B294A703A1302D4230A311B2D19A8D212EEDD65FF6838CFA84'

if (-not (Test-Path -LiteralPath $modelPath)) {
  throw "Missing image classification model rawfile: $modelPath. Run scripts/download-image-classification-model.ps1 first."
}

$actualModelSize = (Get-Item -LiteralPath $modelPath).Length
if ($actualModelSize -ne $expectedModelSize) {
  throw "mobilenetv2.ms has unexpected size $actualModelSize bytes; expected $expectedModelSize bytes."
}

$actualModelSha256 = (Get-FileHash -LiteralPath $modelPath -Algorithm SHA256).Hash
if ($actualModelSha256 -cne $expectedModelSha256) {
  throw "mobilenetv2.ms has unexpected SHA256 $actualModelSha256; expected $expectedModelSha256."
}

Write-Host "mobilenetv2.ms verified: $modelPath ($actualModelSize bytes)"
