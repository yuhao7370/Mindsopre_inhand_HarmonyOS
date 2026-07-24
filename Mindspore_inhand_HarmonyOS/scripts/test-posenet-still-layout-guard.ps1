param(
  [string]$SourceRoot = ''
)

$ErrorActionPreference = 'Stop'
$utf8 = [Text.UTF8Encoding]::new($false)
$guardPath = Join-Path $PSScriptRoot 'check-posenet-still-layout-parity.ps1'
if ([string]::IsNullOrWhiteSpace($SourceRoot)) {
  $SourceRoot = Split-Path -Parent $PSScriptRoot
}
$SourceRoot = [IO.Path]::GetFullPath($SourceRoot)
$tempPrefix = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\', '/') +
  [IO.Path]::DirectorySeparatorChar
$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("posenet-still-guard-" + [Guid]::NewGuid().ToString('N'))

function Normalize-Text([string]$Text) {
  return $Text.Replace("`r`n", "`n").Replace("`r", "`n")
}

function Copy-Candidate([string]$Destination) {
  foreach ($relative in @(
    'entry\src\main\ets\pages\FeatureRuntimePage.ets',
    'entry\src\main\ets\features\runtime\FeatureWorkflowCatalog.ets',
    'entry\src\main\ets\services\ai\PoseService.ets',
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
    throw "PoseNet guard fixture expected one mutation target: $Before"
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
    throw "PoseNet guard fixture accepted mutation: $Name"
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
    throw "PoseNet guard fixture could not find section: $Name"
  }
  $Before = Normalize-Text $Before
  $After = Normalize-Text $After
  $section = $text.Substring($start, $end - $start)
  $relativeIndex = $section.IndexOf($Before, [StringComparison]::Ordinal)
  if ($relativeIndex -lt 0 -or
    $section.IndexOf($Before, $relativeIndex + $Before.Length, [StringComparison]::Ordinal) -ge 0) {
    throw "PoseNet guard fixture expected one section mutation target: $Name"
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
    throw "PoseNet guard fixture accepted mutation: $Name"
  }
}

try {
  & $guardPath -SourceRoot $SourceRoot | Out-Null
  [IO.Directory]::CreateDirectory($tempRoot) | Out-Null
  $page = 'entry\src\main\ets\pages\FeatureRuntimePage.ets'
  $catalog = 'entry\src\main\ets\features\runtime\FeatureWorkflowCatalog.ets'
  $pose = 'entry\src\main\ets\services\ai\PoseService.ets'
  $build = 'scripts\build-hap.ps1'

  Assert-Rejected 'sample-auto-run' $catalog `
    'shouldRunWorkflow: false' `
    'shouldRunWorkflow: true'
  $layoutStart = '  poseNetStillAndroidLayout() {'
  $layoutEnd = "`n`n  @Builder`n  gestureStillAndroidPreview()"
  $previewStart = '  poseNetStillAndroidPreview() {'
  $previewEnd = "`n`n  @Builder`n  poseNetStillAndroidLayout()"
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
    "Button(appString(this.statusKey === 'feature_runtime_pose_failed' ||`n              this.statusKey === 'feature_runtime_run_failed' ?`n              'web_retry' : 'feature_runtime_pose_detect_android'))" `
    "Button(appString('feature_runtime_pose_detect_android'))"
  Assert-RejectedInSection 'replace-current-input-on-run' $page $layoutStart $layoutEnd `
    '.onClick(() => this.runPrimaryAction())' `
    '.onClick(() => this.runPoseNetSampleDetection())'
  Assert-RejectedInSection 'break-picker-preservation' $page `
    '  private applyPickResult(' "`n`n  private aiRunInputs" `
    'this.applyPickedInputState(runtimePickedInputStateAfterCancelledPick(' `
    'this.applyPickedInputState(runtimePickedInputStateAfterAcceptedPick('
  Assert-RejectedInSection 'remove-overlay-orientation' $page $previewStart $previewEnd `
    "Image(this.poseNetStillImageSource(this.poseImageUri))`n            .orientation(this.poseImageOrientation)" `
    "Image(this.poseNetStillImageSource(this.poseImageUri))`n            .orientation(ImageRotateOrientation.UP)"
  Assert-RejectedInSection 'overflow-landscape-result' $page $previewStart $previewEnd `
    '.width(this.percentLength(this.poseNetStillPreviewWidthPercent()))' `
    ".width('100%')"
  Assert-RejectedInSection 'overflow-portrait-result' $page $previewStart $previewEnd `
    '.height(this.percentLength(this.poseNetStillPreviewHeightPercent()))' `
    ".height('100%')"
  Assert-RejectedInSection 'restore-overflowing-aspect-ratio' $page $previewStart $previewEnd `
    ".width(this.percentLength(this.poseNetStillPreviewWidthPercent()))`n        .height(this.percentLength(this.poseNetStillPreviewHeightPercent()))" `
    ".height('100%')`n        .aspectRatio(this.poseAspectRatio())"
  Assert-RejectedInSection 'hardcode-result-separator' $page $layoutStart $layoutEnd `
    "Span(appString('feature_runtime_result_separator'))" `
    "Span('\uFF1A')"
  Assert-RejectedInSection 'break-contained-width-math' $page `
    '  private poseAspectRatio(): number {' "`n`n  private objectDetectionAspectRatio(): number {" `
    'return sourceAspect >= cardAspect ? 100 : sourceAspect / cardAspect * 100;' `
    'return 100;'
  Assert-RejectedInSection 'break-result-update-order' $page `
    '  private updatePosePreview(' "`n`n  private updateGesturePreview" `
    "this.poseImageUri = data.imageUri;`n    this.updatePoseImageOrientation(data.imageUri);`n    this.posePoints = data.result.points;" `
    "this.poseImageUri = data.imageUri;`n    this.posePoints = data.result.points;`n    this.updatePoseImageOrientation(data.imageUri);"
  Assert-RejectedInSection 'remove-exif-read' $pose `
    'export class HarmonyMoveNetInputPreprocessor' 'class MindSporeLiteMoveNetRuntime' `
    'const rotationDegrees = await imageRotationDegreesFromImageSource(imageSource);' `
    'const rotationDegrees = 0;'
  Assert-RejectedInSection 'remove-top-level-scroll' $page $layoutStart $layoutEnd `
    'Scroll() {' `
    'Column() {'
  Assert-RejectedInSection 'restore-centered-short-content' $page $layoutStart $layoutEnd `
    '.align(Alignment.TopStart)' `
    '.align(Alignment.Center)'
  Assert-Rejected 'remove-production-wire' $build `
    "& (Join-Path `$PSScriptRoot 'check-posenet-still-layout-parity.ps1')" `
    "# & (Join-Path `$PSScriptRoot 'check-posenet-still-layout-parity.ps1')"
  Assert-Rejected 'remove-mutation-wire' $build `
    "& (Join-Path `$PSScriptRoot 'test-posenet-still-layout-guard.ps1')" `
    "# & (Join-Path `$PSScriptRoot 'test-posenet-still-layout-guard.ps1')"

  Write-Output 'PoseNet still layout guard mutation fixtures passed.'
} finally {
  if ([IO.Directory]::Exists($tempRoot)) {
    $resolved = [IO.Path]::GetFullPath($tempRoot)
    if (-not $resolved.StartsWith($tempPrefix, [StringComparison]::OrdinalIgnoreCase)) {
      throw 'PoseNet guard fixture refused unsafe cleanup.'
    }
    [IO.Directory]::Delete($resolved, $true)
  }
}
