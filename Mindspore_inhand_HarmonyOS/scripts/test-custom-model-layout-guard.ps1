$ErrorActionPreference = 'Stop'

$sourceRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$guard = Join-Path $PSScriptRoot 'check-custom-model-layout-parity.ps1'
$tempParent = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\', '/')
$tempRoot = Join-Path $tempParent ("mindspore-custom-model-guard-" + [guid]::NewGuid().ToString('N'))
$prefix = $tempParent + [IO.Path]::DirectorySeparatorChar
$utf8 = [Text.UTF8Encoding]::new($false)
if (-not $tempRoot.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) {
  throw 'Custom Model guard refused an unsafe temporary path.'
}

$paths = @(
  'entry\src\main\ets\common\data\FeatureCatalog.ets',
  'entry\src\main\ets\features\runtime\FeatureWorkflowCatalog.ets',
  'entry\src\main\ets\pages\FeatureRuntimePage.ets',
  'entry\src\main\ets\services\picker\ModelFileCacheService.ets',
  'scripts\build-hap.ps1'
)

function New-Fixture([string]$Name) {
  $root = Join-Path $tempRoot $Name
  foreach ($relative in $paths) {
    $target = Join-Path $root $relative
    [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($target)) | Out-Null
    [IO.File]::WriteAllText($target, [IO.File]::ReadAllText((Join-Path $sourceRoot $relative)), $utf8)
  }
  return $root
}

function Replace-Once([string]$Path, [string]$Before, [string]$After) {
  $text = [IO.File]::ReadAllText($Path).Replace("`r`n", "`n").Replace("`r", "`n")
  $beforeText = $Before.Replace("`r`n", "`n").Replace("`r", "`n")
  $first = $text.IndexOf($beforeText, [StringComparison]::Ordinal)
  if ($first -lt 0 -or $text.IndexOf($beforeText, $first + $beforeText.Length, [StringComparison]::Ordinal) -ge 0) {
    throw "Custom Model fixture expected one target: $Before"
  }
  [IO.File]::WriteAllText(
    $Path,
    $text.Substring(0, $first) + $After + $text.Substring($first + $beforeText.Length),
    $utf8
  )
}

function Assert-Rejected([string]$Name, [string]$RelativePath, [string]$Before, [string]$After) {
  $root = New-Fixture $Name
  Replace-Once (Join-Path $root $RelativePath) $Before $After
  $failed = $false
  try { & $guard -SourceRoot $root | Out-Null } catch { $failed = $true }
  if (-not $failed) { throw "Custom Model guard accepted mutation: $Name" }
}

try {
  $valid = New-Fixture 'valid'
  & $guard -SourceRoot $valid | Out-Null

  Assert-Rejected 'missing-scroll' 'entry\src\main\ets\pages\FeatureRuntimePage.ets' `
    "  customModelAndroidLayout() {`n    Column() {`n      this.runtimeActionToolbar(true)`n      Scroll() {" `
    "  customModelAndroidLayout() {`n    Column() {`n      this.runtimeActionToolbar(true)`n      Column() {`n        Text('Scroll() {')"
  Assert-Rejected 'fixed-preview' 'entry\src\main\ets\pages\FeatureRuntimePage.ets' `
    "          .aspectRatio(4 / 3)`n          .constraintSize({ minHeight: 220, maxHeight: 420 })`n          .backgroundColor(AppColor.cardBackground)`n          .border({ width: 1, color: AppColor.divider, radius: AppRadius.card })`n          .margin({ top: AppSpacing.md })`n`n          Button(appString(this.statusKey === 'feature_runtime_custom_model_failed'" `
    "          .height(265)`n          .backgroundColor(AppColor.cardBackground)`n          .border({ width: 1, color: AppColor.divider, radius: AppRadius.card })`n          .margin({ top: AppSpacing.md })`n          // .aspectRatio(4 / 3)`n`n          Button(appString(this.statusKey === 'feature_runtime_custom_model_failed'"
  Assert-Rejected 'public-entry' 'entry\src\main\ets\common\data\FeatureCatalog.ets' `
    "routeName: AppRoute.CUSTOM_MODEL.name, visibleByDefault: false" `
    "routeName: AppRoute.CUSTOM_MODEL.name, visibleByDefault: true"
  Assert-Rejected 'clear-on-start' 'entry\src\main\ets\features\runtime\FeatureWorkflowCatalog.ets' `
    "!usesAndroidCustomModelLayout(workflow) &&" `
    "usesAndroidCustomModelLayout(workflow) &&"
  Assert-Rejected 'short-primary-action' 'entry\src\main\ets\pages\FeatureRuntimePage.ets' `
    "          Button(appString(this.statusKey === 'feature_runtime_custom_model_failed' ||`n            this.statusKey === 'feature_runtime_run_failed' ? 'web_retry' :`n            'feature_runtime_custom_model_execute'), { type: ButtonType.Normal })`n            .width('100%')`n            .constraintSize({ minHeight: 48 })" `
    "          Button(appString(this.statusKey === 'feature_runtime_custom_model_failed' ||`n            this.statusKey === 'feature_runtime_run_failed' ? 'web_retry' :`n            'feature_runtime_custom_model_execute'), { type: ButtonType.Normal })`n            .width('100%')`n            .constraintSize({ minHeight: 37 })"
  Assert-Rejected 'font-scale-string-decoy' 'entry\src\main\ets\pages\FeatureRuntimePage.ets' `
    "            .constraintSize({ minHeight: 48 })`n            .fontSize(16)`n            .maxFontScale(3.2)`n            .fontWeight(FontWeight.Medium)`n            .fontColor(Color.White)`n            .backgroundColor(AppColor.accent)`n            .borderRadius(AppRadius.button)`n            .margin({ top: AppSpacing.sm })`n            .enabled(!this.workflowRunning)`n            .onClick(() => this.runCustomModelAndroidAction())" `
    "            .constraintSize({ minHeight: 48 })`n            .fontSize(16)`n            Text('.maxFontScale(3.2)')`n            .fontWeight(FontWeight.Medium)`n            .fontColor(Color.White)`n            .backgroundColor(AppColor.accent)`n            .borderRadius(AppRadius.button)`n            .margin({ top: AppSpacing.sm })`n            .enabled(!this.workflowRunning)`n            .onClick(() => this.runCustomModelAndroidAction())"
  Assert-Rejected 'running-input-enabled' 'entry\src\main\ets\pages\FeatureRuntimePage.ets' `
    "            .enabled(!this.workflowRunning)`n            .onClick(() => this.prepareInput('modelFile'))" `
    "            .enabled(true)`n            .onClick(() => this.prepareInput('modelFile'))"
  Assert-Rejected 'spinner-removed' 'entry\src\main\ets\pages\FeatureRuntimePage.ets' `
    "            .onClick(() => this.runCustomModelAndroidAction())`n`n          Row() {`n            if (this.workflowRunning) {`n              LoadingProgress()" `
    "            .onClick(() => this.runCustomModelAndroidAction())`n`n          Row() {`n            if (this.workflowRunning) {`n              Text('LoadingProgress()')"
  Assert-Rejected 'status-removed' 'entry\src\main\ets\pages\FeatureRuntimePage.ets' `
    "            Text(appString(this.statusKey))`n              .fontSize(14)`n              .fontColor(AppColor.textSecondary)`n              .maxFontScale(3.2)`n              .maxLines(3)`n              .layoutWeight(1)`n          }`n          .width('100%')`n          .constraintSize({ minHeight: 48 })" `
    "            Text('status')`n              .fontSize(14)`n              .fontColor(AppColor.textSecondary)`n              .maxFontScale(3.2)`n              .maxLines(3)`n              .layoutWeight(1)`n          }`n          .width('100%')`n          .constraintSize({ minHeight: 48 })"
  Assert-Rejected 'output-removed' 'entry\src\main\ets\pages\FeatureRuntimePage.ets' `
    '            Text(this.customModelOutputText())' `
    "            Text('output')"
  Assert-Rejected 'failure-preservation-removed' 'entry\src\main\ets\features\runtime\FeatureWorkflowCatalog.ets' `
    '(usesAndroidCustomModelLayout(workflow) && hasTextResult) ||' `
    "false || // '(usesAndroidCustomModelLayout(workflow) && hasTextResult) ||'"
  Assert-Rejected 'selector-string-decoy' 'entry\src\main\ets\pages\FeatureRuntimePage.ets' `
    '    } else if (usesAndroidCustomModelLayout(workflowForRoute(this.routeName))) {' `
    @'
    } else if (usesAndroidStyleTransferLayout(workflowForRoute(this.routeName))) {
      const selectorDecoy = `
    } else if (usesAndroidCustomModelLayout(workflowForRoute(this.routeName))) {
      `
      Text(selectorDecoy)
'@
  Assert-Rejected 'guard-unwired' 'scripts\build-hap.ps1' `
    "& (Join-Path `$PSScriptRoot 'check-custom-model-layout-parity.ps1')" `
    "# custom model guard removed"

  Write-Output 'Custom Model layout guard fixtures passed.'
}
finally {
  if (Test-Path -LiteralPath $tempRoot) {
    $resolved = [IO.Path]::GetFullPath($tempRoot)
    if (-not $resolved.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) {
      throw 'Custom Model guard refused unsafe cleanup.'
    }
    Remove-Item -LiteralPath $resolved -Recurse -Force
  }
}
