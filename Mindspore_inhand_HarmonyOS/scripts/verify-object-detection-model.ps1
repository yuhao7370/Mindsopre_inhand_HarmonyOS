$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$modelPath = Join-Path $repoRoot 'entry/src/main/resources/rawfile/model/nanodet_plus_m_320.mnn'
$expectedModelSize = 4785492
$expectedModelSha256 = '8E0266D957F8CCA939952F4349639438967EB855FA2EDD1C430546EC0C447E9C'

if (-not (Test-Path -LiteralPath $modelPath)) {
  throw "Missing object detection model: $modelPath. Run scripts/download-object-detection-model.ps1 first."
}

$actualModelSize = (Get-Item -LiteralPath $modelPath).Length
if ($actualModelSize -ne $expectedModelSize) {
  throw "nanodet_plus_m_320.mnn has unexpected size $actualModelSize bytes; expected $expectedModelSize bytes."
}

$actualModelSha256 = (Get-FileHash -LiteralPath $modelPath -Algorithm SHA256).Hash
if ($actualModelSha256 -cne $expectedModelSha256) {
  throw "nanodet_plus_m_320.mnn has unexpected SHA256 $actualModelSha256; expected $expectedModelSha256."
}

Write-Host "nanodet_plus_m_320.mnn verified: $modelPath ($actualModelSize bytes)"
