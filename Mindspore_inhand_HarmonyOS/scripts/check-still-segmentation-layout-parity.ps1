param(
  [string]$SourceRoot = ''
)

$ErrorActionPreference = 'Stop'

function Get-NormalizedText([string]$Path) {
  return (Get-Content -Raw -Encoding UTF8 -LiteralPath $Path).Replace("`r`n", "`n").Replace("`r", "`n")
}

function Remove-ArkTsCommentsAndTemplateRaw([string]$Text, [bool]$PreserveQuotedLiterals = $false) {
  $result = [Text.StringBuilder]::new($Text.Length)
  $state = 'code'
  $terminator = [char]0
  $escaped = $false
  $interpolationDepths = [Collections.Generic.List[int]]::new()
  for ($index = 0; $index -lt $Text.Length; $index++) {
    $current = $Text[$index]
    $next = if ($index + 1 -lt $Text.Length) { $Text[$index + 1] } else { [char]0 }
    if ($state -eq 'lineComment') {
      if ($current -eq [char]0x0A) { [void]$result.Append($current); $state = 'code' } else { [void]$result.Append(' ') }
      continue
    }
    if ($state -eq 'blockComment') {
      if ($current -eq [char]0x2A -and $next -eq [char]0x2F) {
        [void]$result.Append('  '); $index++; $state = 'code'
      } elseif ($current -eq [char]0x0A) { [void]$result.Append($current) } else { [void]$result.Append(' ') }
      continue
    }
    if ($state -eq 'quotedLiteral') {
      if ($current -eq [char]0x0A) { [void]$result.Append($current) }
      elseif ($escaped) { [void]$result.Append($(if ($PreserveQuotedLiterals) { $current } else { ' ' })); $escaped = $false }
      elseif ($current -eq [char]0x5C) { [void]$result.Append($(if ($PreserveQuotedLiterals) { $current } else { ' ' })); $escaped = $true }
      elseif ($current -eq $terminator) { [void]$result.Append($current); $state = 'code' }
      else { [void]$result.Append($(if ($PreserveQuotedLiterals) { $current } else { ' ' })) }
      continue
    }
    if ($state -eq 'templateRaw') {
      if ($escaped) { [void]$result.Append(' '); $escaped = $false }
      elseif ($current -eq [char]0x5C) { [void]$result.Append(' '); $escaped = $true }
      elseif ($current -eq [char]0x0A) { [void]$result.Append($current) }
      elseif ($current -eq [char]0x60) { [void]$result.Append($current); $state = 'code' }
      elseif ($current -eq [char]0x24 -and $next -eq [char]0x7B) {
        [void]$result.Append('${'); $index++; $interpolationDepths.Add(1); $state = 'code'
      } else { [void]$result.Append(' ') }
      continue
    }
    if ($current -eq [char]0x2F -and $next -eq [char]0x2F) {
      [void]$result.Append('  '); $index++; $state = 'lineComment'
    } elseif ($current -eq [char]0x2F -and $next -eq [char]0x2A) {
      [void]$result.Append('  '); $index++; $state = 'blockComment'
    } elseif ($current -eq [char]0x27 -or $current -eq [char]0x22) {
      [void]$result.Append($current); $terminator = $current; $escaped = $false; $state = 'quotedLiteral'
    } elseif ($current -eq [char]0x60) {
      [void]$result.Append($current); $escaped = $false; $state = 'templateRaw'
    } elseif ($interpolationDepths.Count -gt 0 -and $current -eq [char]0x7B) {
      $last = $interpolationDepths.Count - 1; $interpolationDepths[$last]++; [void]$result.Append($current)
    } elseif ($interpolationDepths.Count -gt 0 -and $current -eq [char]0x7D) {
      $last = $interpolationDepths.Count - 1; $interpolationDepths[$last]--; [void]$result.Append($current)
      if ($interpolationDepths[$last] -eq 0) { $interpolationDepths.RemoveAt($last); $state = 'templateRaw' }
    } else { [void]$result.Append($current) }
  }
  return $result.ToString()
}

function Get-TextSection([string]$Text, [string]$StartMarker, [string]$EndMarker, [string]$Description) {
  $start = $Text.IndexOf($StartMarker, [StringComparison]::Ordinal)
  $end = if ($start -ge 0) { $Text.IndexOf($EndMarker, $start + $StartMarker.Length, [StringComparison]::Ordinal) } else { -1 }
  if ($start -lt 0 -or $end -le $start) { throw "Still segmentation parity guard failed: $Description was not found." }
  return $Text.Substring($start, $end - $start)
}

function Test-CodeLine([string]$Text, [string]$Line) {
  $normalizedLine = (Remove-ArkTsCommentsAndTemplateRaw $Line).Trim()
  return [regex]::IsMatch($Text, "(?m)^[\t ]*$([regex]::Escape($normalizedLine))[\t ]*$")
}

function Assert-CodeLine([string]$Text, [string]$Line, [string]$Message) {
  if (-not (Test-CodeLine $Text $Line)) { throw "Still segmentation parity guard failed: $Message" }
}

function Assert-LiteralCodeLine([string]$Text, [string]$Line, [string]$Message) {
  if (-not [regex]::IsMatch($Text, "(?m)^[\t ]*$([regex]::Escape($Line))[\t ]*$")) {
    throw "Still segmentation parity guard failed: $Message"
  }
}

function Assert-Contains([string]$Text, [string]$Marker, [string]$Message) {
  if (-not $Text.Contains($Marker)) { throw "Still segmentation parity guard failed: $Message" }
}

function Assert-Excludes([string]$Text, [string]$Marker, [string]$Message) {
  if ($Text.Contains($Marker)) { throw "Still segmentation parity guard failed: $Message ($Marker)." }
}

function Assert-Count([string]$Text, [string]$Marker, [int]$Expected, [string]$Message) {
  $actual = ($Text.Length - $Text.Replace($Marker, '').Length) / $Marker.Length
  if ($actual -ne $Expected) {
    throw "Still segmentation parity guard failed: $Message Expected $Expected, found $actual."
  }
}

function Get-CodeLineIndex([string]$Text, [string]$Line, [int]$StartAt = 0) {
  $normalizedLine = (Remove-ArkTsCommentsAndTemplateRaw $Line).Trim()
  $match = [regex]::new("^[\t ]*$([regex]::Escape($normalizedLine))[\t ]*$",
    [Text.RegularExpressions.RegexOptions]::Multiline).Match($Text, $StartAt)
  return $(if ($match.Success) { $match.Index } else { -1 })
}

$stripperProbe = @'
// Scroll() {
const quoted = 'Scroll() {';
const template = `Scroll() { ${/* INTERPOLATION_COMMENT */ executableCall()}`;
/* BLOCK_COMMENT */
executableCall()
'@
$strippedProbe = Remove-ArkTsCommentsAndTemplateRaw $stripperProbe
if (Test-CodeLine $strippedProbe 'Scroll() {') {
  throw 'Still segmentation parity guard failed: comments, strings, and template raw text must not spoof checks.'
}
Assert-CodeLine $strippedProbe 'executableCall()' 'comment/template stripper must preserve executable lines.'
Assert-Count $strippedProbe 'executableCall()' 2 'template interpolation code must remain executable.'

if ([string]::IsNullOrWhiteSpace($SourceRoot)) { $SourceRoot = Split-Path -Parent $PSScriptRoot }
$SourceRoot = [IO.Path]::GetFullPath($SourceRoot)
$catalogPath = Join-Path $SourceRoot 'entry\src\main\ets\features\runtime\FeatureWorkflowCatalog.ets'
$inputStatePath = Join-Path $SourceRoot 'entry\src\main\ets\features\runtime\FeatureRuntimeInputState.ets'
$pagePath = Join-Path $SourceRoot 'entry\src\main\ets\pages\FeatureRuntimePage.ets'
$servicePath = Join-Path $SourceRoot 'entry\src\main\ets\services\ai\SegmentationService.ets'
$buildPath = Join-Path $SourceRoot 'scripts\build-hap.ps1'

$catalogSource = Get-NormalizedText $catalogPath
$catalog = Remove-ArkTsCommentsAndTemplateRaw $catalogSource
$catalogWithLiterals = Remove-ArkTsCommentsAndTemplateRaw $catalogSource $true
$inputState = Remove-ArkTsCommentsAndTemplateRaw (Get-NormalizedText $inputStatePath)
$pageSource = Get-NormalizedText $pagePath
$page = Remove-ArkTsCommentsAndTemplateRaw $pageSource
$pageWithLiterals = Remove-ArkTsCommentsAndTemplateRaw $pageSource $true
$service = Remove-ArkTsCommentsAndTemplateRaw (Get-NormalizedText $servicePath)
$buildSource = Get-NormalizedText $buildPath

$selector = Get-TextSection $catalog 'export function usesAndroidStillSegmentationLayout' `
  'export function usesAndroidStillSceneLayout' 'exact still-segmentation selector'
Assert-CodeLine $selector 'return workflow?.routeName === AppRoute.SEGMENTATION_STILL.name;' `
  'selector must target only SEGMENTATION_STILL.'
Assert-Count $selector 'AppRoute.' 1 'selector must contain exactly one route target.'

$clearAtStart = Get-TextSection $catalog 'export function shouldClearRuntimeResultAtWorkflowStart' `
  'export function shouldKeepScreenOnForWorkflow' 'run-start preservation'
Assert-CodeLine $clearAtStart '!usesAndroidStillSegmentationLayout(workflow) &&' `
  'run start must preserve the last accepted still foreground.'

$preserveInput = Get-TextSection $catalogWithLiterals 'export function shouldPreserveRuntimeResultAfterInputReady' `
  'export function shouldPreserveRuntimeTextResultOnAiResult' 'input-ready preservation'
Assert-LiteralCodeLine $preserveInput `
  "(usesAndroidStillSegmentationLayout(workflow) && (inputKind === 'photo' || inputKind === 'camera')) ||" `
  'photo and camera input must preserve the last accepted foreground while the new run starts.'

$preserveVisual = Get-TextSection $catalogWithLiterals 'export function shouldPreserveRuntimeVisualResultOnAiResult' `
  'export function shouldPreserveRuntimeVisualResultOnLiveFrameFailure' 'AI-result preservation'
$stillVisual = Get-TextSection $preserveVisual 'if (usesAndroidStillSegmentationLayout(workflow)) {' `
  '  return false;' 'still visual branch'
Assert-LiteralCodeLine $stillVisual "return !resultOk || dataKind === 'segmentation';" `
  'failure must preserve the old foreground and only segmentation success may replace it.'

$saveGate = Get-TextSection $catalog 'export function compositeSegmentationSaveReady' `
  'export function shouldShowLiveGestureCameraOverlay' 'save readiness'
Assert-CodeLine $saveGate 'return !workflowRunning && foregroundReady && !saveInFlight;' `
  'save readiness must keep all three gates.'

$preview = Get-TextSection $page '  stillSegmentationAndroidPreview() {' `
  "`n`n  @Builder`n  stillSegmentationAndroidLayout()" 'still segmentation preview'
$previewWithLiterals = Get-TextSection $pageWithLiterals '  stillSegmentationAndroidPreview() {' `
  "`n`n  @Builder`n  stillSegmentationAndroidLayout()" 'still segmentation preview literals'
foreach ($line in @(
  'if (this.segmentationForegroundPixelMap !== undefined) {',
  'Image(this.segmentationForegroundPixelMap)',
  '} else if (this.imageInputUri.length > 0) {',
  'Image(this.imageInputUri)',
  '.objectFit(ImageFit.Contain)',
  "Image(`$r('app.media.feature_segmentation'))",
  "Text(appString('workflow_summary_segmentation'))",
  '.backgroundColor(AppColor.cardBackground)'
)) { Assert-CodeLine $preview $line "preview is missing executable line: $line" }
Assert-Count $preview '.objectFit(ImageFit.Contain)' 3 'foreground, input, and empty-state icon must all be contained.'
$foreground = Get-CodeLineIndex $preview 'if (this.segmentationForegroundPixelMap !== undefined) {'
$input = Get-CodeLineIndex $preview '} else if (this.imageInputUri.length > 0) {' ($foreground + 1)
if ($foreground -lt 0 -or $input -le $foreground) {
  throw 'Still segmentation parity guard failed: accepted foreground must take priority over ordinary input.'
}
foreach ($marker in @(
  '.orientation(this.segmentationImageOrientation)',
  'this.segmentationRectangles',
  'this.segmentationBackgroundImageUri',
  'this.backgroundImageUri',
  '.objectFit(ImageFit.Fill)'
)) { Assert-Excludes $preview $marker 'single preview must not mix generations, overlays, or composite background UI' }
Assert-Contains $previewWithLiterals `
  "Image(this.imageInputUri)`n          .width('100%')`n          .height('100%')`n          .objectFit(ImageFit.Contain)" `
  'ordinary input must use contained geometry.'

$layout = Get-TextSection $page '  stillSegmentationAndroidLayout() {' `
  "`n`n  @Builder`n  customModelAndroidLayout()" 'still segmentation layout'
$layoutWithLiterals = Get-TextSection $pageWithLiterals '  stillSegmentationAndroidLayout() {' `
  "`n`n  @Builder`n  customModelAndroidLayout()" 'still segmentation layout literals'
foreach ($line in @(
  'this.runtimeActionToolbar(false)',
  'Scroll() {',
  'Column({ space: AppSpacing.md }) {',
  'this.stillSegmentationAndroidPreview()',
  '.aspectRatio(4 / 3)',
  '.constraintSize({ minHeight: 220, maxHeight: 420 })',
  '.border({ width: 1, color: AppColor.divider, radius: AppRadius.card })',
  'Row({ space: AppSpacing.sm }) {',
  'if (this.workflowRunning || this.resultImageSaveInFlight) {',
  'LoadingProgress()',
  "Text(appString(this.resultImageSaveInFlight ? 'feature_runtime_save_image' : this.statusKey))",
  "if (!this.workflowRunning && !this.resultImageSaveInFlight &&",
  "(this.statusKey === 'feature_runtime_segmentation_failed' ||",
  "this.statusKey === 'feature_runtime_run_failed')) {",
  "Button(appString('web_retry'), { type: ButtonType.Normal })",
  '.onClick(() => this.runPrimaryAction())',
  'Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceBetween }) {',
  "Button(appString(workflowInputLabelKey(workflowForRoute(this.routeName), 'photo')), { type: ButtonType.Normal })",
  ".onClick(() => this.prepareInput('photo'))",
  "Button(appString(workflowInputLabelKey(workflowForRoute(this.routeName), 'camera')), { type: ButtonType.Normal })",
  ".onClick(() => this.prepareInput('camera'))",
  'Button(appString(workflowGoLiveLabelKey(workflowForRoute(this.routeName))), { type: ButtonType.Normal })',
  'this.openStillSegmentationLiveRoute()',
  'SaveButton({',
  '.enabled(compositeSegmentationSaveReady(this.workflowRunning,',
  'this.segmentationForegroundPixelMap !== undefined, this.resultImageSaveInFlight))',
  'this.saveStillSegmentationResultImage()',
  '.padding({ left: AppSpacing.page, right: AppSpacing.page, top: AppSpacing.md, bottom: AppSpacing.xl })',
  '.align(Alignment.TopStart)',
  '.scrollBar(BarState.Auto)',
  '.backgroundColor(AppColor.pageBackground)'
)) { Assert-CodeLine $layout $line "responsive layout is missing executable line: $line" }
Assert-Count $layout 'Scroll() {' 1 'layout must contain exactly one content Scroll.'

$status = Get-TextSection $layout 'Row({ space: AppSpacing.sm }) {' `
  'Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceBetween }) {' 'status/recovery card'
Assert-Count $status '.constraintSize({ minHeight: 48 })' 2 'status row and retry action must each have a 48vp minimum.'
Assert-Count $status '.maxFontScale(1.6)' 2 'status and retry labels must have bounded scaling.'

$actions = Get-TextSection $layout 'Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceBetween }) {' `
  "`n        }`n        .width(" 'four-action grid'
$actionsWithLiterals = Get-TextSection $layoutWithLiterals `
  'Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceBetween }) {' `
  "`n        }`n        .width(" 'four-action grid literals'
Assert-Count $actionsWithLiterals ".width('calc(50% - 4vp)')" 4 'all four actions must use the two-column grid.'
Assert-Count $actions '.constraintSize({ minHeight: 48 })' 4 'all four actions must have a 48vp minimum.'
Assert-Count $actions '.maxFontScale(1.6)' 4 'all four action labels must have bounded scaling.'
Assert-Count $actions '.enabled(!this.workflowRunning && !this.resultImageSaveInFlight)' 3 `
  'Photo, Camera, and Real-time must disable during inference and while the current foreground is being saved.'
$photo = Get-CodeLineIndex $actions ".onClick(() => this.prepareInput('photo'))"
$camera = Get-CodeLineIndex $actions ".onClick(() => this.prepareInput('camera'))" ($photo + 1)
$live = Get-CodeLineIndex $actions 'this.openStillSegmentationLiveRoute()' ($camera + 1)
$save = Get-CodeLineIndex $actions 'SaveButton({' ($live + 1)
if ($photo -lt 0 -or $camera -le $photo -or $live -le $camera -or $save -le $live) {
  throw 'Still segmentation parity guard failed: actions must remain Photo, Camera, Real-time, Save.'
}
foreach ($marker in @(
  '.height(37)',
  '.layoutWeight(4)',
  '.backgroundColor(Color.Black)',
  "Image(`$r('app.media.icon_default'))",
  'this.segmentationRectangles',
  'this.segmentationBackgroundImageUri',
  'this.resultRows',
  "'feature_runtime_inputs_title'",
  'this.runWorkflow()'
)) { Assert-Excludes $layoutWithLiterals $marker 'layout exposes forbidden legacy/generic UI' }

$pick = Get-TextSection $page '  private applyPickResult(' "`n`n  private aiRunInputs" 'picked-input state path'
Assert-CodeLine $pick 'this.applyPickedInputState(runtimePickedInputStateAfterCancelledPick(' `
  'picker cancellation must flow through the preserving helper.'
Assert-CodeLine $pick 'this.segmentationForegroundPixelMapOwner.invalidatePendingReplacement();' `
  'accepted input must invalidate pending replacement without clearing the current owner.'
Assert-Excludes $pick 'this.segmentationForegroundPixelMapOwner.clear();' `
  'accepted input must not clear the last accepted foreground.'

$cancel = Get-TextSection $inputState 'export function runtimePickedInputStateAfterCancelledPick' `
  'export function runtimePickedInputStateAfterModelCacheFailure' 'cancel preservation helper'
Assert-CodeLine $cancel "if (inputKind !== 'backgroundImage') {" `
  'non-background cancellation must return the existing picked-input state.'
Assert-CodeLine $cancel 'return state;' 'non-background cancellation must preserve every existing input field.'

$apply = Get-TextSection $page '  private async applyAiResult(' `
  "`n`n  private showObjectPhotoFailureToastIfNeeded" 'AI result application'
Assert-CodeLine $apply 'await this.updateSegmentationPreview(result, runtimeRequestId);' `
  'still foreground conversion must participate in the running lifecycle.'

$segmentation = Get-TextSection $page '  private async updateSegmentationPreview(' `
  "`n`n  private updatePosePreview" 'foreground replacement'
foreach ($line in @(
  'const requestId = this.segmentationForegroundPixelMapOwner.beginReplacement();',
  'const pixelMap = await styleTransferPixelMapFromRgbaOutput(rgba, width, height);',
  'if (this.segmentationForegroundPixelMapOwner.accept(requestId, pixelMap)) {',
  'this.segmentationForegroundPixelMap = pixelMap;',
  'const foregroundReady = await this.updateSegmentationForegroundPreview(data.result, runtimeRequestId);',
  'if (!foregroundReady) {',
  'this.segmentationForegroundPixelMapOwner.invalidatePendingReplacement();'
)) { Assert-CodeLine $segmentation $line "atomic foreground chain is missing: $line" }
Assert-Contains $segmentation `
  "if (stillSegmentation || liveSegmentation) {`n          this.segmentationForegroundPixelMapOwner.invalidatePendingReplacement();" `
  'current still-segmentation conversion failure must invalidate only the pending replacement.'

$saveWrapper = Get-TextSection $page '  private saveStillSegmentationResultImage(): void {' `
  "`n`n  private async saveResultComponentImageAsync" 'still save wrapper'
Assert-Count $saveWrapper 'compositeSegmentationSaveReady(this.workflowRunning,' 2 `
  'both click entry and async wrapper must reuse the complete three-gate readiness helper.'
Assert-Count $saveWrapper `
  'this.segmentationForegroundPixelMap !== undefined, this.resultImageSaveInFlight)' 2 `
  'both save layers must gate foreground readiness and single flight.'
Assert-Contains $saveWrapper `
  "private saveStillSegmentationResultImage(): void {`n    if (!compositeSegmentationSaveReady(this.workflowRunning," `
  'save click entry must immediately enforce the complete readiness helper.'
Assert-Contains $saveWrapper `
  "private async saveStillSegmentationResultImageAsync(): Promise<void> {`n    if (!compositeSegmentationSaveReady(this.workflowRunning," `
  'async save wrapper must immediately enforce the complete readiness helper.'
Assert-CodeLine $saveWrapper 'await this.saveResultPixelMapAsync(this.segmentationForegroundPixelMap);' `
  'save must use the current owned foreground PixelMap.'

$genericSave = Get-TextSection $page '  private async saveResultPixelMapAsync(' `
  "`n`n  private async performResultPixelMapSave(" 'single-flight save implementation'
foreach ($line in @(
  'if (this.resultImageSaveInFlight) {',
  'this.resultImageSaveInFlight = true;',
  'try {',
  'await this.performResultPixelMapSave(pixelMap);',
  '} finally {',
  'this.resultImageSaveInFlight = false;'
)) { Assert-CodeLine $genericSave $line "single-flight save structure is missing: $line" }
Assert-Count $genericSave 'this.resultImageSaveInFlight = true;' 1 `
  'single-flight acquire must occur exactly once in the save method.'
Assert-Count $genericSave 'this.resultImageSaveInFlight = false;' 1 `
  'single-flight release must occur exactly once in the save method.'
Assert-Contains $genericSave `
  "    this.resultImageSaveInFlight = true;`n    try {`n      await this.performResultPixelMapSave(pixelMap);`n    } finally {`n      this.resultImageSaveInFlight = false;`n    }" `
  'single-flight acquire must precede the save and the only release must remain inside its corresponding finally.'

$serviceRun = Get-TextSection $service 'export class HarmonySubjectSegmentationRunner' `
  "`n`nexport function segmentationConfigForAndroidScene" 'still segmentation service'
Assert-CodeLine $serviceRun `
  'const displaySize = rotatedImageSize(imageInfo.size.width, imageInfo.size.height, rotationDegrees);' `
  'mask dimensions must use EXIF-rotated display size.'
Assert-CodeLine $serviceRun `
  'pixelMap = await imageSource.createPixelMap(decodingOptionsWithImageRotation({}, rotationDegrees));' `
  'still input decode must apply the same EXIF rotation.'

$layoutSelection = Get-TextSection $page '  runtimeLayoutContent() {' `
  "`n    } else {`n      Scroll()" 'top-level layout selection'
Assert-CodeLine $layoutSelection 'this.stillSegmentationAndroidLayout()' `
  'top-level build must call the dedicated still layout.'

$guardCall = "& (Join-Path `$PSScriptRoot 'check-still-segmentation-layout-parity.ps1')"
$mutationCall = "& (Join-Path `$PSScriptRoot 'test-still-segmentation-layout-parity-guard.ps1')"
Assert-Count $buildSource $guardCall 1 'build-hap must contain exactly one production guard invocation.'
Assert-Count $buildSource $mutationCall 1 'build-hap must contain exactly one mutation invocation.'
$tokens = $null
$parseErrors = $null
$buildAst = [Management.Automation.Language.Parser]::ParseFile($buildPath, [ref]$tokens, [ref]$parseErrors)
if ($parseErrors.Count -ne 0) { throw 'Still segmentation parity guard failed: build-hap.ps1 must parse cleanly.' }
foreach ($call in @($guardCall, $mutationCall)) {
  $topLevelCalls = @($buildAst.EndBlock.Statements | Where-Object {
      $_.Extent.Text.Replace("`r`n", "`n").Trim() -eq $call
    })
  if ($topLevelCalls.Count -ne 1) {
    throw "Still segmentation parity guard failed: build-hap must execute one top-level call: $call"
  }
}

Write-Output 'Still image segmentation layout/state parity guard passed.'
