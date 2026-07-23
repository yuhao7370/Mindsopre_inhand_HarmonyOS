$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'arkts-source-guard.ps1')

function Test-VersionImageBinding([string]$Code, [string]$CodeWithLiterals) {
  $shape = [regex]::new('(?ms)Image\s*\(\s*\$r\s*\(\s*''\s*''\s*\)\s*\)')
  $literal = '\AImage\s*\(\s*\$r\s*\(\s*''app\.media\.me_version_v2''\s*\)\s*\)'
  foreach ($match in $shape.Matches($Code)) {
    if ([regex]::IsMatch($CodeWithLiterals.Substring($match.Index), $literal)) {
      return $true
    }
  }
  return $false
}

function Test-LegacyMeImageCall([string]$Code, [string]$CodeWithLiterals) {
  $item = '(?ms)Image\s*\(\s*iconMediaResource\s*\(\s*item\s*\.\s*icon\s*\)\s*\)'
  if ([regex]::IsMatch($Code, $item)) {
    return $true
  }
  $goShape = [regex]::new('(?ms)Image\s*\(\s*iconMediaResource\s*\(\s*(?:''\s*''|"\s*")\s*\)\s*\)')
  $goLiteral = '\AImage\s*\(\s*iconMediaResource\s*\(\s*(?:''go''|"go")\s*\)\s*\)'
  foreach ($match in $goShape.Matches($Code)) {
    if ([regex]::IsMatch($CodeWithLiterals.Substring($match.Index), $goLiteral)) {
      return $true
    }
  }
  return $false
}

function Assert-MeSourceContract([string]$Source) {
  $normalized = $Source.Replace("`r`n", "`n").Replace("`r", "`n")
  $code = Remove-ArkTsCommentsAndTemplateRaw $normalized
  $codeWithLiterals = Remove-ArkTsCommentsAndTemplateRaw $normalized $true
  $builderSlice = Get-ArkTsMethodSlice $code `
    '(?m)^[\t ]*private\s+versionCard\s*\(' `
    'MePage must contain a private versionCard builder' `
    'MePage versionCard builder must have an opening brace' `
    'MePage versionCard builder must have a closing brace'
  $builder = $builderSlice.Text
  $builderWithLiterals = $codeWithLiterals.Substring($builderSlice.Start, $builderSlice.Length)
  if (-not (Test-VersionImageBinding $builder $builderWithLiterals)) {
    throw "MePage versionCard must bind the Harmony flat version icon with `$r('app.media.me_version_v2')"
  }
  if (Test-LegacyMeImageCall $builder $builderWithLiterals) {
    throw 'MePage versionCard must not restore legacy Me row icon rendering or chevrons'
  }
}

$root = Split-Path -Parent $PSScriptRoot
$mediaPath = Join-Path $root 'entry/src/main/resources/base/media/me_version_v2.png'
$expectedHash = '6D956A28DACE944A329EBAE129264EB089D89D2C4018CD4B82642F50278035FF'

if (-not (Test-Path -LiteralPath $mediaPath)) {
  throw 'Missing Harmony Me flat version icon media: me_version_v2.png'
}

$actualHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $mediaPath).Hash
if ($actualHash -ne $expectedHash) {
  throw "Harmony Me flat version icon media hash mismatch. Expected $expectedHash, got $actualHash"
}

$mePageSource = Get-Content -Raw -Encoding UTF8 -LiteralPath (Join-Path $root 'entry/src/main/ets/pages/MePage.ets')
Assert-MeSourceContract $mePageSource

Write-Host 'Me page Harmony flat version icon contract is present'
