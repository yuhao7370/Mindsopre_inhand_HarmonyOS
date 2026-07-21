$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$sourcePath = Join-Path $repoRoot 'model_sources/posenet/movenet_singlepose_lightning_float16_v4.tflite'
$expectedSourceSize = 4758512
$expectedSourceSha256 = '0FAC2226112D0371903CA86E3853CEC24EF603A0B2F96F589B180F0EBDD135AB'
$modelPath = Join-Path $repoRoot 'entry/src/main/resources/rawfile/model/movenet_singlepose_lightning_float16_v4.ms'
$expectedModelSize = 9348680
$expectedModelSha256 = '972F3BE55A484B0A86A418693CF134C5BD5BD32B3418965891E7FF1DD2874677'

if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf) -or
    (Get-Item -LiteralPath $sourcePath).Length -ne $expectedSourceSize -or
    (Get-FileHash -LiteralPath $sourcePath -Algorithm SHA256).Hash -cne $expectedSourceSha256) {
  throw 'MoveNet FLOAT16 v4 TFLite source is missing or differs from the pinned official bytes.'
}
if (-not (Test-Path -LiteralPath $modelPath -PathType Leaf)) {
  throw 'MoveNet MindIR Lite model is missing.'
}
if ((Get-Item -LiteralPath $modelPath).Length -ne $expectedModelSize) {
  throw "MoveNet MindIR Lite model has unexpected byte length."
}
if ((Get-FileHash -LiteralPath $modelPath -Algorithm SHA256).Hash -cne $expectedModelSha256) {
  throw 'MoveNet MindIR Lite model SHA-256 differs from the pinned artifact.'
}

Write-Host 'MoveNet FLOAT16 v4 source and MindSpore Lite 2.6.0 artifact verified.'
