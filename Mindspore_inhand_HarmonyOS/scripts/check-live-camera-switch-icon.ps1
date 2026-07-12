$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$switchIcon = Join-Path $root 'entry/src/main/resources/base/media/front_back_switch.png'
$expectedHash = 'F5182699627421A3E96749C619782A9B4AD63E0941BBAA012BB929960B6C1133'

if (-not (Test-Path -LiteralPath $switchIcon)) {
  throw 'Missing Android live-camera switch media: front_back_switch.png'
}

$hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $switchIcon).Hash
if ($hash -ne $expectedHash) {
  throw "Android live-camera switch media hash mismatch. Expected $expectedHash, got $hash"
}

$runtimePagePath = Join-Path $root 'entry/src/main/ets/pages/FeatureRuntimePage.ets'
$source = (Get-Content -Raw -Encoding UTF8 -LiteralPath $runtimePagePath) -replace "`r`n", "`n"

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

$previewSlice = SourceSlice $source 'if (this.liveCameraSwitchAvailable)' "    }`n    .width('100%')"
if ($previewSlice -notmatch "Image\(\`$r\('app\.media\.front_back_switch'\)\)") {
  throw 'FeatureRuntimePage must render Android front_back_switch.png for live camera switching'
}
if ($previewSlice -match "Button\(appString\('feature_runtime_switch_camera'\)\)") {
  throw 'FeatureRuntimePage must not render the live camera switch as a text button'
}
if ($previewSlice -notmatch '\.width\(35\)' -or $previewSlice -notmatch '\.height\(35\)') {
  throw 'FeatureRuntimePage live camera switch icon must keep the Android 35x35vp visual size'
}
if ($previewSlice -notmatch 'this\.switchLiveCamera\(\)') {
  throw 'FeatureRuntimePage live camera switch icon must keep the existing switch handler'
}

Write-Host 'Android live-camera switch icon wiring is present'
