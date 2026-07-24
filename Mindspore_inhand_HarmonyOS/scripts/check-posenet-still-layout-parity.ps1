param(
  [string]$SourceRoot = ''
)

$ErrorActionPreference = 'Stop'

function Fail([string]$Message) {
  throw "PoseNet still layout guard failed: $Message"
}

function Normalize-Text([string]$Text) {
  return $Text.Replace("`r`n", "`n").Replace("`r", "`n")
}

function Read-Normalized([string]$Path) {
  if (-not [IO.File]::Exists($Path)) {
    Fail "missing source file: $Path"
  }
  return Normalize-Text ([IO.File]::ReadAllText($Path))
}

function Remove-ArkTsCommentsAndTemplateRaw([string]$Text) {
  $result = [Text.StringBuilder]::new($Text.Length)
  $state = 'code'
  $terminator = [char]0
  $escaped = $false
  $interpolationDepths = [Collections.Generic.List[int]]::new()
  for ($index = 0; $index -lt $Text.Length; $index++) {
    $current = $Text[$index]
    $next = if ($index + 1 -lt $Text.Length) { $Text[$index + 1] } else { [char]0 }
    if ($state -eq 'lineComment') {
      if ($current -eq [char]0x0A) {
        [void]$result.Append($current)
        $state = 'code'
      } else {
        [void]$result.Append(' ')
      }
      continue
    }
    if ($state -eq 'blockComment') {
      if ($current -eq [char]0x2A -and $next -eq [char]0x2F) {
        [void]$result.Append('  ')
        $index++
        $state = 'code'
      } elseif ($current -eq [char]0x0A) {
        [void]$result.Append($current)
      } else {
        [void]$result.Append(' ')
      }
      continue
    }
    if ($state -eq 'quotedLiteral') {
      [void]$result.Append($current)
      if ($escaped) {
        $escaped = $false
      } elseif ($current -eq [char]0x5C) {
        $escaped = $true
      } elseif ($current -eq $terminator) {
        $state = 'code'
      }
      continue
    }
    if ($state -eq 'templateRaw') {
      if ($escaped) {
        [void]$result.Append(' ')
        $escaped = $false
      } elseif ($current -eq [char]0x5C) {
        [void]$result.Append(' ')
        $escaped = $true
      } elseif ($current -eq [char]0x0A) {
        [void]$result.Append($current)
      } elseif ($current -eq [char]0x60) {
        [void]$result.Append($current)
        $state = 'code'
      } elseif ($current -eq [char]0x24 -and $next -eq [char]0x7B) {
        [void]$result.Append('${')
        $index++
        $interpolationDepths.Add(1)
        $state = 'code'
      } else {
        [void]$result.Append(' ')
      }
      continue
    }
    if ($current -eq [char]0x2F -and $next -eq [char]0x2F) {
      [void]$result.Append('  ')
      $index++
      $state = 'lineComment'
    } elseif ($current -eq [char]0x2F -and $next -eq [char]0x2A) {
      [void]$result.Append('  ')
      $index++
      $state = 'blockComment'
    } elseif ($current -eq [char]0x27 -or $current -eq [char]0x22) {
      [void]$result.Append($current)
      $terminator = $current
      $escaped = $false
      $state = 'quotedLiteral'
    } elseif ($current -eq [char]0x60) {
      [void]$result.Append($current)
      $escaped = $false
      $state = 'templateRaw'
    } elseif ($interpolationDepths.Count -gt 0 -and $current -eq [char]0x7B) {
      $last = $interpolationDepths.Count - 1
      $interpolationDepths[$last]++
      [void]$result.Append($current)
    } elseif ($interpolationDepths.Count -gt 0 -and $current -eq [char]0x7D) {
      $last = $interpolationDepths.Count - 1
      $interpolationDepths[$last]--
      [void]$result.Append($current)
      if ($interpolationDepths[$last] -eq 0) {
        $interpolationDepths.RemoveAt($last)
        $state = 'templateRaw'
      }
    } else {
      [void]$result.Append($current)
    }
  }
  return $result.ToString()
}

function Section(
  [string]$Text,
  [string]$StartMarker,
  [string]$EndMarker,
  [string]$Description
) {
  $start = $Text.IndexOf($StartMarker, [StringComparison]::Ordinal)
  $end = if ($start -ge 0) {
    $Text.IndexOf($EndMarker, $start + $StartMarker.Length, [StringComparison]::Ordinal)
  } else {
    -1
  }
  if ($start -lt 0 -or $end -le $start) {
    Fail "$Description was not found"
  }
  return $Text.Substring($start, $end - $start)
}

function Has-CodeLine([string]$Text, [string]$Line) {
  return [regex]::IsMatch($Text, "(?m)^[\t ]*$([regex]::Escape($Line))[\t ]*$")
}

function Require-Line([string]$Text, [string]$Line, [string]$Message) {
  if (-not (Has-CodeLine $Text $Line)) {
    Fail $Message
  }
}

function Require-LineCount([string]$Text, [string]$Line, [int]$Expected, [string]$Message) {
  $count = [regex]::Matches($Text, "(?m)^[\t ]*$([regex]::Escape($Line))[\t ]*$").Count
  if ($count -ne $Expected) {
    Fail "$Message Expected $Expected, found $count"
  }
}

function Exclude([string]$Text, [string]$Marker, [string]$Message) {
  if ($Text.Contains($Marker)) {
    Fail $Message
  }
}

if ([string]::IsNullOrWhiteSpace($SourceRoot)) {
  $SourceRoot = Split-Path -Parent $PSScriptRoot
}
$SourceRoot = [IO.Path]::GetFullPath($SourceRoot)
$page = Remove-ArkTsCommentsAndTemplateRaw (Read-Normalized (
    Join-Path $SourceRoot 'entry\src\main\ets\pages\FeatureRuntimePage.ets'
  ))
$catalog = Remove-ArkTsCommentsAndTemplateRaw (Read-Normalized (
    Join-Path $SourceRoot 'entry\src\main\ets\features\runtime\FeatureWorkflowCatalog.ets'
  ))
$poseService = Remove-ArkTsCommentsAndTemplateRaw (Read-Normalized (
    Join-Path $SourceRoot 'entry\src\main\ets\services\ai\PoseService.ets'
  ))
$buildScript = Read-Normalized (Join-Path $SourceRoot 'scripts\build-hap.ps1')

$selector = Section $catalog 'export function usesAndroidPoseNetStillLayout' `
  'export function usesAndroidGestureStillLayout' 'PoseNet route selector'
Require-Line $selector 'return workflow?.routeName === AppRoute.POSENET.name;' `
  'the specialized layout must target only the PoseNet still route'

$initialPreview = Section $catalog 'export function initialPreviewActionForWorkflow' `
  'export function initialLiveCameraPositionForWorkflow' 'initial sample policy'
Require-Line $initialPreview 'if (workflow.routeName !== AppRoute.POSENET.name) {' `
  'only PoseNet still may receive the bundled sample preview'
Require-Line $initialPreview "inputKind: 'sampleImage'," 'the bundled preview must remain a sample-image input'
Require-Line $initialPreview 'shouldRunWorkflow: false' 'the bundled sample must not auto-run'

$poseGeometry = Section $page '  private poseAspectRatio(): number {' `
  "`n`n  private objectDetectionAspectRatio(): number {" 'PoseNet contained preview geometry'
foreach ($line in @(
  'private poseNetStillPreviewWidthPercent(): number {',
  'const sourceAspect = this.poseAspectRatio();',
  'const cardAspect = 4 / 3;',
  'return sourceAspect >= cardAspect ? 100 : sourceAspect / cardAspect * 100;',
  'private poseNetStillPreviewHeightPercent(): number {',
  'return sourceAspect >= cardAspect ? cardAspect / sourceAspect * 100 : 100;'
)) {
  Require-Line $poseGeometry $line "contained preview geometry is missing executable line: $line"
}

$preview = Section $page '  poseNetStillAndroidPreview() {' `
  "`n`n  @Builder`n  poseNetStillAndroidLayout()" 'PoseNet still preview'
foreach ($line in @(
  'if (this.poseImageUri.length > 0 && this.posePoints.length > 0) {',
  'Image(this.poseNetStillImageSource(this.poseImageUri))',
  '.orientation(this.poseImageOrientation)',
  '.objectFit(ImageFit.Fill)',
  'ForEach(this.poseLines(), (line: PoseLine) => {',
  'this.poseNetStillPoseLine(line)',
  'ForEach(this.visiblePosePoints(), (point: PosePoint) => {',
  'this.poseNetStillPosePoint(point)',
  '.width(this.percentLength(this.poseNetStillPreviewWidthPercent()))',
  '.height(this.percentLength(this.poseNetStillPreviewHeightPercent()))',
  '} else if (this.imageInputUri.length > 0) {',
  'Image(this.poseNetStillImageSource(this.imageInputUri))',
  '.objectFit(ImageFit.Contain)',
  '.backgroundColor(AppColor.cardBackground)'
)) {
  Require-Line $preview $line "preview is missing executable line: $line"
}
Exclude $preview '.layoutWeight(9)' 'the preview must not use the old fixed-weight geometry'
Exclude $preview ".backgroundColor('#E6E6E6')" 'the preview must use the shared Harmony theme'
Exclude $preview '.aspectRatio(this.poseAspectRatio())' `
  'the result overlay must use a contained region instead of overflowing the fixed 4:3 card'

$builder = Section $page '  poseNetStillAndroidLayout() {' `
  "`n`n  @Builder`n  gestureStillAndroidPreview()" 'PoseNet still layout'
foreach ($line in @(
  'this.runtimeActionToolbar(false)',
  'Scroll() {',
  'Column({ space: AppSpacing.md }) {',
  'this.poseNetStillAndroidPreview()',
  '.aspectRatio(4 / 3)',
  '.constraintSize({ minHeight: 220, maxHeight: 420 })',
  '.border({ width: 1, color: AppColor.divider, radius: AppRadius.card })',
  'Row({ space: AppSpacing.sm }) {',
  'if (this.workflowRunning) {',
  'LoadingProgress()',
  'Text(appString(this.statusKey))',
  'Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceBetween }) {',
  "Button(appString('feature_input_photo_android'), { type: ButtonType.Normal })",
  ".onClick(() => this.prepareInput('photo'))",
  "Button(appString('feature_input_camera_android'), { type: ButtonType.Normal })",
  ".onClick(() => this.prepareInput('camera'))",
  "Button(appString('feature_runtime_go_live_android_hms'), { type: ButtonType.Normal })",
  '.onClick(() => this.openLinkedLiveRoute())',
  "Button(appString(this.statusKey === 'feature_runtime_pose_failed' ||",
  "this.statusKey === 'feature_runtime_run_failed' ?",
  "'web_retry' : 'feature_runtime_pose_detect_android'))",
  '.onClick(() => this.runPrimaryAction())',
  'if (this.resultRows.length > 0) {',
  'Text(appString(workflowResultTitleKey(workflowForRoute(this.routeName))))',
  'ForEach(this.resultRows, (row: AiRunResultRow) => {',
  'Span(appString(row.labelKey))',
  "Span(appString('feature_runtime_result_separator'))",
  'Span(this.resultRowValue(row))',
  '.padding({ left: AppSpacing.page, right: AppSpacing.page, top: AppSpacing.md, bottom: AppSpacing.xl })',
  '.align(Alignment.TopStart)',
  '.scrollBar(BarState.Auto)',
  ".backgroundColor(AppColor.pageBackground)"
)) {
  Require-Line $builder $line "layout is missing executable line: $line"
}
Require-LineCount $builder 'Scroll() {' 1 'the static page must expose one top-level content Scroll'
$status = Section $builder 'Row({ space: AppSpacing.sm }) {' `
  'Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceBetween }) {' 'status region'
$actions = Section $builder 'Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceBetween }) {' `
  'if (this.resultRows.length > 0) {' 'action grid'
Require-LineCount $status '.constraintSize({ minHeight: 48 })' 1 `
  'the status must have a 48vp minimum height'
Require-LineCount $status '.maxFontScale(1.6)' 1 'the status must have bounded scaling'
Require-LineCount $actions ".width('calc(50% - 4vp)')" 4 `
  'all four actions must use the two-column grid'
Require-LineCount $actions '.constraintSize({ minHeight: 48 })' 4 `
  'all four actions must have a 48vp minimum height'
Require-LineCount $actions '.maxFontScale(1.6)' 4 `
  'all four action labels must have bounded scaling'
Require-LineCount $actions '.enabled(!this.workflowRunning)' 3 `
  'photo, camera, and live actions must disable while inference runs'
Exclude $builder '.height(37)' 'the old undersized action height must be removed'
Exclude $actions '.layoutWeight(1)' 'the old fixed single-row action weight must be removed'
Exclude $builder '.onClick(() => this.runPoseNetSampleDetection())' `
  'Detect/Retry must rerun the current input rather than replacing it with the sample'

$pickResult = Section $page '  private applyPickResult(' `
  "`n`n  private aiRunInputs" 'picker result flow'
Require-Line $pickResult 'this.applyPickedInputState(runtimePickedInputStateAfterCancelledPick(' `
  'picker cancellation must restore the previous PoseNet input state'

$poseUpdate = Section $page '  private updatePosePreview(' `
  "`n`n  private updateGesturePreview" 'pose result update'
$uriIndex = $poseUpdate.IndexOf('this.poseImageUri = data.imageUri;', [StringComparison]::Ordinal)
$orientationIndex = $poseUpdate.IndexOf('this.updatePoseImageOrientation(data.imageUri);', [StringComparison]::Ordinal)
$pointsIndex = $poseUpdate.IndexOf('this.posePoints = data.result.points;', [StringComparison]::Ordinal)
if ($uriIndex -lt 0 -or $orientationIndex -le $uriIndex -or $pointsIndex -le $orientationIndex) {
  Fail 'pose URI, EXIF orientation, and coordinates must be committed in one ordered update'
}

$localPreprocessor = Section $poseService 'export class HarmonyMoveNetInputPreprocessor' `
  'class MindSporeLiteMoveNetRuntime' 'local MoveNet input preprocessor'
Require-Line $localPreprocessor 'const rotationDegrees = await imageRotationDegreesFromImageSource(imageSource);' `
  'the pose runner must read EXIF rotation'
Require-Line $localPreprocessor `
  'const displaySize = rotatedImageSize(imageInfo.size.width, imageInfo.size.height, rotationDegrees);' `
  'pose output dimensions must use the rotated display size'
Require-Line $localPreprocessor `
  'pixelMap = await imageSource.createPixelMap(decodingOptionsWithImageRotation({' `
  'pose inference must decode the same rotated pixels shown by the overlay'

$layoutSelection = $page.Substring($page.IndexOf("  @Builder`n  runtimeLayoutContent() {"))
Require-Line $layoutSelection '} else if (usesAndroidPoseNetStillLayout(workflowForRoute(this.routeName))) {' `
  'runtime layout selection must retain the dedicated PoseNet branch'
Require-Line $layoutSelection 'this.poseNetStillAndroidLayout()' `
  'the PoseNet route must render the dedicated layout'

$productionCall = "& (Join-Path `$PSScriptRoot 'check-posenet-still-layout-parity.ps1')"
$mutationCall = "& (Join-Path `$PSScriptRoot 'test-posenet-still-layout-guard.ps1')"
Require-Line $buildScript $productionCall 'build-hap must execute the production PoseNet guard'
Require-Line $buildScript $mutationCall 'build-hap must execute the PoseNet mutation runner'

Write-Output 'PoseNet still layout guard passed.'
