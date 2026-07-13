$ErrorActionPreference = 'Stop'

$assetDirectory = Join-Path $PSScriptRoot '..\entry\src\main\resources\rawfile\models\gesture'
$modelPath = Join-Path $assetDirectory 'GestureDetector.ms'
$manifestPath = Join-Path $assetDirectory 'manifest.json'
$expectedModelHash = 'A3440EF5B102BB9D25D984A8A2CA44EF4FC0557B65F0AC236176375FF9FFA5DA'
$expectedModelSize = 2269168
$expectedManifestHash = '1F45E5C63DF32A3A67F36DAAD237BEE48CDA148FF0A7609FC81CE5E5DA5D30EA'

function Get-RequiredJsonProperty([object]$object, [string]$name, [string]$path) {
  if ($object -isnot [PSCustomObject]) {
    throw "$path must be a JSON object."
  }
  $matches = @($object.PSObject.Properties | Where-Object { $_.Name -ceq $name })
  if ($matches.Count -ne 1) {
    throw "$path must contain exactly one '$name' property."
  }
  return $matches[0]
}

function Get-RequiredJsonObject([object]$object, [string]$name, [string]$path) {
  $property = Get-RequiredJsonProperty $object $name $path
  if ($property.Value -isnot [PSCustomObject]) {
    throw "$path.$name must be a JSON object."
  }
  return $property.Value
}

function Assert-JsonString([object]$object, [string]$name, [string]$expected, [string]$path) {
  $property = Get-RequiredJsonProperty $object $name $path
  if ($property.Value -isnot [string] -or $property.Value -cne $expected) {
    throw "$path.$name must be the JSON string '$expected'."
  }
}

function Test-IsJsonNumber([object]$value) {
  return ($value -is [byte] -or $value -is [sbyte] -or
    $value -is [int16] -or $value -is [uint16] -or
    $value -is [int32] -or $value -is [uint32] -or
    $value -is [int64] -or $value -is [uint64] -or
    $value -is [single] -or $value -is [double] -or
    $value -is [decimal])
}

function Assert-JsonInteger([object]$object, [string]$name, [int64]$expected, [string]$path) {
  $property = Get-RequiredJsonProperty $object $name $path
  if (-not (Test-IsJsonNumber $property.Value)) {
    throw "$path.$name must be a JSON number."
  }
  $value = [decimal]$property.Value
  if ([decimal]::Truncate($value) -ne $value -or $value -ne [decimal]$expected) {
    throw "$path.$name must be the integer $expected."
  }
}

function Assert-JsonNumber([object]$object, [string]$name, [decimal]$expected, [string]$path) {
  $property = Get-RequiredJsonProperty $object $name $path
  if (-not (Test-IsJsonNumber $property.Value) -or [decimal]$property.Value -ne $expected) {
    throw "$path.$name must be the JSON number $expected."
  }
}

function Assert-JsonIntegerArrayValue([object]$value, [int64[]]$expected, [string]$path) {
  if ($value -isnot [System.Array] -or $value.Count -ne $expected.Count) {
    throw "$path must be a JSON array with $($expected.Count) items."
  }
  for ($index = 0; $index -lt $expected.Count; $index++) {
    if (-not (Test-IsJsonNumber $value[$index])) {
      throw "$path[$index] must be a JSON number."
    }
    $actual = [decimal]$value[$index]
    if ([decimal]::Truncate($actual) -ne $actual -or $actual -ne [decimal]$expected[$index]) {
      throw "$path[$index] must be the integer $($expected[$index])."
    }
  }
}

function Assert-JsonIntegerArray([object]$object, [string]$name, [int64[]]$expected, [string]$path) {
  $property = Get-RequiredJsonProperty $object $name $path
  Assert-JsonIntegerArrayValue $property.Value $expected "$path.$name"
}

function Assert-JsonAnchorPairs([object]$object, [int64[][]]$expected, [string]$path) {
  $property = Get-RequiredJsonProperty $object 'anchors' $path
  if ($property.Value -isnot [System.Array] -or $property.Value.Count -ne $expected.Count) {
    throw "$path.anchors must be a JSON array with $($expected.Count) pairs."
  }
  for ($index = 0; $index -lt $expected.Count; $index++) {
    Assert-JsonIntegerArrayValue $property.Value[$index] $expected[$index] "$path.anchors[$index]"
  }
}

function Get-NormalizedTextSha256([string]$path) {
  $raw = [IO.File]::ReadAllText($path)
  $normalized = $raw.Replace("`r`n", "`n")
  $encoding = New-Object Text.UTF8Encoding($false)
  $sha256 = [Security.Cryptography.SHA256]::Create()
  try {
    $bytes = $encoding.GetBytes($normalized)
    return (($sha256.ComputeHash($bytes) | ForEach-Object { $_.ToString('X2') }) -join '')
  } finally {
    $sha256.Dispose()
  }
}

if (-not (Test-Path -LiteralPath $modelPath -PathType Leaf)) {
  throw "Missing HMS gesture model: $modelPath"
}

$model = Get-Item -LiteralPath $modelPath
if ($model.Length -ne $expectedModelSize) {
  throw "Gesture model size mismatch: expected $expectedModelSize, got $($model.Length)"
}

$actualModelHash = (Get-FileHash -LiteralPath $modelPath -Algorithm SHA256).Hash
if ($actualModelHash -cne $expectedModelHash) {
  throw "Gesture model hash mismatch: expected $expectedModelHash, got $actualModelHash"
}

if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
  throw "Missing HMS gesture manifest: $manifestPath"
}

$actualManifestHash = Get-NormalizedTextSha256 $manifestPath
if ($actualManifestHash -cne $expectedManifestHash) {
  throw "Gesture manifest hash mismatch: expected $expectedManifestHash, got $actualManifestHash"
}

$manifest = [IO.File]::ReadAllText($manifestPath) | ConvertFrom-Json
if ($manifest -isnot [PSCustomObject]) {
  throw 'The HMS gesture manifest root must be a JSON object.'
}

Assert-JsonInteger $manifest 'schemaVersion' 1 '$'
Assert-JsonString $manifest 'format' 'MNN FlatBuffer' '$'

$upstream = Get-RequiredJsonObject $manifest 'upstream' '$'
Assert-JsonString $upstream 'artifact' 'com.huawei.hms:ml-computer-vision-gesture-model' '$.upstream'
Assert-JsonString $upstream 'version' '2.1.0.300' '$.upstream'
Assert-JsonString $upstream 'aarUrl' 'https://developer.huawei.com/repo/com/huawei/hms/ml-computer-vision-gesture-model/2.1.0.300/ml-computer-vision-gesture-model-2.1.0.300.aar' '$.upstream'
Assert-JsonString $upstream 'aarSha256' '92FD6AE357E3C5B0407F8E0FED1644D7E01604F9399AF97F23E87C7D2F8CD01C' '$.upstream'

$modelContract = Get-RequiredJsonObject $manifest 'model' '$'
Assert-JsonString $modelContract 'file' 'GestureDetector.ms' '$.model'
Assert-JsonInteger $modelContract 'sizeBytes' $expectedModelSize '$.model'
Assert-JsonString $modelContract 'sha256' $expectedModelHash '$.model'

$input = Get-RequiredJsonObject $manifest 'input' '$'
Assert-JsonString $input 'name' 'data' '$.input'
Assert-JsonString $input 'dataType' 'FLOAT32' '$.input'
Assert-JsonString $input 'layout' 'NCHW' '$.input'
Assert-JsonIntegerArray $input 'shape' @(1, 3, 224, 224) '$.input'
Assert-JsonString $input 'resize' 'NEAREST' '$.input'
Assert-JsonString $input 'geometry' 'DIRECT_STRETCH' '$.input'
Assert-JsonString $input 'colorOrder' 'BGR' '$.input'
$normalization = Get-RequiredJsonObject $input 'normalization' '$.input'
Assert-JsonIntegerArray $normalization 'mean' @(0, 0, 0) '$.input.normalization'
Assert-JsonString $normalization 'operation' 'value / divisor' '$.input.normalization'
Assert-JsonInteger $normalization 'divisor' 255 '$.input.normalization'

$outputsProperty = Get-RequiredJsonProperty $manifest 'outputs' '$'
if ($outputsProperty.Value -isnot [System.Array] -or $outputsProperty.Value.Count -ne 3) {
  throw '$.outputs must be a JSON array with 3 items.'
}
$expectedOutputs = @(
  @{ Name = 'layer89-conv-hand'; Shape = @(1, 60, 7, 7) },
  @{ Name = 'layer101-conv-hand'; Shape = @(1, 60, 14, 14) },
  @{ Name = 'layer113-conv-hand'; Shape = @(1, 60, 28, 28) }
)
for ($index = 0; $index -lt $expectedOutputs.Count; $index++) {
  $output = $outputsProperty.Value[$index]
  $path = "$.outputs[$index]"
  if ($output -isnot [PSCustomObject]) { throw "$path must be a JSON object." }
  Assert-JsonString $output 'name' $expectedOutputs[$index].Name $path
  Assert-JsonString $output 'dataType' 'FLOAT32' $path
  Assert-JsonString $output 'layout' 'NCHW' $path
  Assert-JsonIntegerArray $output 'shape' $expectedOutputs[$index].Shape $path
}

$detector = Get-RequiredJsonObject $manifest 'detector' '$'
Assert-JsonString $detector 'architecture' 'YOLOv3' '$.detector'
Assert-JsonInteger $detector 'classCount' 15 '$.detector'
Assert-JsonInteger $detector 'valuesPerAnchor' 20 '$.detector'

$headsProperty = Get-RequiredJsonProperty $detector 'heads' '$.detector'
if ($headsProperty.Value -isnot [System.Array] -or $headsProperty.Value.Count -ne 3) {
  throw '$.detector.heads must be a JSON array with 3 items.'
}
$expectedHeads = @(
  @{ Output = 'layer89-conv-hand'; Stride = 32; Anchors = @(@(105, 101), @(133, 135), @(174, 150)) },
  @{ Output = 'layer101-conv-hand'; Stride = 16; Anchors = @(@(32, 37), @(47, 37), @(65, 56)) },
  @{ Output = 'layer113-conv-hand'; Stride = 8; Anchors = @(@(19, 19), @(25, 27), @(35, 26)) }
)
for ($index = 0; $index -lt $expectedHeads.Count; $index++) {
  $head = $headsProperty.Value[$index]
  $path = "$.detector.heads[$index]"
  if ($head -isnot [PSCustomObject]) { throw "$path must be a JSON object." }
  Assert-JsonString $head 'output' $expectedHeads[$index].Output $path
  Assert-JsonInteger $head 'stride' $expectedHeads[$index].Stride $path
  Assert-JsonAnchorPairs $head $expectedHeads[$index].Anchors $path
}

$thresholds = Get-RequiredJsonObject $detector 'thresholds' '$.detector'
Assert-JsonNumber $thresholds 'still' 0.6 '$.detector.thresholds'
Assert-JsonNumber $thresholds 'live' 0.1 '$.detector.thresholds'
Assert-JsonNumber $thresholds 'nmsIou' 0.45 '$.detector.thresholds'
Assert-JsonString $detector 'nms' 'PER_CLASS' '$.detector'
$resultLimit = Get-RequiredJsonProperty $detector 'resultLimit' '$.detector'
if ($null -ne $resultLimit.Value) {
  throw '$.detector.resultLimit must be an explicit JSON null.'
}

Write-Output "HMS gesture model verified: $expectedModelSize bytes, SHA-256 $expectedModelHash"
