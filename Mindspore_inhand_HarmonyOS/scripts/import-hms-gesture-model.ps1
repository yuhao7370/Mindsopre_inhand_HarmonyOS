param(
  [string]$AarPath
)

$ErrorActionPreference = 'Stop'

$aarUrl = 'https://developer.huawei.com/repo/com/huawei/hms/ml-computer-vision-gesture-model/2.1.0.300/ml-computer-vision-gesture-model-2.1.0.300.aar'
$expectedAarHash = '92FD6AE357E3C5B0407F8E0FED1644D7E01604F9399AF97F23E87C7D2F8CD01C'
$expectedModelHash = 'A3440EF5B102BB9D25D984A8A2CA44EF4FC0557B65F0AC236176375FF9FFA5DA'
$expectedModelSize = 2269168
$destination = Join-Path $PSScriptRoot '..\entry\src\main\resources\rawfile\models\gesture\GestureDetector.ms'
$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("hms-gesture-import-" + [Guid]::NewGuid().ToString('N'))
$tempRoot = [IO.Path]::GetFullPath($tempRoot)
$tempBase = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd([IO.Path]::DirectorySeparatorChar)

if (-not $tempRoot.StartsWith($tempBase + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
  throw "Unsafe temporary extraction path: $tempRoot"
}

New-Item -ItemType Directory -Path $tempRoot | Out-Null
try {
  $archivePath = Join-Path $tempRoot 'gesture-model.zip'
  if ([string]::IsNullOrWhiteSpace($AarPath)) {
    Write-Output "Downloading HMS gesture model AAR 2.1.0.300..."
    Invoke-WebRequest -UseBasicParsing -Uri $aarUrl -OutFile $archivePath
  } else {
    $resolvedAar = (Resolve-Path -LiteralPath $AarPath).Path
    Copy-Item -LiteralPath $resolvedAar -Destination $archivePath
  }

  $actualAarHash = (Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash
  if ($actualAarHash -ne $expectedAarHash) {
    throw "HMS gesture AAR hash mismatch: expected $expectedAarHash, got $actualAarHash"
  }

  $extractPath = Join-Path $tempRoot 'extracted'
  Expand-Archive -LiteralPath $archivePath -DestinationPath $extractPath
  $sourceModel = Join-Path $extractPath 'assets\GestureDetector.ms'
  if (-not (Test-Path -LiteralPath $sourceModel -PathType Leaf)) {
    throw 'The verified HMS gesture AAR does not contain assets/GestureDetector.ms.'
  }

  $sourceModelItem = Get-Item -LiteralPath $sourceModel
  if ($sourceModelItem.Length -ne $expectedModelSize) {
    throw "Gesture model size mismatch: expected $expectedModelSize, got $($sourceModelItem.Length)"
  }
  $actualModelHash = (Get-FileHash -LiteralPath $sourceModel -Algorithm SHA256).Hash
  if ($actualModelHash -ne $expectedModelHash) {
    throw "Gesture model hash mismatch: expected $expectedModelHash, got $actualModelHash"
  }

  New-Item -ItemType Directory -Force -Path (Split-Path -Parent $destination) | Out-Null
  Copy-Item -LiteralPath $sourceModel -Destination $destination -Force
  Write-Output "Imported GestureDetector.ms: $expectedModelSize bytes, SHA-256 $expectedModelHash"
} finally {
  if (Test-Path -LiteralPath $tempRoot) {
    Remove-Item -LiteralPath $tempRoot -Recurse -Force
  }
}
