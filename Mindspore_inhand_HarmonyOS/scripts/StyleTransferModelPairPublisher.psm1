function Publish-StyleTransferModelPair {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)] [string[]]$CandidatePaths,
    [Parameter(Mandatory)] [string[]]$StablePaths,
    [scriptblock]$BeforeSecondPublish,
    [scriptblock]$BeforeRollbackMember
  )

  if ($CandidatePaths.Count -ne 2 -or $StablePaths.Count -ne 2) {
    throw 'Style-transfer pair publication requires exactly two candidates and two stable paths.'
  }

  $transactionId = [Guid]::NewGuid().ToString('N')
  $states = @()
  for ($index = 0; $index -lt 2; $index++) {
    if (-not (Test-Path -LiteralPath $CandidatePaths[$index] -PathType Leaf)) {
      throw "Missing style-transfer candidate: $($CandidatePaths[$index])"
    }
    $states += [pscustomobject]@{
      Candidate = $CandidatePaths[$index]
      Stable = $StablePaths[$index]
      Backup = "$($StablePaths[$index]).pair-backup.$transactionId"
      RollbackDiscard = "$($StablePaths[$index]).pair-rollback-discard.$transactionId"
      HadStable = Test-Path -LiteralPath $StablePaths[$index] -PathType Leaf
      Published = $false
      RollbackFailed = $false
    }
  }

  try {
    for ($index = 0; $index -lt 2; $index++) {
      if ($index -eq 1 -and $null -ne $BeforeSecondPublish) {
        & $BeforeSecondPublish
      }
      $state = $states[$index]
      if ($state.HadStable) {
        [IO.File]::Replace($state.Candidate, $state.Stable, $state.Backup)
      } else {
        [IO.File]::Move($state.Candidate, $state.Stable)
      }
      $state.Published = $true
    }
  } catch {
    $publicationFailure = $_
    for ($index = 1; $index -ge 0; $index--) {
      $state = $states[$index]
      if (-not $state.Published) { continue }
      try {
        if ($null -ne $BeforeRollbackMember) {
          & $BeforeRollbackMember $state
        }
        if ($state.HadStable) {
          if (Test-Path -LiteralPath $state.Stable -PathType Leaf) {
            [IO.File]::Replace($state.Backup, $state.Stable, $state.RollbackDiscard)
          } elseif (Test-Path -LiteralPath $state.Backup -PathType Leaf) {
            [IO.File]::Move($state.Backup, $state.Stable)
          }
        } elseif (Test-Path -LiteralPath $state.Stable -PathType Leaf) {
          Remove-Item -LiteralPath $state.Stable -Force
        }
      } catch {
        $state.RollbackFailed = $true
        Write-Warning "Style-transfer pair rollback failed for $($state.Stable): $($_.Exception.Message)"
      }
    }
    throw $publicationFailure
  } finally {
    foreach ($state in $states) {
      if (-not $state.RollbackFailed) {
        Remove-Item -LiteralPath $state.Backup -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $state.RollbackDiscard -Force -ErrorAction SilentlyContinue
      }
    }
  }
}

Export-ModuleMember -Function Publish-StyleTransferModelPair
