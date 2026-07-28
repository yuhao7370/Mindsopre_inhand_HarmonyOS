param(
  [string]$SourceRoot = ''
)

$ErrorActionPreference = 'Stop'

function Fail([string]$Message) {
  throw "Static gesture layout guard failed: $Message"
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
$gestureService = Remove-ArkTsCommentsAndTemplateRaw (Read-Normalized (
    Join-Path $SourceRoot 'entry\src\main\ets\services\ai\GestureService.ets'
  ))
$buildScript = Read-Normalized (Join-Path $SourceRoot 'scripts\build-hap.ps1')

$selector = Section $catalog 'export function usesAndroidGestureStillLayout' `
  'export function runtimeInputKindsForWorkflow' 'static gesture route selector'
Require-Line $selector 'return workflow?.routeName === AppRoute.GESTURE_STILL.name;' `
  'the specialized layout must target only the static gesture route'
Require-Line $selector 'return usesAndroidGestureStillLayout(workflow) && !resultOk;' `
  'the failure Toast policy must remain scoped to failed static gesture results'

$geometry = Section $page '  private gestureAspectRatio(): number {' `
  "`n`n  private objectPhotoLabelPosition(" 'static gesture contained preview geometry'
foreach ($line in @(
  'private gestureStillPreviewWidthPercent(): number {',
  'const sourceAspect = this.gestureAspectRatio();',
  'const cardAspect = 4 / 3;',
  'return sourceAspect >= cardAspect ? 100 : sourceAspect / cardAspect * 100;',
  'private gestureStillPreviewHeightPercent(): number {',
  'return sourceAspect >= cardAspect ? cardAspect / sourceAspect * 100 : 100;'
)) {
  Require-Line $geometry $line "contained preview geometry is missing executable line: $line"
}

$labelGeometry = Section $page '  private gestureStillLabelPosition(' `
  "`n`n  private objectDetectionLabel(" 'static gesture label geometry'
foreach ($line in @(
  'private gestureStillLabelPosition(gesture: GestureDetection): GestureStillLabelPosition {',
  'const labelWidth = 88;',
  'const labelHeight = 24;',
  'const gap = 4;',
  'const canPlaceRight = boxRight + gap + labelWidth <= overlayWidth;',
  'const canPlaceBelow = boxBottom + gap + labelHeight <= overlayHeight;',
  'if (canPlaceRight) {',
  '} else if (canPlaceBelow) {',
  '} else if (boxLeft >= labelWidth + gap) {',
  '} else if (boxTop >= labelHeight + gap) {',
  'labelTop = boxBottom + gap;'
)) {
  Require-Line $labelGeometry $line "static gesture label geometry is missing executable line: $line"
}

$preview = Section $page '  gestureStillAndroidPreview() {' `
  "`n`n  @Builder`n  gestureStillAndroidLayout()" 'static gesture preview'
foreach ($line in @(
  'if (this.gestureImageUri.length > 0 && this.visibleGestureDetections().length > 0) {',
  'Image(this.gestureImageUri)',
  '.orientation(this.gestureImageOrientation)',
  '.objectFit(ImageFit.Fill)',
  'ForEach(this.visibleGestureDetections(), (gesture: GestureDetection) => {',
  'this.gestureStillBox(gesture)',
  '.width(this.percentLength(this.gestureStillPreviewWidthPercent()))',
  '.height(this.percentLength(this.gestureStillPreviewHeightPercent()))',
  '.onAreaChange((_previousArea: Area, currentArea: Area) => {',
  'this.gestureStillOverlayWidthVp = Number.isFinite(width) && width > 0 ? width : 0;',
  'this.gestureStillOverlayHeightVp = Number.isFinite(height) && height > 0 ? height : 0;',
  '} else if (this.imageInputUri.length > 0) {',
  'Image(this.imageInputUri)',
  '.objectFit(ImageFit.Contain)',
  "Image(`$r('app.media.icon_style'))",
  "Text(appString('workflow_summary_gesture_still_android_prompt'))",
  '.backgroundColor(AppColor.cardBackground)'
)) {
  Require-Line $preview $line "preview is missing executable line: $line"
}
Exclude $preview '.layoutWeight(9)' 'the preview must not use the old fixed-weight geometry'
Exclude $preview '.padding(50)' 'the preview must not use the old fixed inner padding'
Exclude $preview ".backgroundColor('#E6E6E6')" 'the preview must use the shared Harmony theme'
Exclude $preview '.aspectRatio(this.gestureAspectRatio())' `
  'the result overlay must use a contained region inside the fixed 4:3 card'

$box = Section $page '  gestureStillBox(gesture: GestureDetection) {' `
  "`n`n  @Builder`n  gestureBox(" 'static gesture overlay label'
foreach ($line in @(
  'Text(this.gestureLabelResource(gesture))',
  'Text(this.gestureScoreLabel(gesture))',
  '.maxFontScale(1.2)',
  '.width(88)',
  '.height(24)',
  'x: this.percentLength(this.gestureStillLabelPosition(gesture).left),',
  'y: this.percentLength(this.gestureStillLabelPosition(gesture).top)',
  '.border({ width: 2, color: AppColor.accent, radius: 2 })'
)) {
  Require-Line $box $line "static overlay label is missing executable line: $line"
}
Exclude $box '.translate({ y: -24 })' `
  'the static gesture label must use edge-aware placement instead of a fixed upward offset'

$builder = Section $page '  gestureStillAndroidLayout() {' `
  "`n`n  @Builder`n  textRecognitionPreview()" 'static gesture layout'
foreach ($line in @(
  'this.runtimeActionToolbar(false)',
  'Scroll() {',
  'Column({ space: AppSpacing.md }) {',
  'this.gestureStillAndroidPreview()',
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
  "Button(appString(this.statusKey === 'feature_runtime_gesture_failed' ||",
  "this.statusKey === 'feature_runtime_digit_failed' ||",
  "this.statusKey === 'feature_runtime_run_failed' ?",
  "'web_retry' : workflowRunActionKey(workflowForRoute(this.routeName))))",
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
  '.backgroundColor(AppColor.pageBackground)'
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
Exclude $builder ".backgroundColor('#F4F3F8')" 'the old Android action fill must be removed'
Exclude $builder ".backgroundColor('#E4E4E4')" 'duplicate Android dividers must be removed'
Exclude $actions '.layoutWeight(1)' 'the old fixed single-row action weight must be removed'

$pickResult = Section $page '  private applyPickResult(' `
  "`n`n  private aiRunInputs" 'picker result flow'
Require-Line $pickResult 'this.applyPickedInputState(runtimePickedInputStateAfterCancelledPick(' `
  'picker cancellation must restore the previous static gesture input state'

$gestureUpdate = Section $page '  private updateGesturePreview(' `
  "`n`n  private applyLiveGestureResultState" 'gesture result update'
$uriIndex = $gestureUpdate.IndexOf('this.gestureImageUri = data.imageUri;', [StringComparison]::Ordinal)
$orientationIndex = $gestureUpdate.IndexOf('this.updateGestureImageOrientation(data.imageUri);', [StringComparison]::Ordinal)
$detectionsIndex = $gestureUpdate.IndexOf('this.gestureDetections = data.result.gestures;', [StringComparison]::Ordinal)
if ($uriIndex -lt 0 -or $orientationIndex -le $uriIndex -or $detectionsIndex -le $orientationIndex) {
  Fail 'gesture URI, EXIF orientation, and coordinates must be committed in one ordered update'
}

$estimator = Section $gestureService 'export class HarmonyGestureRegionEstimator' `
  'function gestureRegionDecodeOptions' 'gesture region estimator'
Require-Line $estimator `
  'pixelMap = await createPixelMapWithExifOrientation(imageSource, gestureRegionDecodeOptions());' `
  'gesture inference must decode the same EXIF-oriented pixels shown by the overlay'
Require-Line $estimator 'const width = imageInfo.size.width;' `
  'gesture output width must use the oriented PixelMap'
Require-Line $estimator 'const height = imageInfo.size.height;' `
  'gesture output height must use the oriented PixelMap'

$layoutSelection = $page.Substring($page.IndexOf("  @Builder`n  runtimeLayoutContent() {"))
Require-Line $layoutSelection '} else if (usesAndroidGestureStillLayout(workflowForRoute(this.routeName))) {' `
  'runtime layout selection must retain the dedicated static gesture branch'
Require-Line $layoutSelection 'this.gestureStillAndroidLayout()' `
  'the static gesture route must render the dedicated layout'

$productionCall = "& (Join-Path `$PSScriptRoot 'check-static-gesture-layout-parity.ps1')"
$mutationCall = "& (Join-Path `$PSScriptRoot 'test-static-gesture-layout-guard.ps1')"
Require-Line $buildScript $productionCall 'build-hap must execute the production static gesture guard'
Require-Line $buildScript $mutationCall 'build-hap must execute the static gesture mutation runner'

Write-Output 'Static gesture layout parity guard passed.'
