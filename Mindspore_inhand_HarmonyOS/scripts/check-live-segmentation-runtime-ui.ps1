param(
  [string]$SourceRoot = ''
)

$ErrorActionPreference = 'Stop'

function Fail([string]$Message) {
  throw "Live segmentation runtime UI guard failed: $Message"
}

function Read-Normalized([string]$Path) {
  if (-not [IO.File]::Exists($Path)) {
    Fail "missing source file: $Path"
  }
  return ([IO.File]::ReadAllText($Path)).Replace("`r`n", "`n").Replace("`r", "`n")
}

function Remove-ArkTsCommentsAndLiteralText([string]$Text, [bool]$PreserveLiterals = $false) {
  $result = [Text.StringBuilder]::new($Text.Length)
  $state = 'code'
  $quote = [char]0
  $escaped = $false
  for ($index = 0; $index -lt $Text.Length; $index++) {
    $current = $Text[$index]
    $next = if ($index + 1 -lt $Text.Length) { $Text[$index + 1] } else { [char]0 }
    if ($state -eq 'line') {
      if ($current -eq [char]0x0A) {
        [void]$result.Append($current)
        $state = 'code'
      } else {
        [void]$result.Append(' ')
      }
      continue
    }
    if ($state -eq 'block') {
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
    if ($state -eq 'string') {
      if ($PreserveLiterals) {
        [void]$result.Append($current)
      } elseif ($current -eq [char]0x0A) {
        [void]$result.Append($current)
      } else {
        [void]$result.Append(' ')
      }
      if ($escaped) {
        $escaped = $false
      } elseif ($current -eq [char]0x5C) {
        $escaped = $true
      } elseif ($current -eq $quote) {
        $state = 'code'
      }
      continue
    }
    if ($current -eq [char]0x2F -and $next -eq [char]0x2F) {
      [void]$result.Append('  ')
      $index++
      $state = 'line'
    } elseif ($current -eq [char]0x2F -and $next -eq [char]0x2A) {
      [void]$result.Append('  ')
      $index++
      $state = 'block'
    } elseif ($current -eq [char]0x22 -or $current -eq [char]0x27 -or $current -eq [char]0x60) {
      [void]$result.Append($(if ($PreserveLiterals) { $current } else { ' ' }))
      $quote = $current
      $escaped = $false
      $state = 'string'
    } else {
      [void]$result.Append($current)
    }
  }
  return $result.ToString()
}

function Balanced-Section([string]$Text, [string]$Start, [string]$Name) {
  $startIndex = $Text.IndexOf($Start, [StringComparison]::Ordinal)
  if ($startIndex -lt 0) { Fail "missing $Name start marker: $Start" }
  $openIndex = $Text.IndexOf('{', $startIndex)
  if ($openIndex -lt 0) { Fail "missing $Name opening brace." }
  $depth = 0
  for ($index = $openIndex; $index -lt $Text.Length; $index++) {
    if ($Text[$index] -eq '{') { $depth++ }
    if ($Text[$index] -eq '}') {
      $depth--
      if ($depth -eq 0) {
        return $Text.Substring($startIndex, $index - $startIndex + 1)
      }
    }
  }
  Fail "missing $Name closing brace."
}

function Balanced-Section-UsingBounds(
  [string]$CodeText,
  [string]$LiteralText,
  [string]$Start,
  [string]$Name
) {
  $startIndex = $LiteralText.IndexOf($Start, [StringComparison]::Ordinal)
  if ($startIndex -lt 0) { Fail "missing $Name start marker: $Start" }
  $openIndex = $CodeText.IndexOf('{', $startIndex)
  if ($openIndex -lt 0) { Fail "missing $Name opening brace." }
  $depth = 0
  for ($index = $openIndex; $index -lt $CodeText.Length; $index++) {
    if ($CodeText[$index] -eq '{') { $depth++ }
    if ($CodeText[$index] -eq '}') {
      $depth--
      if ($depth -eq 0) {
        return $LiteralText.Substring($startIndex, $index - $startIndex + 1)
      }
    }
  }
  Fail "missing $Name closing brace."
}

function Assert-Contains([string]$Text, [string]$Marker, [string]$Message) {
  if ($Text.IndexOf($Marker, [StringComparison]::Ordinal) -lt 0) { Fail $Message }
}

function Assert-Excludes([string]$Text, [string]$Marker, [string]$Message) {
  if ($Text.IndexOf($Marker, [StringComparison]::Ordinal) -ge 0) { Fail $Message }
}

function Assert-Count([string]$Text, [string]$Marker, [int]$Expected, [string]$Message) {
  $count = ([regex]::Matches($Text, [regex]::Escape($Marker))).Count
  if ($count -ne $Expected) { Fail "$Message Expected $Expected, found $count." }
}

function Assert-TopLevelBuildExecution([string]$BuildPath, [string]$ScriptName) {
  $tokens = $null
  $parseErrors = $null
  $ast = [Management.Automation.Language.Parser]::ParseFile($BuildPath, [ref]$tokens, [ref]$parseErrors)
  if ($parseErrors.Count -gt 0) { Fail 'build-hap.ps1 has parse errors.' }
  $expected = "& (Join-Path `$PSScriptRoot '$ScriptName')"
  $matches = @($ast.EndBlock.Statements | Where-Object { $_.Extent.Text.Trim() -eq $expected })
  if ($matches.Count -ne 1) {
    Fail "build-hap.ps1 must execute $ScriptName exactly once at top level; found $($matches.Count)."
  }
}

$root = if ($SourceRoot) { [IO.Path]::GetFullPath($SourceRoot) } else {
  [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
}
$pagePath = Join-Path $root 'entry\src\main\ets\pages\FeatureRuntimePage.ets'
$catalogPath = Join-Path $root 'entry\src\main\ets\features\runtime\FeatureWorkflowCatalog.ets'
$buildPath = Join-Path $root 'scripts\build-hap.ps1'
$pageRaw = Read-Normalized $pagePath
$catalogRaw = Read-Normalized $catalogPath
$page = Remove-ArkTsCommentsAndLiteralText $pageRaw
$pageWithLiterals = Remove-ArkTsCommentsAndLiteralText $pageRaw $true
$catalog = Remove-ArkTsCommentsAndLiteralText $catalogRaw
$catalogWithLiterals = Remove-ArkTsCommentsAndLiteralText $catalogRaw $true

$segmentationOverlay = Balanced-Section $page '  liveSegmentationStatusOverlay() {' 'live segmentation status overlay'
$segmentationOverlayWithLiterals = Balanced-Section-UsingBounds $page $pageWithLiterals `
  '  liveSegmentationStatusOverlay() {' 'live segmentation status overlay literals'
$segmentationLayout = Balanced-Section $page '  segmentationAndroidLiveLayout() {' 'live segmentation layout'
$segmentationLayoutWithLiterals = Balanced-Section-UsingBounds $page $pageWithLiterals `
  '  segmentationAndroidLiveLayout() {' 'live segmentation layout literals'
$segmentationRetry = Balanced-Section $page '  private retryLiveSegmentation(): void {' 'live segmentation retry'
$segmentationRetryWithLiterals = Balanced-Section-UsingBounds $page $pageWithLiterals `
  '  private retryLiveSegmentation(): void {' 'live segmentation retry literals'
$runAsync = Balanced-Section $page '  private async runWorkflowAsync(' 'workflow execution'
$previewStart = Balanced-Section $page '  private async startLiveCameraPreviewAsync(): Promise<void> {' 'camera preview start'
$foreground = Balanced-Section $page '  private async updateSegmentationForegroundPreview(' 'segmentation foreground publication'
$foregroundWithLiterals = Balanced-Section-UsingBounds $page $pageWithLiterals `
  '  private async updateSegmentationForegroundPreview(' 'segmentation foreground publication literals'
$surface = Balanced-Section $page '  liveCameraSurfaceContent() {' 'shared live camera surface'
$surfaceWithLiterals = Balanced-Section-UsingBounds $page $pageWithLiterals `
  '  liveCameraSurfaceContent() {' 'shared live camera surface literals'
$retryMapping = Balanced-Section $catalog 'export function liveSegmentationRetryActionForStatus(' 'segmentation retry mapping'
$retryMappingWithLiterals = Balanced-Section-UsingBounds $catalog $catalogWithLiterals `
  'export function liveSegmentationRetryActionForStatus(' 'segmentation retry mapping literals'
$preparingPolicy = Balanced-Section $catalog 'export function shouldPublishLiveSegmentationPreparingStatus(' 'segmentation preparing policy'
$simpleLayout = Balanced-Section $catalog 'export function usesSimpleAndroidLiveLayout(' 'shared simple live layout routes'
$liveSegmentationLayout = Balanced-Section $catalog 'export function usesAndroidLiveSegmentationLayout(' 'live segmentation route policy'
$initialCamera = Balanced-Section $catalog 'export function initialLiveCameraPositionForWorkflow(' 'initial live camera policy'
$initialCameraWithLiterals = Balanced-Section-UsingBounds $catalog $catalogWithLiterals `
  'export function initialLiveCameraPositionForWorkflow(' 'initial live camera policy literals'
$cameraMemory = Balanced-Section $catalog 'export function rememberedLiveCameraPositionForWorkflow(' 'camera memory restore'
$cameraRemember = Balanced-Section $catalog 'export function rememberLiveCameraPositionForRoute(' 'camera memory update'
$visualPreservation = Balanced-Section $catalog 'export function shouldPreserveRuntimeVisualResultOnAiResult(' 'visual result preservation'
$visualPreservationWithLiterals = Balanced-Section-UsingBounds $catalog $catalogWithLiterals `
  'export function shouldPreserveRuntimeVisualResultOnAiResult(' 'visual result preservation literals'
$textPreservation = Balanced-Section $catalog 'export function shouldPreserveRuntimeTextResultOnAiResult(' 'text result preservation'
$mirrorPolicy = Balanced-Section $catalog 'export function shouldMirrorSegmentationForeground(' 'segmentation mirror policy'
$mirrorPolicyWithLiterals = Balanced-Section-UsingBounds $catalog $catalogWithLiterals `
  'export function shouldMirrorSegmentationForeground(' 'segmentation mirror policy literals'

foreach ($marker in @(
  'export type SpecializedAndroidLiveLayout =',
  "return 'segmentation';",
  'export type LiveSegmentationRetryAction =',
  'usesAndroidLiveSegmentationLayout(workflow)'
)) { Assert-Contains $catalogWithLiterals $marker "missing route-isolated segmentation layout marker: $marker" }
Assert-Excludes $simpleLayout 'routeName === AppRoute.SEGMENTATION_LIVE.name' `
  'segmentation must leave the shared simple-layout route set.'
Assert-Contains $liveSegmentationLayout 'workflow?.routeName === AppRoute.SEGMENTATION_LIVE.name' `
  'segmentation runtime state must be isolated to its own route.'

foreach ($marker in @(
  'this.runtimeActionToolbar(true)',
  'this.liveCameraSurfaceContent()',
  'this.liveSegmentationStatusOverlay()',
  'if (this.liveCameraSwitchAvailable) {',
  'this.runtimeCameraSwitchAction()',
  '.layoutWeight(1)'
)) { Assert-Contains $segmentationLayout $marker "missing executable segmentation layout marker: $marker" }
Assert-Contains $segmentationLayout '.backgroundColor(' 'segmentation layout must retain a camera fallback.'
Assert-Count $segmentationLayout 'this.runtimeCameraSwitchAction()' 1 `
  'segmentation layout must expose exactly one camera switch action.'
Assert-Contains $segmentationLayoutWithLiterals @"
          Row() {
            if (this.liveCameraSwitchAvailable) {
              this.runtimeCameraSwitchAction()
            }
          }
          .width('100%')
          .padding({ left: AppSpacing.md, right: AppSpacing.md })
          .justifyContent(FlexAlign.End)
"@ 'segmentation camera-switch action layer must retain horizontal safe-edge insets.'

foreach ($marker in @(
  'Text(appString(this.statusKey))',
  'LoadingProgress()',
  '.constraintSize({ minWidth: 72, minHeight: 48 })',
  '.onClick(() => this.retryLiveSegmentation())',
  '.constraintSize({ maxWidth: 520 })'
)) { Assert-Contains $segmentationOverlay $marker "missing executable segmentation status marker: $marker" }
Assert-Contains $segmentationOverlayWithLiterals "if (this.liveSegmentationRetryAction() !== 'none') {" `
  'segmentation status must show Retry only for recoverable state.'
foreach ($marker in @(
  "Button(appString('web_retry'), { type: ButtonType.Normal })",
  ".width('calc(100% - 32vp)')",
  ".backgroundColor('#B31F2937')"
)) { Assert-Contains $segmentationOverlayWithLiterals $marker "missing literal segmentation status marker: $marker" }
foreach ($forbidden in @('.height(96)', 'maxHeight:', '.clip(true)', '.maxLines(', '.textOverflow(')) {
  Assert-Excludes $segmentationOverlay $forbidden "segmentation status must size naturally: $forbidden"
}
Assert-Count $segmentationOverlay '.onClick(' 1 'segmentation status overlay must expose one Retry callback.'

foreach ($marker in @(
  'const action = liveSegmentationRetryActionForStatus(workflow, this.statusKey);',
  'this.liveCameraInputSelected = true;',
  'this.startLiveCameraPreview();',
  'this.stopLiveRuntimeLoop();',
  'this.startLiveRuntimeLoop(workflow);'
)) { Assert-Contains $segmentationRetry $marker "segmentation Retry is missing: $marker" }
foreach ($marker in @(
  "if (action === 'restartCamera') {",
  "if (action !== 'restartInference' || workflow === undefined) {",
  "this.statusKey = 'feature_runtime_status_preparing';"
)) { Assert-Contains $segmentationRetryWithLiterals $marker "segmentation Retry is missing: $marker" }
Assert-Excludes $segmentationRetryWithLiterals "this.prepareInput('camera')" `
  'segmentation Retry must directly restore the live camera surface.'
$stopIndex = $segmentationRetry.IndexOf('this.stopLiveRuntimeLoop();', [StringComparison]::Ordinal)
$startIndex = $segmentationRetry.IndexOf('this.startLiveRuntimeLoop(workflow);', [StringComparison]::Ordinal)
if ($stopIndex -lt 0 -or $startIndex -lt 0 -or $stopIndex -gt $startIndex) {
  Fail 'segmentation inference Retry must stop the old loop before restart.'
}

foreach ($status in @(
  'feature_runtime_live_camera_failed',
  'feature_runtime_live_camera_surface_missing',
  'feature_runtime_permission_denied',
  'feature_runtime_live_frame_failed',
  'feature_runtime_run_failed',
  'feature_runtime_pending_adapter',
  'feature_runtime_segmentation_failed'
)) { Assert-Contains $retryMappingWithLiterals "'$status'" "segmentation retry mapping is missing $status." }
Assert-Contains $retryMapping 'if (!usesAndroidLiveSegmentationLayout(workflow)) {' `
  'segmentation Retry must remain route specific.'
Assert-Contains $preparingPolicy '!usesAndroidLiveSegmentationLayout(workflow) || !hasForegroundOrRetry;' `
  'preparing state must preserve durable segmentation success/failure.'
Assert-Contains $runAsync 'shouldPublishLiveSegmentationPreparingStatus(' `
  'automatic frames must not erase durable segmentation state.'
Assert-Contains $runAsync 'this.segmentationForegroundPixelMap !== undefined || this.liveSegmentationRetryAction() !==' `
  'preparing state must account for last foreground and Retry.'
Assert-Contains $previewStart 'shouldClearRuntimeResultAtWorkflowStart(workflow)' `
  'camera restart must use the shared result-clear policy gate.'

Assert-Contains $initialCamera 'workflow.routeName === AppRoute.SEGMENTATION_LIVE.name' `
  'live segmentation must keep an explicit default camera policy.'
Assert-Contains $initialCameraWithLiterals "return 'front';" `
  'live segmentation must default to the front camera.'
foreach ($marker in @('rememberedLiveCameraPositions.get(routeName)', 'initialLiveCameraPositionForWorkflow(workflow)')) {
  Assert-Contains $cameraMemory $marker "per-route camera restore is missing: $marker"
}
Assert-Contains $cameraRemember 'rememberedLiveCameraPositions.set(routeName, position);' `
  'camera switches must be remembered per route.'

Assert-Contains $textPreservation 'usesAndroidLiveSegmentationLayout(workflow)' `
  'segmentation failures must retain the last valid text state.'
Assert-Contains $visualPreservation 'if (usesAndroidLiveSegmentationLayout(workflow)) {' `
  'segmentation visual preservation is missing.'
Assert-Contains $visualPreservationWithLiterals "return !resultOk || dataKind === 'segmentation';" `
  'segmentation visual preservation must retain accepted masks and failures.'
foreach ($forbidden in @('segmentationForegroundPixelMapOwner.clear();', 'this.segmentationForegroundPixelMap = undefined;')) {
  Assert-Excludes $foreground $forbidden "live foreground failure must not clear the last valid mask: $forbidden"
}
foreach ($marker in @(
  'this.segmentationForegroundPixelMapOwner.invalidatePendingReplacement();',
  'return false;',
  'return true;'
)) { Assert-Contains $foreground $marker "foreground publication must report and preserve failures: $marker" }
Assert-Contains $foregroundWithLiterals "this.statusKey = 'feature_runtime_segmentation_failed';" `
  'foreground publication must report segmentation failure.'

foreach ($marker in @(
  'shouldShowLiveSegmentationCameraOverlay(workflowForRoute(this.routeName))',
  '.objectFit(ImageFit.Fill)',
  '.scale({ x: this.segmentationForegroundMirrorScaleX(), y: 1 })'
)) { Assert-Contains $surface $marker "shared canvas mask alignment is missing: $marker" }
foreach ($marker in @(".width('100%')", ".height('100%')")) {
  Assert-Contains $surfaceWithLiterals $marker "shared canvas mask alignment is missing: $marker"
}
Assert-Contains $mirrorPolicy 'usesAndroidLiveSegmentationLayout(workflow)' `
  'live segmentation mirror policy is missing.'
Assert-Contains $mirrorPolicyWithLiterals "liveCameraPosition === 'front'" `
  'front live segmentation masks must mirror with the preview.'

Assert-TopLevelBuildExecution $buildPath 'check-live-segmentation-runtime-ui.ps1'
Assert-TopLevelBuildExecution $buildPath 'test-live-segmentation-runtime-ui-guard.ps1'

Write-Output 'Live segmentation runtime UI parity is present.'
