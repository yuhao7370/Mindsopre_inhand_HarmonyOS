$ErrorActionPreference = 'Stop'

function Get-NormalizedText([string]$Path) {
  return (Get-Content -Raw -Encoding UTF8 -LiteralPath $Path).Replace("`r`n", "`n").Replace("`r", "`n")
}

function Invoke-GuardFixture(
  [string]$Name,
  [string]$Newline,
  [string]$Mutation,
  [bool]$ShouldAccept
) {
  $projectRoot = Split-Path -Parent $PSScriptRoot
  $tempRoot = Join-Path ([IO.Path]::GetTempPath()) "text-translation-layout-guard-$PID-$Name"
  $utf8 = [Text.UTF8Encoding]::new($false)
  $sourcePaths = @(
    'entry\src\main\ets\features\runtime\FeatureWorkflowCatalog.ets',
    'entry\src\main\ets\services\ai\AiService.ets',
    'entry\src\main\ets\pages\FeatureRuntimePage.ets'
  )

  try {
    foreach ($relativePath in $sourcePaths) {
      $sourcePath = Join-Path $projectRoot $relativePath
      $targetPath = Join-Path $tempRoot $relativePath
      New-Item -ItemType Directory -Force -Path (Split-Path -Parent $targetPath) | Out-Null
      $text = Get-NormalizedText $sourcePath
      if ($relativePath.EndsWith('FeatureRuntimePage.ets')) {
        if ($Mutation -eq 'extra-result-rows') {
          $marker = '          Text(translatedTextForAiResult(this.resultRows))'
          $text = $text.Replace($marker, "$marker`n          Text(this.resultRows[0].value)")
        } elseif ($Mutation -eq 'after-overlay') {
          $marker = '      this.runtimePermissionRecoveryOverlay()'
          $text = $text.Replace($marker, "$marker`n      Text('forbidden-after-overlay')")
        }
      }
      [IO.File]::WriteAllText($targetPath, $text.Replace("`n", $Newline), $utf8)
    }

    $guardTarget = Join-Path $tempRoot 'scripts\check-text-translation-input-parity.ps1'
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $guardTarget) | Out-Null
    [IO.File]::WriteAllText(
      $guardTarget,
      (Get-Content -Raw -Encoding UTF8 -LiteralPath (Join-Path $PSScriptRoot 'check-text-translation-input-parity.ps1')),
      $utf8
    )

    $failureMessage = $null
    try {
      & $guardTarget | Out-Null
    } catch {
      $failureMessage = $_.Exception.Message
    }

    if ($ShouldAccept -and $failureMessage) {
      return "$Name should be accepted but was rejected: $failureMessage"
    }
    if (-not $ShouldAccept -and -not $failureMessage) {
      return "$Name should be rejected but was accepted"
    }
    return $null
  } finally {
    Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
  }
}

$failures = @()
foreach ($fixture in @(
  @{ Name = 'baseline-lf'; Newline = "`n"; Mutation = 'none'; ShouldAccept = $true },
  @{ Name = 'baseline-crlf'; Newline = "`r`n"; Mutation = 'none'; ShouldAccept = $true },
  @{ Name = 'extra-result-rows'; Newline = "`n"; Mutation = 'extra-result-rows'; ShouldAccept = $false },
  @{ Name = 'component-after-overlay'; Newline = "`n"; Mutation = 'after-overlay'; ShouldAccept = $false }
)) {
  $failure = Invoke-GuardFixture `
    $fixture.Name `
    $fixture.Newline `
    $fixture.Mutation `
    $fixture.ShouldAccept
  if ($failure) {
    $failures += $failure
  }
}

if ($failures.Count -gt 0) {
  throw "Text translation layout guard fixture failed: $($failures -join '; ')"
}

Write-Output 'Text translation layout guard fixtures passed.'
