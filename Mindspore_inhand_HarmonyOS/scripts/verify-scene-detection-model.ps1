$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$modelPath = Join-Path $projectRoot 'entry/src/main/resources/rawfile/model/resnet18-place365.ms'
$labelPath = Join-Path $projectRoot 'entry/src/main/resources/rawfile/labels/places365.txt'
$expectedModelSize = 45448504
$expectedModelSha256 = '286F2C85249FD51F6C437986E1C2C1F4EC10358A9B0EB97C886F2DC1AC63ECD9'
$expectedLabelCount = 365
$expectedLabelSha256 = 'DE7AB93ADE1235B47809BBF63EF476F8F209FBC4EFDF677825302B4E90EE95C8'

if (!(Test-Path $modelPath)) {
    throw "Missing resnet18-place365.ms at $modelPath"
}

$actualModelSize = (Get-Item $modelPath).Length
if ($actualModelSize -ne $expectedModelSize) {
    throw "resnet18-place365.ms has unexpected size $actualModelSize bytes; expected $expectedModelSize bytes."
}

$actualModelSha256 = (Get-FileHash -LiteralPath $modelPath -Algorithm SHA256).Hash
if ($actualModelSha256 -ne $expectedModelSha256) {
    throw "resnet18-place365.ms has unexpected SHA256 $actualModelSha256; expected $expectedModelSha256."
}

if (!(Test-Path $labelPath)) {
    throw "Missing Places365 labels at $labelPath"
}

$labels = Get-Content $labelPath | Where-Object { $_.Trim().Length -gt 0 }
$labelCount = $labels.Count
if ($labelCount -ne $expectedLabelCount) {
    throw "places365.txt has unexpected label count $labelCount; expected $expectedLabelCount."
}

$normalizedLabelText = $labels -join "`n"
$normalizedLabelBytes = [System.Text.Encoding]::ASCII.GetBytes($normalizedLabelText)
$actualLabelSha256 = [System.BitConverter]::ToString(
    [System.Security.Cryptography.SHA256]::Create().ComputeHash($normalizedLabelBytes)
).Replace('-', '')
if ($actualLabelSha256 -ne $expectedLabelSha256) {
    throw "places365.txt has unexpected SHA256 $actualLabelSha256; expected $expectedLabelSha256."
}

Write-Host "resnet18-place365.ms verified: $modelPath ($actualModelSize bytes)"
Write-Host "places365.txt verified: $labelPath ($labelCount labels)"
