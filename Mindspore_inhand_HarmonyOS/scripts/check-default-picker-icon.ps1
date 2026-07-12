$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$defaultIcon = Join-Path $root 'entry/src/main/resources/base/media/icon_default.png'
$expectedHash = '4BAC77D235A808DE1CBAFE13303B5A529D3623C8629069E6F6D2305388B0F4D6'

if (-not (Test-Path -LiteralPath $defaultIcon)) {
  throw 'Missing Android default picker icon media: icon_default.png'
}

$hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $defaultIcon).Hash
if ($hash -ne $expectedHash) {
  throw "Android default picker icon media hash mismatch. Expected $expectedHash, got $hash"
}

$runtimePage = Get-Content -Raw -Encoding UTF8 -LiteralPath (Join-Path $root 'entry/src/main/ets/pages/FeatureRuntimePage.ets')
$runtimePage = $runtimePage -replace "`r`n", "`n"

function SourceSlice([string] $text, [string] $startMarker, [string] $endMarker) {
  $start = $text.IndexOf($startMarker)
  if ($start -lt 0) {
    throw "Missing source marker: $startMarker"
  }
  $end = $text.IndexOf($endMarker, $start + $startMarker.Length)
  if ($end -lt 0) {
    throw "Missing source marker after ${startMarker}: $endMarker"
  }
  return $text.Substring($start, $end - $start)
}

function AssertDefaultPickerIcon([string] $slice, [string] $name, [string] $expectedInputKind) {
  if ($slice -match "Text\('\+'\)") {
    throw "$name must render Android icon_default.png instead of a text plus marker"
  }
  if ($slice -notmatch "Image\(\`$r\('app\.media\.icon_default'\)\)" -or
    $slice -notmatch '\.objectFit\(ImageFit\.Contain\)') {
    throw "$name must render Android icon_default.png as a contained image"
  }
  if ($slice -notmatch "prepareInput\('$expectedInputKind'\)") {
    throw "$name must keep the existing prepareInput('$expectedInputKind') picker behavior"
  }
}

$styleCustom = SourceSlice $runtimePage 'styleTransferCustomStyleItem()' 'styleTransferStyleImage(style:'
$portraitCustom = SourceSlice $runtimePage 'portraitSegmentationCustomBackgroundItem()' 'liveCameraPreview()'

AssertDefaultPickerIcon $styleCustom 'Style Transfer custom style tile' 'styleImage'
AssertDefaultPickerIcon $portraitCustom 'Portrait Segmentation custom background tile' 'backgroundImage'

Write-Host 'Android default picker icon wiring is present'
