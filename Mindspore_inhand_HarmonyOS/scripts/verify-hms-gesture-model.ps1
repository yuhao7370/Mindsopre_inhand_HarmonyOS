$ErrorActionPreference = 'Stop'

$assetDirectory = Join-Path $PSScriptRoot '..\entry\src\main\resources\rawfile\models\gesture'
$modelPath = Join-Path $assetDirectory 'GestureDetector.ms'
$manifestPath = Join-Path $assetDirectory 'manifest.json'
$expectedModelHash = 'A3440EF5B102BB9D25D984A8A2CA44EF4FC0557B65F0AC236176375FF9FFA5DA'
$expectedModelSize = 2269168

if (-not (Test-Path -LiteralPath $modelPath -PathType Leaf)) {
  throw "Missing HMS gesture model: $modelPath"
}

$model = Get-Item -LiteralPath $modelPath
if ($model.Length -ne $expectedModelSize) {
  throw "Gesture model size mismatch: expected $expectedModelSize, got $($model.Length)"
}

$actualModelHash = (Get-FileHash -LiteralPath $modelPath -Algorithm SHA256).Hash
if ($actualModelHash -ne $expectedModelHash) {
  throw "Gesture model hash mismatch: expected $expectedModelHash, got $actualModelHash"
}

if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
  throw "Missing HMS gesture manifest: $manifestPath"
}

$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
$expectedAarUrl = 'https://developer.huawei.com/repo/com/huawei/hms/ml-computer-vision-gesture-model/2.1.0.300/ml-computer-vision-gesture-model-2.1.0.300.aar'
if ($manifest.schemaVersion -ne 1 -or
    $manifest.format -ne 'MNN FlatBuffer' -or
    $manifest.upstream.artifact -ne 'com.huawei.hms:ml-computer-vision-gesture-model' -or
    $manifest.upstream.version -ne '2.1.0.300' -or
    $manifest.upstream.aarUrl -ne $expectedAarUrl -or
    $manifest.upstream.aarSha256 -ne '92FD6AE357E3C5B0407F8E0FED1644D7E01604F9399AF97F23E87C7D2F8CD01C' -or
    $manifest.model.file -ne 'GestureDetector.ms' -or
    $manifest.model.sizeBytes -ne $expectedModelSize -or
    $manifest.model.sha256 -ne $expectedModelHash) {
  throw 'HMS gesture manifest provenance mismatch.'
}

$expectedInput = 'data|FLOAT32|NCHW|1,3,224,224'
$actualInput = "$($manifest.input.name)|$($manifest.input.dataType)|$($manifest.input.layout)|$($manifest.input.shape -join ',')"
if ($actualInput -ne $expectedInput -or
    $manifest.input.resize -ne 'NEAREST' -or
    $manifest.input.colorOrder -ne 'BGR' -or
    $manifest.input.geometry -ne 'DIRECT_STRETCH' -or
    ($manifest.input.normalization.mean -join ',') -ne '0,0,0' -or
    $manifest.input.normalization.operation -ne 'value / divisor' -or
    $manifest.input.normalization.divisor -ne 255) {
  throw 'HMS gesture manifest input contract mismatch.'
}

$expectedOutputs = @(
  'layer89-conv-hand|FLOAT32|NCHW|1,60,7,7',
  'layer101-conv-hand|FLOAT32|NCHW|1,60,14,14',
  'layer113-conv-hand|FLOAT32|NCHW|1,60,28,28'
)
$actualOutputs = @($manifest.outputs | ForEach-Object {
  "$($_.name)|$($_.dataType)|$($_.layout)|$($_.shape -join ',')"
})
if (($actualOutputs -join ';') -ne ($expectedOutputs -join ';')) {
  throw 'HMS gesture manifest output contract mismatch.'
}

$expectedAnchors = @(
  'layer89-conv-hand|32|105,101;133,135;174,150',
  'layer101-conv-hand|16|32,37;47,37;65,56',
  'layer113-conv-hand|8|19,19;25,27;35,26'
)
$actualAnchors = @($manifest.detector.heads | ForEach-Object {
  $pairs = @($_.anchors | ForEach-Object { $_ -join ',' }) -join ';'
  "$($_.output)|$($_.stride)|$pairs"
})
if (($actualAnchors -join '|') -ne ($expectedAnchors -join '|') -or
    $manifest.detector.architecture -ne 'YOLOv3' -or
    $manifest.detector.classCount -ne 15 -or
    $manifest.detector.valuesPerAnchor -ne 20 -or
    $manifest.detector.thresholds.still -ne 0.6 -or
    $manifest.detector.thresholds.live -ne 0.1 -or
    $manifest.detector.thresholds.nmsIou -ne 0.45 -or
    $manifest.detector.nms -ne 'PER_CLASS' -or
    $manifest.detector.resultLimit -ne $null) {
  throw 'HMS gesture manifest detector contract mismatch.'
}

Write-Output "HMS gesture model verified: $expectedModelSize bytes, SHA-256 $expectedModelHash"
