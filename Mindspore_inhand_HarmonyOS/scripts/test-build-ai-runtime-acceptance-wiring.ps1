$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$buildCall = "& (Join-Path `$PSScriptRoot 'build-hap.ps1')"
$gestureName = 'verify-gesture-native-contract.ps1'
$gestureCall = "& (Join-Path `$PSScriptRoot '$gestureName')"
$translationName = 'test-translation-xz-native-contract.ps1'
$translationCall = "& (Join-Path `$PSScriptRoot '$translationName')"
$ohosTestCall = '& cmd.exe /d /c "`"$hvigor`" assembleHap --mode module -p product=default -p module=entry@ohosTest --no-daemon 2>&1"'

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
  $rootCommands = @(
    foreach ($statement in $ast.EndBlock.Statements) {
      if (
        $statement -is [System.Management.Automation.Language.PipelineAst] -and
        $statement.PipelineElements.Count -eq 1 -and
        $statement.PipelineElements[0] -is [System.Management.Automation.Language.CommandAst]
      ) {
        $statement.PipelineElements[0]
      }
    }
  )

  $expectations = @(
    @{ Label = 'main HAP build'; Text = $buildCall },
    @{ Label = $gestureName; Text = $gestureCall },
    @{ Label = $translationName; Text = $translationCall },
    @{ Label = 'ohosTest HAP build'; Text = $ohosTestCall }
  )
  $offsets = @()
  foreach ($expectation in $expectations) {
    $allMatches = @($allCommands | Where-Object { $_.Extent.Text.Trim() -ceq $expectation.Text })
    if ($allMatches.Count -ne 1) {
      throw "Expected exactly one direct $($expectation.Label) invocation in the full AST, got $($allMatches.Count)."
    }
    $rootMatches = @($rootCommands | Where-Object { $_.Extent.Text.Trim() -ceq $expectation.Text })
    if ($rootMatches.Count -ne 1) {
      throw "Expected exactly one top-level direct $($expectation.Label) invocation, got $($rootMatches.Count)."
    }
    $offsets += $rootMatches[0].Extent.StartOffset
  }

  if (-not ($offsets[0] -lt $offsets[1] -and $offsets[1] -lt $offsets[2] -and $offsets[2] -lt $offsets[3])) {
    throw 'Unified acceptance order must be main HAP, gesture contract, translation contract, then ohosTest HAP.'
  }
}

$acceptancePath = Join-Path $PSScriptRoot 'build-ai-runtime-acceptance.ps1'
if (-not (Test-Path -LiteralPath $acceptancePath -PathType Leaf)) {
  throw "Missing unified acceptance script: $acceptancePath"
}

$source = Get-Content -LiteralPath $acceptancePath -Raw
Assert-AcceptanceWiring $source
$commentOnlySource = $source.Replace($gestureCall, "# $gestureCall").Replace($translationCall, "# $translationCall")
$commentOnlyRejected = $false
try {
  Assert-AcceptanceWiring $commentOnlySource
} catch {
  $commentOnlyRejected = $true
}
if (-not $commentOnlyRejected) {
  throw 'Wiring guard accepted comment-only native verifier calls.'
}

$conditionalSource = $source.Replace($gestureCall, "if (`$false) { $gestureCall }").Replace(
  $translationCall,
  "if (`$false) { $translationCall }"
)
$conditionalRejected = $false
try {
  Assert-AcceptanceWiring $conditionalSource
} catch {
  $conditionalRejected = $true
}
if (-not $conditionalRejected) {
  throw 'Wiring guard accepted native verifier calls hidden behind false conditions.'
}

$fakeOhosTestSource = $source.Replace($ohosTestCall, "Write-Output 'module=entry@ohosTest'")
$fakeOhosTestRejected = $false
try {
  Assert-AcceptanceWiring $fakeOhosTestSource
} catch {
  $fakeOhosTestRejected = $true
}
if (-not $fakeOhosTestRejected) {
  throw 'Wiring guard accepted a non-build ohosTest marker command.'
}

Write-Output 'AI runtime native contract acceptance wiring verified.'
