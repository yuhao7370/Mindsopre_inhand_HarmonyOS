$ErrorActionPreference = 'Stop'

function Remove-ArkTsCommentsAndTemplateRaw(
  [string]$Text,
  [bool]$PreserveQuotedLiterals = $false
) {
  $result = [Text.StringBuilder]::new($Text.Length)
  $state = 'code'
  $terminator = [char]0
  $escaped = $false
  $interpolationDepths = [Collections.Generic.List[int]]::new()
  for ($index = 0; $index -lt $Text.Length; $index++) {
    $current = $Text[$index]
    $next = if ($index + 1 -lt $Text.Length) { $Text[$index + 1] } else { [char]0 }
    if ($state -eq 'lineComment') {
      if ($current -eq [char]0x0A) {
        [void]$result.Append($current)
        $state = 'code'
      } else {
        [void]$result.Append(' ')
      }
      continue
    }
    if ($state -eq 'blockComment') {
      if ($current -eq [char]0x2A -and $next -eq [char]0x2F) {
        [void]$result.Append('  ')
        $index++
        $state = 'code'
      } elseif ($current -eq [char]0x0A) {
        [void]$result.Append($current)
      } else {
        [void]$result.Append(' ')
      }
      continue
    }
    if ($state -eq 'quotedLiteral') {
      if ($current -eq [char]0x0A) {
        [void]$result.Append($current)
      } elseif ($escaped) {
        [void]$result.Append($(if ($PreserveQuotedLiterals) { $current } else { ' ' }))
        $escaped = $false
      } elseif ($current -eq [char]0x5C) {
        [void]$result.Append($(if ($PreserveQuotedLiterals) { $current } else { ' ' }))
        $escaped = $true
      } elseif ($current -eq $terminator) {
        [void]$result.Append($current)
        $state = 'code'
      } else {
        [void]$result.Append($(if ($PreserveQuotedLiterals) { $current } else { ' ' }))
      }
      continue
    }
    if ($state -eq 'templateRaw') {
      if ($escaped) {
        [void]$result.Append(' ')
        $escaped = $false
      } elseif ($current -eq [char]0x5C) {
        [void]$result.Append(' ')
        $escaped = $true
      } elseif ($current -eq [char]0x0A) {
        [void]$result.Append($current)
      } elseif ($current -eq [char]0x60) {
        [void]$result.Append($current)
        $state = 'code'
      } elseif ($current -eq [char]0x24 -and $next -eq [char]0x7B) {
        [void]$result.Append('${')
        $index++
        $interpolationDepths.Add(1)
        $state = 'code'
      } else {
        [void]$result.Append(' ')
      }
      continue
    }
    if ($current -eq [char]0x2F -and $next -eq [char]0x2F) {
      [void]$result.Append('  ')
      $index++
      $state = 'lineComment'
    } elseif ($current -eq [char]0x2F -and $next -eq [char]0x2A) {
      [void]$result.Append('  ')
      $index++
      $state = 'blockComment'
    } elseif ($current -eq [char]0x27 -or $current -eq [char]0x22) {
      [void]$result.Append($current)
      $terminator = $current
      $escaped = $false
      $state = 'quotedLiteral'
    } elseif ($current -eq [char]0x60) {
      [void]$result.Append($current)
      $escaped = $false
      $state = 'templateRaw'
    } elseif ($interpolationDepths.Count -gt 0 -and $current -eq [char]0x7B) {
      $last = $interpolationDepths.Count - 1
      $interpolationDepths[$last]++
      [void]$result.Append($current)
    } elseif ($interpolationDepths.Count -gt 0 -and $current -eq [char]0x7D) {
      $last = $interpolationDepths.Count - 1
      $interpolationDepths[$last]--
      [void]$result.Append($current)
      if ($interpolationDepths[$last] -eq 0) {
        $interpolationDepths.RemoveAt($last)
        $state = 'templateRaw'
      }
    } else {
      [void]$result.Append($current)
    }
  }
  return $result.ToString()
}

function Get-VersionCardSlice([string]$Code) {
  $start = [regex]::Match($Code, '(?m)^[\t ]*private\s+versionCard\s*\(')
  if (-not $start.Success) {
    throw 'MePage must contain a private versionCard builder'
  }
  $openingBrace = $Code.IndexOf('{', $start.Index + $start.Length)
  if ($openingBrace -lt 0) {
    throw 'MePage versionCard builder must have an opening brace'
  }
  $depth = 0
  for ($index = $openingBrace; $index -lt $Code.Length; $index++) {
    if ($Code[$index] -eq '{') {
      $depth++
    } elseif ($Code[$index] -eq '}') {
      $depth--
      if ($depth -eq 0) {
        $length = $index - $start.Index + 1
        return [pscustomobject]@{
          Start = $start.Index
          Length = $length
          Text = $Code.Substring($start.Index, $length)
        }
      }
    }
  }
  throw 'MePage versionCard builder must have a closing brace'
}

function Test-VersionImageBinding([string]$Code, [string]$CodeWithLiterals) {
  $shape = [regex]::new('(?ms)^[\t ]*Image\s*\(\s*\$r\s*\(\s*''\s*''\s*\)\s*\)')
  $literal = '\A[\t ]*Image\s*\(\s*\$r\s*\(\s*''app\.media\.me_version_v2''\s*\)\s*\)'
  foreach ($match in $shape.Matches($Code)) {
    if ([regex]::IsMatch($CodeWithLiterals.Substring($match.Index), $literal)) {
      return $true
    }
  }
  return $false
}

function Test-LegacyMeImageCall([string]$Code, [string]$CodeWithLiterals) {
  $item = '(?ms)^[\t ]*Image\s*\(\s*iconMediaResource\s*\(\s*item\s*\.\s*icon\s*\)\s*\)'
  if ([regex]::IsMatch($Code, $item)) {
    return $true
  }
  $goShape = [regex]::new('(?ms)^[\t ]*Image\s*\(\s*iconMediaResource\s*\(\s*(?:''\s*''|"\s*")\s*\)\s*\)')
  $goLiteral = '\A[\t ]*Image\s*\(\s*iconMediaResource\s*\(\s*(?:''go''|"go")\s*\)\s*\)'
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
  $builderSlice = Get-VersionCardSlice $code
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
