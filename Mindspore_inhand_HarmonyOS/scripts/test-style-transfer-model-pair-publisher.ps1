$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'StyleTransferModelPairPublisher.psm1') -Force

function Assert-Bytes([string]$Path, [byte[]]$Expected, [string]$Message) {
  $actual = [IO.File]::ReadAllBytes($Path)
  if ([BitConverter]::ToString($actual) -cne [BitConverter]::ToString($Expected)) {
    throw $Message
  }
}

$testRoot = Join-Path ([IO.Path]::GetTempPath()) "style-transfer-pair-$([Guid]::NewGuid().ToString('N'))"
[IO.Directory]::CreateDirectory($testRoot) | Out-Null
try {
  $predictStable = Join-Path $testRoot 'style_predict_fp16.mnn'
  $transferStable = Join-Path $testRoot 'style_transform_fp16.mnn'
  $predictCandidate = Join-Path $testRoot 'predict.candidate'
  $transferCandidate = Join-Path $testRoot 'transfer.candidate'
  [IO.File]::WriteAllBytes($predictStable, [byte[]](1, 1))
  [IO.File]::WriteAllBytes($transferStable, [byte[]](2, 2))
  [IO.File]::WriteAllBytes($predictCandidate, [byte[]](3, 3))
  [IO.File]::WriteAllBytes($transferCandidate, [byte[]](4, 4))

  $failed = $false
  try {
    Publish-StyleTransferModelPair `
      -CandidatePaths @($predictCandidate, $transferCandidate) `
      -StablePaths @($predictStable, $transferStable) `
      -BeforeSecondPublish { throw 'injected second publication failure' }
  } catch {
    $failed = $true
  }
  if (-not $failed) { throw 'Pair publisher did not surface the injected failure.' }
  Assert-Bytes $predictStable ([byte[]](1, 1)) 'Predict stable was not rolled back.'
  Assert-Bytes $transferStable ([byte[]](2, 2)) 'Transfer stable changed despite pair failure.'

  [IO.File]::WriteAllBytes($predictCandidate, [byte[]](7, 7))
  [IO.File]::WriteAllBytes($transferCandidate, [byte[]](8, 8))
  $caughtMessage = ''
  $rollbackWarnings = @()
  try {
    Publish-StyleTransferModelPair `
      -CandidatePaths @($predictCandidate, $transferCandidate) `
      -StablePaths @($predictStable, $transferStable) `
      -BeforeSecondPublish { throw 'original publication failure' } `
      -BeforeRollbackMember {
        param($state)
        [IO.File]::Copy($state.Stable, $state.RollbackDiscard, $true)
        throw 'injected rollback failure'
      } `
      -WarningVariable rollbackWarnings
  } catch {
    $caughtMessage = $_.Exception.Message
  }
  if ($caughtMessage -cne 'original publication failure') {
    throw "Pair publisher did not preserve the original publication error: $caughtMessage"
  }
  if (($rollbackWarnings -join "`n") -notmatch 'injected rollback failure') {
    throw 'Pair publisher did not report rollback failure context.'
  }
  $retainedBackups = @(Get-ChildItem -LiteralPath $testRoot -Filter '*.pair-backup.*')
  $retainedDiscards = @(Get-ChildItem -LiteralPath $testRoot -Filter '*.pair-rollback-discard.*')
  if ($retainedBackups.Count -ne 1 -or $retainedDiscards.Count -ne 1) {
    throw 'Pair publisher deleted recovery artifacts after rollback itself failed.'
  }
  Remove-Item -LiteralPath $retainedBackups[0].FullName -Force
  Remove-Item -LiteralPath $retainedDiscards[0].FullName -Force

  [IO.File]::WriteAllBytes($predictCandidate, [byte[]](5, 5))
  [IO.File]::WriteAllBytes($transferCandidate, [byte[]](6, 6))
  Publish-StyleTransferModelPair `
    -CandidatePaths @($predictCandidate, $transferCandidate) `
    -StablePaths @($predictStable, $transferStable)
  Assert-Bytes $predictStable ([byte[]](5, 5)) 'Predict stable was not published.'
  Assert-Bytes $transferStable ([byte[]](6, 6)) 'Transfer stable was not published.'
} finally {
  Remove-Item -LiteralPath $testRoot -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host 'Style-transfer model pair publisher tests passed.'
