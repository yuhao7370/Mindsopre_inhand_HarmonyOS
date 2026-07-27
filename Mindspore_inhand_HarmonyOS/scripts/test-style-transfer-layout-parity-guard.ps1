$ErrorActionPreference = 'Stop'

$sourceRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$guardPath = Join-Path $PSScriptRoot 'check-style-transfer-layout-parity.ps1'
$tempParent = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd(
  [IO.Path]::DirectorySeparatorChar,
  [IO.Path]::AltDirectorySeparatorChar
)
$tempRoot = [IO.Path]::GetFullPath((Join-Path $tempParent ("mindspore-style-transfer-guard-" + [guid]::NewGuid().ToString('N'))))
$tempPrefix = $tempParent + [IO.Path]::DirectorySeparatorChar
$utf8 = [Text.UTF8Encoding]::new($false)
if (-not $tempRoot.StartsWith($tempPrefix, [StringComparison]::OrdinalIgnoreCase)) {
  throw 'Style Transfer guard fixture refused an unsafe temporary path.'
}

$guardedPaths = @(
  'entry\src\main\ets\features\runtime\FeatureWorkflowCatalog.ets',
  'entry\src\main\ets\pages\FeatureRuntimePage.ets',
  'scripts\build-hap.ps1'
)

function Copy-GuardedSources([string]$Destination, [bool]$CrLf = $false) {
  foreach ($relativePath in $guardedPaths) {
    $target = Join-Path $Destination $relativePath
    [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($target)) | Out-Null
    $text = [IO.File]::ReadAllText((Join-Path $sourceRoot $relativePath))
    $text = $text.Replace("`r`n", "`n").Replace("`r", "`n")
    if ($CrLf) { $text = $text.Replace("`n", "`r`n") }
    [IO.File]::WriteAllText($target, $text, $utf8)
  }
}

function Replace-Once([string]$Path, [string]$Before, [string]$After) {
  $text = [IO.File]::ReadAllText($Path).Replace("`r`n", "`n").Replace("`r", "`n")
  $Before = $Before.Replace("`r`n", "`n").Replace("`r", "`n")
  $After = $After.Replace("`r`n", "`n").Replace("`r", "`n")
  $first = $text.IndexOf($Before, [StringComparison]::Ordinal)
  if ($first -lt 0 -or $text.IndexOf($Before, $first + $Before.Length, [StringComparison]::Ordinal) -ge 0) {
    throw "Style Transfer guard fixture expected one mutation target: $Before"
  }
  [IO.File]::WriteAllText(
    $Path,
    $text.Substring(0, $first) + $After + $text.Substring($first + $Before.Length),
    $utf8
  )
}

function New-Mutation([string]$Name) {
  $root = Join-Path $tempRoot $Name
  Copy-GuardedSources $root
  return $root
}

function Assert-GuardFails([string]$Root, [string]$Description) {
  $failed = $false
  try { & $guardPath -SourceRoot $Root | Out-Null } catch { $failed = $true }
  if (-not $failed) { throw "Style Transfer guard fixture accepted mutation: $Description" }
}

function Mutate-Page([string]$Name, [string]$Before, [string]$After, [string]$Description) {
  $root = New-Mutation $Name
  Replace-Once (Join-Path $root 'entry\src\main\ets\pages\FeatureRuntimePage.ets') $Before $After
  Assert-GuardFails $root $Description
}

function Mutate-Catalog([string]$Name, [string]$Before, [string]$After, [string]$Description) {
  $root = New-Mutation $Name
  Replace-Once (Join-Path $root 'entry\src\main\ets\features\runtime\FeatureWorkflowCatalog.ets') $Before $After
  Assert-GuardFails $root $Description
}

try {
  foreach ($case in @(@('valid-lf', $false), @('valid-crlf', $true))) {
    $root = Join-Path $tempRoot $case[0]
    Copy-GuardedSources $root $case[1]
    & $guardPath -SourceRoot $root | Out-Null
  }

  Mutate-Page 'missing-page-scroll' `
    "  styleTransferAndroidLayout() {`n    Column() {`n      this.runtimeActionToolbar(true)`n      Scroll() {" `
    "  styleTransferAndroidLayout() {`n    Column() {`n      this.runtimeActionToolbar(true)`n      Column() {" `
    'page-level Scroll removed'
  Mutate-Page 'legacy-preview-height' `
    "          .aspectRatio(4 / 3)`n          .constraintSize({ minHeight: 220, maxHeight: 420 })`n          .backgroundColor(AppColor.cardBackground)`n          .border({ width: 1, color: AppColor.divider, radius: AppRadius.card })`n          .margin({ top: AppSpacing.md })`n`n          Button(appString(this.statusKey === 'feature_runtime_style_transfer_failed'" `
    "          .height(265)`n          .backgroundColor(AppColor.cardBackground)`n          .border({ width: 1, color: AppColor.divider, radius: AppRadius.card })`n          .margin({ top: AppSpacing.md })`n`n          Button(appString(this.statusKey === 'feature_runtime_style_transfer_failed'" `
    'legacy fixed preview restored'
  Mutate-Page 'short-primary-action' `
    "          Button(appString(this.statusKey === 'feature_runtime_style_transfer_failed' ||`n            this.statusKey === 'feature_runtime_run_failed' ? 'web_retry' : this.runActionKey))`n            .width('100%')`n            .constraintSize({ minHeight: 48 })`n            .fontSize(16)" `
    "          Button(appString(this.statusKey === 'feature_runtime_style_transfer_failed' ||`n            this.statusKey === 'feature_runtime_run_failed' ? 'web_retry' : this.runActionKey))`n            .width('100%')`n            .constraintSize({ minHeight: 37 })`n            .fontSize(16)" `
    'one action target falls below 48vp'
  Mutate-Page 'status-removed' `
    "                .margin({ right: AppSpacing.sm })`n            }`n            Text(appString(this.statusKey))`n              .fontSize(14)`n              .fontColor(AppColor.textSecondary)`n              .maxFontScale(3.2)`n              .maxLines(3)`n              .layoutWeight(1)`n          }`n          .width('100%')`n          .constraintSize({ minHeight: 56 })" `
    "                .margin({ right: AppSpacing.sm })`n            }`n            Text('status')`n              .fontSize(14)`n              .fontColor(AppColor.textSecondary)`n              .maxFontScale(3.2)`n              .maxLines(3)`n              .layoutWeight(1)`n          }`n          .width('100%')`n          .constraintSize({ minHeight: 56 })" `
    'visible status removed'
  Mutate-Page 'hidden-model-restored' `
    "          .width('100%')`n          .border({ width: 1, color: AppColor.divider, radius: AppRadius.button })`n          .margin({ top: AppSpacing.sm })`n`n          this.styleTransferStyleGrid()" `
    "          .width('100%')`n          .border({ width: 1, color: AppColor.divider, radius: AppRadius.button })`n          .margin({ top: AppSpacing.sm })`n`n          Button(appString(workflowInputLabelKey(workflowForRoute(this.routeName), 'styleTransferModelFile')))`n          this.styleTransferStyleGrid()" `
    'hidden model-file control restored'
  Mutate-Page 'four-column-grid' `
    "      .columnsTemplate('1fr 1fr 1fr')`n      .rowsTemplate('1fr 1fr 1fr 1fr 1fr 1fr 1fr')" `
    "      .columnsTemplate('1fr 1fr 1fr 1fr')`n      .rowsTemplate('1fr 1fr 1fr 1fr 1fr 1fr 1fr')" `
    'style cards become too narrow'
  Mutate-Page 'nested-grid-scrollbar' `
    "      .aspectRatio(3 / 7)`n      .scrollBar(BarState.Off)`n      .enableScrollInteraction(false)" `
    "      .aspectRatio(3 / 7)`n      .scrollBar(BarState.Auto)`n      .enableScrollInteraction(false)" `
    'nested style-grid scrollbar restored'
  Mutate-Page 'nested-grid-interaction' `
    "      .scrollBar(BarState.Off)`n      .enableScrollInteraction(false)" `
    "      .scrollBar(BarState.Off)`n      .enableScrollInteraction(true)" `
    'nested style-grid interaction restored'
  Mutate-Page 'raw-accessibility-name' `
    '      return `${title ?? ''Style''} ${style.id + 1}`;' `
    '      return style.rawfilePath;' `
    'built-in style accessibility helper exposes an internal path'
  Mutate-Page 'zero-based-accessibility-name' `
    '      return `Style ${style.id + 1}`;' `
    '      return `Style ${style.id}`;' `
    'built-in style fallback accessibility name becomes zero-based'
  Mutate-Page 'oversized-custom-label' `
    "        Text(appString('feature_runtime_style_custom'))`n          .fontSize(11)`n          .fontColor(AppColor.textSecondary)`n          .maxFontScale(1.6)" `
    "        Text(appString('feature_runtime_style_custom'))`n          .fontSize(11)`n          .fontColor(AppColor.textSecondary)`n          .maxFontScale(3.2)" `
    'custom style label can overflow its square card at large system font scale'
  Mutate-Page 'missing-built-in-badge' `
    "      if (this.styleImageUri === builtInStyleTransferUri(style)) {`n        SymbolGlyph(`$r('sys.symbol.checkmark'))" `
    "      if (this.styleImageUri === builtInStyleTransferUri(style)) {`n        Text('selected')" `
    'built-in selected marker removed'
  Mutate-Page 'missing-custom-badge' `
    "      if (isCustomStyleTransferUri(this.styleImageUri)) {`n        SymbolGlyph(`$r('sys.symbol.checkmark'))" `
    "      if (isCustomStyleTransferUri(this.styleImageUri)) {`n        Text('selected')" `
    'custom selected marker removed'

  Mutate-Catalog 'failure-clears-last-result' `
    "    return !resultOk || dataKind === 'styleTransfer';" `
    "    return dataKind === 'styleTransfer';" 'failure no longer preserves the last valid result'
  Mutate-Catalog 'running-input-enabled' `
    "  if (workflow?.routeName === AppRoute.STYLE_TRANSFER.name) {`n    return false;`n  }" `
    "  if (workflow?.routeName === AppRoute.STYLE_TRANSFER.name) {`n    return true;`n  }" `
    'Style Transfer inputs can change while running'

  Write-Output 'Style Transfer layout parity guard fixtures passed.'
}
finally {
  if (Test-Path -LiteralPath $tempRoot) {
    $resolved = [IO.Path]::GetFullPath($tempRoot)
    if (-not $resolved.StartsWith($tempPrefix, [StringComparison]::OrdinalIgnoreCase)) {
      throw 'Style Transfer guard fixture refused an unsafe cleanup path.'
    }
    Remove-Item -LiteralPath $resolved -Recurse -Force
  }
}
