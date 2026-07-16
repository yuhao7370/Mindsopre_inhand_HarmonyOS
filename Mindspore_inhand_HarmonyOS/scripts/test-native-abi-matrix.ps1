[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$profile = Get-Content -LiteralPath (Join-Path $projectRoot 'entry\build-profile.json5') -Raw
$mainCMake = Get-Content -LiteralPath (Join-Path $projectRoot 'entry\src\main\cpp\CMakeLists.txt') -Raw
$translationCMake = Get-Content -LiteralPath (Join-Path $projectRoot 'entry\src\main\cpp\translation_xz\CMakeLists.txt') -Raw
$abiSectionMatch = [regex]::Match($profile, '"abiFilters"\s*:\s*\[(?<abis>.*?)\]', [System.Text.RegularExpressions.RegexOptions]::Singleline)
if (-not $abiSectionMatch.Success) { throw 'Unable to read abiFilters from build-profile.json5' }
$abis = [regex]::Matches($abiSectionMatch.Groups['abis'].Value, '"([^"]+)"') | ForEach-Object { $_.Groups[1].Value }

if (-not $abis) { throw 'abiFilters list in build-profile.json5 is empty.' }

foreach ($abi in $abis) {
  if ($profile -cnotmatch ('"' + [regex]::Escape($abi) + '"')) {
    throw "entry/build-profile.json5 does not package ABI $abi"
  }
  foreach ($path in @(
    (Join-Path $projectRoot "entry\libs\$abi\libMNN.so"),
    (Join-Path $projectRoot "entry\src\main\cpp\translation_xz\third_party\xz\lib\$abi\liblzma.a")
  )) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
      throw "Missing native dependency for ${abi}: $path"
    }
  }
}

if ($translationCMake -cnotmatch 'lib/\$\{OHOS_ARCH\}/liblzma\.a') {
  throw 'translation_xz/CMakeLists.txt must select liblzma by OHOS_ARCH.'
}

Write-Output ('Native ABI matrix contract passed: ' + ($abis -join ', '))
