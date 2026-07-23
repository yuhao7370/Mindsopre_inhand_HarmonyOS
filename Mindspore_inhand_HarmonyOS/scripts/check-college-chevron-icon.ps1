$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$chevronIcon = Join-Path $root 'entry/src/main/resources/base/media/me_go.png'
$expectedHash = 'EECDAC679EC9E327F16C350789C201DF9D04442FBAD670E2CA65685E957C37EE'

if (-not (Test-Path -LiteralPath $chevronIcon)) {
  throw 'Missing Harmony College entry chevron media: me_go.png'
}

$hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $chevronIcon).Hash
if ($hash -ne $expectedHash) {
  throw "Harmony College entry chevron media hash mismatch. Expected $expectedHash, got $hash"
}

$collegePagePath = Join-Path $root 'entry/src/main/ets/pages/CollegePage.ets'
$source = (Get-Content -Raw -Encoding UTF8 -LiteralPath $collegePagePath) -replace "`r`n", "`n"

function CollegeEntryCardSlice([string] $text) {
  $methodMarker = 'private collegeEntryCard(item: CollegeItem)'
  $start = $text.IndexOf($methodMarker)
  if ($start -lt 0) {
    throw "Missing Harmony College entry method: $methodMarker"
  }

  $openingBrace = $text.IndexOf('{', $start + $methodMarker.Length)
  if ($openingBrace -lt 0) {
    throw 'Missing opening brace for Harmony College entry method'
  }

  $braceDepth = 0
  for ($index = $openingBrace; $index -lt $text.Length; $index++) {
    if ($text[$index] -eq '{') {
      $braceDepth++
    } elseif ($text[$index] -eq '}') {
      $braceDepth--
      if ($braceDepth -eq 0) {
        return $text.Substring($start, $index - $start + 1)
      }
    }
  }

  throw 'Unclosed Harmony College entry method body'
}

$entryCardSlice = CollegeEntryCardSlice $source
if ($entryCardSlice -notmatch 'Text\s*\(\s*appString\(collegeAdapterViewTitleKey\)\s*\)') {
  throw 'Harmony College entry must render the adapter view title'
}
if ($entryCardSlice -notmatch 'Text\s*\(\s*appString\(collegeAdapterViewTitleKey\)\s*\)(?s:.*?)Image\(\$r\(''app\.media\.me_go''\)\)(?s:.*?)\.width\(6\)(?s:.*?)\.height\(12\)') {
  throw 'Harmony College entry must render me_go.png after the adapter view title at 6x12vp'
}
if ($entryCardSlice -match "Text\s*\(\s*'>'\s*\)") {
  throw "Harmony College entry must not use a text '>' chevron placeholder"
}

Write-Host 'Harmony College entry chevron contract is present'
