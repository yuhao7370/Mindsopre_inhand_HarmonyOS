$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'arkts-source-guard.ps1')

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
$source = Get-Content -Raw -Encoding UTF8 -LiteralPath $collegePagePath

function Test-CollegeChevronBinding([string]$Code, [string]$CodeWithLiterals, [int]$TitleIndex) {
  $shape = [regex]::new('(?ms)(?<![\p{L}\p{Nd}_$])Image\s*\(\s*\$r\s*\(\s*''\s*''\s*\)\s*\)\s*\.width\s*\(\s*6\s*\)\s*\.height\s*\(\s*12\s*\)')
  $literal = '\AImage\s*\(\s*\$r\s*\(\s*''app\.media\.me_go''\s*\)\s*\)\s*\.width\s*\(\s*6\s*\)\s*\.height\s*\(\s*12\s*\)'
  foreach ($match in $shape.Matches($Code)) {
    if ($match.Index -gt $TitleIndex -and [regex]::IsMatch($CodeWithLiterals.Substring($match.Index), $literal)) {
      return $true
    }
  }
  return $false
}

function Test-CollegeTextChevronPlaceholder([string]$Code, [string]$CodeWithLiterals) {
  $shape = [regex]::new('(?ms)(?<![\p{L}\p{Nd}_$])Text\s*\(\s*(?:''\s*''|"\s*")\s*\)')
  $literal = '\AText\s*\(\s*(?:''>''|">")\s*\)'
  foreach ($match in $shape.Matches($Code)) {
    if ([regex]::IsMatch($CodeWithLiterals.Substring($match.Index), $literal)) {
      return $true
    }
  }
  return $false
}

function Assert-CollegeSourceContract([string]$Source) {
  $normalized = $Source.Replace("`r`n", "`n").Replace("`r", "`n")
  $code = Remove-ArkTsCommentsAndTemplateRaw $normalized
  $codeWithLiterals = Remove-ArkTsCommentsAndTemplateRaw $normalized $true
  $entrySlice = Get-ArkTsMethodSlice $code `
    '(?m)^[\t ]*private\s+collegeEntryCard\s*\(\s*item\s*:\s*CollegeItem\s*\)' `
    'Missing Harmony College entry method: private collegeEntryCard(item: CollegeItem)' `
    'Missing opening brace for Harmony College entry method' `
    'Unclosed Harmony College entry method body'
  $entry = $entrySlice.Text
  $entryWithLiterals = $codeWithLiterals.Substring($entrySlice.Start, $entrySlice.Length)
  $title = [regex]::Match($entry, '(?<![\p{L}\p{Nd}_$])Text\s*\(\s*appString\s*\(\s*collegeAdapterViewTitleKey\s*\)\s*\)')
  if (-not $title.Success) {
    throw 'Harmony College entry must render the adapter view title'
  }
  if (-not (Test-CollegeChevronBinding $entry $entryWithLiterals $title.Index)) {
    throw 'Harmony College entry must render me_go.png after the adapter view title at 6x12vp'
  }
  if (Test-CollegeTextChevronPlaceholder $entry $entryWithLiterals) {
    throw "Harmony College entry must not use a text '>' chevron placeholder"
  }
}

Assert-CollegeSourceContract $source

Write-Host 'Harmony College entry chevron contract is present'
