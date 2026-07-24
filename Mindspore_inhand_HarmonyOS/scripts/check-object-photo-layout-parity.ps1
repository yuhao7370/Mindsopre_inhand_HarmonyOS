param(
  [string]$SourceRoot = ''
)

$ErrorActionPreference = 'Stop'

function Get-NormalizedText([string]$Path) {
  return (Get-Content -Raw -Encoding UTF8 -LiteralPath $Path).Replace("`r`n", "`n").Replace("`r", "`n")
}

function Remove-ArkTsCommentsAndTemplateRaw(
  [string]$Text,
  [bool]$PreserveQuotedLiterals = $false
) {
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
      if ($current -eq [char]0x0A) {
        [void]$result.Append($current)
      } elseif ($escaped) {
        [void]$result.Append($(if ($PreserveQuotedLiterals) { $current } else { ' ' }))
        $escaped = $false
      } elseif ($current -eq [char]0x5C) {
        [void]$result.Append($(if ($PreserveQuotedLiterals) { $current } else { ' ' }))
        $escaped = $true
      } elseif ($current -eq $terminator) {
        [void]$result.Append($current)
        $state = 'code'
      } else {
        [void]$result.Append($(if ($PreserveQuotedLiterals) { $current } else { ' ' }))
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

function Get-TextSection(
  [string]$Text,
  [string]$StartMarker,
  [string]$EndMarker,
  [string]$Description
) {
  $start = $Text.IndexOf($StartMarker, [StringComparison]::Ordinal)
  $end = $Text.IndexOf($EndMarker, $start + $StartMarker.Length, [StringComparison]::Ordinal)
  if ($start -lt 0 -or $end -le $start) {
    throw "Object Photo parity guard failed: $Description was not found."
  }
  return $Text.Substring($start, $end - $start)
}

function Test-CodeLine([string]$Text, [string]$Line) {
  $normalizedLine = (Remove-ArkTsCommentsAndTemplateRaw $Line).Trim()
  return [regex]::IsMatch($Text, "(?m)^[\t ]*$([regex]::Escape($normalizedLine))[\t ]*$")
}

function Assert-CodeLine([string]$Text, [string]$Line, [string]$Message) {
  if (-not (Test-CodeLine $Text $Line)) {
    throw "Object Photo parity guard failed: $Message"
  }
}

function Get-CodeLineIndex([string]$Text, [string]$Line, [int]$StartAt = 0) {
  $normalizedLine = (Remove-ArkTsCommentsAndTemplateRaw $Line).Trim()
  $pattern = "^[\t ]*$([regex]::Escape($normalizedLine))[\t ]*$"
  $match = [regex]::new($pattern, [Text.RegularExpressions.RegexOptions]::Multiline).Match($Text, $StartAt)
  if ($match.Success) {
    return $match.Index
  }
  return -1
}

function Assert-LiteralCodeLine([string]$Text, [string]$Line, [string]$Message) {
  if (-not [regex]::IsMatch($Text, "(?m)^[\t ]*$([regex]::Escape($Line))[\t ]*$")) {
    throw "Object Photo parity guard failed: $Message"
  }
}

function Assert-Contains([string]$Text, [string]$Marker, [string]$Message) {
  if (-not $Text.Contains($Marker)) {
    throw "Object Photo parity guard failed: $Message"
  }
}

function Assert-Excludes([string]$Text, [string]$Marker, [string]$Message) {
  if ($Text.Contains($Marker)) {
    throw "Object Photo parity guard failed: $Message ($Marker)."
  }
}

function Assert-Count([string]$Text, [string]$Marker, [int]$Expected, [string]$Message) {
  $actual = ($Text.Length - $Text.Replace($Marker, '').Length) / $Marker.Length
  if ($actual -ne $Expected) {
    throw "Object Photo parity guard failed: $Message Expected $Expected, found $actual."
  }
}

$stripperProbe = @'
// this.runtimeActionToolbar(true)
const quoted = 'this.runtimeActionToolbar(true)';
const template = `this.runtimeActionToolbar(true) ${/* INTERPOLATION_COMMENT */ executableCall()}`;
/* BLOCK_COMMENT */
executableCall()
'@
$strippedProbe = Remove-ArkTsCommentsAndTemplateRaw $stripperProbe
if (Test-CodeLine $strippedProbe 'this.runtimeActionToolbar(true)') {
  throw 'Object Photo parity guard failed: comments, strings, and template raw text must not spoof code-line checks.'
}
Assert-CodeLine $strippedProbe 'executableCall()' 'comment/template stripper must preserve executable lines.'
Assert-Contains $strippedProbe '${' 'template interpolation boundary must remain executable.'
Assert-Count $strippedProbe 'executableCall()' 2 'template interpolation code must remain executable.'
Assert-Excludes $strippedProbe 'INTERPOLATION_COMMENT' 'comments inside template interpolation must be removed'
Assert-Excludes $strippedProbe 'BLOCK_COMMENT' 'block comments must be removed'

if ([string]::IsNullOrWhiteSpace($SourceRoot)) {
  $SourceRoot = Split-Path -Parent $PSScriptRoot
}
$SourceRoot = [IO.Path]::GetFullPath($SourceRoot)
$catalogPath = Join-Path $SourceRoot 'entry\src\main\ets\features\runtime\FeatureWorkflowCatalog.ets'
$pagePath = Join-Path $SourceRoot 'entry\src\main\ets\pages\FeatureRuntimePage.ets'
$preprocessorPath = Join-Path $SourceRoot 'entry\src\main\ets\services\ai\HarmonyObjectDetectionInputPreprocessor.ets'
$buildScriptPath = Join-Path $SourceRoot 'scripts\build-hap.ps1'

$catalogSource = Get-NormalizedText $catalogPath
$catalog = Remove-ArkTsCommentsAndTemplateRaw $catalogSource
$catalogWithLiterals = Remove-ArkTsCommentsAndTemplateRaw $catalogSource $true
$pageSource = Get-NormalizedText $pagePath
$page = Remove-ArkTsCommentsAndTemplateRaw $pageSource
$pageWithLiterals = Remove-ArkTsCommentsAndTemplateRaw $pageSource $true
$preprocessor = Remove-ArkTsCommentsAndTemplateRaw (Get-NormalizedText $preprocessorPath)

$workflow = Get-TextSection $catalogWithLiterals `
  '    routeName: AppRoute.OBJECT_PHOTO.name,' `
  '    routeName: AppRoute.OBJECT_CAMERA.name,' `
  'Object Photo workflow'
foreach ($line in @(
  "inputKinds: ['photo'],",
  "optionalInputKinds: ['modelFile'],",
  "requiredPermissions: ['media'],",
  "resultKind: 'detections',",
  'liveMode: false,'
)) {
  Assert-LiteralCodeLine $workflow $line "workflow contract is missing: $line"
}

$selector = Get-TextSection $catalog `
  'export function usesAndroidObjectPhotoLayout' `
  'export function usesAndroidStyleTransferLayout' `
  'Object Photo selector'
Assert-CodeLine $selector 'return workflow?.routeName === AppRoute.OBJECT_PHOTO.name;' `
  'selector must target only Object Photo.'
Assert-Count $selector 'AppRoute.' 1 'selector must contain exactly one route target.'

$preserveInput = Get-TextSection $catalog `
  'export function shouldPreserveRuntimeResultAfterInputReady' `
  'export function shouldPreserveRuntimeTextResultOnAiResult' `
  'Object Photo input preservation'
foreach ($line in @(
  '(usesAndroidObjectPhotoLayout(workflow) && (inputKind === ''photo'' || inputKind === ''modelFile'')) ||',
  '(usesAndroidCustomModelLayout(workflow) &&'
)) {
  Assert-CodeLine $preserveInput $line "input/cache preservation is missing: $line"
}

$preserveText = Get-TextSection $catalog `
  'export function shouldPreserveRuntimeTextResultOnAiResult' `
  'export function shouldPreserveRuntimeVisualResultOnAiResult' `
  'Object Photo text preservation'
Assert-CodeLine $preserveText `
  'return (usesAndroidStillSceneLayout(workflow) || usesAndroidObjectPhotoLayout(workflow)) && !resultOk;' `
  'failed Object Photo result rows must be preserved.'

$preserveVisual = Get-TextSection $catalog `
  'export function shouldPreserveRuntimeVisualResultOnAiResult' `
  'export function shouldPreserveRuntimeVisualResultOnLiveFrameFailure' `
  'Object Photo visual preservation'
Assert-CodeLine $preserveVisual 'if (usesAndroidObjectPhotoLayout(workflow)) {' `
  'Object Photo visual preservation branch is missing.'
$objectPhotoVisual = Get-TextSection $preserveVisual `
  'if (usesAndroidObjectPhotoLayout(workflow)) {' `
  'if (usesAndroidStyleTransferLayout(workflow)) {' `
  'Object Photo visual preservation branch'
Assert-CodeLine $objectPhotoVisual "return !resultOk || dataKind === 'objectDetections';" `
  'Object Photo failures must preserve the prior overlay and only object-detection success may replace it.'

$clearAtStart = Get-TextSection $catalog `
  'export function shouldClearRuntimeResultAtWorkflowStart' `
  'export function shouldKeepScreenOnForWorkflow' `
  'Object Photo run-start preservation'
Assert-CodeLine $clearAtStart '!usesAndroidObjectPhotoLayout(workflow) &&' `
  'Object Photo must retain its last valid result when a run starts.'

$initialInput = Get-TextSection $catalog `
  'export function initialInputKindForWorkflow' `
  'export function initialPreviewActionForWorkflow' `
  'Object Photo initial picker'
Assert-CodeLine $initialInput "return 'photo';" 'Object Photo must keep its automatic initial photo picker.'

$cancelPolicy = Get-TextSection $catalog `
  'export function shouldLeaveRuntimeAfterCancelledInitialPick' `
  'export function cancelledPickStatusKeyForWorkflow' `
  'Object Photo initial-cancel policy'
foreach ($line in @(
  'return initialPick &&',
  'workflow.routeName === AppRoute.OBJECT_PHOTO.name &&',
  "inputKind === 'photo';"
)) {
  Assert-CodeLine $cancelPolicy $line "initial-cancel route-exit contract is missing: $line"
}

$autoRun = Get-TextSection $catalog `
  'export function shouldAutoRunWorkflowAfterInputReady' `
  'export function shouldAutoRunStyleTransferAfterStyleReady' `
  'Object Photo auto-run policy'
Assert-CodeLine $autoRun `
  "if (workflow.routeName === AppRoute.OBJECT_PHOTO.name && inputKind === 'photo') {" `
  'a successfully picked Object Photo image must still auto-run.'

$geometry = Get-TextSection $page `
  '  private objectDetectionAspectRatio(): number {' `
  "`n`n  private gestureAspectRatio(): number {" `
  'Object Photo contained geometry'
foreach ($line in @(
  'private objectPhotoPreviewWidthPercent(): number {',
  'const sourceAspect = this.objectDetectionAspectRatio();',
  'const cardAspect = 4 / 3;',
  'return sourceAspect >= cardAspect ? 100 : sourceAspect / cardAspect * 100;',
  'private objectPhotoPreviewHeightPercent(): number {',
  'return sourceAspect >= cardAspect ? cardAspect / sourceAspect * 100 : 100;'
)) {
  Assert-CodeLine $geometry $line "contained result geometry is missing: $line"
}

$labelGeometry = Get-TextSection $page `
  '  private objectPhotoLabelPosition(' `
  "`n`n  private gestureStillLabelPosition(" `
  'Object Photo label geometry'
foreach ($line in @(
  'const overlayWidth = this.objectPhotoOverlayWidthVp;',
  'const overlayHeight = this.objectPhotoOverlayHeightVp;',
  'const labelWidth = 112;',
  'const labelHeight = 24;',
  'const gap = 4;',
  'const canPlaceRight = boxRight + gap + labelWidth <= overlayWidth;',
  'const canPlaceBelow = boxBottom + gap + labelHeight <= overlayHeight;',
  'if (canPlaceRight) {',
  '} else if (canPlaceBelow) {',
  '} else if (boxLeft >= labelWidth + gap) {',
  '} else if (boxTop >= labelHeight + gap) {',
  'labelLeft = Math.min(Math.max(labelLeft, 0), Math.max(0, overlayWidth - labelWidth));',
  'labelTop = Math.min(Math.max(labelTop, 0), Math.max(0, overlayHeight - labelHeight));'
)) {
  Assert-CodeLine $labelGeometry $line "edge-aware label geometry is missing: $line"
}

$box = Get-TextSection $page `
  '  objectPhotoDetectionBox(detection: ObjectDetection, index: number) {' `
  "`n`n  @Builder`n  objectDetectionBox(" `
  'Object Photo detection box'
foreach ($line in @(
  'Stack({ alignContent: Alignment.TopStart }) {',
  '.border({ width: 2, color: objectDetectionOverlayColor(index), radius: 2 })',
  'Text(this.objectDetectionLabel(detection, index))',
  '.fontColor(objectDetectionOverlayTextColor(index))',
  '.backgroundColor(objectDetectionOverlayColor(index))',
  '.maxFontScale(1.2)',
  '.maxLines(1)',
  '.textOverflow({ overflow: TextOverflow.Ellipsis })',
  '.width(112)',
  '.height(24)',
  'x: this.percentLength(this.objectPhotoLabelPosition(detection).left),',
  'y: this.percentLength(this.objectPhotoLabelPosition(detection).top)'
)) {
  Assert-CodeLine $box $line "route-local detection overlay is missing: $line"
}

$preview = Get-TextSection $page `
  '  objectPhotoAndroidPreview() {' `
  "`n`n  @Builder`n  objectPhotoAndroidLayout()" `
  'Object Photo preview'
$previewWithLiterals = Get-TextSection $pageWithLiterals `
  '  objectPhotoAndroidPreview() {' `
  "`n`n  @Builder`n  objectPhotoAndroidLayout()" `
  'Object Photo preview with literals'
foreach ($line in @(
  'if (this.objectDetectionImageUri.length > 0 && this.objectDetections.length > 0) {',
  'Image(this.objectDetectionImageUri)',
  '.orientation(this.objectDetectionImageOrientation)',
  '.objectFit(ImageFit.Fill)',
  'this.objectPhotoDetectionBox(detection, index)',
  '.width(this.percentLength(this.objectPhotoPreviewWidthPercent()))',
  '.height(this.percentLength(this.objectPhotoPreviewHeightPercent()))',
  '.onAreaChange((_previousArea: Area, currentArea: Area) => {',
  'this.objectPhotoOverlayWidthVp = Number.isFinite(width) && width > 0 ? width : 0;',
  'this.objectPhotoOverlayHeightVp = Number.isFinite(height) && height > 0 ? height : 0;',
  '} else if (this.imageInputUri.length > 0) {',
  'Image(this.imageInputUri)',
  '.objectFit(ImageFit.Contain)',
  "Text(appString('feature_runtime_help_object_photo'))",
  '.backgroundColor(AppColor.cardBackground)'
)) {
  Assert-CodeLine $preview $line "preview contract is missing: $line"
}
Assert-Excludes $preview '.aspectRatio(this.objectDetectionAspectRatio())' `
  'the result must use a contained inner plane rather than an unbounded source-aspect card'
Assert-Excludes $preview 'this.objectDetectionBox(detection, index)' `
  'Object Photo must use its route-local measured label overlay'
Assert-Contains $previewWithLiterals `
  "Image(this.imageInputUri)`n          .width('100%')`n          .height('100%')`n          .objectFit(ImageFit.Contain)" `
  'ordinary Object Photo input must use ImageFit.Contain.'

$layout = Get-TextSection $page `
  '  objectPhotoAndroidLayout() {' `
  "`n`n  @Builder`n  styleTransferAndroidLayout()" `
  'Object Photo layout'
$layoutWithLiterals = Get-TextSection $pageWithLiterals `
  '  objectPhotoAndroidLayout() {' `
  "`n`n  @Builder`n  styleTransferAndroidLayout()" `
  'Object Photo layout with literals'
foreach ($line in @(
  'this.runtimeActionToolbar(true)',
  'Scroll() {',
  'Column({ space: AppSpacing.md }) {',
  'this.objectPhotoAndroidPreview()',
  '.aspectRatio(4 / 3)',
  '.constraintSize({ minHeight: 220, maxHeight: 420 })',
  '.border({ width: 1, color: AppColor.divider, radius: AppRadius.card })',
  'Row({ space: AppSpacing.sm }) {',
  'if (this.workflowRunning) {',
  'LoadingProgress()',
  'Text(appString(this.statusKey))',
  'Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceBetween }) {',
  "Button(appString(workflowInputLabelKey(workflowForRoute(this.routeName), 'photo')), { type: ButtonType.Normal })",
  ".onClick(() => this.prepareInput('photo'))",
  "Button(appString(this.statusKey === 'feature_runtime_object_detection_failed' ||",
  "this.statusKey === 'feature_runtime_run_failed' ?",
  "'web_retry' : this.runActionKey))",
  '.onClick(() => this.runPrimaryAction())',
  'if (this.resultRows.length > 0) {',
  'Text(appString(workflowResultTitleKey(workflowForRoute(this.routeName))))',
  'ForEach(this.resultRows, (row: AiRunResultRow) => {',
  "Span(appString('feature_runtime_result_separator'))",
  '.padding({ left: AppSpacing.page, right: AppSpacing.page, top: AppSpacing.md, bottom: AppSpacing.xl })',
  '.align(Alignment.TopStart)',
  '.scrollBar(BarState.Auto)',
  '.backgroundColor(AppColor.pageBackground)'
)) {
  Assert-CodeLine $layout $line "responsive layout is missing: $line"
}
Assert-Count $layout 'Scroll() {' 1 'layout must contain exactly one top-level content Scroll.'
$status = Get-TextSection $layout `
  'Row({ space: AppSpacing.sm }) {' `
  'Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceBetween }) {' `
  'Object Photo status card'
$actions = Get-TextSection $layout `
  'Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceBetween }) {' `
  'if (this.resultRows.length > 0) {' `
  'Object Photo action grid'
$actionsWithLiterals = Get-TextSection $layoutWithLiterals `
  'Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceBetween }) {' `
  'if (this.resultRows.length > 0) {' `
  'Object Photo action grid with literals'
Assert-Count $status '.constraintSize({ minHeight: 48 })' 1 'status must have a 48vp minimum height.'
Assert-Count $status '.maxFontScale(1.6)' 1 'status text must have bounded scaling.'
Assert-Count $actionsWithLiterals ".width('calc(50% - 4vp)')" 2 'both actions must use the two-column grid.'
Assert-Count $actions '.constraintSize({ minHeight: 48 })' 2 'both actions must have a 48vp minimum height.'
Assert-Count $actions '.maxFontScale(1.6)' 2 'both action labels must have bounded scaling.'
Assert-Count $actions '.enabled(!this.workflowRunning)' 1 'photo action must disable while inference runs.'
foreach ($marker in @(
  'modelFile',
  'feature_runtime_object_select_model',
  "prepareInput('modelFile')",
  '.height(37)',
  "backgroundColor('#33B5E5')",
  'feature_runtime_inputs_title',
  'feature_runtime_permissions_title',
  'feature_runtime_debug',
  'resultImageSaveControl(',
  'resultComponentImageSaveControl('
)) {
  Assert-Excludes $layoutWithLiterals $marker 'Object Photo layout exposes forbidden legacy/generic UI'
}
foreach ($marker in @(
  'modelFile',
  'feature_runtime_object_select_model',
  "prepareInput('modelFile')"
)) {
  Assert-Excludes $previewWithLiterals $marker 'Object Photo preview exposes a forbidden model action'
}
Assert-Excludes $actions '.layoutWeight(1)' 'actions must not use the old fixed single-row weight.'

$pickResult = Get-TextSection $page `
  '  private applyPickResult(' `
  "`n`n  private aiRunInputs" `
  'Object Photo picker result flow'
Assert-CodeLine $pickResult `
  'this.applyPickedInputState(runtimePickedInputStateAfterCancelledPick(' `
  'later picker cancellation must preserve the selected input.'
Assert-CodeLine $pickResult `
  'if (workflow && shouldLeaveRuntimeAfterCancelledInitialPick(workflow, inputKind, initialPick)) {' `
  'only the initial Object Photo cancellation may leave the route.'
Assert-CodeLine $pickResult 'router.back();' 'initial picker cancellation must return from the route.'

$update = Get-TextSection $page `
  '  private updateObjectDetectionPreview(result: AiRunResult): void {' `
  "`n`n  private async updateSegmentationPreview" `
  'Object Photo atomic result update'
$uriIndex = Get-CodeLineIndex $update 'this.objectDetectionImageUri = data.imageUri;'
$orientationIndex = Get-CodeLineIndex $update 'this.updateObjectDetectionImageOrientation(data.imageUri);' ($uriIndex + 1)
$detectionsIndex = Get-CodeLineIndex $update 'this.objectDetections = data.detections;' ($orientationIndex + 1)
$widthIndex = Get-CodeLineIndex $update 'this.objectDetectionImageWidth = this.objectDetectionSourceWidth(data.detections);' ($detectionsIndex + 1)
$heightIndex = Get-CodeLineIndex $update 'this.objectDetectionImageHeight = this.objectDetectionSourceHeight(data.detections);' ($widthIndex + 1)
if ($uriIndex -lt 0 -or $orientationIndex -le $uriIndex -or $detectionsIndex -le $orientationIndex -or
  $widthIndex -le $detectionsIndex -or $heightIndex -le $widthIndex) {
  throw 'Object Photo parity guard failed: URI, EXIF orientation, detections, and source size must update together.'
}

foreach ($line in @(
  'const rotationDegrees = await imageRotationDegreesFromImageSource(imageSource);',
  'const displaySize = rotatedImageSize(imageInfo.size.width, imageInfo.size.height, rotationDegrees);',
  'pixelMap = await imageSource.createPixelMap(decodingOptionsWithImageRotation(',
  'imageWidth: displaySize.width,',
  'imageHeight: displaySize.height'
)) {
  Assert-CodeLine $preprocessor $line "EXIF-oriented inference contract is missing: $line"
}

$cacheCaller = Get-TextSection $page `
  '  private async cacheAndApplyPickedModelFile(' `
  "`n`n  private applyModelFileCacheResult" `
  'model cache caller'
$currentIndex = Get-CodeLineIndex $cacheCaller 'if (!isInputPreparationRequestCurrent(requestId, this.inputPreparationRequestId)) {'
$staleIndex = Get-CodeLineIndex $cacheCaller 'if (cacheResult === undefined) {' ($currentIndex + 1)
$applyIndex = Get-CodeLineIndex $cacheCaller 'this.applyModelFileCacheResult(cacheResult, inputKind);' ($staleIndex + 1)
if ($currentIndex -lt 0 -or $staleIndex -le $currentIndex -or $applyIndex -le $staleIndex) {
  throw 'Object Photo parity guard failed: stale model-cache work must be rejected before applying success.'
}

$cacheResult = Get-TextSection $page `
  '  private applyModelFileCacheResult(' `
  "`n`n  private showCustomModelCacheToastIfNeeded" `
  'model cache success handler'
$failureReturnIndex = Get-CodeLineIndex $cacheResult 'return;'
$applyPickIndex = Get-CodeLineIndex $cacheResult 'this.applyPickResult({' ($failureReturnIndex + 1)
$followupIndex = Get-CodeLineIndex $cacheResult `
  'const followupInputKind = objectPhotoFollowupInputKindAfterModelCacheSuccess(workflow, inputKind);' `
  ($applyPickIndex + 1)
$initialPickIndex = Get-CodeLineIndex $cacheResult 'this.prepareInput(followupInputKind, true);' ($followupIndex + 1)
if ($failureReturnIndex -lt 0 -or $applyPickIndex -le $failureReturnIndex -or
  $followupIndex -le $applyPickIndex -or $initialPickIndex -le $followupIndex) {
  throw 'Object Photo parity guard failed: only successful cached models may open the follow-up initial photo picker.'
}

$build = $page.Substring($page.IndexOf("`n  @Builder`n  runtimeLayoutContent() {", [StringComparison]::Ordinal))
Assert-CodeLine $build '} else if (usesAndroidObjectPhotoLayout(workflowForRoute(this.routeName))) {' `
  'runtime layout selection must retain the dedicated Object Photo branch.'
Assert-CodeLine $build 'this.objectPhotoAndroidLayout()' `
  'the Object Photo route must render its dedicated layout.'

$buildScript = Get-NormalizedText $buildScriptPath
$guardCall = "& (Join-Path `$PSScriptRoot 'check-object-photo-layout-parity.ps1')"
$mutationCall = "& (Join-Path `$PSScriptRoot 'test-object-photo-layout-parity-guard.ps1')"
Assert-Count $buildScript $guardCall 1 'build-hap must contain one Object Photo guard invocation.'
Assert-Count $buildScript $mutationCall 1 'build-hap must contain one Object Photo mutation invocation.'
$tokens = $null
$parseErrors = $null
$buildAst = [Management.Automation.Language.Parser]::ParseFile(
  $buildScriptPath,
  [ref]$tokens,
  [ref]$parseErrors
)
if ($parseErrors.Count -ne 0) {
  throw 'Object Photo parity guard failed: build-hap.ps1 must parse cleanly.'
}
foreach ($call in @($guardCall, $mutationCall)) {
  $topLevelCalls = @($buildAst.EndBlock.Statements | Where-Object {
      $_.Extent.Text.Replace("`r`n", "`n").Trim() -eq $call
    })
  if ($topLevelCalls.Count -ne 1) {
    throw "Object Photo parity guard failed: build-hap must execute one top-level call: $call"
  }
}

Write-Output 'Object Photo layout parity guard passed.'
