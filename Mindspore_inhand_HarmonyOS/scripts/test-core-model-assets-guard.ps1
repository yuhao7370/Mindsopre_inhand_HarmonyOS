$ErrorActionPreference = 'Stop'

$modulePath = Join-Path $PSScriptRoot 'CoreModelAssetGuard.psm1'
if (-not (Test-Path -LiteralPath $modulePath -PathType Leaf)) {
  throw "Core model guard fixture failed: missing parser module $modulePath."
}
Import-Module $modulePath -Force

function Assert-Rejects([scriptblock]$Action, [string]$Label) {
  try {
    & $Action
  } catch {
    Write-Host "Rejected invalid core guard fixture: $Label"
    return
  }
  throw "Core model guard fixture unexpectedly accepted: $Label"
}

$commandMarker = "& (Join-Path `$PSScriptRoot 'check-core-model-assets.ps1')"
$commandDecoy = @"
# & (Join-Path `$PSScriptRoot 'check-core-model-assets.ps1')
`$decoy = @'
& (Join-Path `$PSScriptRoot 'check-core-model-assets.ps1')
'@
"@
$commandDecoyAst = ConvertTo-CoreGuardPowerShellAst $commandDecoy 'command decoy'
Assert-Rejects {
  Assert-CoreGuardExecutableCommand $commandDecoyAst $commandMarker 'comment/here-string command decoy'
} 'comment and here-string command marker'
$commandAst = ConvertTo-CoreGuardPowerShellAst $commandMarker 'real command'
Assert-CoreGuardExecutableCommand $commandAst $commandMarker 'real command'

$memberMarker = '[System.IO.File]::Replace($tmpPath, $modelPath, $backupPath)'
$memberDecoyAst = ConvertTo-CoreGuardPowerShellAst "# $memberMarker`n`$decoy = '$memberMarker'" 'member decoy'
Assert-Rejects {
  Assert-CoreGuardExecutableMemberCall $memberDecoyAst $memberMarker 'comment/string member decoy'
} 'comment and string member marker'
$memberAst = ConvertTo-CoreGuardPowerShellAst $memberMarker 'real member call'
Assert-CoreGuardExecutableMemberCall $memberAst $memberMarker 'real member call'

$assignmentDecoy = @'
$expectedModelSha256 = 'WRONG'
$decoy = 'EXPECTED'
'@
$assignmentDecoyAst = ConvertTo-CoreGuardPowerShellAst $assignmentDecoy 'assignment decoy'
Assert-Rejects {
  Assert-CoreGuardAssignmentLiteral $assignmentDecoyAst 'expectedModelSha256' 'EXPECTED' 'unrelated assignment decoy'
} 'literal in unrelated assignment'
$assignmentAst = ConvertTo-CoreGuardPowerShellAst "`$expectedModelSha256 = 'EXPECTED'" 'real assignment'
Assert-CoreGuardAssignmentLiteral $assignmentAst 'expectedModelSha256' 'EXPECTED' 'real assignment'

$wrongTargetJson5 = @'
{
  "targets": [
    { "name": "default", "config": { "ignoreResourcePattern": ["LICENSE-Apache-2.0.txt"] } },
    {
      "name": "ohosTest",
      "config": { "ignoreResourcePattern": ["*.ms", "NOTICE.md"] }
    }
  ]
}
// "LICENSE-Apache-2.0.txt"
'@
$wrongTargetValues = @(Get-CoreGuardJson5ArrayForNamedObject $wrongTargetJson5 'ohosTest' 'ignoreResourcePattern')
if ($wrongTargetValues -contains 'LICENSE-Apache-2.0.txt') {
  throw 'Core model guard fixture accepted an exclusion from the wrong target/comment.'
}
$rightTargetJson5 = $wrongTargetJson5.Replace('"*.ms", "NOTICE.md"', '"*.ms", "NOTICE.md", "LICENSE-Apache-2.0.txt"')
$rightTargetValues = @(Get-CoreGuardJson5ArrayForNamedObject $rightTargetJson5 'ohosTest' 'ignoreResourcePattern')
if ($rightTargetValues -notcontains 'LICENSE-Apache-2.0.txt') {
  throw 'Core model guard fixture rejected an exclusion in the ohosTest ignoreResourcePattern.'
}

Write-Host 'Core model asset guard fixtures passed.'
