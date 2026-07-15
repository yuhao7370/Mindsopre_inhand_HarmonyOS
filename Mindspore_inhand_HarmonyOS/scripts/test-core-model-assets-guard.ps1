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
  $script:unexpectedAcceptances.Add($Label)
  Write-Host "UNEXPECTEDLY accepted invalid core guard fixture: $Label"
}

$script:unexpectedAcceptances = [Collections.Generic.List[string]]::new()

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

$stableAliasMutation = @'
$stableAlias = $modelPath
Set-Content -LiteralPath $stableAlias -Value 'bad'
'@
$stableAliasMutationAst = ConvertTo-CoreGuardPowerShellAst $stableAliasMutation 'stable alias mutation'
Assert-Rejects {
  Assert-CoreGuardNoStableMutation $stableAliasMutationAst 'stable alias mutation'
} 'stable path mutation through an alias'
$approvedPublication = @'
[System.IO.File]::Replace($tmpPath, $modelPath, $backupPath)
[System.IO.File]::Move($tmpPath, $modelPath)
[System.IO.File]::Move($backupPath, $modelPath)
'@
$approvedPublicationAst = ConvertTo-CoreGuardPowerShellAst $approvedPublication 'approved publication calls'
Assert-CoreGuardNoStableMutation $approvedPublicationAst 'approved publication calls'

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

$deadBranchAssignment = @'
$expectedModelSha256 = if ($false) { 'EXPECTED' } else { 'WRONG' }
'@
$deadBranchAssignmentAst = ConvertTo-CoreGuardPowerShellAst $deadBranchAssignment 'dead branch assignment'
Assert-Rejects {
  Assert-CoreGuardAssignmentLiteral $deadBranchAssignmentAst 'expectedModelSha256' 'EXPECTED' 'dead branch assignment'
} 'literal only in a dead assignment branch'

$unsafeFinally = @'
try {
  [System.IO.File]::Replace($tmpPath, $modelPath, $backupPath)
} finally {
  Remove-Item -LiteralPath $tmpPath -Force -ErrorAction SilentlyContinue
  Test-Path -LiteralPath $modelPath
  Remove-Item -LiteralPath $backupPath -Force -ErrorAction SilentlyContinue
}
'@
$unsafeFinallyAst = ConvertTo-CoreGuardPowerShellAst $unsafeFinally 'unsafe finally cleanup'
Assert-Rejects {
  Assert-CoreGuardFinallyCleanup $unsafeFinallyAst 'unsafe finally cleanup'
} 'unconditional backup deletion after unrelated Test-Path'

$quotedAliasMutation = @'
$stableAlias = "$modelPath"
Set-Content -LiteralPath $stableAlias -Value 'bad'
'@
$quotedAliasMutationAst = ConvertTo-CoreGuardPowerShellAst $quotedAliasMutation 'quoted stable alias mutation'
Assert-Rejects {
  Assert-CoreGuardNoStableMutation $quotedAliasMutationAst 'quoted stable alias mutation'
} 'stable path mutation through an expandable-string alias'

$pipelineMutationAst = ConvertTo-CoreGuardPowerShellAst 'Get-Item $modelPath | Remove-Item' 'pipeline stable mutation'
Assert-Rejects {
  Assert-CoreGuardNoStableMutation $pipelineMutationAst 'pipeline stable mutation'
} 'stable path mutation through a pipeline'

$qualifiedMutationAst = ConvertTo-CoreGuardPowerShellAst `
  'Microsoft.PowerShell.Management\Set-Content -LiteralPath $modelPath -Value bad' `
  'module-qualified stable mutation'
Assert-Rejects {
  Assert-CoreGuardNoStableMutation $qualifiedMutationAst 'module-qualified stable mutation'
} 'stable path mutation through a module-qualified command'

$misboundModels = @'
$models = @(
  [pscustomobject]@{ Name = 'first.ms'; Bytes = 2; Sha256 = 'SECOND' },
  [pscustomobject]@{ Name = 'second.ms'; Bytes = 1; Sha256 = 'FIRST' }
)
'@
$misboundModelsAst = ConvertTo-CoreGuardPowerShellAst $misboundModels 'misbound model array'
Assert-Rejects {
  Assert-CoreGuardObjectArrayContract $misboundModelsAst 'models' 'first.ms' 1 'FIRST' 'misbound first model'
} 'model constants not bound to the expected Name'
$boundModels = $misboundModels.Replace("Bytes = 2; Sha256 = 'SECOND'", "Bytes = 1; Sha256 = 'FIRST'")
$boundModelsAst = ConvertTo-CoreGuardPowerShellAst $boundModels 'bound model array'
Assert-CoreGuardObjectArrayContract $boundModelsAst 'models' 'first.ms' 1 'FIRST' 'bound first model'

$deadBranchArray = @'
$resourceEntries = @(
  if ($false) { 'resources/rawfile/model/required.ms' }
  'resources/rawfile/model/other.ms'
)
'@
$deadBranchArrayAst = ConvertTo-CoreGuardPowerShellAst $deadBranchArray 'dead branch resource array'
Assert-Rejects {
  Assert-CoreGuardStringArrayContains $deadBranchArrayAst 'resourceEntries' `
    'resources/rawfile/model/required.ms' 'dead branch resource entry'
} 'HAP entry only in a dead array branch'
$literalArrayAst = ConvertTo-CoreGuardPowerShellAst `
  "`$resourceEntries = @('resources/rawfile/model/required.ms')" `
  'literal resource array'
Assert-CoreGuardStringArrayContains $literalArrayAst 'resourceEntries' `
  'resources/rawfile/model/required.ms' 'literal resource entry'

$dotSourcedDownloaderAst = ConvertTo-CoreGuardPowerShellAst `
  ". (Join-Path `$PSScriptRoot 'download-image-classification-model.ps1')" `
  'dot-sourced downloader'
Assert-Rejects {
  Assert-CoreGuardNoDownloaderCommand $dotSourcedDownloaderAst 'dot-sourced downloader'
} 'dot-sourced downloader in normal build'
$directDownloaderAst = ConvertTo-CoreGuardPowerShellAst `
  "powershell.exe -File (Join-Path `$PSScriptRoot 'download-style-transfer-models.ps1')" `
  'direct powershell downloader'
Assert-Rejects {
  Assert-CoreGuardNoDownloaderCommand $directDownloaderAst 'direct powershell downloader'
} 'powershell -File downloader in normal build'
$verifierOnlyBuildAst = ConvertTo-CoreGuardPowerShellAst `
  "& (Join-Path `$PSScriptRoot 'ensure-mindspore-models.ps1')" `
  'verifier-only build'
Assert-CoreGuardNoDownloaderCommand $verifierOnlyBuildAst 'verifier-only build'

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

if ($script:unexpectedAcceptances.Count -ne 0) {
  throw "Core model guard fixture unexpectedly accepted: $($script:unexpectedAcceptances -join '; ')"
}

Write-Host 'Core model asset guard fixtures passed.'
