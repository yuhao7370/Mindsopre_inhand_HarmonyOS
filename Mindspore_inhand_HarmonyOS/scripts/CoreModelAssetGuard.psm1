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

function Get-CoreGuardAssignmentVariableName(
  [Management.Automation.Language.AssignmentStatementAst]$Assignment
) {
  $left = $Assignment.Left
  while ($left -is [Management.Automation.Language.AttributedExpressionAst]) {
    $left = $left.Child
  }
  if ($left -is [Management.Automation.Language.VariableExpressionAst]) {
    return $left.VariablePath.UserPath
  }
  return $null
}

function Get-CoreGuardAssignment(
  [Management.Automation.Language.Ast]$Ast,
  [string]$VariableName,
  [string]$Message
) {
  $matches = @($Ast.FindAll({
    param($node)
    $node -is [Management.Automation.Language.AssignmentStatementAst] -and
      (Get-CoreGuardAssignmentVariableName $node) -ceq $VariableName
  }, $true))
  if ($matches.Count -ne 1) {
    throw "Core model asset guard failed: $Message Expected one assignment to `$$VariableName, found $($matches.Count)."
  }
  return $matches[0]
}

function Get-CoreGuardDirectExpression([Management.Automation.Language.Ast]$Ast) {
  if ($Ast -is [Management.Automation.Language.ExpressionAst]) {
    return $Ast
  }
  if ($Ast -is [Management.Automation.Language.CommandExpressionAst]) {
    return $Ast.Expression
  }
  if ($Ast -is [Management.Automation.Language.PipelineAst] -and
      $Ast.PipelineElements.Count -eq 1 -and
      $Ast.PipelineElements[0] -is [Management.Automation.Language.CommandExpressionAst]) {
    return $Ast.PipelineElements[0].Expression
  }
  return $null
}

function Get-CoreGuardDirectLiteral([Management.Automation.Language.Ast]$Ast) {
  $expression = Get-CoreGuardDirectExpression $Ast
  if ($expression -is [Management.Automation.Language.StringConstantExpressionAst] -or
      $expression -is [Management.Automation.Language.ConstantExpressionAst]) {
    return [pscustomobject]@{ IsLiteral = $true; Value = $expression.Value }
  }
  return [pscustomobject]@{ IsLiteral = $false; Value = $null }
}

function Get-CoreGuardDirectArrayElements(
  [Management.Automation.Language.AssignmentStatementAst]$Assignment,
  [string]$Message
) {
  $arrayExpression = Get-CoreGuardDirectExpression $Assignment.Right
  if ($arrayExpression -isnot [Management.Automation.Language.ArrayExpressionAst] -or
      $arrayExpression.SubExpression.Statements.Count -ne 1) {
    throw "Core model asset guard failed: $Message must be a direct literal array."
  }
  $bodyExpression = Get-CoreGuardDirectExpression $arrayExpression.SubExpression.Statements[0]
  if ($bodyExpression -is [Management.Automation.Language.ArrayLiteralAst]) {
    return @($bodyExpression.Elements)
  }
  if ($null -ne $bodyExpression) {
    return @($bodyExpression)
  }
  throw "Core model asset guard failed: $Message must contain only direct array elements."
}

function Assert-CoreGuardAssignmentLiteral(
  [Management.Automation.Language.Ast]$Ast,
  [string]$VariableName,
  [object]$ExpectedValue,
  [string]$Message
) {
  $assignment = Get-CoreGuardAssignment $Ast $VariableName $Message
  $literal = Get-CoreGuardDirectLiteral $assignment.Right
  if (-not $literal.IsLiteral -or $literal.Value -cne $ExpectedValue) {
    throw "Core model asset guard failed: $Message Assignment `$$VariableName must directly equal literal $ExpectedValue."
  }
}

function Assert-CoreGuardStringArrayContains(
  [Management.Automation.Language.Ast]$Ast,
  [string]$VariableName,
  [string]$ExpectedValue,
  [string]$Message
) {
  $assignment = Get-CoreGuardAssignment $Ast $VariableName $Message
  $values = foreach ($element in @(Get-CoreGuardDirectArrayElements $assignment $Message)) {
    $literal = Get-CoreGuardDirectLiteral $element
    if (-not $literal.IsLiteral) {
      throw "Core model asset guard failed: $Message contains a non-literal array element."
    }
    $literal.Value
  }
  if (@($values | Where-Object { $_ -ceq $ExpectedValue }).Count -ne 1) {
    throw "Core model asset guard failed: $Message must contain literal $ExpectedValue exactly once."
  }
}

function Assert-CoreGuardObjectArrayContract(
  [Management.Automation.Language.Ast]$Ast,
  [string]$VariableName,
  [string]$ExpectedName,
  [long]$ExpectedBytes,
  [string]$ExpectedSha256,
  [string]$Message
) {
  $assignment = Get-CoreGuardAssignment $Ast $VariableName $Message
  $matches = @()
  foreach ($element in @(Get-CoreGuardDirectArrayElements $assignment $Message)) {
    if ($element -isnot [Management.Automation.Language.ConvertExpressionAst] -or
        $element.Type.TypeName.FullName -cne 'pscustomobject' -or
        $element.Child -isnot [Management.Automation.Language.HashtableAst]) {
      throw "Core model asset guard failed: $Message must contain direct [pscustomobject] literals."
    }
    $fields = @{}
    foreach ($pair in $element.Child.KeyValuePairs) {
      $key = Get-CoreGuardDirectLiteral $pair.Item1
      $value = Get-CoreGuardDirectLiteral $pair.Item2
      if (-not $key.IsLiteral -or -not $value.IsLiteral -or $fields.ContainsKey([string]$key.Value)) {
        throw "Core model asset guard failed: $Message contains a non-literal or duplicate object field."
      }
      $fields[[string]$key.Value] = $value.Value
    }
    if ($fields.ContainsKey('Name') -and $fields['Name'] -ceq $ExpectedName) {
      $matches += ,$fields
    }
  }
  if ($matches.Count -ne 1 -or
      -not $matches[0].ContainsKey('Bytes') -or [long]$matches[0]['Bytes'] -ne $ExpectedBytes -or
      -not $matches[0].ContainsKey('Sha256') -or $matches[0]['Sha256'] -cne $ExpectedSha256) {
    throw "Core model asset guard failed: $Message must bind $ExpectedName to $ExpectedBytes bytes and SHA-256 $ExpectedSha256."
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
  $backupRemoveText = 'Remove-Item -LiteralPath $backupPath -Force -ErrorAction SilentlyContinue'
  $backupRemovals = @($finallyAst.FindAll({
    param($node)
    $node -is [Management.Automation.Language.CommandAst] -and
      (Normalize-CoreGuardText $node.Extent.Text) -ceq $backupRemoveText
  }, $true))
  $guardingIfs = @($finallyAst.FindAll({
    param($node)
    if ($node -isnot [Management.Automation.Language.IfStatementAst] -or $node.Clauses.Count -ne 1 -or
        (Normalize-CoreGuardText $node.Clauses[0].Item1.Extent.Text) -cne 'Test-Path -LiteralPath $modelPath') {
      return $false
    }
    return @($node.Clauses[0].Item2.FindAll({
      param($child)
      $child -is [Management.Automation.Language.CommandAst] -and
        (Normalize-CoreGuardText $child.Extent.Text) -ceq $backupRemoveText
    }, $true)).Count -eq 1
  }, $true))
  if ($backupRemovals.Count -ne 1 -or $guardingIfs.Count -ne 1) {
    throw "Core model asset guard failed: $Message must remove its private backup only inside if (Test-Path -LiteralPath `$modelPath)."
  }
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
      $assignedVariable = Get-CoreGuardAssignmentVariableName $assignment
      if ($null -eq $assignedVariable) {
        continue
      }
      $rightExpression = Get-CoreGuardDirectExpression $assignment.Right
      foreach ($stableVariable in @($stableVariables)) {
        $isAlias = $rightExpression -is [Management.Automation.Language.VariableExpressionAst] -and
          $rightExpression.VariablePath.UserPath -ceq $stableVariable
        if (-not $isAlias -and $rightExpression -is [Management.Automation.Language.ExpandableStringExpressionAst] -and
            $rightExpression.NestedExpressions.Count -eq 1 -and
            $rightExpression.NestedExpressions[0] -is [Management.Automation.Language.VariableExpressionAst] -and
            $rightExpression.NestedExpressions[0].VariablePath.UserPath -ceq $stableVariable) {
          $innerText = $rightExpression.Extent.Text.Substring(1, $rightExpression.Extent.Text.Length - 2)
          $isAlias = $innerText -ceq "`$$stableVariable" -or $innerText -ceq "`${$stableVariable}"
        }
        if ($isAlias -and $stableVariables.Add($assignedVariable)) {
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
  $mutatingAliases = @{
    'ac' = 'Add-Content'; 'clc' = 'Clear-Content'; 'cp' = 'Copy-Item'; 'cpi' = 'Copy-Item'
    'irm' = 'Invoke-RestMethod'; 'iwr' = 'Invoke-WebRequest'; 'mi' = 'Move-Item'; 'move' = 'Move-Item'
    'mv' = 'Move-Item'; 'ni' = 'New-Item'; 'del' = 'Remove-Item'; 'erase' = 'Remove-Item'
    'rd' = 'Remove-Item'; 'ri' = 'Remove-Item'; 'rm' = 'Remove-Item'; 'rmdir' = 'Remove-Item'
    'ren' = 'Rename-Item'; 'rni' = 'Rename-Item'; 'sc' = 'Set-Content'; 'tee' = 'Tee-Object'
  }
  foreach ($command in @($Ast.FindAll({ param($node) $node -is [Management.Automation.Language.CommandAst] }, $true))) {
    $commandName = $command.GetCommandName()
    if ($null -eq $commandName) { continue }
    $unqualifiedCommandName = ($commandName -split '\\')[-1]
    if ($mutatingAliases.ContainsKey($unqualifiedCommandName)) {
      $unqualifiedCommandName = $mutatingAliases[$unqualifiedCommandName]
    }
    $pipeline = $command.Parent
    while ($null -ne $pipeline -and $pipeline -isnot [Management.Automation.Language.PipelineAst]) {
      $pipeline = $pipeline.Parent
    }
    $mutationText = if ($null -ne $pipeline) { $pipeline.Extent.Text } else { $command.Extent.Text }
    if ($mutatingCommands -icontains $unqualifiedCommandName -and $mutationText -match $stablePattern) {
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

function Assert-CoreGuardNoDownloaderCommand(
  [Management.Automation.Language.Ast]$Ast,
  [string]$Message
) {
  $downloaderPattern = '(?i)download-[^\s''"]*models?\.ps1\b'
  $downloaderVariables = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
  foreach ($assignment in @($Ast.FindAll({
    param($node)
    $node -is [Management.Automation.Language.AssignmentStatementAst]
  }, $true))) {
    $assignedVariable = Get-CoreGuardAssignmentVariableName $assignment
    $literal = Get-CoreGuardDirectLiteral $assignment.Right
    if ($null -ne $assignedVariable -and $literal.IsLiteral -and
        [string]$literal.Value -match $downloaderPattern) {
      [void]$downloaderVariables.Add($assignedVariable)
    }
  }

  foreach ($command in @($Ast.FindAll({ param($node) $node -is [Management.Automation.Language.CommandAst] }, $true))) {
    if ($command.Extent.Text -match $downloaderPattern) {
      throw "Core model asset guard failed: $Message executes or dot-sources a model downloader."
    }
    $commandName = $command.GetCommandName()
    $unqualifiedCommandName = if ($null -ne $commandName) { ($commandName -split '\\')[-1] } else { '' }
    $isProcessInvocation = @('powershell', 'powershell.exe', 'pwsh', 'pwsh.exe', 'cmd', 'cmd.exe') -icontains $unqualifiedCommandName
    if ($command.InvocationOperator -notin @(
        [Management.Automation.Language.TokenKind]::Ampersand,
        [Management.Automation.Language.TokenKind]::Dot
      ) -and -not $isProcessInvocation) {
      continue
    }
    $referencedVariables = @($command.FindAll({
      param($node)
      $node -is [Management.Automation.Language.VariableExpressionAst]
    }, $true) | ForEach-Object { $_.VariablePath.UserPath })
    if (@($referencedVariables | Where-Object { $downloaderVariables.Contains($_) }).Count -ne 0) {
      throw "Core model asset guard failed: $Message invokes a model downloader through a direct literal variable."
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
  'Assert-CoreGuardStringArrayContains',
  'Assert-CoreGuardObjectArrayContract',
  'Assert-CoreGuardFinallyCleanup',
  'Assert-CoreGuardNoStableMutation',
  'Assert-CoreGuardNoDownloaderCommand',
  'Get-CoreGuardJson5ArrayForNamedObject'
)
