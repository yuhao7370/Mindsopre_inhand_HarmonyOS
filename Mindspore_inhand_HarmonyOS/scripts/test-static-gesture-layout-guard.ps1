param(
  [string]$SourceRoot = ''
)

$ErrorActionPreference = 'Stop'
$utf8 = [Text.UTF8Encoding]::new($false)
$guardPath = Join-Path $PSScriptRoot 'check-static-gesture-layout-parity.ps1'
if ([string]::IsNullOrWhiteSpace($SourceRoot)) {
  $SourceRoot = Split-Path -Parent $PSScriptRoot
}
$SourceRoot = [IO.Path]::GetFullPath($SourceRoot)
$tempPrefix = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\', '/') +
  [IO.Path]::DirectorySeparatorChar
$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("static-gesture-guard-" + [Guid]::NewGuid().ToString('N'))

function Normalize-Text([string]$Text) {
  return $Text.Replace("`r`n", "`n").Replace("`r", "`n")
}

function Copy-Candidate([string]$Destination) {
  foreach ($relative in @(
    'entry\src\main\ets\pages\FeatureRuntimePage.ets',
    'entry\src\main\ets\features\runtime\FeatureWorkflowCatalog.ets',
    'entry\src\main\ets\services\ai\GestureService.ets',
    'scripts\build-hap.ps1'
  )) {
    $target = Join-Path $Destination $relative
    [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($target)) | Out-Null
    [IO.File]::Copy((Join-Path $SourceRoot $relative), $target, $true)
  }
}

function Replace-Once(
  [string]$Path,
  [string]$Before,
  [string]$After
) {
  $text = Normalize-Text ([IO.File]::ReadAllText($Path))
  $Before = Normalize-Text $Before
  $After = Normalize-Text $After
  $first = $text.IndexOf($Before, [StringComparison]::Ordinal)
  if ($first -lt 0 -or $text.IndexOf($Before, $first + $Before.Length, [StringComparison]::Ordinal) -ge 0) {
    throw "Static gesture guard fixture expected one mutation target: $Before"
  }
  [IO.File]::WriteAllText(
    $Path,
    $text.Substring(0, $first) + $After + $text.Substring($first + $Before.Length),
    $utf8
  )
}

function Assert-Rejected(
  [string]$Name,
  [string]$RelativePath,
  [string]$Before,
  [string]$After
) {
  $root = Join-Path $tempRoot $Name
  Copy-Candidate $root
  Replace-Once (Join-Path $root $RelativePath) $Before $After
  $rejected = $false
  try {
    & $guardPath -SourceRoot $root | Out-Null
  } catch {
    $rejected = $true
  }
  if (-not $rejected) {
    throw "Static gesture guard fixture accepted mutation: $Name"
  }
}

function Assert-RejectedInSection(
  [string]$Name,
  [string]$RelativePath,
  [string]$StartMarker,
  [string]$EndMarker,
  [string]$Before,
  [string]$After
) {
  $root = Join-Path $tempRoot $Name
  Copy-Candidate $root
  $path = Join-Path $root $RelativePath
  $text = Normalize-Text ([IO.File]::ReadAllText($path))
  $start = $text.IndexOf($StartMarker, [StringComparison]::Ordinal)
  $end = if ($start -ge 0) {
    $text.IndexOf($EndMarker, $start + $StartMarker.Length, [StringComparison]::Ordinal)
  } else {
    -1
  }
  if ($start -lt 0 -or $end -le $start) {
    throw "Static gesture guard fixture could not find section: $Name"
  }
  $Before = Normalize-Text $Before
  $After = Normalize-Text $After
  $section = $text.Substring($start, $end - $start)
  $relativeIndex = $section.IndexOf($Before, [StringComparison]::Ordinal)
  if ($relativeIndex -lt 0 -or
    $section.IndexOf($Before, $relativeIndex + $Before.Length, [StringComparison]::Ordinal) -ge 0) {
    throw "Static gesture guard fixture expected one section mutation target: $Name"
  }
  $absoluteIndex = $start + $relativeIndex
  [IO.File]::WriteAllText(
    $path,
    $text.Substring(0, $absoluteIndex) + $After +
      $text.Substring($absoluteIndex + $Before.Length),
    $utf8
  )
  $rejected = $false
  try {
    & $guardPath -SourceRoot $root | Out-Null
  } catch {
    $rejected = $true
  }
  if (-not $rejected) {
    throw "Static gesture guard fixture accepted mutation: $Name"
  }
}

try {
  $productionRejected = $false
  try {
    & $guardPath -SourceRoot $SourceRoot | Out-Null
  } catch {
    $productionRejected = $true
  }
  if ($productionRejected) {
    throw 'Static gesture mutation fixtures require the production candidate to pass first.'
  }

  [IO.Directory]::CreateDirectory($tempRoot) | Out-Null
  $page = 'entry\src\main\ets\pages\FeatureRuntimePage.ets'
  $catalog = 'entry\src\main\ets\features\runtime\FeatureWorkflowCatalog.ets'
  $gesture = 'entry\src\main\ets\services\ai\GestureService.ets'
  $build = 'scripts\build-hap.ps1'
  $layoutStart = '  gestureStillAndroidLayout() {'
  $layoutEnd = "`n`n  @Builder`n  textRecognitionAndroidLayout()"
  $previewStart = '  gestureStillAndroidPreview() {'
  $previewEnd = "`n`n  @Builder`n  gestureStillAndroidLayout()"

  Assert-RejectedInSection 'restore-fixed-action-row' $page $layoutStart $layoutEnd `
    'Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceBetween }) {' `
    'Row() {'
  Assert-RejectedInSection 'restore-undersized-photo' $page $layoutStart $layoutEnd `
    "Button(appString('feature_input_photo_android'), { type: ButtonType.Normal })`n              .width('calc(50% - 4vp)')`n              .constraintSize({ minHeight: 48 })" `
    "Button(appString('feature_input_photo_android'), { type: ButtonType.Normal })`n              .width('calc(50% - 4vp)')`n              .height(37)"
  Assert-RejectedInSection 'remove-status' $page $layoutStart $layoutEnd `
    'Text(appString(this.statusKey))' `
    "Text('')"
  Assert-RejectedInSection 'status-comment-decoy' $page $layoutStart $layoutEnd `
    'Text(appString(this.statusKey))' `
    '// Text(appString(this.statusKey))'
  Assert-RejectedInSection 'toolbar-template-decoy' $page $layoutStart $layoutEnd `
    'this.runtimeActionToolbar(false)' `
    "const toolbarDecoy = `` `nthis.runtimeActionToolbar(false)`n ``"
  Assert-RejectedInSection 'remove-retry-label' $page $layoutStart $layoutEnd `
    "Button(appString(this.statusKey === 'feature_runtime_gesture_failed' ||`n              this.statusKey === 'feature_runtime_run_failed' ?`n              'web_retry' : 'feature_runtime_gesture_detect_android'))" `
    "Button(appString('feature_runtime_gesture_detect_android'))"
  Assert-RejectedInSection 'replace-current-input-on-run' $page $layoutStart $layoutEnd `
    '.onClick(() => this.runPrimaryAction())' `
    ".onClick(() => this.prepareInput('photo'))"
  Assert-RejectedInSection 'break-picker-preservation' $page `
    '  private applyPickResult(' "`n`n  private aiRunInputs" `
    'this.applyPickedInputState(runtimePickedInputStateAfterCancelledPick(' `
    'this.applyPickedInputState(this.pickedInputState())'
  Assert-RejectedInSection 'remove-overlay-orientation' $page $previewStart $previewEnd `
    "Image(this.gestureImageUri)`n            .orientation(this.gestureImageOrientation)" `
    "Image(this.gestureImageUri)`n            .orientation(ImageRotateOrientation.UP)"
  Assert-RejectedInSection 'restore-obscuring-inner-label' $page $previewStart $previewEnd `
    'this.gestureStillBox(gesture)' `
    'this.gestureBox(gesture)'
  Assert-RejectedInSection 'force-label-right-overflow' $page `
    '  private gestureAspectRatio(): number {' "`n`n  private objectDetectionLabel(" `
    'const canPlaceRight = boxRight + gap + labelWidth <= overlayWidth;' `
    'const canPlaceRight = true;'
  Assert-RejectedInSection 'remove-left-edge-fallback' $page `
    '  private gestureAspectRatio(): number {' "`n`n  private objectDetectionLabel(" `
    '} else if (boxLeft >= labelWidth + gap) {' `
    '} else if (false) {'
  Assert-RejectedInSection 'remove-below-hand-fallback' $page `
    '  private gestureAspectRatio(): number {' "`n`n  private objectDetectionLabel(" `
    '} else if (canPlaceBelow) {' `
    '} else if (false) {'
  Assert-RejectedInSection 'remove-top-edge-fallback' $page `
    '  private gestureAspectRatio(): number {' "`n`n  private objectDetectionLabel(" `
    '} else if (boxTop >= labelHeight + gap) {' `
    '} else if (false) {'
  Assert-RejectedInSection 'remove-overlay-measurement' $page $previewStart $previewEnd `
    'this.gestureStillOverlayWidthVp = Number.isFinite(width) && width > 0 ? width : 0;' `
    'this.gestureStillOverlayWidthVp = 0;'
  Assert-RejectedInSection 'overflow-landscape-result' $page $previewStart $previewEnd `
    '.width(this.percentLength(this.gestureStillPreviewWidthPercent()))' `
    ".width('100%')"
  Assert-RejectedInSection 'overflow-portrait-result' $page $previewStart $previewEnd `
    '.height(this.percentLength(this.gestureStillPreviewHeightPercent()))' `
    ".height('100%')"
  Assert-RejectedInSection 'restore-overflowing-aspect-ratio' $page $previewStart $previewEnd `
    ".width(this.percentLength(this.gestureStillPreviewWidthPercent()))`n        .height(this.percentLength(this.gestureStillPreviewHeightPercent()))" `
    ".height('100%')`n        .aspectRatio(this.gestureAspectRatio())"
  Assert-RejectedInSection 'hardcode-result-separator' $page $layoutStart $layoutEnd `
    "Span(appString('feature_runtime_result_separator'))" `
    "Span('\uFF1A')"
  Assert-RejectedInSection 'break-contained-width-math' $page `
    '  private gestureAspectRatio(): number {' "`n`n  private objectDetectionLabel(" `
    'return sourceAspect >= cardAspect ? 100 : sourceAspect / cardAspect * 100;' `
    'return 100;'
  Assert-RejectedInSection 'break-result-update-order' $page `
    '  private updateGesturePreview(' "`n`n  private applyLiveGestureResultState" `
    "this.gestureImageUri = data.imageUri;`n    this.updateGestureImageOrientation(data.imageUri);`n    this.gestureDetections = data.result.gestures;" `
    "this.gestureImageUri = data.imageUri;`n    this.gestureDetections = data.result.gestures;`n    this.updateGestureImageOrientation(data.imageUri);"
  Assert-RejectedInSection 'remove-exif-oriented-decode' $gesture `
    'export class HarmonyGestureRegionEstimator' 'function gestureRegionDecodeOptions' `
    'pixelMap = await createPixelMapWithExifOrientation(imageSource, gestureRegionDecodeOptions());' `
    'pixelMap = await imageSource.createPixelMap(gestureRegionDecodeOptions());'
  Assert-RejectedInSection 'remove-top-level-scroll' $page $layoutStart $layoutEnd `
    'Scroll() {' `
    'Column() {'
  Assert-RejectedInSection 'restore-centered-short-content' $page $layoutStart $layoutEnd `
    '.align(Alignment.TopStart)' `
    '.align(Alignment.Center)'
  Assert-Rejected 'remove-route-scope' $catalog `
    'return workflow?.routeName === AppRoute.GESTURE_STILL.name;' `
    'return workflow !== undefined;'
  Assert-Rejected 'remove-production-wire' $build `
    "& (Join-Path `$PSScriptRoot 'check-static-gesture-layout-parity.ps1')" `
    "# & (Join-Path `$PSScriptRoot 'check-static-gesture-layout-parity.ps1')"
  Assert-Rejected 'remove-mutation-wire' $build `
    "& (Join-Path `$PSScriptRoot 'test-static-gesture-layout-guard.ps1')" `
    "# & (Join-Path `$PSScriptRoot 'test-static-gesture-layout-guard.ps1')"

  Write-Output 'Static gesture layout guard mutation fixtures passed.'
} finally {
  if ([IO.Directory]::Exists($tempRoot)) {
    $resolved = [IO.Path]::GetFullPath($tempRoot)
    if (-not $resolved.StartsWith($tempPrefix, [StringComparison]::OrdinalIgnoreCase)) {
      throw 'Static gesture guard fixture refused unsafe cleanup.'
    }
    [IO.Directory]::Delete($resolved, $true)
  }
}
