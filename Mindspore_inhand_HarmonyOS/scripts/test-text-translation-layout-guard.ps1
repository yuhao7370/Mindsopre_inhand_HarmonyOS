$ErrorActionPreference = 'Stop'

function Get-NormalizedText([string]$Path) {
  return (Get-Content -Raw -Encoding UTF8 -LiteralPath $Path).Replace("`r`n", "`n").Replace("`r", "`n")
}

function Replace-ExactlyOnce([string]$Text, [string]$Old, [string]$New, [string]$Name) {
  $count = ($Text.Length - $Text.Replace($Old, '').Length) / $Old.Length
  if ($count -ne 1) { throw "Mutation '$Name' expected one marker, found $count." }
  return $Text.Replace($Old, $New)
}

function Invoke-GuardFixture([hashtable]$Fixture) {
  $projectRoot = Split-Path -Parent $PSScriptRoot
  $tempRoot = Join-Path ([IO.Path]::GetTempPath()) "text-translation-layout-$PID-$([guid]::NewGuid())"
  $utf8 = [Text.UTF8Encoding]::new($false)
  try {
    foreach ($relativePath in @(
      'entry\src\main\ets\features\runtime\FeatureWorkflowCatalog.ets',
      'entry\src\main\ets\services\ai\AiService.ets',
      'entry\src\main\ets\pages\FeatureRuntimePage.ets'
    )) {
      $source = Join-Path $projectRoot $relativePath
      $target = Join-Path $tempRoot $relativePath
      New-Item -ItemType Directory -Force -Path (Split-Path -Parent $target) | Out-Null
      $text = Get-NormalizedText $source
      if ([string]$Fixture.Old -ne '' -and $relativePath.EndsWith([string]$Fixture.File)) {
        $text = Replace-ExactlyOnce $text ([string]$Fixture.Old) ([string]$Fixture.New) ([string]$Fixture.Name)
      }
      [IO.File]::WriteAllText($target, $text.Replace("`n", [string]$Fixture.Newline), $utf8)
    }

    $guardTarget = Join-Path $tempRoot 'scripts\check-text-translation-input-parity.ps1'
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $guardTarget) | Out-Null
    $guardSource = Join-Path $PSScriptRoot 'check-text-translation-input-parity.ps1'
    [IO.File]::WriteAllText(
      $guardTarget,
      (Get-Content -Raw -Encoding UTF8 -LiteralPath $guardSource),
      $utf8
    )
    $failure = $null
    try { & $guardTarget | Out-Null } catch { $failure = $_.Exception.Message }
    if ([bool]$Fixture.Accept -and $failure) {
      return "$($Fixture.Name) should pass but failed: $failure"
    }
    if (-not [bool]$Fixture.Accept -and -not $failure) {
      return "$($Fixture.Name) should fail but passed"
    }
    return $null
  } finally {
    Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
  }
}

$fixtures = @(
  @{ Name='baseline-lf'; Newline="`n"; File='none'; Old=''; New=''; Accept=$true },
  @{ Name='baseline-crlf'; Newline="`r`n"; File='none'; Old=''; New=''; Accept=$true },
  @{ Name='nested-scroll'; Newline="`n"; File='FeatureRuntimePage.ets';
    Old='          Text(translatedTextForAiResult(this.resultRows))';
    New="          Scroll() {`n            Text(translatedTextForAiResult(this.resultRows))`n          }"; Accept=$false },
  @{ Name='short-photo'; Newline="`n"; File='FeatureRuntimePage.ets';
    Old="          Button(appString('feature_input_photo_android'), { type: ButtonType.Normal })`n            .width('100%')`n            .constraintSize({ minHeight: 48 })";
    New="          Button(appString('feature_input_photo_android'), { type: ButtonType.Normal })`n            .width('100%')`n            .height(37)"; Accept=$false },
  @{ Name='copy-ungated'; Newline="`n"; File='FeatureRuntimePage.ets';
    Old='            .enabled(this.translationCopyEnabled())';
    New='            .enabled(!this.workflowRunning)'; Accept=$false },
  @{ Name='status-removed'; Newline="`n"; File='FeatureRuntimePage.ets';
    Old="            Text(appString(this.statusKey))`n              .fontSize(14)`n              .fontColor(AppColor.textSecondary)`n              .layoutWeight(1)`n          }`n          .width('100%')`n          .constraintSize({ minHeight: 48 })`n          .padding({ left: AppSpacing.md, right: AppSpacing.md";
    New="            Text(appString(this.runActionKey))`n              .fontSize(14)`n              .fontColor(AppColor.textSecondary)`n              .layoutWeight(1)`n          }`n          .width('100%')`n          .constraintSize({ minHeight: 48 })`n          .padding({ left: AppSpacing.md, right: AppSpacing.md"; Accept=$false },
  @{ Name='loading-removed'; Newline="`n"; File='FeatureRuntimePage.ets';
    Old="            if (this.workflowRunning) {`n              LoadingProgress()`n                .width(24)`n                .height(24)`n            }`n            Text(appString(this.statusKey))`n              .fontSize(14)`n              .fontColor(AppColor.textSecondary)`n              .layoutWeight(1)`n          }`n          .width('100%')`n          .constraintSize({ minHeight: 48 })`n          .padding({ left: AppSpacing.md, right: AppSpacing.md";
    New="            Text(appString(this.statusKey))`n              .fontSize(14)`n              .fontColor(AppColor.textSecondary)`n              .layoutWeight(1)`n          }`n          .width('100%')`n          .constraintSize({ minHeight: 48 })`n          .padding({ left: AppSpacing.md, right: AppSpacing.md"; Accept=$false },
  @{ Name='retry-label-removed'; Newline="`n"; File='FeatureRuntimePage.ets';
    Old='textTranslationRunActionLabelKey(this.statusKey, this.runActionKey)';
    New='this.runActionKey'; Accept=$false },
  @{ Name='start-clears-result'; Newline="`n"; File='FeatureWorkflowCatalog.ets';
    Old='    !usesAndroidTextTranslationLayout(workflow) &&';
    New=''; Accept=$false },
  @{ Name='failed-result-overwrites'; Newline="`n"; File='FeatureWorkflowCatalog.ets';
    Old='    usesAndroidTextTranslationLayout(workflow) ||';
    New=''; Accept=$false },
  @{ Name='image-ready-clears-result'; Newline="`n"; File='FeatureWorkflowCatalog.ets';
    Old="    (usesAndroidTextTranslationLayout(workflow) && (inputKind === 'photo' || inputKind === 'camera')) ||";
    New=''; Accept=$false },
  @{ Name='running-input-enabled'; Newline="`n"; File='FeatureWorkflowCatalog.ets';
    Old="  if (usesAndroidTextTranslationLayout(workflow)) {`n    return false;`n  }";
    New="  if (usesAndroidTextTranslationLayout(workflow)) {`n    return true;`n  }"; Accept=$false },
  @{ Name='source-result-fallback'; Newline="`n"; File='AiService.ets';
    Old="  return resultRowValue(rows, 'feature_runtime_result_translated_text');";
    New="  return resultRowValue(rows, 'feature_runtime_result_text');"; Accept=$false }
)

$failures = @()
foreach ($fixture in $fixtures) {
  $failure = Invoke-GuardFixture $fixture
  if ($failure) { $failures += $failure }
}

if ($failures.Count -gt 0) {
  throw "Text translation layout guard fixture failed: $($failures -join '; ')"
}
Write-Output 'Text translation layout guard fixtures passed.'
