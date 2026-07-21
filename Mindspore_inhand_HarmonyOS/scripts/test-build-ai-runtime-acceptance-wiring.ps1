$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$buildCall = "& (Join-Path `$PSScriptRoot 'build-hap.ps1')"
$gestureCall = "& (Join-Path `$PSScriptRoot 'verify-gesture-native-contract.ps1') -DevEcoSdkRoot `$env:DEVECO_SDK_HOME -LibraryPath `$gestureLibPath"
$translationCall = "& (Join-Path `$PSScriptRoot 'test-translation-xz-native-contract.ps1') -DevEcoSdkRoot `$env:DEVECO_SDK_HOME -LibraryPath `$translationLibPath"
$gestureAssignment = '$gestureLibPath = Join-Path $PSScriptRoot "..\entry\build\default\intermediates\stripped_native_libs\default\$abi\libgesture_mnn.so"'
$translationAssignment = '$translationLibPath = Join-Path $PSScriptRoot "..\entry\build\default\intermediates\stripped_native_libs\default\$abi\libtranslation_archive.so"'
$ohosTestCall = '& cmd.exe /d /c "`"$hvigor`" assembleHap --mode module -p product=default -p module=entry@ohosTest --no-daemon 2>&1"'

function Get-DirectCommands([System.Management.Automation.Language.Ast]$Block) {
  return @(
    foreach ($statement in $Block.Statements) {
      if ($statement -is [System.Management.Automation.Language.PipelineAst] -and
        $statement.PipelineElements.Count -eq 1 -and
        $statement.PipelineElements[0] -is [System.Management.Automation.Language.CommandAst]) {
        $statement.PipelineElements[0]
      }
    }
  )
}

function Assert-SingleCommand(
  [System.Management.Automation.Language.CommandAst[]]$Commands,
  [string]$Expected,
  [string]$Label
) {
  $matches = @($Commands | Where-Object { $_.Extent.Text.Trim() -ceq $Expected })
  if ($matches.Count -ne 1) {
    throw "Expected exactly one direct $Label invocation, got $($matches.Count)."
  }
  return $matches[0]
}

function Assert-AcceptanceWiring([string]$Source) {
  $tokens = $null
  $parseErrors = $null
  $ast = [System.Management.Automation.Language.Parser]::ParseInput($Source, [ref]$tokens, [ref]$parseErrors)
  if ($parseErrors.Count -ne 0) {
    throw "Unified acceptance has $($parseErrors.Count) PowerShell parse error(s)."
  }

  $allCommands = @($ast.FindAll({
    param($node)
    return $node -is [System.Management.Automation.Language.CommandAst]
  }, $true))
  $rootCommands = @(Get-DirectCommands $ast.EndBlock)
  $build = Assert-SingleCommand $rootCommands $buildCall 'main HAP build'
  $ohosTest = Assert-SingleCommand $rootCommands $ohosTestCall 'ohosTest HAP build'

  $abiLoops = @($ast.FindAll({
    param($node)
    return $node -is [System.Management.Automation.Language.ForEachStatementAst] -and
      $node.Variable.VariablePath.UserPath -ceq 'abi' -and
      $node.Condition.Extent.Text.Trim() -ceq '$abis'
  }, $true))
  if ($abiLoops.Count -ne 1) {
    throw "Expected exactly one foreach (`$abi in `$abis) native-contract loop, got $($abiLoops.Count)."
  }
  $abiLoop = $abiLoops[0]
  $loopCommands = @(Get-DirectCommands $abiLoop.Body)
  [void](Assert-SingleCommand $loopCommands $gestureCall 'gesture native contract')
  [void](Assert-SingleCommand $loopCommands $translationCall 'translation native contract')

  foreach ($expectation in @(
    @{ Text = $gestureCall; Label = 'gesture native contract' },
    @{ Text = $translationCall; Label = 'translation native contract' }
  )) {
    $allMatches = @($allCommands | Where-Object { $_.Extent.Text.Trim() -ceq $expectation.Text })
    if ($allMatches.Count -ne 1) {
      throw "Expected exactly one $($expectation.Label) invocation in the full AST, got $($allMatches.Count)."
    }
  }

  $loopAssignments = @($abiLoop.Body.Statements | Where-Object {
    $_ -is [System.Management.Automation.Language.AssignmentStatementAst]
  } | ForEach-Object { $_.Extent.Text.Trim() })
  foreach ($assignment in @($gestureAssignment, $translationAssignment)) {
    if (@($loopAssignments | Where-Object { $_ -ceq $assignment }).Count -ne 1) {
      throw "Native contract library path must be assigned directly from the current ABI: $assignment"
    }
  }

  if (-not ($build.Extent.StartOffset -lt $abiLoop.Extent.StartOffset -and
    $abiLoop.Extent.StartOffset -lt $ohosTest.Extent.StartOffset)) {
    throw 'Unified acceptance order must be main HAP, per-ABI native contracts, then ohosTest HAP.'
  }
}

function Replace-ExactlyOnce([string]$Source, [string]$Before, [string]$After) {
  $first = $Source.IndexOf($Before, [StringComparison]::Ordinal)
  if ($first -lt 0 -or $Source.IndexOf($Before, $first + $Before.Length, [StringComparison]::Ordinal) -ge 0) {
    throw "Wiring fixture expected exactly one mutation target: $Before"
  }
  return $Source.Substring(0, $first) + $After + $Source.Substring($first + $Before.Length)
}

function Assert-MutationRejected([string]$Source, [string]$Label) {
  $rejected = $false
  try { Assert-AcceptanceWiring $Source } catch { $rejected = $true }
  if (-not $rejected) { throw "Wiring guard accepted mutation: $Label" }
}

$acceptancePath = Join-Path $PSScriptRoot 'build-ai-runtime-acceptance.ps1'
if (-not (Test-Path -LiteralPath $acceptancePath -PathType Leaf)) {
  throw "Missing unified acceptance script: $acceptancePath"
}
$source = Get-Content -LiteralPath $acceptancePath -Raw
Assert-AcceptanceWiring $source

Assert-MutationRejected (Replace-ExactlyOnce $source $gestureCall "# $gestureCall") `
  'gesture verifier replaced by a comment'
Assert-MutationRejected (Replace-ExactlyOnce $source $translationCall "# $translationCall") `
  'translation verifier replaced by a comment'
Assert-MutationRejected (Replace-ExactlyOnce $source $gestureCall "if (`$false) { $gestureCall }") `
  'gesture verifier hidden behind a false condition'
Assert-MutationRejected (Replace-ExactlyOnce $source $gestureCall `
  "& (Join-Path `$PSScriptRoot 'verify-gesture-native-contract.ps1')") `
  'gesture verifier without explicit native SDK and stripped library path'
Assert-MutationRejected (Replace-ExactlyOnce $source $gestureAssignment `
  '$gestureLibPath = Join-Path $PSScriptRoot "..\entry\build\default\intermediates\stripped_native_libs\default\arm64-v8a\libgesture_mnn.so"') `
  'gesture library path hard-codes one ABI'
Assert-MutationRejected (Replace-ExactlyOnce $source $ohosTestCall "Write-Output 'module=entry@ohosTest'") `
  'ohosTest build replaced by a marker'

Write-Output 'AI runtime native contract acceptance wiring verified.'
