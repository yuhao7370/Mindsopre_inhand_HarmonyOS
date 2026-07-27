param(
  [string]$SourceRoot = ''
)

$ErrorActionPreference = 'Stop'

function Fail([string]$Message) {
  throw "Portrait runtime UI guard failed: $Message"
}

function Read-Normalized([string]$Path) {
  if (-not [IO.File]::Exists($Path)) { Fail "missing source file: $Path" }
  return ([IO.File]::ReadAllText($Path)).Replace("`r`n", "`n").Replace("`r", "`n")
}

function Convert-ArkTsToGuardCode([string]$Text) {
  $result = [Text.StringBuilder]::new($Text.Length)
  $literal = [Text.StringBuilder]::new()
  $state = 'code'
  $quote = [char]0
  $escaped = $false
  for ($index = 0; $index -lt $Text.Length; $index++) {
    $current = $Text[$index]
    $next = if ($index + 1 -lt $Text.Length) { $Text[$index + 1] } else { [char]0 }
    if ($state -eq 'line') {
      if ($current -eq [char]0x0A) { [void]$result.Append($current); $state = 'code' }
      else { [void]$result.Append(' ') }
      continue
    }
    if ($state -eq 'block') {
      if ($current -eq [char]0x2A -and $next -eq [char]0x2F) {
        [void]$result.Append('  '); $index++; $state = 'code'
      } elseif ($current -eq [char]0x0A) { [void]$result.Append($current) }
      else { [void]$result.Append(' ') }
      continue
    }
    if ($state -eq 'string') {
      if ($escaped) { [void]$literal.Append($current); $escaped = $false }
      elseif ($current -eq [char]0x5C) { [void]$literal.Append($current); $escaped = $true }
      elseif ($current -eq $quote) {
        $hex = [BitConverter]::ToString([Text.Encoding]::UTF8.GetBytes($literal.ToString())).Replace('-', '')
        [void]$result.Append("__ARK_LITERAL_${hex}__")
        $literal.Clear() | Out-Null
        $state = 'code'
      } elseif ($current -eq [char]0x0A) {
        [void]$literal.Append($current); [void]$result.Append($current)
      } else { [void]$literal.Append($current) }
      continue
    }
    if ($current -eq [char]0x2F -and $next -eq [char]0x2F) {
      [void]$result.Append('  '); $index++; $state = 'line'
    } elseif ($current -eq [char]0x2F -and $next -eq [char]0x2A) {
      [void]$result.Append('  '); $index++; $state = 'block'
    } elseif ($current -eq [char]0x22 -or $current -eq [char]0x27 -or $current -eq [char]0x60) {
      $quote = $current; $escaped = $false; $state = 'string'
    } else { [void]$result.Append($current) }
  }
  if ($state -eq 'string') { Fail 'unterminated ArkTS literal while parsing guard source.' }
  return $result.ToString()
}

function Balanced-Section([string]$CodeText, [string]$Start, [string]$Name) {
  $startIndex = $CodeText.IndexOf($Start, [StringComparison]::Ordinal)
  if ($startIndex -lt 0) { Fail "missing $Name start marker: $Start" }
  $openIndex = $CodeText.IndexOf('{', $startIndex)
  if ($openIndex -lt 0) { Fail "missing $Name opening brace." }
  $depth = 0
  for ($index = $openIndex; $index -lt $CodeText.Length; $index++) {
    if ($CodeText[$index] -eq '{') { $depth++ }
    elseif ($CodeText[$index] -eq '}') {
      $depth--
      if ($depth -eq 0) { return $CodeText.Substring($startIndex, $index - $startIndex + 1) }
    }
  }
  Fail "missing $Name closing brace."
}

function Assert-Contains([string]$Text, [string]$Marker, [string]$Message) {
  $codeMarker = Convert-ArkTsToGuardCode $Marker
  if ($Text.IndexOf($codeMarker, [StringComparison]::Ordinal) -lt 0) { Fail $Message }
}

function Assert-Excludes([string]$Text, [string]$Marker, [string]$Message) {
  $codeMarker = Convert-ArkTsToGuardCode $Marker
  if ($Text.IndexOf($codeMarker, [StringComparison]::Ordinal) -ge 0) { Fail $Message }
}

function Assert-Count([string]$Text, [string]$Marker, [int]$Expected, [string]$Message) {
  $codeMarker = Convert-ArkTsToGuardCode $Marker
  $actual = ([regex]::Matches($Text, [regex]::Escape($codeMarker))).Count
  if ($actual -ne $Expected) { Fail "$Message Expected $Expected, found $actual." }
}

function Assert-TopLevelBuildExecution([string]$BuildPath, [string]$ScriptName) {
  $tokens = $null
  $parseErrors = $null
  $ast = [Management.Automation.Language.Parser]::ParseFile($BuildPath, [ref]$tokens, [ref]$parseErrors)
  if ($parseErrors.Count -gt 0) { Fail 'build-hap.ps1 has parse errors.' }
  $expected = "& (Join-Path `$PSScriptRoot '$ScriptName')"
  $matches = @($ast.EndBlock.Statements | Where-Object { $_.Extent.Text.Trim() -eq $expected })
  if ($matches.Count -ne 1) { Fail "build-hap.ps1 must execute $ScriptName exactly once; found $($matches.Count)." }
}

$root = if ($SourceRoot) { [IO.Path]::GetFullPath($SourceRoot) } else {
  [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
}
$pagePath = Join-Path $root 'entry\src\main\ets\pages\FeatureRuntimePage.ets'
$experienceCatalogPath = Join-Path $root 'entry\src\main\ets\common\data\FeatureCatalog.ets'
$catalogPath = Join-Path $root 'entry\src\main\ets\features\runtime\FeatureWorkflowCatalog.ets'
$inputStatePath = Join-Path $root 'entry\src\main\ets\features\runtime\FeatureRuntimeInputState.ets'
$backgroundCatalogPath = Join-Path $root 'entry\src\main\ets\features\runtime\PortraitSegmentationBackgroundCatalog.ets'
$aiServicePath = Join-Path $root 'entry\src\main\ets\services\ai\AiService.ets'
$segmentationServicePath = Join-Path $root 'entry\src\main\ets\services\ai\SegmentationService.ets'
$cameraServicePath = Join-Path $root 'entry\src\main\ets\services\camera\LiveCameraService.ets'
$buildPath = Join-Path $root 'scripts\build-hap.ps1'
$page = Convert-ArkTsToGuardCode (Read-Normalized $pagePath)
$experienceCatalog = Convert-ArkTsToGuardCode (Read-Normalized $experienceCatalogPath)
$catalog = Convert-ArkTsToGuardCode (Read-Normalized $catalogPath)
$inputState = Convert-ArkTsToGuardCode (Read-Normalized $inputStatePath)
$backgroundCatalog = Convert-ArkTsToGuardCode (Read-Normalized $backgroundCatalogPath)
$aiService = Convert-ArkTsToGuardCode (Read-Normalized $aiServicePath)
$segmentationService = Convert-ArkTsToGuardCode (Read-Normalized $segmentationServicePath)
$cameraService = Convert-ArkTsToGuardCode (Read-Normalized $cameraServicePath)

$portraitLayout = Balanced-Section $page '  portraitSegmentationAndroidLayout() {' 'portrait layout'
$portraitToolbar = Balanced-Section $page '  portraitSegmentationToolbar() {' 'portrait toolbar'
$portraitCameraPreview = Balanced-Section $page '  portraitSegmentationCameraPreview() {' 'portrait camera preview'
$portraitResultPreview = Balanced-Section $page '  portraitSegmentationResultPreview() {' 'portrait result preview'
$portraitComposite = Balanced-Section $page '  portraitSegmentationComposite() {' 'portrait composite'
$portraitStatus = Balanced-Section $page '  portraitSegmentationStatus() {' 'portrait status'
$portraitBackgroundStrip = Balanced-Section $page '  portraitSegmentationBackgroundStrip() {' 'portrait background strip'
$saveComponent = Balanced-Section $page '  private saveResultComponentImage(componentId: string): void {' 'portrait save entry'
$saveComponentAsync = Balanced-Section $page '  private async saveResultComponentImageAsync(componentId: string): Promise<void> {' 'portrait async save entry'
$applyPickResult = Balanced-Section $page '  private applyPickResult(' 'picker application'
$selectPortraitBackground = Balanced-Section $page `
  '  private selectPortraitBackgroundPreset(preset: PortraitSegmentationBackgroundPreset): void {' `
  'portrait preset selection'
$portraitBackgroundImageSource = Balanced-Section $page `
  '  private portraitBackgroundImageSource(presetId: string, fallbackUri: string): Resource | string {' `
  'portrait background image source'
$foreground = Balanced-Section $page '  private async updateSegmentationForegroundPreview(' 'segmentation foreground publication'
$captureFrame = Balanced-Section $page '  private async prepareLiveFrameImageInput(' 'live frame capture'
$frameEncoder = Balanced-Section $cameraService 'export class HarmonyLiveFrameImageEncoder' 'live frame encoder'
$retry = Balanced-Section $page '  private retryLiveSegmentation(): void {' 'segmentation retry'
$layoutRouter = Balanced-Section $page '  runtimeLayoutContent() {' 'runtime layout router'
$initialCamera = Balanced-Section $catalog 'export function initialLiveCameraPositionForWorkflow(' 'camera policy'
$cameraMemory = Balanced-Section $catalog 'export function rememberedLiveCameraPositionForWorkflow(' 'camera memory restore'
$cameraRemember = Balanced-Section $catalog 'export function rememberLiveCameraPositionForRoute(' 'camera memory update'
$retryMapping = Balanced-Section $catalog 'export function liveSegmentationRetryActionForStatus(' 'segmentation retry policy'
$preparingPolicy = Balanced-Section $catalog 'export function shouldPublishLiveSegmentationPreparingStatus(' 'segmentation preparing policy'
$visualPreservation = Balanced-Section $catalog 'export function shouldPreserveRuntimeVisualResultOnAiResult(' 'portrait visual preservation'
$cameraPreservation = Balanced-Section $catalog 'export function shouldPreserveLiveCameraInputOnFailure(' 'portrait camera preservation'
$segmentationFailureStatus = Balanced-Section $aiService '  private segmentationFailureMessageKey(' 'segmentation failure status mapping'
$coreVisionResult = Balanced-Section $segmentationService 'export async function segmentationResultFromCoreVision(' 'Core Vision segmentation result'
$localMaskResult = Balanced-Section $segmentationService 'export function localSegmentationResultFromMask(' 'local segmentation mask result'
$segmentationServiceResult = Balanced-Section $segmentationService 'export class SegmentationService {' 'segmentation service result'
$cancelledBackgroundState = Balanced-Section $inputState 'export function runtimePickedInputStateAfterCancelledPick(' 'cancelled background state'
$portraitWorkflowMatch = [regex]::Match($catalog, '(?s)\{\s*routeName:\s*AppRoute\.PORTRAIT_SEGMENTATION\.name,.*?\n\s*\},')
if (-not $portraitWorkflowMatch.Success) { Fail 'missing portrait segmentation workflow definition.' }
$portraitWorkflow = $portraitWorkflowMatch.Value

Assert-Contains $catalog 'return workflow?.routeName === AppRoute.PORTRAIT_SEGMENTATION.name;' `
  'portrait behavior must remain isolated to PORTRAIT_SEGMENTATION.'
Assert-Contains $experienceCatalog `
  "{ id: 'segmentation', title: 'Portrait Segmentation', titleKey: 'title_segmentation', icon: 'image', routeName: AppRoute.PORTRAIT_SEGMENTATION.name, visibleByDefault: true }" `
  'the visible portrait-segmentation card must open the background-capable portrait route.'
Assert-Contains $layoutRouter 'this.portraitSegmentationAndroidLayout()' `
  'runtime layout router must retain the portrait-specific route.'
Assert-Contains $portraitWorkflow "inputKinds: ['camera']" 'portrait must use the live camera input.'
Assert-Contains $portraitWorkflow "optionalInputKinds: ['backgroundImage']" `
  'portrait must retain the explicit custom background picker.'
Assert-Contains $portraitWorkflow "requiredPermissions: ['camera']" `
  'portrait startup must request CAMERA only for the active camera input.'
Assert-Excludes $portraitWorkflow 'media' 'portrait must not request media before the custom background picker is opened.'
Assert-Contains $backgroundCatalog 'portraitSegmentationBackgroundStateAfterCancelledPick(' `
  'portrait custom-background cancellation contract is missing.'
Assert-Contains $cancelledBackgroundState 'backgroundImageUri: backgroundState.backgroundImageUri' `
  'cancelled custom background picker must preserve the active background.'
Assert-Contains $applyPickResult "this.applyPickedInputState(runtimePickedInputStateAfterCancelledPick(" `
  'cancelled picker state must flow through the preserved input state.'

Assert-Contains $initialCamera "workflow.routeName === AppRoute.PORTRAIT_SEGMENTATION.name" `
  'portrait needs an explicit camera default.'
Assert-Contains $initialCamera "return 'front';" 'portrait must default to the front camera.'
foreach ($marker in @('rememberedLiveCameraPositions.get(routeName)', 'initialLiveCameraPositionForWorkflow(workflow)')) {
  Assert-Contains $cameraMemory $marker "portrait must restore camera position per route: $marker"
}
Assert-Contains $cameraRemember 'rememberedLiveCameraPositions.set(routeName, position);' `
  'portrait camera switches must be remembered per route.'

Assert-Contains $portraitLayout 'this.portraitSegmentationToolbar()' 'portrait layout needs its toolbar.'
Assert-Contains $portraitLayout 'this.portraitSegmentationCameraPreview()' 'portrait camera preview is missing.'
Assert-Contains $portraitLayout 'this.portraitSegmentationResultPreview()' 'portrait result preview is missing.'
Assert-Contains $portraitLayout 'this.portraitSegmentationStatus()' 'portrait layout needs its independent status lane.'
Assert-Contains $portraitLayout 'this.portraitSegmentationBackgroundStrip()' 'portrait layout needs its background controls.'
Assert-Contains $portraitLayout 'Scroll() {' 'portrait split previews must remain reachable on compact screens.'
$portraitCameraIndex = $portraitLayout.IndexOf(
  (Convert-ArkTsToGuardCode 'this.portraitSegmentationCameraPreview()'), [StringComparison]::Ordinal)
$portraitResultIndex = $portraitLayout.IndexOf(
  (Convert-ArkTsToGuardCode 'this.portraitSegmentationResultPreview()'), [StringComparison]::Ordinal)
$portraitScrollIndex = $portraitLayout.IndexOf((Convert-ArkTsToGuardCode 'Scroll() {'), [StringComparison]::Ordinal)
if ($portraitCameraIndex -ge $portraitResultIndex) {
  Fail 'portrait camera preview must appear before the segmentation result.'
}
if ($portraitCameraIndex -ge $portraitScrollIndex) {
  Fail 'portrait camera XComponent must remain outside Scroll to avoid hardware-surface overlay.'
}
if ($portraitResultIndex -le $portraitScrollIndex) {
  Fail 'portrait result preview must remain inside the reachable scrolling content.'
}
Assert-Contains $portraitCameraPreview '.aspectRatio(this.liveCameraPreviewAspectRatio)' `
  'portrait camera preview must follow the oriented camera aspect ratio.'
Assert-Contains $portraitResultPreview '.aspectRatio(this.liveCameraPreviewAspectRatio)' `
  'portrait result preview must match the oriented camera aspect ratio.'
Assert-Contains $portraitCameraPreview 'this.liveCameraSurfaceContent()' `
  'portrait camera preview must contain only the live camera.'
Assert-Contains $portraitResultPreview 'this.portraitSegmentationComposite()' `
  'portrait result preview must contain the composite.'
Assert-Excludes $portraitCameraPreview 'this.portraitSegmentationComposite()' `
  'camera and composite must not share one overlay stack.'
Assert-Excludes $portraitComposite 'this.portraitSegmentationStatus()' `
  'portrait status must stay outside the composite canvas.'
Assert-Excludes $portraitComposite 'this.portraitSegmentationBackgroundStrip()' `
  'portrait background controls must stay outside the composite canvas.'
Assert-Count $portraitComposite '.objectFit(ImageFit.Cover)' 2 `
  'portrait background and foreground must preserve aspect ratio with matching crops.'
Assert-Excludes $portraitComposite '.objectFit(ImageFit.Fill)' `
  'portrait composite must not stretch either image layer.'
Assert-Contains $captureFrame 'captureToCacheImage(surfaceId, context.cacheDir, rotation)' `
  'portrait inference input must use the current camera rotation.'
Assert-Contains $frameEncoder 'await pixelMap.rotate(rotationDegrees);' `
  'captured Surface frames must be rotated into display orientation before inference.'
Assert-Excludes $selectPortraitBackground 'this.runWorkflow()' `
  'background selection must not rerun segmentation.'
foreach ($rawfilePath in @(
  "portrait/portrait2.jpg",
  "portrait/portrait3.jpg",
  "portrait/portrait4.jpg",
  "portrait/portrait5.jpg"
)) {
  Assert-Contains $portraitBackgroundImageSource "`$rawfile('$rawfilePath')" `
    "portrait built-in background must use an ArkUI rawfile Resource: $rawfilePath"
}
Assert-Contains $portraitComposite '.id(segmentationBackgroundReplacementComponentId)' `
  'portrait composite needs the stable save snapshot view id.'
Assert-Count $page '.id(segmentationBackgroundReplacementComponentId)' 1 `
  'portrait save snapshot view id must be unique in FeatureRuntimePage.'

foreach ($marker in @(
  'Text(appString(this.statusKey))',
  'LoadingProgress()',
  "if (this.liveSegmentationRetryAction() !== 'none')",
  '.onClick(() => this.retryLiveSegmentation())',
  '.constraintSize({ minWidth: 72, minHeight: 48 })',
  '.maxLines(2)',
  '.maxFontScale(3.2)'
)) { Assert-Contains $portraitStatus $marker "portrait status is incomplete: $marker" }
Assert-Contains $retryMapping 'usesAndroidLiveSegmentationLayout(workflow)' `
  'live segmentation Retry policy must remain covered.'
Assert-Contains $retryMapping 'usesAndroidPortraitSegmentationLayout(workflow)' `
  'portrait Retry policy must be route-specific.'
Assert-Contains $retryMapping "statusKey === 'feature_runtime_segmentation_no_subject'" `
  'portrait no-subject status must remain recoverable with Retry.'
Assert-Contains $segmentationFailureStatus "result.failureReason === 'noSubject'" `
  'segmentation no-subject failures must retain their production reason.'
Assert-Contains $segmentationFailureStatus "'feature_runtime_segmentation_no_subject'" `
  'segmentation no-subject failures must use the localized production status.'
Assert-Contains $segmentationFailureStatus "'feature_runtime_segmentation_failed'" `
  'segmentation runtime exceptions must retain the generic production status.'
Assert-Contains $coreVisionResult "failureReason: 'noSubject'" `
  'Core Vision no-subject results must be distinguishable from runtime exceptions.'
Assert-Contains $localMaskResult "failureReason: 'noSubject'" `
  'local segmentation no-subject results must be distinguishable from runtime exceptions.'
Assert-Contains $segmentationServiceResult "failureReason: 'runtimeException'" `
  'segmentation runtime exceptions must preserve the generic production reason.'
Assert-Contains $preparingPolicy 'usesAndroidPortraitSegmentationLayout(workflow)' `
  'portrait must retain a valid foreground or retry status during live updates.'
foreach ($marker in @('this.liveCameraInputSelected = true;', 'this.stopLiveRuntimeLoop();', 'this.startLiveRuntimeLoop(workflow);')) {
  Assert-Contains $retry $marker "portrait Retry must restart the correct live layer: $marker"
}
Assert-Excludes $retry "this.prepareInput('camera')" 'portrait Retry must not replace the active camera input.'

Assert-Contains $portraitBackgroundStrip 'ForEach(portraitSegmentationBackgroundPresets' `
  'portrait preset choices are missing.'
Assert-Contains $portraitBackgroundStrip 'this.selectPortraitBackgroundPreset(preset)' `
  'portrait preset selection is missing.'
Assert-Contains $portraitBackgroundStrip "this.prepareInput('backgroundImage')" `
  'portrait custom background picker is missing.'
Assert-Contains $portraitBackgroundStrip "SymbolGlyph(`$r('sys.symbol.checkmark'))" `
  'portrait selected state must provide a visible check in addition to color.'
Assert-Count $portraitBackgroundStrip "SymbolGlyph(`$r('sys.symbol.checkmark'))" 2 `
  'portrait preset and custom selected states must both provide a visible check.'
Assert-Contains $portraitBackgroundStrip '.height(184)' `
  'portrait 3.2x background labels need a full-height, non-clipped strip.'
Assert-Contains $portraitBackgroundStrip 'this.selectedPortraitBackgroundPresetId === preset.id' `
  'portrait preset selected state is missing.'
Assert-Contains $portraitBackgroundStrip 'this.selectedPortraitBackgroundPresetId === portraitSegmentationCustomBackgroundId' `
  'portrait custom selected state is missing.'

foreach ($marker in @(
  'compositeSegmentationSaveReady(this.workflowRunning,',
  'this.segmentationForegroundPixelMap !== undefined, this.resultImageSaveInFlight)',
  'this.saveResultComponentImage(segmentationBackgroundReplacementComponentId)'
)) { Assert-Contains $portraitToolbar $marker "portrait save readiness is incomplete: $marker" }
Assert-Contains $saveComponentAsync 'this.resultImageSaveInFlight = true;' `
  'portrait save must acquire single-flight ownership.'
Assert-Contains $saveComponentAsync 'finally {' 'portrait save must release single-flight ownership.'
Assert-Contains $saveComponentAsync 'this.resultImageSaveInFlight = false;' `
  'portrait save must release single-flight ownership in finally.'
Assert-Contains $saveComponent 'this.showRuntimeToast(this.statusKey);' `
  'portrait save failure must provide localized feedback.'
Assert-Contains $saveComponentAsync 'this.showRuntimeToast(this.statusKey);' `
  'portrait save completion must provide localized feedback.'

Assert-Contains $visualPreservation 'if (usesAndroidPortraitSegmentationLayout(workflow)) {' `
  'portrait visual preservation must be explicit.'
Assert-Contains $visualPreservation "if (usesAndroidPortraitSegmentationLayout(workflow)) {`n    return !resultOk || dataKind === 'segmentation';`n  }" `
  'portrait transient failures must retain the last valid composite.'
Assert-Excludes $visualPreservation "return workflow?.routeName === AppRoute.PORTRAIT_SEGMENTATION.name &&" `
  'portrait preservation must not retain an unreachable duplicate fallback.'
Assert-Contains $cameraPreservation 'usesAndroidPortraitSegmentationLayout(workflow)' `
  'portrait camera failure must preserve the active input.'
Assert-Contains $foreground 'usesAndroidPortraitSegmentationLayout(workflow)' `
  'portrait foreground conversion failure must preserve the prior foreground and report failure.'
Assert-Contains $foreground "this.statusKey = 'feature_runtime_segmentation_failed';" `
  'portrait foreground conversion failure must expose a recoverable state.'
Assert-TopLevelBuildExecution $buildPath 'check-portrait-runtime-ui.ps1'
Assert-TopLevelBuildExecution $buildPath 'test-portrait-runtime-ui-guard.ps1'

Write-Output 'Portrait runtime UI contract is present.'
