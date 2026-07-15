$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$modelPath = Join-Path $repoRoot 'entry/src/main/resources/rawfile/model/ssd.ms'
$expectedModelSize = 17515528
$expectedModelSha256 = '0AAB891E297109836120F4F0A43C1547F813D4B530948F2926DE171FFF91B553'

if (-not (Test-Path -LiteralPath $modelPath)) {
  throw "Missing object detection model: $modelPath. Run scripts/download-object-detection-model.ps1 first."
}

$actualModelSize = (Get-Item -LiteralPath $modelPath).Length
if ($actualModelSize -ne $expectedModelSize) {
  throw "ssd.ms has unexpected size $actualModelSize bytes; expected $expectedModelSize bytes."
}

$actualModelSha256 = (Get-FileHash -LiteralPath $modelPath -Algorithm SHA256).Hash
if ($actualModelSha256 -cne $expectedModelSha256) {
  throw "ssd.ms has unexpected SHA256 $actualModelSha256; expected $expectedModelSha256."
}

Write-Host "ssd.ms verified: $modelPath ($actualModelSize bytes)"
