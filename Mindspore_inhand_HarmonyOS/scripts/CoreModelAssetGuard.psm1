Set-StrictMode -Version Latest

function Normalize-CoreGuardText([string]$Text) {
  return $Text.Replace("`r`n", "`n").Replace("`r", "`n").Trim()
}

function ConvertTo-CoreGuardPowerShellAst([string]$Text, [string]$Label) {
  $tokens = $null
  $errors = $null
  $ast = [Management.Automation.Language.Parser]::ParseInput($Text, [ref]$tokens, [ref]$errors)
  if ($errors.Count -ne 0) {
    throw "Core model asset guard failed: $Label must parse as PowerShell: $($errors[0].Message)"
  }
  return $ast
}

function Read-CoreGuardPowerShellAst([string]$Path) {
  $text = Get-Content -Raw -LiteralPath $Path
  return ConvertTo-CoreGuardPowerShellAst $text $Path
}

function Assert-CoreGuardExecutableCommand(
  [Management.Automation.Language.Ast]$Ast,
  [string]$ExactText,
  [string]$Message
) {
  $expected = Normalize-CoreGuardText $ExactText
  $matches = @($Ast.FindAll({
    param($node)
    $node -is [Management.Automation.Language.CommandAst] -and
      (Normalize-CoreGuardText $node.Extent.Text) -ceq $expected
  }, $true))
  if ($matches.Count -ne 1) {
    throw "Core model asset guard failed: $Message Expected one executable command, found $($matches.Count)."
  }
}

function Assert-CoreGuardExecutableMemberCall(
  [Management.Automation.Language.Ast]$Ast,
  [string]$ExactText,
  [string]$Message,
  [int]$ExpectedCount = 1
) {
  $expected = Normalize-CoreGuardText $ExactText
  $matches = @($Ast.FindAll({
    param($node)
    $node -is [Management.Automation.Language.InvokeMemberExpressionAst] -and
      (Normalize-CoreGuardText $node.Extent.Text) -ceq $expected
  }, $true))
  if ($matches.Count -ne $ExpectedCount) {
    throw "Core model asset guard failed: $Message Expected $ExpectedCount executable member call(s), found $($matches.Count)."
  }
}

function Get-CoreGuardAssignment(
  [Management.Automation.Language.Ast]$Ast,
  [string]$VariableName,
  [string]$Message
) {
  $matches = @($Ast.FindAll({
    param($node)
    $node -is [Management.Automation.Language.AssignmentStatementAst] -and
      $node.Left -is [Management.Automation.Language.VariableExpressionAst] -and
      $node.Left.VariablePath.UserPath -ceq $VariableName
  }, $true))
  if ($matches.Count -ne 1) {
    throw "Core model asset guard failed: $Message Expected one assignment to `$$VariableName, found $($matches.Count)."
  }
  return $matches[0]
}

function Assert-CoreGuardAssignmentLiteral(
  [Management.Automation.Language.Ast]$Ast,
  [string]$VariableName,
  [object]$ExpectedValue,
  [string]$Message
) {
  $assignment = Get-CoreGuardAssignment $Ast $VariableName $Message
  $values = @($assignment.Right.FindAll({
    param($node)
    $node -is [Management.Automation.Language.StringConstantExpressionAst] -or
      $node -is [Management.Automation.Language.ConstantExpressionAst]
  }, $true) | ForEach-Object { $_.Value })
  if ($values -cnotcontains $ExpectedValue) {
    throw "Core model asset guard failed: $Message Assignment `$$VariableName is missing literal $ExpectedValue."
  }
}

function Assert-CoreGuardFinallyCleanup(
  [Management.Automation.Language.Ast]$Ast,
  [string]$Message
) {
  $publicationCall = '[System.IO.File]::Replace($tmpPath, $modelPath, $backupPath)'
  $tryStatements = @($Ast.FindAll({
    param($node)
    if ($node -isnot [Management.Automation.Language.TryStatementAst] -or $null -eq $node.Finally) {
      return $false
    }
    return @($node.Body.FindAll({
      param($child)
      $child -is [Management.Automation.Language.InvokeMemberExpressionAst] -and
        (Normalize-CoreGuardText $child.Extent.Text) -ceq $publicationCall
    }, $true)).Count -eq 1
  }, $true))
  if ($tryStatements.Count -ne 1) {
    throw "Core model asset guard failed: $Message Publication must be enclosed by one try/finally."
  }
  $finallyAst = $tryStatements[0].Finally
  Assert-CoreGuardExecutableCommand $finallyAst 'Remove-Item -LiteralPath $tmpPath -Force -ErrorAction SilentlyContinue' "$Message must clean its request temp in finally."
  Assert-CoreGuardExecutableCommand $finallyAst 'Test-Path -LiteralPath $modelPath' "$Message must retain a recovery backup until stable exists."
  Assert-CoreGuardExecutableCommand $finallyAst 'Remove-Item -LiteralPath $backupPath -Force -ErrorAction SilentlyContinue' "$Message must clean its private backup after stable exists."
}

function Assert-CoreGuardNoStableMutation(
  [Management.Automation.Language.Ast]$Ast,
  [string]$Message
) {
  $stableVariables = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
  [void]$stableVariables.Add('modelPath')
  $changed = $true
  while ($changed) {
    $changed = $false
    foreach ($assignment in @($Ast.FindAll({ param($node) $node -is [Management.Automation.Language.AssignmentStatementAst] }, $true))) {
      if ($assignment.Left -isnot [Management.Automation.Language.VariableExpressionAst]) {
        continue
      }
      $rightText = Normalize-CoreGuardText $assignment.Right.Extent.Text
      foreach ($stableVariable in @($stableVariables)) {
        if ($rightText -ceq "`$$stableVariable" -and $stableVariables.Add($assignment.Left.VariablePath.UserPath)) {
          $changed = $true
          break
        }
      }
    }
  }

  $stablePattern = '\$(' + (($stableVariables | ForEach-Object { [regex]::Escape($_) }) -join '|') + ')\b'
  $mutatingCommands = @(
    'Add-Content', 'Clear-Content', 'Copy-Item', 'Invoke-RestMethod', 'Invoke-WebRequest',
    'Move-Item', 'New-Item', 'Out-File', 'Remove-Item', 'Rename-Item', 'Set-Content',
    'Start-BitsTransfer', 'Tee-Object', 'curl', 'wget'
  )
  foreach ($command in @($Ast.FindAll({ param($node) $node -is [Management.Automation.Language.CommandAst] }, $true))) {
    $commandName = $command.GetCommandName()
    if ($null -ne $commandName -and $mutatingCommands -icontains $commandName -and
        $command.Extent.Text -match $stablePattern) {
      throw "Core model asset guard failed: $Message mutates the stable path through $commandName."
    }
  }

  $allowedMemberCalls = @(
    '[System.IO.File]::Replace($tmpPath, $modelPath, $backupPath)',
    '[System.IO.File]::Move($tmpPath, $modelPath)',
    '[System.IO.File]::Move($backupPath, $modelPath)'
  )
  $mutatingMembers = @('AppendAllLines', 'AppendAllText', 'Copy', 'Create', 'Delete', 'Move', 'Open', 'OpenWrite', 'Replace', 'WriteAllBytes', 'WriteAllLines', 'WriteAllText')
  foreach ($call in @($Ast.FindAll({ param($node) $node -is [Management.Automation.Language.InvokeMemberExpressionAst] }, $true))) {
    $memberName = [string]$call.Member.Value
    $normalizedCall = Normalize-CoreGuardText $call.Extent.Text
    if ($mutatingMembers -icontains $memberName -and $call.Extent.Text -match $stablePattern -and
        $allowedMemberCalls -cnotcontains $normalizedCall) {
      throw "Core model asset guard failed: $Message mutates the stable path through member $memberName."
    }
  }

  foreach ($redirection in @($Ast.FindAll({ param($node) $node -is [Management.Automation.Language.FileRedirectionAst] }, $true))) {
    if ($redirection.Extent.Text -match $stablePattern) {
      throw "Core model asset guard failed: $Message redirects output to the stable path."
    }
  }
}

function Remove-CoreGuardJson5Comments([string]$Text) {
  $result = [Text.StringBuilder]::new($Text.Length)
  $state = 'code'
  $terminator = [char]0
  $escaped = $false
  for ($index = 0; $index -lt $Text.Length; $index++) {
    $current = $Text[$index]
    $next = if ($index + 1 -lt $Text.Length) { $Text[$index + 1] } else { [char]0 }
    if ($state -eq 'lineComment') {
      if ($current -eq [char]0x0A) { [void]$result.Append($current); $state = 'code' } else { [void]$result.Append(' ') }
      continue
    }
    if ($state -eq 'blockComment') {
      if ($current -eq [char]0x2A -and $next -eq [char]0x2F) {
        [void]$result.Append('  '); $index++; $state = 'code'
      } elseif ($current -eq [char]0x0A) { [void]$result.Append($current) } else { [void]$result.Append(' ') }
      continue
    }
    if ($state -eq 'string') {
      [void]$result.Append($current)
      if ($escaped) { $escaped = $false }
      elseif ($current -eq [char]0x5C) { $escaped = $true }
      elseif ($current -eq $terminator) { $state = 'code' }
      continue
    }
    if ($current -eq [char]0x2F -and $next -eq [char]0x2F) {
      [void]$result.Append('  '); $index++; $state = 'lineComment'
    } elseif ($current -eq [char]0x2F -and $next -eq [char]0x2A) {
      [void]$result.Append('  '); $index++; $state = 'blockComment'
    } elseif ($current -eq [char]0x22 -or $current -eq [char]0x27) {
      [void]$result.Append($current); $terminator = $current; $escaped = $false; $state = 'string'
    } else {
      [void]$result.Append($current)
    }
  }
  return $result.ToString()
}

function Get-CoreGuardContainingJson5Object([string]$Text, [int]$Position) {
  $stack = [Collections.Generic.List[int]]::new()
  $state = 'code'
  $terminator = [char]0
  $escaped = $false
  for ($index = 0; $index -le $Position; $index++) {
    $current = $Text[$index]
    if ($state -eq 'string') {
      if ($escaped) { $escaped = $false }
      elseif ($current -eq [char]0x5C) { $escaped = $true }
      elseif ($current -eq $terminator) { $state = 'code' }
      continue
    }
    if ($current -eq [char]0x22 -or $current -eq [char]0x27) { $state = 'string'; $terminator = $current; continue }
    if ($current -eq [char]0x7B) { $stack.Add($index) }
    elseif ($current -eq [char]0x7D -and $stack.Count -gt 0) { $stack.RemoveAt($stack.Count - 1) }
  }
  if ($stack.Count -eq 0) { throw 'Core model asset guard failed: named JSON5 target is not inside an object.' }
  $start = $stack[$stack.Count - 1]
  $depth = 0
  $state = 'code'
  $escaped = $false
  for ($index = $start; $index -lt $Text.Length; $index++) {
    $current = $Text[$index]
    if ($state -eq 'string') {
      if ($escaped) { $escaped = $false }
      elseif ($current -eq [char]0x5C) { $escaped = $true }
      elseif ($current -eq $terminator) { $state = 'code' }
      continue
    }
    if ($current -eq [char]0x22 -or $current -eq [char]0x27) { $state = 'string'; $terminator = $current; continue }
    if ($current -eq [char]0x7B) { $depth++ }
    elseif ($current -eq [char]0x7D) {
      $depth--
      if ($depth -eq 0) { return $Text.Substring($start, $index - $start + 1) }
    }
  }
  throw 'Core model asset guard failed: named JSON5 target object is unterminated.'
}

function Get-CoreGuardJson5ArrayForNamedObject(
  [string]$Text,
  [string]$ObjectName,
  [string]$ArrayProperty
) {
  $clean = Remove-CoreGuardJson5Comments $Text
  $namePattern = '(?m)(?:"name"|''name''|name)\s*:\s*(?:"' + [regex]::Escape($ObjectName) + '"|''' + [regex]::Escape($ObjectName) + ''')'
  $nameMatches = @([regex]::Matches($clean, $namePattern))
  if ($nameMatches.Count -ne 1) {
    throw "Core model asset guard failed: expected one JSON5 object named $ObjectName; found $($nameMatches.Count)."
  }
  $object = Get-CoreGuardContainingJson5Object $clean $nameMatches[0].Index
  $propertyPattern = '(?m)(?:"' + [regex]::Escape($ArrayProperty) + '"|''' + [regex]::Escape($ArrayProperty) + '''|' + [regex]::Escape($ArrayProperty) + ')\s*:\s*\['
  $propertyMatches = @([regex]::Matches($object, $propertyPattern))
  if ($propertyMatches.Count -ne 1) {
    throw "Core model asset guard failed: $ObjectName must contain one $ArrayProperty array; found $($propertyMatches.Count)."
  }
  $arrayStart = $propertyMatches[0].Index + $propertyMatches[0].Length - 1
  $depth = 0
  $state = 'code'
  $terminator = [char]0
  $escaped = $false
  $arrayEnd = -1
  for ($index = $arrayStart; $index -lt $object.Length; $index++) {
    $current = $object[$index]
    if ($state -eq 'string') {
      if ($escaped) { $escaped = $false }
      elseif ($current -eq [char]0x5C) { $escaped = $true }
      elseif ($current -eq $terminator) { $state = 'code' }
      continue
    }
    if ($current -eq [char]0x22 -or $current -eq [char]0x27) { $state = 'string'; $terminator = $current; continue }
    if ($current -eq [char]0x5B) { $depth++ }
    elseif ($current -eq [char]0x5D) { $depth--; if ($depth -eq 0) { $arrayEnd = $index; break } }
  }
  if ($arrayEnd -lt 0) { throw "Core model asset guard failed: $ArrayProperty array is unterminated." }
  $arrayText = $object.Substring($arrayStart + 1, $arrayEnd - $arrayStart - 1)
  return @([regex]::Matches($arrayText, '"(?:\\.|[^"\\])*"|''(?:\\.|[^''\\])*''') | ForEach-Object {
    $_.Value.Substring(1, $_.Value.Length - 2)
  })
}

Export-ModuleMember -Function @(
  'ConvertTo-CoreGuardPowerShellAst',
  'Read-CoreGuardPowerShellAst',
  'Assert-CoreGuardExecutableCommand',
  'Assert-CoreGuardExecutableMemberCall',
  'Assert-CoreGuardAssignmentLiteral',
  'Assert-CoreGuardFinallyCleanup',
  'Assert-CoreGuardNoStableMutation',
  'Get-CoreGuardJson5ArrayForNamedObject'
)
