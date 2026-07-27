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

function Get-ArkTsMethodSlice(
  [string]$Code,
  [string]$MethodPattern,
  [string]$MissingMethodMessage,
  [string]$MissingOpeningBraceMessage,
  [string]$MissingClosingBraceMessage
) {
  $start = [regex]::Match($Code, $MethodPattern)
  if (-not $start.Success) {
    throw $MissingMethodMessage
  }
  $openingBrace = $Code.IndexOf('{', $start.Index + $start.Length)
  if ($openingBrace -lt 0) {
    throw $MissingOpeningBraceMessage
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
  throw $MissingClosingBraceMessage
}
