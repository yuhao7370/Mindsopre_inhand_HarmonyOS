$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$thumbnail = Join-Path $root 'entry/src/main/resources/base/media/dance_thumbnail.png'
$expectedHash = '6842B663F34C73B8EB81013302AF698ADD43CB1ED5AC256B1224CE2A4369699E'

if (-not (Test-Path -LiteralPath $thumbnail)) {
  throw 'Missing Android Dance thumbnail media: dance_thumbnail.png'
}

$hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $thumbnail).Hash
if ($hash -ne $expectedHash) {
  throw "Android Dance thumbnail media hash mismatch. Expected $expectedHash, got $hash"
}

$dancePage = Get-Content -Raw -Encoding UTF8 -LiteralPath (Join-Path $root 'entry/src/main/ets/pages/DancePage.ets')
$dancePage = $dancePage -replace "`r`n", "`n"

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

$referencePanel = SourceSlice $dancePage 'referenceVideoPanel()' 'preparePanel()'
$videoStart = $referencePanel.IndexOf('Video({')
if ($videoStart -lt 0) {
  throw 'Missing Dance reference Video component'
}
$videoEnd = $referencePanel.IndexOf('})', $videoStart)
if ($videoEnd -lt 0) {
  throw 'Missing Dance reference Video component end marker'
}
$videoSlice = $referencePanel.Substring($videoStart, $videoEnd - $videoStart)

if ($videoSlice -notmatch "previewUri: \`$r\('app\.media\.dance_thumbnail'\)") {
  throw 'Dance reference Video must use Android dance_thumbnail.png as previewUri'
}
if ($videoSlice -match 'skeleton_template') {
  throw 'Dance reference Video must not use PoseNet skeleton_template as its previewUri'
}

Write-Host 'Android Dance reference video thumbnail wiring is present'
