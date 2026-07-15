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

function Normalize-Newlines([string]$Text) {
  return $Text.Replace("`r`n", "`n").Replace("`r", "`n")
}

function Copy-GuardedSources([string]$Destination) {
  foreach ($relativePath in @(
    'entry\src\main\ets\features\runtime\FeatureWorkflowCatalog.ets',
    'entry\src\main\ets\pages\FeatureRuntimePage.ets',
    'scripts\build-hap.ps1'
  )) {
    $target = Join-Path $Destination $relativePath
    [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($target)) | Out-Null
    [IO.File]::Copy((Join-Path $sourceRoot $relativePath), $target, $true)
  }
}

function Replace-Once([string]$Path, [string]$Before, [string]$After) {
  $text = Normalize-Newlines ([IO.File]::ReadAllText($Path))
  $Before = Normalize-Newlines $Before
  $After = Normalize-Newlines $After
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

function Replace-OnceInSection(
  [string]$Path,
  [string]$StartMarker,
  [string]$EndMarker,
  [string]$Before,
  [string]$After
) {
  $text = Normalize-Newlines ([IO.File]::ReadAllText($Path))
  $StartMarker = Normalize-Newlines $StartMarker
  $EndMarker = Normalize-Newlines $EndMarker
  $Before = Normalize-Newlines $Before
  $After = Normalize-Newlines $After
  $start = $text.IndexOf($StartMarker, [StringComparison]::Ordinal)
  $end = if ($start -ge 0) { $text.IndexOf($EndMarker, $start + $StartMarker.Length, [StringComparison]::Ordinal) } else { -1 }
  if ($start -lt 0 -or $end -le $start) {
    throw "Style Transfer guard fixture could not bound mutation section: $StartMarker"
  }
  $section = $text.Substring($start, $end - $start)
  $relative = $section.IndexOf($Before, [StringComparison]::Ordinal)
  if ($relative -lt 0 -or $section.IndexOf($Before, $relative + $Before.Length, [StringComparison]::Ordinal) -ge 0) {
    throw "Style Transfer guard fixture expected one section mutation target: $Before"
  }
  $absolute = $start + $relative
  [IO.File]::WriteAllText(
    $Path,
    $text.Substring(0, $absolute) + $After + $text.Substring($absolute + $Before.Length),
    $utf8
  )
}

function Replace-NthInSection(
  [string]$Path,
  [string]$StartMarker,
  [string]$EndMarker,
  [string]$Before,
  [string]$After,
  [int]$Occurrence
) {
  $text = Normalize-Newlines ([IO.File]::ReadAllText($Path))
  $StartMarker = Normalize-Newlines $StartMarker
  $EndMarker = Normalize-Newlines $EndMarker
  $Before = Normalize-Newlines $Before
  $After = Normalize-Newlines $After
  $start = $text.IndexOf($StartMarker, [StringComparison]::Ordinal)
  $end = if ($start -ge 0) { $text.IndexOf($EndMarker, $start + $StartMarker.Length, [StringComparison]::Ordinal) } else { -1 }
  if ($start -lt 0 -or $end -le $start -or $Occurrence -lt 1) {
    throw "Style Transfer guard fixture could not bound mutation section: $StartMarker"
  }
  $section = $text.Substring($start, $end - $start)
  $relative = -1
  $searchAt = 0
  for ($index = 1; $index -le $Occurrence; $index++) {
    $relative = $section.IndexOf($Before, $searchAt, [StringComparison]::Ordinal)
    if ($relative -lt 0) { throw "Style Transfer guard fixture could not find occurrence $Occurrence of: $Before" }
    $searchAt = $relative + $Before.Length
  }
  $absolute = $start + $relative
  [IO.File]::WriteAllText(
    $Path,
    $text.Substring(0, $absolute) + $After + $text.Substring($absolute + $Before.Length),
    $utf8
  )
}

function Assert-GuardFails([string]$Root, [string]$Description) {
  $failed = $false
  try { & $guardPath -SourceRoot $Root | Out-Null } catch { $failed = $true }
  if (-not $failed) { throw "Style Transfer guard fixture accepted mutation: $Description" }
}

function New-MutationRoot([string]$Name) {
  $root = Join-Path $tempRoot $Name
  Copy-GuardedSources $root
  return $root
}

function Assert-PageSectionMutationFails(
  [string]$Name,
  [string]$StartMarker,
  [string]$EndMarker,
  [string]$Before,
  [string]$After,
  [string]$Description
) {
  $root = New-MutationRoot $Name
  Replace-OnceInSection `
    (Join-Path $root 'entry\src\main\ets\pages\FeatureRuntimePage.ets') `
    $StartMarker $EndMarker $Before $After
  Assert-GuardFails $root $Description
}

function Assert-PageSectionDesiredMutationFails(
  [string]$Name,
  [string]$StartMarker,
  [string]$EndMarker,
  [string]$Desired,
  [string]$CurrentMarker,
  [string]$Replacement,
  [string]$Description
) {
  $root = New-MutationRoot $Name
  $path = Join-Path $root 'entry\src\main\ets\pages\FeatureRuntimePage.ets'
  $text = Normalize-Newlines ([IO.File]::ReadAllText($path))
  $StartMarker = Normalize-Newlines $StartMarker
  $EndMarker = Normalize-Newlines $EndMarker
  $Desired = Normalize-Newlines $Desired
  $CurrentMarker = Normalize-Newlines $CurrentMarker
  $start = $text.IndexOf($StartMarker, [StringComparison]::Ordinal)
  $end = if ($start -ge 0) { $text.IndexOf($EndMarker, $start + $StartMarker.Length, [StringComparison]::Ordinal) } else { -1 }
  if ($start -lt 0 -or $end -le $start) {
    throw "Style Transfer guard fixture could not bound desired mutation section: $StartMarker"
  }
  $section = $text.Substring($start, $end - $start)
  if ($section.Contains($Desired)) {
    Replace-OnceInSection $path $StartMarker $EndMarker $Desired $Replacement
  } elseif (-not $section.Contains($CurrentMarker)) {
    throw "Style Transfer guard fixture found neither desired nor current marker: $Description"
  }
  Assert-GuardFails $root $Description
}

try {
  $validRoot = Join-Path $tempRoot 'valid'
  Copy-GuardedSources $validRoot
  & $guardPath -SourceRoot $validRoot | Out-Null

  $selectorRoot = Join-Path $tempRoot 'wrong-selector'
  Copy-GuardedSources $selectorRoot
  Replace-Once `
    (Join-Path $selectorRoot 'entry\src\main\ets\features\runtime\FeatureWorkflowCatalog.ets') `
    'return workflow?.routeName === AppRoute.STYLE_TRANSFER.name;' `
    'return workflow?.routeName === AppRoute.OBJECT_PHOTO.name;'
  Assert-GuardFails $selectorRoot 'selector targets a sibling route'

  $builderRoot = Join-Path $tempRoot 'quoted-builder-decoy'
  Copy-GuardedSources $builderRoot
  Replace-Once `
    (Join-Path $builderRoot 'entry\src\main\ets\pages\FeatureRuntimePage.ets') `
    '      this.styleTransferAndroidLayout()' `
    "      const builderDecoy = 'this.styleTransferAndroidLayout()';"
  Assert-GuardFails $builderRoot 'builder selection exists only in a quoted decoy'

  $quotedSelectorRoot = New-MutationRoot 'quoted-route-selector'
  Replace-Once `
    (Join-Path $quotedSelectorRoot 'entry\src\main\ets\features\runtime\FeatureWorkflowCatalog.ets') `
    'return workflow?.routeName === AppRoute.STYLE_TRANSFER.name;' `
    "const selectorDecoy = 'return workflow?.routeName === AppRoute.STYLE_TRANSFER.name;'; return false;"
  Assert-GuardFails $quotedSelectorRoot 'route selector exists only in a quoted decoy'

  $wrongBuildRoot = New-MutationRoot 'wrong-build-selector'
  Replace-Once `
    (Join-Path $wrongBuildRoot 'entry\src\main\ets\pages\FeatureRuntimePage.ets') `
    '} else if (usesAndroidStyleTransferLayout(workflowForRoute(this.routeName))) {' `
    '} else if (usesAndroidObjectPhotoLayout(workflowForRoute(this.routeName))) {'
  Assert-GuardFails $wrongBuildRoot 'build selector targets a sibling route'

  $templateBuildRoot = New-MutationRoot 'template-builder-decoy'
  Replace-Once `
    (Join-Path $templateBuildRoot 'entry\src\main\ets\pages\FeatureRuntimePage.ets') `
    '      this.styleTransferAndroidLayout()' `
    '      const builderDecoy = `this.styleTransferAndroidLayout()`;'
  Assert-GuardFails $templateBuildRoot 'builder selection exists only in template raw text'

  $commentBuildRoot = New-MutationRoot 'comment-builder-decoy'
  Replace-Once `
    (Join-Path $commentBuildRoot 'entry\src\main\ets\pages\FeatureRuntimePage.ets') `
    '      this.styleTransferAndroidLayout()' `
    '      // this.styleTransferAndroidLayout()'
  Assert-GuardFails $commentBuildRoot 'builder selection exists only in a comment'

  $swappedBuilderRoot = New-MutationRoot 'swapped-style-custom-builders'
  Replace-Once `
    (Join-Path $swappedBuilderRoot 'entry\src\main\ets\pages\FeatureRuntimePage.ets') `
    "} else if (usesAndroidStyleTransferLayout(workflowForRoute(this.routeName))) {`n      this.styleTransferAndroidLayout()`n    } else if (usesAndroidCustomModelLayout(workflowForRoute(this.routeName))) {`n      this.customModelAndroidLayout()" `
    "} else if (usesAndroidStyleTransferLayout(workflowForRoute(this.routeName))) {`n      this.customModelAndroidLayout()`n    } else if (usesAndroidCustomModelLayout(workflowForRoute(this.routeName))) {`n      this.styleTransferAndroidLayout()"
  Assert-GuardFails $swappedBuilderRoot 'Style and Custom selectors render each other builder'

  Assert-PageSectionMutationFails 'missing-toolbar' `
    '  styleTransferAndroidLayout() {' '  stillSegmentationAndroidLayout() {' `
    'this.runtimeActionToolbar(true)' "const toolbarDecoy = 'this.runtimeActionToolbar(true)';" `
    'toolbar exists only as a literal decoy'
  Assert-PageSectionMutationFails 'missing-preview-height' `
    '  styleTransferAndroidLayout() {' '  stillSegmentationAndroidLayout() {' `
    '.height(265)' "const previewDecoy = '.height(265)';" `
    'fixed Android preview height exists only as a literal decoy'

  Assert-PageSectionDesiredMutationFails 'empty-preview-wrong-icon' `
    '  styleTransferAndroidLayout() {' '  stillSegmentationAndroidLayout() {' `
    "Image(`$r('app.media.icon_style'))" "Image(`$r('app.media.icon_default'))" `
    "Image(`$r('app.media.icon_default'))" `
    'empty preview does not use Android icon_style'
  Assert-PageSectionDesiredMutationFails 'empty-preview-wrong-font-size' `
    '  styleTransferAndroidLayout() {' '  stillSegmentationAndroidLayout() {' `
    "Text(appString('feature_runtime_style_choose_image'))`n                .fontSize(16)" `
    "Text(appString('feature_runtime_style_choose_image'))`n                .fontSize(14)" `
    "Text(appString('feature_runtime_style_choose_image'))`n                .fontSize(15)" `
    'empty preview prompt does not use Android 16sp text'

  Assert-PageSectionDesiredMutationFails 'style-title-wrong-font-size' `
    '  styleTransferStyleGrid() {' '  styleTransferStyleItem(' `
    "Text(appString('feature_runtime_style_presets_title'))`n        .fontSize(17)" `
    "Text(appString('feature_runtime_style_presets_title'))`n        .fontSize(14)" `
    "Text(appString('feature_runtime_style_presets_title'))`n        .fontSize(16)" `
    'Choose Style title does not use Android 17sp text'
  Assert-PageSectionDesiredMutationFails 'style-container-wrong-margin' `
    '  styleTransferStyleGrid() {' '  styleTransferStyleItem(' `
    '.margin({ left: 20, right: 20, top: 30 })' '.margin({ left: 20, right: 20, top: 10 })' `
    '.margin({ left: 20, right: 20, top: 29 })' `
    'style container does not use Android 20/20/30 margins'
  Assert-PageSectionDesiredMutationFails 'style-grid-wrong-top-margin' `
    '  styleTransferStyleGrid() {' '  styleTransferStyleItem(' `
    '.margin({ top: 20, bottom: 20 })' '.margin({ top: AppSpacing.sm })' `
    '.margin({ top: 19, bottom: 20 })' `
    'style RecyclerView does not keep Android 20vp top margin'
  Assert-PageSectionDesiredMutationFails 'style-grid-wrong-bottom-margin' `
    '  styleTransferStyleGrid() {' '  styleTransferStyleItem(' `
    '.margin({ top: 20, bottom: 20 })' '.margin({ top: AppSpacing.sm })' `
    '.margin({ top: 20, bottom: 19 })' `
    'style RecyclerView does not keep Android 20vp bottom margin'

  $previewWidthRoot = New-MutationRoot 'second-preview-width-not-256'
  Replace-NthInSection `
    (Join-Path $previewWidthRoot 'entry\src\main\ets\pages\FeatureRuntimePage.ets') `
    '  styleTransferAndroidLayout() {' '  stillSegmentationAndroidLayout() {' `
    '.width(256)' '.width(255)' 2
  Assert-GuardFails $previewWidthRoot 'original preview is not exactly 256vp wide'

  $previewHeightRoot = New-MutationRoot 'second-preview-height-not-256'
  Replace-NthInSection `
    (Join-Path $previewHeightRoot 'entry\src\main\ets\pages\FeatureRuntimePage.ets') `
    '  styleTransferAndroidLayout() {' '  stillSegmentationAndroidLayout() {' `
    '.height(256)' '.height(255)' 2
  Assert-GuardFails $previewHeightRoot 'original preview is not exactly 256vp high'
  Assert-PageSectionMutationFails 'missing-album-action' `
    '  styleTransferAndroidLayout() {' '  stillSegmentationAndroidLayout() {' `
    "Button(appString('feature_runtime_style_album'), { type: ButtonType.Normal })" `
    "const albumDecoy = `"Button(appString('feature_runtime_style_album'), { type: ButtonType.Normal })`";" `
    'Album action exists only as a literal decoy'
  Assert-PageSectionMutationFails 'missing-grid-columns' `
    '  styleTransferStyleGrid() {' '  styleTransferStyleItem(' `
    ".columnsTemplate('1fr 1fr 1fr 1fr')" "const gridDecoy = `".columnsTemplate('1fr 1fr 1fr 1fr')`";" `
    'four-column grid exists only as a literal decoy'
  Assert-PageSectionMutationFails 'missing-permission-overlay' `
    '  styleTransferAndroidLayout() {' '  stillSegmentationAndroidLayout() {' `
    'this.runtimePermissionRecoveryOverlay()' "const overlayDecoy = 'this.runtimePermissionRecoveryOverlay()';" `
    'permission overlay exists only as a literal decoy'

  $recoveryEnabledRoot = New-MutationRoot 'recovery-enabled-while-running'
  Replace-Once `
    (Join-Path $recoveryEnabledRoot 'entry\src\main\ets\pages\FeatureRuntimePage.ets') `
    ".enabled(!this.workflowRunning)`n            .onClick(() => this.recoverStyleOriginalPreview())" `
    ".enabled(true)`n            .onClick(() => this.recoverStyleOriginalPreview())"
  Assert-GuardFails $recoveryEnabledRoot 'Recovery is not rendered disabled while running'

  $saveEnabledRoot = New-MutationRoot 'save-enabled-while-running'
  Replace-Once `
    (Join-Path $saveEnabledRoot 'entry\src\main\ets\pages\FeatureRuntimePage.ets') `
    ".enabled(!this.workflowRunning)`n              .onClick((_event: ClickEvent, result: SaveButtonOnClickResult) => {" `
    ".enabled(true)`n              .onClick((_event: ClickEvent, result: SaveButtonOnClickResult) => {"
  Assert-GuardFails $saveEnabledRoot 'secure Save is not rendered disabled while running'

  $saveEntryRoot = New-MutationRoot 'secure-save-entry-unguarded'
  $saveEntryPage = Join-Path $saveEntryRoot 'entry\src\main\ets\pages\FeatureRuntimePage.ets'
  $saveEntryText = Normalize-Newlines ([IO.File]::ReadAllText($saveEntryPage))
  $saveEntryGuard = "                if (this.workflowRunning) {`n                  return;`n                }`n"
  if ($saveEntryText.Contains($saveEntryGuard)) {
    Replace-Once $saveEntryPage $saveEntryGuard ''
  } elseif (-not $saveEntryText.Contains(
      '              .onClick((_event: ClickEvent, result: SaveButtonOnClickResult) => {'
    )) {
    throw 'Style Transfer guard fixture could not find the secure Save handler entry.'
  }
  Assert-GuardFails $saveEntryRoot 'secure Save handler entry no longer rejects while running'

  $saveEntryDecoyRoot = New-MutationRoot 'secure-save-entry-quoted-guard'
  $saveEntryDecoyPage = Join-Path $saveEntryDecoyRoot 'entry\src\main\ets\pages\FeatureRuntimePage.ets'
  $saveEntryDecoyText = Normalize-Newlines ([IO.File]::ReadAllText($saveEntryDecoyPage))
  if ($saveEntryDecoyText.Contains($saveEntryGuard)) {
    Replace-Once $saveEntryDecoyPage $saveEntryGuard `
      "                const runningGuardDecoy = 'if (this.workflowRunning) { return; }';`n"
  } else {
    Replace-Once $saveEntryDecoyPage `
      '              .onClick((_event: ClickEvent, result: SaveButtonOnClickResult) => {' `
      "              .onClick((_event: ClickEvent, result: SaveButtonOnClickResult) => {`n                const runningGuardDecoy = 'if (this.workflowRunning) { return; }';"
  }
  Assert-GuardFails $saveEntryDecoyRoot 'secure Save running guard exists only in a quoted decoy'

  Assert-PageSectionMutationFails 'recovery-handler-unguarded' `
    '  private recoverStyleOriginalPreview()' '  private selectPortraitBackgroundPreset' `
    'if (this.workflowRunning) {' 'if (false) {' `
    'Recovery handler no longer rejects while running'

  $saveGuardRoot = New-MutationRoot 'save-handler-unguarded'
  Replace-NthInSection `
    (Join-Path $saveGuardRoot 'entry\src\main\ets\pages\FeatureRuntimePage.ets') `
    '  private saveStyleTransferResultImage()' '  private saveStillSegmentationResultImage' `
    'if (this.workflowRunning) {' 'if (false) {' 1
  Assert-GuardFails $saveGuardRoot 'Save click wrapper no longer rejects while running'

  Assert-PageSectionMutationFails 'denied-save-no-toast' `
    '  styleTransferAndroidLayout() {' '  stillSegmentationAndroidLayout() {' `
    'this.showRuntimeToast(this.statusKey);' "const deniedToastDecoy = 'this.showRuntimeToast(this.statusKey);';" `
    'denied secure Save no longer shows immediate failure Toast'
  Assert-PageSectionMutationFails 'save-toast-leaks-to-segmentation' `
    '  private saveResultPixelMap(' '  private saveStyleTransferResultImage()' `
    "this.statusKey = 'feature_runtime_save_image_failed';" `
    "this.statusKey = 'feature_runtime_save_image_failed'; this.showRuntimeToast(this.statusKey);" `
    'Style Transfer Toast leaks into shared segmentation save path'

  Assert-PageSectionMutationFails 'cache-feedback-before-stale-gate' `
    '  private async cacheAndApplyPickedModelFile(' '  private applyModelFileCacheResult' `
    'if (!isInputPreparationRequestCurrent(requestId, this.inputPreparationRequestId)) {' `
    "this.showStyleTransferModelCacheToastIfNeeded(inputKind, cacheResult!.messageKey); this.resetStyleTransferPageAfterModelCacheSuccess(); if (!isInputPreparationRequestCurrent(requestId, this.inputPreparationRequestId)) {" `
    'cache Toast/reset moved before the stale request gate'
  Assert-PageSectionMutationFails 'duplicate-cache-apply-before-stale-gate' `
    '  private async cacheAndApplyPickedModelFile(' '  private applyModelFileCacheResult' `
    'if (!isInputPreparationRequestCurrent(requestId, this.inputPreparationRequestId)) {' `
    "this.applyModelFileCacheResult(cacheResult, inputKind);`n    if (!isInputPreparationRequestCurrent(requestId, this.inputPreparationRequestId)) {" `
    'cache result is applied once before and once after the stale gate'
  Assert-PageSectionMutationFails 'cache-failure-clears-page' `
    '  private applyModelFileCacheResult(' '  private showCustomModelCacheToastIfNeeded' `
    'if (!shouldPreserveRuntimeResultAfterInputReady(workflow, inputKind)) {' `
    'if (usesAndroidStyleTransferLayout(workflow) || !shouldPreserveRuntimeResultAfterInputReady(workflow, inputKind)) {' `
    'failed Style Transfer model cache clears the current page'

  Assert-PageSectionMutationFails 'result-failure-toast-removed' `
    '  private async applyAiResult(' '  private showObjectPhotoFailureToastIfNeeded' `
    'this.showStyleTransferFailureToastIfNeeded(result.ok);' `
    "const resultToastDecoy = 'this.showStyleTransferFailureToastIfNeeded(result.ok);';" `
    'failed AI result no longer reaches Style Transfer Toast'
  Assert-PageSectionMutationFails 'throw-failure-toast-removed' `
    '  private applyRuntimeFailure()' '  private async prepareLiveFrameImageInput' `
    'this.showStyleTransferFailureToastIfNeeded(false);' `
    "const throwToastDecoy = 'this.showStyleTransferFailureToastIfNeeded(false);';" `
    'thrown run no longer reaches Style Transfer Toast'
  Assert-PageSectionMutationFails 'permission-failure-clears-visuals' `
    '  private async runWorkflowAsync(' '  private applyRuntimeFailure' `
    "if (!shouldPreserveRuntimeVisualResultOnAiResult(workflow, false, '')) {" `
    'if (usesAndroidStyleTransferLayout(workflow)) {' `
    'permission failure clears Style Transfer visuals'
  Assert-PageSectionMutationFails 'conversion-not-awaited' `
    '  private async runWorkflowAsync(' '  private applyRuntimeFailure' `
    'await this.applyAiResult(result, runtimeRequestId);' `
    'this.applyAiResult(result, runtimeRequestId);' `
    'workflowRunning can settle before styled PixelMap conversion'

  Assert-PageSectionMutationFails 'picked-input-keeps-stale-owner' `
    '  private applyPickResult(' '  private aiRunInputs' `
    'this.styledImagePixelMapOwner.invalidatePendingReplacement();' `
    "const pickOwnerDecoy = 'this.styledImagePixelMapOwner.invalidatePendingReplacement();';" `
    'accepted content/camera/style pick omits pending-owner invalidation'
  Assert-PageSectionMutationFails 'camera-does-not-replace-content' `
    '  private applyPickResult(' '  private aiRunInputs' `
    "} else if (inputKind === 'camera' && usesAndroidStyleTransferLayout(workflow)) {" `
    '} else if (false) {' `
    'accepted camera input does not replace the effective content image'
  Assert-PageSectionMutationFails 'built-in-style-keeps-stale-owner' `
    '  private selectBuiltInStyle(' '  private shouldRunStyleTransferAfterStyleReady' `
    'this.styledImagePixelMapOwner.invalidatePendingReplacement();' `
    "const builtInOwnerDecoy = 'this.styledImagePixelMapOwner.invalidatePendingReplacement();';" `
    'built-in style selection omits pending-owner invalidation'
  Assert-PageSectionDesiredMutationFails 'custom-style-missing-original-toast' `
    '  private applyPickResult(' '  private aiRunInputs' `
    'this.showStyleTransferStyleSelectionToastIfNeeded(inputKind);' `
    'this.statusKey = workflow ?' '' `
    'custom style selection omits the no-content Toast helper call'
  Assert-PageSectionDesiredMutationFails 'custom-style-quoted-original-toast' `
    '  private applyPickResult(' '  private aiRunInputs' `
    'this.showStyleTransferStyleSelectionToastIfNeeded(inputKind);' `
    'this.statusKey = workflow ?' `
    "const customStyleToastDecoy = 'this.showStyleTransferStyleSelectionToastIfNeeded(inputKind);';" `
    'custom style selection Toast helper exists only in a quoted decoy'
  Assert-PageSectionDesiredMutationFails 'built-in-style-missing-original-toast' `
    '  private selectBuiltInStyle(' '  private shouldRunStyleTransferAfterStyleReady' `
    "this.showStyleTransferStyleSelectionToastIfNeeded('styleImage');" `
    'this.statusKey = workflow ?' '' `
    'built-in style selection omits the no-content Toast helper call'
  Assert-PageSectionDesiredMutationFails 'built-in-style-quoted-original-toast' `
    '  private selectBuiltInStyle(' '  private shouldRunStyleTransferAfterStyleReady' `
    "this.showStyleTransferStyleSelectionToastIfNeeded('styleImage');" `
    'this.statusKey = workflow ?' `
    'const builtInStyleToastDecoy = "this.showStyleTransferStyleSelectionToastIfNeeded(''styleImage'');";' `
    'built-in style selection Toast helper exists only in a quoted decoy'
  Assert-PageSectionMutationFails 'success-clears-old-owner' `
    '  private async updateStyledImagePreview(' '  private openHelpPage' `
    'const requestId = this.styledImagePixelMapOwner.beginReplacement();' `
    'this.styledImagePixelMapOwner.clear(); const requestId = this.styledImagePixelMapOwner.beginReplacement();' `
    'successful Style Transfer result clears the old owner before replacement'

  $rejectClearRoot = New-MutationRoot 'conversion-reject-clears-owner'
  Replace-NthInSection `
    (Join-Path $rejectClearRoot 'entry\src\main\ets\pages\FeatureRuntimePage.ets') `
    '  private async updateStyledImagePreview(' '  private openHelpPage' `
    'this.styledImagePixelMapOwner.invalidatePendingReplacement();' `
    'this.styledImagePixelMapOwner.clear();' 3
  Assert-GuardFails $rejectClearRoot 'current conversion rejection clears the previous owner'

  $rejectToastRoot = New-MutationRoot 'conversion-reject-omits-toast'
  Replace-NthInSection `
    (Join-Path $rejectToastRoot 'entry\src\main\ets\pages\FeatureRuntimePage.ets') `
    '  private async updateStyledImagePreview(' '  private openHelpPage' `
    'this.showStyleTransferFailureToastIfNeeded(false);' `
    "const rejectToastDecoy = 'this.showStyleTransferFailureToastIfNeeded(false);';" 2
  Assert-GuardFails $rejectToastRoot 'current conversion rejection omits failure Toast'

  $rejectStatusRoot = New-MutationRoot 'conversion-reject-omits-failure-status'
  Replace-NthInSection `
    (Join-Path $rejectStatusRoot 'entry\src\main\ets\pages\FeatureRuntimePage.ets') `
    '  private async updateStyledImagePreview(' '  private openHelpPage' `
    "this.statusKey = 'feature_runtime_style_transfer_failed';" `
    "const rejectStatusDecoy = `"this.statusKey = 'feature_runtime_style_transfer_failed';`";" 2
  Assert-GuardFails $rejectStatusRoot 'current conversion rejection omits failure status'

  $staleToastRoot = New-MutationRoot 'stale-conversion-shows-feedback'
  Replace-NthInSection `
    (Join-Path $staleToastRoot 'entry\src\main\ets\pages\FeatureRuntimePage.ets') `
    '  private async updateStyledImagePreview(' '  private openHelpPage' `
    'this.styledImagePixelMapOwner.accept(requestId, pixelMap);' `
    'this.showStyleTransferFailureToastIfNeeded(false); this.styledImagePixelMapOwner.accept(requestId, pixelMap);' 1
  Assert-GuardFails $staleToastRoot 'stale conversion emits user feedback'

  $genericMutations = @(
    @{ Name = 'generic-inputs'; Code = "Text(appString('feature_runtime_inputs_title'))" },
    @{ Name = 'generic-permissions'; Code = "Text(appString('feature_runtime_permissions_title'))" },
    @{ Name = 'generic-status'; Code = 'Text(appString(this.statusKey))' },
    @{ Name = 'generic-result'; Code = 'this.resultRow(this.resultRows[0])' },
    @{ Name = 'generic-debug'; Code = "Text(appString('feature_runtime_debug'))" },
    @{ Name = 'generic-file-preview'; Code = "this.filePreview('feature_runtime_preview_model', this.modelInputUri)" },
    @{ Name = 'generic-styled-result'; Code = "this.pixelMapPreview('feature_runtime_result_styled_image', this.styledImagePixelMap!)" },
    @{ Name = 'generic-run'; Code = 'this.runPrimaryAction()' }
  )
  foreach ($mutation in $genericMutations) {
    Assert-PageSectionMutationFails $mutation.Name `
      '  styleTransferAndroidLayout() {' '  stillSegmentationAndroidLayout() {' `
      '  styleTransferAndroidLayout() {' `
      ("  styleTransferAndroidLayout() {`r`n    " + $mutation.Code) `
      ("executable generic UI injected: " + $mutation.Name)
  }
} finally {
  if ([IO.Directory]::Exists($tempRoot)) {
    $resolved = [IO.Path]::GetFullPath($tempRoot)
    if (-not $resolved.StartsWith($tempPrefix, [StringComparison]::OrdinalIgnoreCase)) {
      throw 'Style Transfer guard fixture refused unsafe cleanup.'
    }
    [IO.Directory]::Delete($resolved, $true)
  }
}

Write-Output 'Style Transfer layout parity guard fixture passed.'
