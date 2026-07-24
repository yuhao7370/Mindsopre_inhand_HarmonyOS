$ErrorActionPreference = 'Stop'

$sourceRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$guardPath = Join-Path $PSScriptRoot 'check-still-segmentation-layout-parity.ps1'
$tempParent = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd(
  [IO.Path]::DirectorySeparatorChar,
  [IO.Path]::AltDirectorySeparatorChar
)
$tempRoot = [IO.Path]::GetFullPath((Join-Path $tempParent (
      'mindspore-still-segmentation-guard-' + [guid]::NewGuid().ToString('N'))))
$tempPrefix = $tempParent + [IO.Path]::DirectorySeparatorChar
$utf8 = [Text.UTF8Encoding]::new($false)

if (-not $tempRoot.StartsWith($tempPrefix, [StringComparison]::OrdinalIgnoreCase)) {
  throw 'Still segmentation guard fixture refused an unsafe temporary path.'
}

function Normalize-Newlines([string]$Text) {
  return $Text.Replace("`r`n", "`n").Replace("`r", "`n")
}

function Copy-GuardedSources([string]$Destination) {
  foreach ($relativePath in @(
    'entry\src\main\ets\features\runtime\FeatureWorkflowCatalog.ets',
    'entry\src\main\ets\features\runtime\FeatureRuntimeInputState.ets',
    'entry\src\main\ets\pages\FeatureRuntimePage.ets',
    'entry\src\main\ets\services\ai\SegmentationService.ets',
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
    throw "Still segmentation guard fixture expected one mutation target: $Before"
  }
  [IO.File]::WriteAllText($Path,
    $text.Substring(0, $first) + $After + $text.Substring($first + $Before.Length), $utf8)
}

function Replace-OnceInSection(
  [string]$Path,
  [string]$StartMarker,
  [string]$EndMarker,
  [string]$Before,
  [string]$After
) {
  $text = Normalize-Newlines ([IO.File]::ReadAllText($Path))
  $start = $text.IndexOf($StartMarker, [StringComparison]::Ordinal)
  $end = if ($start -ge 0) {
    $text.IndexOf($EndMarker, $start + $StartMarker.Length, [StringComparison]::Ordinal)
  } else { -1 }
  if ($start -lt 0 -or $end -le $start) {
    throw "Still segmentation guard fixture could not bound: $StartMarker"
  }
  $Before = Normalize-Newlines $Before
  $After = Normalize-Newlines $After
  $section = $text.Substring($start, $end - $start)
  $relative = $section.IndexOf($Before, [StringComparison]::Ordinal)
  if ($relative -lt 0 -or $section.IndexOf($Before, $relative + $Before.Length, [StringComparison]::Ordinal) -ge 0) {
    throw "Still segmentation guard fixture expected one section target: $Before"
  }
  $absolute = $start + $relative
  [IO.File]::WriteAllText($Path,
    $text.Substring(0, $absolute) + $After + $text.Substring($absolute + $Before.Length), $utf8)
}

function New-MutationRoot([string]$Name) {
  $root = Join-Path $tempRoot $Name
  Copy-GuardedSources $root
  return $root
}

function Assert-GuardRejects(
  [string]$Name,
  [string]$RelativePath,
  [string]$StartMarker,
  [string]$EndMarker,
  [string]$Before,
  [string]$After
) {
  $root = New-MutationRoot $Name
  Replace-OnceInSection (Join-Path $root $RelativePath) $StartMarker $EndMarker $Before $After
  $rejected = $false
  try { & $guardPath -SourceRoot $root *> $null } catch { $rejected = $true }
  if (-not $rejected) { throw "Still segmentation guard fixture accepted mutation: $Name" }
}

function Assert-GuardRejectsGlobal(
  [string]$Name,
  [string]$RelativePath,
  [string]$Before,
  [string]$After
) {
  $root = New-MutationRoot $Name
  Replace-Once (Join-Path $root $RelativePath) $Before $After
  $rejected = $false
  try { & $guardPath -SourceRoot $root *> $null } catch { $rejected = $true }
  if (-not $rejected) { throw "Still segmentation guard fixture accepted mutation: $Name" }
}

function Assert-GuardAccepts(
  [string]$Name,
  [string]$RelativePath,
  [string]$StartMarker,
  [string]$EndMarker,
  [string]$Before,
  [string]$After
) {
  $root = New-MutationRoot $Name
  Replace-OnceInSection (Join-Path $root $RelativePath) $StartMarker $EndMarker $Before $After
  try { & $guardPath -SourceRoot $root *> $null } catch {
    throw "Still segmentation guard fixture rejected harmless decoy ($Name): $($_.Exception.Message)"
  }
}

try {
  $validRoot = Join-Path $tempRoot 'valid'
  Copy-GuardedSources $validRoot
  & $guardPath -SourceRoot $validRoot *> $null

  $page = 'entry\src\main\ets\pages\FeatureRuntimePage.ets'
  $catalog = 'entry\src\main\ets\features\runtime\FeatureWorkflowCatalog.ets'
  $inputState = 'entry\src\main\ets\features\runtime\FeatureRuntimeInputState.ets'
  $service = 'entry\src\main\ets\services\ai\SegmentationService.ets'
  $build = 'scripts\build-hap.ps1'
  $layoutStart = '  stillSegmentationAndroidLayout() {'
  $layoutEnd = "`n`n  @Builder`n  customModelAndroidLayout()"
  $previewStart = '  stillSegmentationAndroidPreview() {'
  $previewEnd = "`n`n  @Builder`n  stillSegmentationAndroidLayout()"

  Assert-GuardRejects 'remove-scroll' $page $layoutStart $layoutEnd 'Scroll() {' 'Column() {'
  Assert-GuardRejects 'duplicate-scroll' $page $layoutStart $layoutEnd 'Scroll() {' "Scroll() {`n        Scroll() {"
  Assert-GuardRejects 'restore-fixed-row' $page $layoutStart $layoutEnd `
    'Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceBetween }) {' 'Row() {'
  Assert-GuardRejects 'remove-preview-ratio' $page $layoutStart $layoutEnd `
    '.aspectRatio(4 / 3)' '.aspectRatio(1)'
  Assert-GuardRejects 'remove-status' $page $layoutStart $layoutEnd `
    "Text(appString(this.resultImageSaveInFlight ? 'feature_runtime_save_image' : this.statusKey))" `
    "Text('status')"
  Assert-GuardRejects 'remove-loading' $page $layoutStart $layoutEnd `
    'LoadingProgress()' "Text('LoadingProgress()')"
  Assert-GuardRejects 'remove-retry-handler' $page $layoutStart $layoutEnd `
    '.onClick(() => this.runPrimaryAction())' ".onClick(() => this.prepareInput('photo'))"
  Assert-GuardRejects 'undersize-photo' $page $layoutStart $layoutEnd `
    "Button(appString(workflowInputLabelKey(workflowForRoute(this.routeName), 'photo')), { type: ButtonType.Normal })`n              .width('calc(50% - 4vp)')`n              .constraintSize({ minHeight: 48 })" `
    "Button(appString(workflowInputLabelKey(workflowForRoute(this.routeName), 'photo')), { type: ButtonType.Normal })`n              .width('calc(50% - 4vp)')`n              .height(37)"
  Assert-GuardRejects 'remove-camera-font-bound' $page $layoutStart $layoutEnd `
    "Button(appString(workflowInputLabelKey(workflowForRoute(this.routeName), 'camera')), { type: ButtonType.Normal })`n              .width('calc(50% - 4vp)')`n              .constraintSize({ minHeight: 48 })`n              .maxFontScale(1.6)" `
    "Button(appString(workflowInputLabelKey(workflowForRoute(this.routeName), 'camera')), { type: ButtonType.Normal })`n              .width('calc(50% - 4vp)')`n              .constraintSize({ minHeight: 48 })"
  Assert-GuardRejects 'remove-photo-action' $page $layoutStart $layoutEnd `
    ".onClick(() => this.prepareInput('photo'))" ".onClick(() => this.prepareInput('camera'))"
  Assert-GuardRejects 'remove-camera-action' $page $layoutStart $layoutEnd `
    ".onClick(() => this.prepareInput('camera'))" ".onClick(() => this.prepareInput('photo'))"
  Assert-GuardRejects 'remove-live-action' $page $layoutStart $layoutEnd `
    'this.openStillSegmentationLiveRoute()' 'router.back()'
  Assert-GuardRejects 'enable-photo-during-save' $page $layoutStart $layoutEnd `
    ".enabled(!this.workflowRunning && !this.resultImageSaveInFlight)`n              .onClick(() => this.prepareInput('photo'))" `
    ".enabled(!this.workflowRunning)`n              .onClick(() => this.prepareInput('photo'))"
  Assert-GuardRejects 'enable-camera-during-save' $page $layoutStart $layoutEnd `
    ".enabled(!this.workflowRunning && !this.resultImageSaveInFlight)`n              .onClick(() => this.prepareInput('camera'))" `
    ".enabled(!this.workflowRunning)`n              .onClick(() => this.prepareInput('camera'))"
  Assert-GuardRejects 'enable-live-route-during-save' $page $layoutStart $layoutEnd `
    ".enabled(!this.workflowRunning && !this.resultImageSaveInFlight)`n              .onClick(() => {" `
    ".enabled(!this.workflowRunning)`n              .onClick(() => {"
  Assert-GuardRejects 'remove-save-action' $page $layoutStart $layoutEnd `
    'SaveButton({' 'Button({'
  Assert-GuardRejects 'remove-save-running-gate' $page $layoutStart $layoutEnd `
    '.enabled(compositeSegmentationSaveReady(this.workflowRunning,' `
    '.enabled(compositeSegmentationSaveReady(false,'
  Assert-GuardRejects 'remove-save-foreground-gate' $page $layoutStart $layoutEnd `
    ".enabled(compositeSegmentationSaveReady(this.workflowRunning,`n                  this.segmentationForegroundPixelMap !== undefined, this.resultImageSaveInFlight))" `
    ".enabled(compositeSegmentationSaveReady(this.workflowRunning,`n                  true, this.resultImageSaveInFlight))"
  Assert-GuardRejects 'remove-save-flight-gate' $page $layoutStart $layoutEnd `
    ".enabled(compositeSegmentationSaveReady(this.workflowRunning,`n                  this.segmentationForegroundPixelMap !== undefined, this.resultImageSaveInFlight))" `
    ".enabled(compositeSegmentationSaveReady(this.workflowRunning,`n                  this.segmentationForegroundPixelMap !== undefined, false))"

  Assert-GuardRejects 'reverse-preview-priority' $page $previewStart $previewEnd `
    'if (this.segmentationForegroundPixelMap !== undefined) {' 'if (this.imageInputUri.length > 0) {'
  Assert-GuardRejects 'stretch-input' $page $previewStart $previewEnd `
    "Image(this.imageInputUri)`n          .width('100%')`n          .height('100%')`n          .objectFit(ImageFit.Contain)" `
    "Image(this.imageInputUri)`n          .width('100%')`n          .height('100%')`n          .objectFit(ImageFit.Fill)"
  Assert-GuardRejects 'rotate-accepted-foreground-again' $page $previewStart $previewEnd `
    'Image(this.segmentationForegroundPixelMap)' `
    "Image(this.segmentationForegroundPixelMap)`n          .orientation(this.segmentationImageOrientation)"
  Assert-GuardAccepts 'scroll-string-decoy' $page $layoutStart $layoutEnd `
    'Scroll() {' "Scroll() {`n        const decoy = ``Scroll() {``"
  Assert-GuardAccepts 'retry-comment-decoy' $page $layoutStart $layoutEnd `
    '.onClick(() => this.runPrimaryAction())' `
    "// .onClick(() => this.prepareInput('photo'))`n              .onClick(() => this.runPrimaryAction())"

  Assert-GuardRejects 'clear-at-run-start' $catalog `
    'export function shouldClearRuntimeResultAtWorkflowStart' `
    'export function shouldKeepScreenOnForWorkflow' `
    '!usesAndroidStillSegmentationLayout(workflow) &&' ''
  Assert-GuardRejects 'clear-after-photo-ready' $catalog `
    'export function shouldPreserveRuntimeResultAfterInputReady' `
    'export function shouldPreserveRuntimeTextResultOnAiResult' `
    "(usesAndroidStillSegmentationLayout(workflow) && (inputKind === 'photo' || inputKind === 'camera')) ||" `
    "(usesAndroidStillSegmentationLayout(workflow) && inputKind === 'camera') ||"
  Assert-GuardRejects 'clear-after-camera-ready' $catalog `
    'export function shouldPreserveRuntimeResultAfterInputReady' `
    'export function shouldPreserveRuntimeTextResultOnAiResult' `
    "(usesAndroidStillSegmentationLayout(workflow) && (inputKind === 'photo' || inputKind === 'camera')) ||" `
    "(usesAndroidStillSegmentationLayout(workflow) && inputKind === 'photo') ||"
  Assert-GuardRejects 'clear-on-failure' $catalog `
    'if (usesAndroidStillSegmentationLayout(workflow)) {' `
    'return workflow?.routeName === AppRoute.PORTRAIT_SEGMENTATION.name' `
    "return !resultOk || dataKind === 'segmentation';" `
    "return dataKind === 'segmentation';"
  Assert-GuardRejects 'preserve-wrong-success-kind' $catalog `
    'if (usesAndroidStillSegmentationLayout(workflow)) {' `
    'return workflow?.routeName === AppRoute.PORTRAIT_SEGMENTATION.name' `
    "return !resultOk || dataKind === 'segmentation';" 'return true;'
  Assert-GuardRejects 'remove-save-ready-running-gate' $catalog `
    'export function compositeSegmentationSaveReady' `
    'export function shouldShowLiveGestureCameraOverlay' `
    'return !workflowRunning && foregroundReady && !saveInFlight;' `
    'return foregroundReady && !saveInFlight;'

  Assert-GuardRejects 'break-page-cancel-helper' $page `
    '  private applyPickResult(' "`n`n  private aiRunInputs" `
    'this.applyPickedInputState(runtimePickedInputStateAfterCancelledPick(' `
    "const cancelDecoy = 'runtimePickedInputStateAfterCancelledPick';"
  Assert-GuardRejects 'break-cancel-helper' $inputState `
    'export function runtimePickedInputStateAfterCancelledPick' `
    'export function runtimePickedInputStateAfterModelCacheFailure' `
    "if (inputKind !== 'backgroundImage') {`n    return state;" `
    "if (inputKind !== 'backgroundImage') {`n    return { ...state, imageInputUri: '' };"
  Assert-GuardRejects 'clear-owner-on-new-input' $page `
    '  private applyPickResult(' "`n`n  private aiRunInputs" `
    'this.segmentationForegroundPixelMapOwner.invalidatePendingReplacement();' `
    'this.segmentationForegroundPixelMapOwner.clear();'
  Assert-GuardRejects 'fire-and-forget-foreground' $page `
    '  private async updateSegmentationPreview(' "`n`n  private updatePosePreview" `
    'await foregroundUpdate;' 'foregroundUpdate;'
  Assert-GuardRejects 'bypass-owner-accept' $page `
    '  private async updateSegmentationPreview(' "`n`n  private updatePosePreview" `
    'if (this.segmentationForegroundPixelMapOwner.accept(requestId, pixelMap)) {' `
    'if (pixelMap !== undefined) {'
  Assert-GuardRejects 'clear-owner-on-conversion-failure' $page `
    '  private async updateSegmentationPreview(' "`n`n  private updatePosePreview" `
    "if (stillSegmentation) {`n          this.segmentationForegroundPixelMapOwner.invalidatePendingReplacement();`n          this.statusKey = 'feature_runtime_segmentation_failed';" `
    "if (stillSegmentation) {`n          this.segmentationForegroundPixelMapOwner.clear();`n          this.statusKey = 'feature_runtime_segmentation_failed';"

  Assert-GuardRejects 'remove-click-save-gate' $page `
    '  private saveStillSegmentationResultImage(): void {' `
    "`n`n  private async saveResultComponentImageAsync" `
    "private saveStillSegmentationResultImage(): void {`n    if (!compositeSegmentationSaveReady(this.workflowRunning," `
    "private saveStillSegmentationResultImage(): void {`n    if (false && !compositeSegmentationSaveReady(this.workflowRunning,"
  Assert-GuardRejects 'remove-single-flight-acquire' $page `
    '  private async saveResultPixelMapAsync(' `
    "`n`n  private async performResultPixelMapSave(" `
    'this.resultImageSaveInFlight = true;' 'this.resultImageSaveInFlight = false;'
  Assert-GuardRejects 'release-before-await-empty-finally' $page `
    '  private async saveResultPixelMapAsync(' `
    "`n`n  private async performResultPixelMapSave(" `
    "this.resultImageSaveInFlight = true;`n    try {`n      await this.performResultPixelMapSave(pixelMap);`n    } finally {`n      this.resultImageSaveInFlight = false;`n    }" `
    "this.resultImageSaveInFlight = true;`n    this.resultImageSaveInFlight = false;`n    try {`n      await this.performResultPixelMapSave(pixelMap);`n    } finally {`n    }"
  Assert-GuardRejects 'remove-single-flight-release' $page `
    '  private async saveResultPixelMapAsync(' `
    "`n`n  private async performResultPixelMapSave(" `
    "    } finally {`n      this.resultImageSaveInFlight = false;`n    }" `
    "    } finally {`n    }"
  Assert-GuardRejects 'commented-single-flight-release-decoy' $page `
    '  private async saveResultPixelMapAsync(' `
    "`n`n  private async performResultPixelMapSave(" `
    '      this.resultImageSaveInFlight = false;' `
    '      // this.resultImageSaveInFlight = false;'
  Assert-GuardRejects 'string-single-flight-release-decoy' $page `
    '  private async saveResultPixelMapAsync(' `
    "`n`n  private async performResultPixelMapSave(" `
    '      this.resultImageSaveInFlight = false;' `
    "      const releaseDecoy = 'this.resultImageSaveInFlight = false;';"
  Assert-GuardRejects 'unrelated-finally-release-decoy' $page `
    '  private async saveResultPixelMapAsync(' `
    "`n`n  private async performResultPixelMapSave(" `
    "this.resultImageSaveInFlight = true;`n    try {`n      await this.performResultPixelMapSave(pixelMap);`n    } finally {`n      this.resultImageSaveInFlight = false;`n    }" `
    "this.resultImageSaveInFlight = true;`n    this.resultImageSaveInFlight = false;`n    try {`n      await this.performResultPixelMapSave(pixelMap);`n    } finally {`n    }`n    try {`n      return;`n    } finally {`n      this.resultImageSaveInFlight = false;`n    }"
  Assert-GuardRejects 'save-wrong-pixelmap' $page `
    '  private saveStillSegmentationResultImage(): void {' `
    "`n`n  private async saveResultComponentImageAsync" `
    'await this.saveResultPixelMapAsync(this.segmentationForegroundPixelMap);' `
    'await this.saveResultPixelMapAsync(this.styledImagePixelMap);'

  Assert-GuardRejects 'remove-exif-decode' $service `
    'export class HarmonySubjectSegmentationRunner' `
    "`n`nexport function segmentationConfigForAndroidScene" `
    'pixelMap = await imageSource.createPixelMap(decodingOptionsWithImageRotation({}, rotationDegrees));' `
    'pixelMap = await imageSource.createPixelMap({});'
  Assert-GuardRejects 'remove-rotated-mask-size' $service `
    'export class HarmonySubjectSegmentationRunner' `
    "`n`nexport function segmentationConfigForAndroidScene" `
    'const displaySize = rotatedImageSize(imageInfo.size.width, imageInfo.size.height, rotationDegrees);' `
    'const displaySize = imageInfo.size;'

  Assert-GuardRejectsGlobal 'remove-production-wire' $build `
    "& (Join-Path `$PSScriptRoot 'check-still-segmentation-layout-parity.ps1')" `
    "`$guardDecoy = `"check-still-segmentation-layout-parity.ps1`""
  Assert-GuardRejectsGlobal 'remove-mutation-wire' $build `
    "& (Join-Path `$PSScriptRoot 'test-still-segmentation-layout-parity-guard.ps1')" `
    "`$mutationDecoy = `"test-still-segmentation-layout-parity-guard.ps1`""

  Write-Output 'Still image segmentation parity guard negative fixtures passed.'
} finally {
  if ($tempRoot.StartsWith($tempPrefix, [StringComparison]::OrdinalIgnoreCase) -and
    [IO.Directory]::Exists($tempRoot)) {
    [IO.Directory]::Delete($tempRoot, $true)
  }
}
