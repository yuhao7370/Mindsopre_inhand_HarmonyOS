$ErrorActionPreference = 'Stop'

$sourceRoot = Split-Path -Parent $PSScriptRoot
$guardPath = Join-Path $PSScriptRoot 'check-object-photo-layout-parity.ps1'
$tempParent = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$fixtureRoot = Join-Path $tempParent ("object-photo-layout-guard-" + [guid]::NewGuid().ToString('N'))
$utf8 = [Text.UTF8Encoding]::new($false)
$nl = "`n"

function Copy-GuardSources {
  $relativePaths = @(
    'entry\src\main\ets\features\runtime\FeatureWorkflowCatalog.ets',
    'entry\src\main\ets\pages\FeatureRuntimePage.ets',
    'entry\src\main\ets\services\ai\HarmonyObjectDetectionInputPreprocessor.ets',
    'scripts\build-hap.ps1'
  )
  foreach ($relativePath in $relativePaths) {
    $targetPath = Join-Path $fixtureRoot $relativePath
    [IO.Directory]::CreateDirectory((Split-Path -Parent $targetPath)) | Out-Null
    [IO.File]::Copy((Join-Path $sourceRoot $relativePath), $targetPath, $true)
  }
}

function Replace-Once([string]$RelativePath, [string]$OldText, [string]$NewText) {
  $path = Join-Path $fixtureRoot $RelativePath
  $text = [IO.File]::ReadAllText($path).Replace("`r`n", "`n").Replace("`r", "`n")
  $OldText = $OldText.Replace("`r`n", "`n").Replace("`r", "`n")
  $NewText = $NewText.Replace("`r`n", "`n").Replace("`r", "`n")
  $first = $text.IndexOf($OldText, [StringComparison]::Ordinal)
  $last = $text.LastIndexOf($OldText, [StringComparison]::Ordinal)
  if ($first -lt 0 -or $first -ne $last) {
    throw "Fixture mutation must match exactly once: $RelativePath"
  }
  [IO.File]::WriteAllText($path, $text.Substring(0, $first) + $NewText +
    $text.Substring($first + $OldText.Length), $utf8)
}

function Replace-OnceInSection(
  [string]$RelativePath,
  [string]$StartMarker,
  [string]$EndMarker,
  [string]$OldText,
  [string]$NewText
) {
  $path = Join-Path $fixtureRoot $RelativePath
  $text = [IO.File]::ReadAllText($path).Replace("`r`n", "`n").Replace("`r", "`n")
  $start = $text.IndexOf($StartMarker, [StringComparison]::Ordinal)
  $end = if ($start -ge 0) {
    $text.IndexOf($EndMarker, $start + $StartMarker.Length, [StringComparison]::Ordinal)
  } else {
    -1
  }
  if ($start -lt 0 -or $end -le $start) {
    throw "Fixture section was not found: $RelativePath / $StartMarker"
  }
  $OldText = $OldText.Replace("`r`n", "`n").Replace("`r", "`n")
  $NewText = $NewText.Replace("`r`n", "`n").Replace("`r", "`n")
  $section = $text.Substring($start, $end - $start)
  $relativeIndex = $section.IndexOf($OldText, [StringComparison]::Ordinal)
  if ($relativeIndex -lt 0 -or
    $section.IndexOf($OldText, $relativeIndex + $OldText.Length, [StringComparison]::Ordinal) -ge 0) {
    throw "Fixture section mutation must match exactly once: $RelativePath / $OldText"
  }
  $absoluteIndex = $start + $relativeIndex
  [IO.File]::WriteAllText(
    $path,
    $text.Substring(0, $absoluteIndex) + $NewText +
      $text.Substring($absoluteIndex + $OldText.Length),
    $utf8
  )
}

function Assert-GuardRejectsMutation(
  [string]$Name,
  [string]$RelativePath,
  [string]$OldText,
  [string]$NewText
) {
  Copy-GuardSources
  Replace-Once $RelativePath $OldText $NewText
  $rejected = $false
  try {
    & $guardPath -SourceRoot $fixtureRoot *> $null
  } catch {
    $rejected = $true
  }
  if (-not $rejected) {
    throw "Object Photo guard fixture failed: source mutation was accepted ($Name)."
  }
}

function Assert-GuardRejectsSectionMutation(
  [string]$Name,
  [string]$RelativePath,
  [string]$StartMarker,
  [string]$EndMarker,
  [string]$OldText,
  [string]$NewText
) {
  Copy-GuardSources
  Replace-OnceInSection $RelativePath $StartMarker $EndMarker $OldText $NewText
  $rejected = $false
  try {
    & $guardPath -SourceRoot $fixtureRoot *> $null
  } catch {
    $rejected = $true
  }
  if (-not $rejected) {
    throw "Object Photo guard fixture failed: source mutation was accepted ($Name)."
  }
}

function Assert-GuardAcceptsSectionMutation(
  [string]$Name,
  [string]$RelativePath,
  [string]$StartMarker,
  [string]$EndMarker,
  [string]$OldText,
  [string]$NewText
) {
  Copy-GuardSources
  Replace-OnceInSection $RelativePath $StartMarker $EndMarker $OldText $NewText
  try {
    & $guardPath -SourceRoot $fixtureRoot *> $null
  } catch {
    throw "Object Photo guard fixture failed: harmless decoy was rejected ($Name): $($_.Exception.Message)"
  }
}

try {
  Copy-GuardSources
  & $guardPath -SourceRoot $fixtureRoot *> $null

  $page = 'entry\src\main\ets\pages\FeatureRuntimePage.ets'
  $catalog = 'entry\src\main\ets\features\runtime\FeatureWorkflowCatalog.ets'
  $preprocessor = 'entry\src\main\ets\services\ai\HarmonyObjectDetectionInputPreprocessor.ets'
  $build = 'scripts\build-hap.ps1'
  $layoutStart = '  objectPhotoAndroidLayout() {'
  $layoutEnd = "`n`n  @Builder`n  styleTransferAndroidLayout()"
  $previewStart = '  objectPhotoAndroidPreview() {'
  $previewEnd = "`n`n  @Builder`n  objectPhotoAndroidLayout()"
  $boxStart = '  objectPhotoDetectionBox(detection: ObjectDetection, index: number) {'
  $boxEnd = "`n`n  @Builder`n  objectDetectionBox("
  $geometryStart = '  private objectDetectionAspectRatio(): number {'
  $geometryEnd = "`n`n  private gestureAspectRatio(): number {"
  $labelStart = '  private objectPhotoLabelPosition('
  $labelEnd = "`n`n  private gestureStillLabelPosition("

  Assert-GuardRejectsSectionMutation 'remove-top-level-scroll' $page $layoutStart $layoutEnd `
    'Scroll() {' 'Column() {'
  Assert-GuardRejectsSectionMutation 'duplicate-scroll' $page $layoutStart $layoutEnd `
    'Scroll() {' "Scroll() {`n        Scroll() {"
  Assert-GuardRejectsSectionMutation 'restore-centered-short-content' $page $layoutStart $layoutEnd `
    '.align(Alignment.TopStart)' '.align(Alignment.Center)'
  Assert-GuardRejectsSectionMutation 'remove-status' $page $layoutStart $layoutEnd `
    'Text(appString(this.statusKey))' "Text('Text(appString(this.statusKey))')"
  Assert-GuardRejectsSectionMutation 'remove-loading' $page $layoutStart $layoutEnd `
    'LoadingProgress()' "Text('LoadingProgress()')"
  Assert-GuardRejectsSectionMutation 'remove-status-min-height' $page $layoutStart $layoutEnd `
    ".layoutWeight(1)`n          }`n          .width('100%')`n          .constraintSize({ minHeight: 48 })" `
    ".layoutWeight(1)`n          }`n          .width('100%')`n          .constraintSize({ minHeight: 40 })"
  Assert-GuardRejectsSectionMutation 'restore-fixed-action-row' $page $layoutStart $layoutEnd `
    'Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceBetween }) {' 'Row() {'
  Assert-GuardRejectsSectionMutation 'undersize-photo-action' $page $layoutStart $layoutEnd `
    "Button(appString(workflowInputLabelKey(workflowForRoute(this.routeName), 'photo')), { type: ButtonType.Normal })`n              .width('calc(50% - 4vp)')`n              .constraintSize({ minHeight: 48 })" `
    "Button(appString(workflowInputLabelKey(workflowForRoute(this.routeName), 'photo')), { type: ButtonType.Normal })`n              .width('calc(50% - 4vp)')`n              .height(37)"
  Assert-GuardRejectsSectionMutation 'undersize-run-action' $page $layoutStart $layoutEnd `
    "'web_retry' : this.runActionKey))`n              .width('calc(50% - 4vp)')`n              .constraintSize({ minHeight: 48 })" `
    "'web_retry' : this.runActionKey))`n              .width('calc(50% - 4vp)')`n              .height(37)"
  Assert-GuardRejectsSectionMutation 'remove-photo-font-bound' $page $layoutStart $layoutEnd `
    "Button(appString(workflowInputLabelKey(workflowForRoute(this.routeName), 'photo')), { type: ButtonType.Normal })`n              .width('calc(50% - 4vp)')`n              .constraintSize({ minHeight: 48 })`n              .maxFontScale(1.6)" `
    "Button(appString(workflowInputLabelKey(workflowForRoute(this.routeName), 'photo')), { type: ButtonType.Normal })`n              .width('calc(50% - 4vp)')`n              .constraintSize({ minHeight: 48 })"
  Assert-GuardRejectsSectionMutation 'remove-retry-label' $page $layoutStart $layoutEnd `
    "Button(appString(this.statusKey === 'feature_runtime_object_detection_failed' ||`n              this.statusKey === 'feature_runtime_run_failed' ?`n              'web_retry' : this.runActionKey))" `
    'Button(appString(this.runActionKey)'
  Assert-GuardRejectsSectionMutation 'replace-current-input-on-retry' $page $layoutStart $layoutEnd `
    '.onClick(() => this.runPrimaryAction())' ".onClick(() => this.prepareInput('photo'))"
  Assert-GuardRejectsSectionMutation 'make-later-pick-initial' $page $layoutStart $layoutEnd `
    ".onClick(() => this.prepareInput('photo'))" ".onClick(() => this.prepareInput('photo', true))"

  $modelAction = "            Button(appString(workflowInputLabelKey(workflowForRoute(this.routeName), 'modelFile')))`n" +
    "              .onClick(() => this.prepareInput('modelFile'))`n"
  Assert-GuardRejectsSectionMutation 'expose-model-action' $page $layoutStart $layoutEnd `
    'Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceBetween }) {' `
    ("Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceBetween }) {`n" + $modelAction)
  Assert-GuardAcceptsSectionMutation 'model-action-string-decoy' $page $layoutStart $layoutEnd `
    'Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceBetween }) {' `
    ("Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceBetween }) {`n" +
      "            const modelDecoy = ``Button modelFile prepareInput('modelFile')``")
  Assert-GuardRejectsSectionMutation 'expose-model-action-in-preview' $page $previewStart $previewEnd `
    'Stack({ alignContent: Alignment.Center }) {' `
    ("Stack({ alignContent: Alignment.Center }) {`n" + $modelAction)
  Assert-GuardAcceptsSectionMutation 'model-action-preview-string-decoy' $page $previewStart $previewEnd `
    'Stack({ alignContent: Alignment.Center }) {' `
    ("Stack({ alignContent: Alignment.Center }) {`n" +
      "      const modelDecoy = ``Button modelFile prepareInput('modelFile')``")

  Assert-GuardRejectsSectionMutation 'remove-input-contain' $page $previewStart $previewEnd `
    "Image(this.imageInputUri)`n          .width('100%')`n          .height('100%')`n          .objectFit(ImageFit.Contain)" `
    "Image(this.imageInputUri)`n          .width('100%')`n          .height('100%')`n          .objectFit(ImageFit.Fill)"
  Assert-GuardRejectsSectionMutation 'remove-result-orientation' $page $previewStart $previewEnd `
    "Image(this.objectDetectionImageUri)`n            .orientation(this.objectDetectionImageOrientation)" `
    "Image(this.objectDetectionImageUri)`n            .orientation(ImageRotateOrientation.UP)"
  Assert-GuardRejectsSectionMutation 'overflow-landscape-result' $page $previewStart $previewEnd `
    '.height(this.percentLength(this.objectPhotoPreviewHeightPercent()))' ".height('100%')"
  Assert-GuardRejectsSectionMutation 'overflow-portrait-result' $page $previewStart $previewEnd `
    '.width(this.percentLength(this.objectPhotoPreviewWidthPercent()))' ".width('100%')"
  Assert-GuardRejectsSectionMutation 'restore-uncontained-result' $page $previewStart $previewEnd `
    ".width(this.percentLength(this.objectPhotoPreviewWidthPercent()))`n        .height(this.percentLength(this.objectPhotoPreviewHeightPercent()))" `
    ".width('100%')`n        .aspectRatio(this.objectDetectionAspectRatio())"
  Assert-GuardRejectsSectionMutation 'remove-overlay-measurement' $page $previewStart $previewEnd `
    '.onAreaChange((_previousArea: Area, currentArea: Area) => {' `
    "/* .onAreaChange((_previousArea: Area, currentArea: Area) => { */"
  Assert-GuardRejectsSectionMutation 'restore-inner-box-label' $page $previewStart $previewEnd `
    'this.objectPhotoDetectionBox(detection, index)' 'this.objectDetectionBox(detection, index)'
  Assert-GuardRejectsSectionMutation 'break-contained-width-math' $page $geometryStart $geometryEnd `
    'return sourceAspect >= cardAspect ? 100 : sourceAspect / cardAspect * 100;' 'return 100;'
  Assert-GuardRejectsSectionMutation 'break-contained-height-math' $page $geometryStart $geometryEnd `
    'return sourceAspect >= cardAspect ? cardAspect / sourceAspect * 100 : 100;' 'return 100;'

  Assert-GuardRejectsSectionMutation 'force-label-right-overflow' $page $labelStart $labelEnd `
    'const canPlaceRight = boxRight + gap + labelWidth <= overlayWidth;' 'const canPlaceRight = true;'
  Assert-GuardRejectsSectionMutation 'remove-label-below-fallback' $page $labelStart $labelEnd `
    'const canPlaceBelow = boxBottom + gap + labelHeight <= overlayHeight;' 'const canPlaceBelow = false;'
  Assert-GuardRejectsSectionMutation 'remove-label-left-fallback' $page $labelStart $labelEnd `
    '} else if (boxLeft >= labelWidth + gap) {' '} else if (false) {'
  Assert-GuardRejectsSectionMutation 'remove-label-top-fallback' $page $labelStart $labelEnd `
    '} else if (boxTop >= labelHeight + gap) {' '} else if (false) {'
  Assert-GuardRejectsSectionMutation 'remove-label-clamp-x' $page $labelStart $labelEnd `
    'labelLeft = Math.min(Math.max(labelLeft, 0), Math.max(0, overlayWidth - labelWidth));' 'labelLeft = labelLeft;'
  Assert-GuardRejectsSectionMutation 'remove-label-clamp-y' $page $labelStart $labelEnd `
    'labelTop = Math.min(Math.max(labelTop, 0), Math.max(0, overlayHeight - labelHeight));' 'labelTop = labelTop;'
  Assert-GuardRejectsSectionMutation 'restore-inner-box-label-implementation' $page $boxStart $boxEnd `
    'Text(this.objectDetectionLabel(detection, index))' "Text('')"

  Assert-GuardRejectsSectionMutation 'hardcode-result-separator' $page $layoutStart $layoutEnd `
    "Span(appString('feature_runtime_result_separator'))" "Span(': ')"

  Assert-GuardRejectsSectionMutation 'clear-at-run-start' $catalog `
    'export function shouldClearRuntimeResultAtWorkflowStart' `
    'export function shouldKeepScreenOnForWorkflow' `
    '    !usesAndroidObjectPhotoLayout(workflow) &&' ''
  Assert-GuardRejectsSectionMutation 'clear-after-photo-ready' $catalog `
    'export function shouldPreserveRuntimeResultAfterInputReady' `
    'export function shouldPreserveRuntimeTextResultOnAiResult' `
    "(usesAndroidObjectPhotoLayout(workflow) && (inputKind === 'photo' || inputKind === 'modelFile')) ||" `
    "(usesAndroidObjectPhotoLayout(workflow) && inputKind === 'modelFile') ||"
  Assert-GuardRejectsSectionMutation 'clear-after-model-cache' $catalog `
    'export function shouldPreserveRuntimeResultAfterInputReady' `
    'export function shouldPreserveRuntimeTextResultOnAiResult' `
    "(usesAndroidObjectPhotoLayout(workflow) && (inputKind === 'photo' || inputKind === 'modelFile')) ||" `
    "(usesAndroidObjectPhotoLayout(workflow) && inputKind === 'photo') ||"
  Assert-GuardRejectsSectionMutation 'clear-failed-result-rows' $catalog `
    'export function shouldPreserveRuntimeTextResultOnAiResult' `
    'export function shouldPreserveRuntimeVisualResultOnAiResult' `
    'return (usesAndroidStillSceneLayout(workflow) || usesAndroidObjectPhotoLayout(workflow)) && !resultOk;' `
    'return usesAndroidStillSceneLayout(workflow) && !resultOk;'
  Assert-GuardRejectsSectionMutation 'clear-failed-overlay' $catalog `
    '  if (usesAndroidObjectPhotoLayout(workflow)) {' `
    '  if (usesAndroidStyleTransferLayout(workflow)) {' `
    "return !resultOk || dataKind === 'objectDetections';" "return dataKind === 'objectDetections';"
  Assert-GuardRejectsSectionMutation 'preserve-wrong-success-kind' $catalog `
    '  if (usesAndroidObjectPhotoLayout(workflow)) {' `
    '  if (usesAndroidStyleTransferLayout(workflow)) {' `
    "return !resultOk || dataKind === 'objectDetections';" 'return true;'

  Assert-GuardRejectsSectionMutation 'break-cancel-input-preservation' $page `
    '  private applyPickResult(' "`n`n  private aiRunInputs" `
    'this.applyPickedInputState(runtimePickedInputStateAfterCancelledPick(' `
    "const cancelDecoy = 'this.applyPickedInputState(runtimePickedInputStateAfterCancelledPick(';"
  Assert-GuardRejectsSectionMutation 'disable-initial-cancel-exit' $catalog `
    'export function shouldLeaveRuntimeAfterCancelledInitialPick' `
    'export function cancelledPickStatusKeyForWorkflow' `
    'return initialPick &&' 'return false &&'
  Assert-GuardRejectsSectionMutation 'exit-on-later-cancel' $catalog `
    'export function shouldLeaveRuntimeAfterCancelledInitialPick' `
    'export function cancelledPickStatusKeyForWorkflow' `
    'return initialPick &&' 'return'
  Assert-GuardRejectsSectionMutation 'remove-router-back' $page `
    '  private applyPickResult(' "`n`n  private aiRunInputs" `
    'router.back();' "const backDecoy = 'router.back();';"

  $staleGate = '    if (!isInputPreparationRequestCurrent(requestId, this.inputPreparationRequestId)) {' + $nl +
    '      return;' + $nl +
    '    }' + $nl +
    '    if (cacheResult === undefined) {'
  $staleGateDecoy = "    if ('if (!isInputPreparationRequestCurrent(requestId, this.inputPreparationRequestId)) {'.length > 0) {" + $nl +
    '      return;' + $nl +
    '    }' + $nl +
    '    if (cacheResult === undefined) {'
  Assert-GuardRejectsMutation 'break-cache-stale-gate' $page $staleGate $staleGateDecoy
  Assert-GuardRejectsMutation 'break-cache-apply' $page `
    '    this.applyModelFileCacheResult(cacheResult, inputKind);' `
    "    const applyDecoy = 'this.applyModelFileCacheResult(cacheResult, inputKind);';"
  Assert-GuardRejectsMutation 'break-cache-followup-policy' $page `
    '    const followupInputKind = objectPhotoFollowupInputKindAfterModelCacheSuccess(workflow, inputKind);' `
    "    const followupInputKind = 'objectPhotoFollowupInputKindAfterModelCacheSuccess(workflow, inputKind)';"
  Assert-GuardRejectsMutation 'break-cache-followup-initial-pick' $page `
    '      this.prepareInput(followupInputKind, true);' `
    "      const initialPickDecoy = 'this.prepareInput(followupInputKind, true);';"
  Assert-GuardRejectsSectionMutation 'remove-route-scope' $catalog `
    'export function usesAndroidObjectPhotoLayout' `
    'export function usesAndroidStyleTransferLayout' `
    '  return workflow?.routeName === AppRoute.OBJECT_PHOTO.name;' `
    '  return workflow !== undefined;'
  Assert-GuardRejectsMutation 'remove-exif-oriented-decode' $preprocessor `
    '      pixelMap = await imageSource.createPixelMap(decodingOptionsWithImageRotation(' `
    '      pixelMap = await imageSource.createPixelMap('
  Assert-GuardRejectsMutation 'remove-production-wire' $build `
    '& (Join-Path $PSScriptRoot ''check-object-photo-layout-parity.ps1'')' `
    '$guardCallDecoy = "& (Join-Path $PSScriptRoot ''check-object-photo-layout-parity.ps1'')"'
  Assert-GuardRejectsMutation 'remove-mutation-wire' $build `
    '& (Join-Path $PSScriptRoot ''test-object-photo-layout-parity-guard.ps1'')' `
    '$mutationCallDecoy = "& (Join-Path $PSScriptRoot ''test-object-photo-layout-parity-guard.ps1'')"'

  Write-Output 'Object Photo layout guard negative fixtures passed.'
} finally {
  $resolvedFixtureRoot = [IO.Path]::GetFullPath($fixtureRoot)
  if ($resolvedFixtureRoot.StartsWith($tempParent, [StringComparison]::OrdinalIgnoreCase) -and
    [IO.Directory]::Exists($resolvedFixtureRoot)) {
    [IO.Directory]::Delete($resolvedFixtureRoot, $true)
  }
}
