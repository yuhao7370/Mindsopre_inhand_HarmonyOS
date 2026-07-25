param(
  [string]$SourceRoot = ''
)

$ErrorActionPreference = 'Stop'

function Fail([string]$Message) {
  throw "Live gesture runtime UI guard failed: $Message"
}

function Read-Normalized([string]$Path) {
  if (-not [IO.File]::Exists($Path)) { Fail "missing source file: $Path" }
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
      if ($PreserveLiterals) { [void]$result.Append($current) }
      elseif ($current -eq [char]0x0A) { [void]$result.Append($current) }
      else { [void]$result.Append(' ') }
      if ($escaped) { $escaped = $false }
      elseif ($current -eq [char]0x5C) { $escaped = $true }
      elseif ($current -eq $quote) { $state = 'code' }
      continue
    }
    if ($current -eq [char]0x2F -and $next -eq [char]0x2F) {
      [void]$result.Append('  '); $index++; $state = 'line'
    } elseif ($current -eq [char]0x2F -and $next -eq [char]0x2A) {
      [void]$result.Append('  '); $index++; $state = 'block'
    } elseif ($current -eq [char]0x22 -or $current -eq [char]0x27 -or $current -eq [char]0x60) {
      [void]$result.Append($(if ($PreserveLiterals) { $current } else { ' ' }))
      $quote = $current; $escaped = $false; $state = 'string'
    } else { [void]$result.Append($current) }
  }
  return $result.ToString()
}

function Balanced-Section([string]$CodeText, [string]$LiteralText, [string]$Start, [string]$Name) {
  $startIndex = $LiteralText.IndexOf($Start, [StringComparison]::Ordinal)
  if ($startIndex -lt 0) { Fail "missing $Name start marker: $Start" }
  $openIndex = $CodeText.IndexOf('{', $startIndex)
  if ($openIndex -lt 0) { Fail "missing $Name opening brace." }
  $depth = 0
  for ($index = $openIndex; $index -lt $CodeText.Length; $index++) {
    if ($CodeText[$index] -eq '{') { $depth++ }
    elseif ($CodeText[$index] -eq '}') {
      $depth--
      if ($depth -eq 0) { return $LiteralText.Substring($startIndex, $index - $startIndex + 1) }
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

function Assert-TopLevelBuildExecution([string]$BuildPath, [string]$ScriptName) {
  $tokens = $null
  $parseErrors = $null
  $ast = [Management.Automation.Language.Parser]::ParseFile($BuildPath, [ref]$tokens, [ref]$parseErrors)
  if ($parseErrors.Count -gt 0) { Fail 'build-hap.ps1 has parse errors.' }
  $expected = "& (Join-Path `$PSScriptRoot '$ScriptName')"
  $matches = @($ast.EndBlock.Statements | Where-Object { $_.Extent.Text.Trim() -eq $expected })
  if ($matches.Count -ne 1) { Fail "build-hap.ps1 must execute $ScriptName exactly once at top level; found $($matches.Count)." }
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

$gestureLayout = Balanced-Section $page $pageWithLiterals '  gestureAndroidLiveLayout() {' 'live gesture layout'
$gestureStatus = Balanced-Section $page $pageWithLiterals '  liveGestureStatusOverlay() {' 'live gesture status overlay'
$gestureBox = Balanced-Section $page $pageWithLiterals '  liveGestureBox(gesture: GestureDetection) {' 'live gesture box'
$gestureStyle = Balanced-Section $page $pageWithLiterals '  private gestureBoxStyle(gesture: GestureDetection): GestureRectanglePercent {' 'live gesture coordinate style'
$gestureLabelPosition = Balanced-Section $page $pageWithLiterals '  private liveGestureLabelLeft(gesture: GestureDetection): string {' 'live gesture label position'
$gestureLabelPositionCode = Balanced-Section $page $page '  private liveGestureLabelLeft(gesture: GestureDetection): string {' 'live gesture label position code'
$surface = Balanced-Section $page $pageWithLiterals '  liveCameraSurfaceContent() {' 'shared live camera surface'
$updateGesture = Balanced-Section $page $pageWithLiterals '  private updateGesturePreview(result: AiRunResult): void {' 'live gesture result publication'
$previewResult = Balanced-Section $page $pageWithLiterals '  private applyLiveCameraPreviewResult(result: LiveCameraPreviewResult): void {' 'live camera preview result'
$retry = Balanced-Section $page $pageWithLiterals '  private retryLiveGesture(): void {' 'live gesture retry'
$runAsync = Balanced-Section $page $pageWithLiterals '  private async runWorkflowAsync(' 'workflow execution'
$layoutRouter = Balanced-Section $page $pageWithLiterals '  runtimeLayoutContent() {' 'runtime layout router'
$initialCamera = Balanced-Section $catalog $catalogWithLiterals 'export function initialLiveCameraPositionForWorkflow(' 'initial live camera policy'
$cameraMemory = Balanced-Section $catalog $catalog 'export function rememberedLiveCameraPositionForWorkflow(' 'camera memory restore'
$cameraRemember = Balanced-Section $catalog $catalog 'export function rememberLiveCameraPositionForRoute(' 'camera memory update'
$gestureRoute = Balanced-Section $catalog $catalogWithLiterals 'export function usesAndroidLiveGestureLayout(' 'live gesture route policy'
$retryMapping = Balanced-Section $catalog $catalogWithLiterals 'export function liveGestureRetryActionForStatus(' 'live gesture retry mapping'
$preparingPolicy = Balanced-Section $catalog $catalogWithLiterals 'export function shouldPublishLiveGesturePreparingStatus(' 'live gesture preparing policy'
$clearPolicy = Balanced-Section $catalog $catalogWithLiterals 'export function shouldClearRuntimeResultAtWorkflowStart(' 'live gesture result clear policy'
$textPreservation = Balanced-Section $catalog $catalogWithLiterals 'export function shouldPreserveRuntimeTextResultOnAiResult(' 'live gesture text preservation'
$visualPreservation = Balanced-Section $catalog $catalogWithLiterals 'export function shouldPreserveRuntimeVisualResultOnAiResult(' 'live gesture visual preservation'
$cameraInputPreservation = Balanced-Section $catalog $catalogWithLiterals 'export function shouldPreserveLiveCameraInputOnFailure(' 'live camera input preservation'

Assert-Contains $catalog 'export type LiveGestureRetryAction =' 'missing live gesture Retry action type.'
Assert-Contains $gestureRoute 'workflow?.routeName === AppRoute.GESTURE_LIVE.name' 'live gesture behavior must be route isolated.'
Assert-Contains $catalogWithLiterals "return 'gesture';" 'gesture must select its own live layout.'
$simpleLayout = Balanced-Section $catalog $catalogWithLiterals 'export function usesSimpleAndroidLiveLayout(' 'shared simple live layout routes'
Assert-Excludes $simpleLayout 'AppRoute.GESTURE_LIVE.name' 'gesture must leave the shared simple live layout.'
Assert-Contains $layoutRouter "specializedAndroidLiveLayoutForWorkflow(workflowForRoute(this.routeName)) === 'gesture'" 'runtime router must select the live gesture layout.'
Assert-Contains $layoutRouter 'this.gestureAndroidLiveLayout()' 'runtime router must render the live gesture layout.'

foreach ($marker in @('workflow.routeName === AppRoute.GESTURE_LIVE.name', "return 'back';")) {
  Assert-Contains $initialCamera $marker "live gesture must default to the rear camera: $marker"
}
foreach ($marker in @('rememberedLiveCameraPositions.get(routeName)', 'return rememberedPosition ?? initialLiveCameraPositionForWorkflow(workflow);')) {
  Assert-Contains $cameraMemory $marker "live gesture must restore camera position per route: $marker"
}
Assert-Contains $cameraRemember 'rememberedLiveCameraPositions.set(routeName, position);' 'camera switch must persist per route.'

Assert-Contains $catalogWithLiterals "return shouldShowLiveGestureCameraOverlay(workflow) && liveCameraPosition === 'front';" `
  'front live gesture overlays must mirror and rear overlays must remain unmirrored.'
Assert-Contains $surface 'this.liveGestureBox(gesture)' 'live gesture surface must use its route-specific label overlay.'
Assert-Excludes $surface 'this.gestureBox(gesture)' 'live gesture surface must not fall back to the generic one-line label.'
Assert-Contains $gestureStyle 'shouldMirrorLiveGestureCameraOverlay(workflowForRoute(this.routeName), this.liveCameraPosition)' `
  'live gesture box coordinates must use the front-only mirror policy.'
Assert-Contains $gestureLabelPosition 'shouldMirrorLiveGestureCameraOverlay(workflowForRoute(this.routeName), this.liveCameraPosition)' `
  'front live gesture labels must use the same front-only policy as the mirrored box.'
Assert-Contains $gestureLabelPosition "return 'calc(100% - 176vp)';" `
  'front live gesture labels must stay within the camera edge at 3.2x.'
Assert-Contains $page '@State liveGestureOverlayWidthVp: number = 0;' `
  'live gesture labels must measure the camera canvas before applying rear-edge placement.'
Assert-Contains $gestureLayout '.onAreaChange((_previousArea: Area, currentArea: Area) => {' `
  'live gesture layout must capture the camera canvas area.'
Assert-Contains $gestureLayout 'this.liveGestureOverlayWidthVp = Number.isFinite(width) && width > 0 ? width : 0;' `
  'live gesture layout must retain a valid camera canvas width.'
foreach ($marker in @(
  'const canvasWidth = this.liveGestureOverlayWidthVp;',
  'if (canvasWidth <= 176) {',
  'const labelLeft = this.gestureBoxStyle(gesture).left * canvasWidth / 100;',
  'const clampedLabelLeft = Math.min(Math.max(labelLeft, 0), canvasWidth - 176);'
)) { Assert-Contains $gestureLabelPositionCode $marker "rear live gesture label must clamp to the measured camera edge: $marker" }
Assert-Contains $gestureLabelPosition "return '0vp';" `
  'live gesture labels must use a safe fallback before the camera canvas is measured.'
Assert-Contains $gestureLabelPosition 'return `${clampedLabelLeft}vp`;' `
  'live gesture labels must publish the clamped rear-camera coordinate.'
foreach ($marker in @(
  'Text(this.gestureLabelResource(gesture))',
  '.maxLines(2)',
  '.textOverflow({ overflow: TextOverflow.Ellipsis })',
  '.maxFontScale(3.2)',
  '.constraintSize({ maxWidth: 176 })',
  '.width(176)',
  ".backgroundColor('#B31F2937')"
)) { Assert-Contains $gestureBox $marker "live gesture label must remain bounded and legible: $marker" }
Assert-Contains $gestureBox 'x: this.liveGestureLabelLeft(gesture),' `
  'live gesture label cards must use the edge-safe position policy.'
foreach ($forbidden in @('.width(88)', '.height(100)')) {
  Assert-Excludes $gestureBox $forbidden "live gesture label must not use a fixed one-line/unbounded result panel: $forbidden"
}

foreach ($marker in @(
  'this.runtimeActionToolbar(true)',
  'this.liveCameraSurfaceContent()',
  'this.liveGestureStatusOverlay()',
  'if (this.liveCameraSwitchAvailable) {',
  'this.runtimeCameraSwitchAction()',
  ".width('100%')",
  '.layoutWeight(1)'
)) { Assert-Contains $gestureLayout $marker "live gesture layout is incomplete: $marker" }
Assert-Contains $gestureLayout '.padding({ left: AppSpacing.md, right: AppSpacing.md })' `
  'live gesture camera switch needs safe-edge insets.'
Assert-Contains $gestureStatus 'Text(appString(this.statusKey))' 'live gesture must expose a status label.'
Assert-Contains $gestureStatus 'LoadingProgress()' 'live gesture must expose preparing state.'
Assert-Contains $gestureStatus "if (this.liveGestureRetryAction() !== 'none')" 'live gesture must expose recoverable Retry.'
Assert-Contains $gestureStatus '.onClick(() => this.retryLiveGesture())' 'live gesture Retry must restart the route-specific workflow.'
foreach ($marker in @('.constraintSize({ minWidth: 72, minHeight: 48 })', '.constraintSize({ maxWidth: 520 })', ".width('calc(100% - 32vp)')", ".backgroundColor('#B31F2937')")) {
  Assert-Contains $gestureStatus $marker "live gesture status must be bounded, high contrast, and touch safe: $marker"
}
foreach ($forbidden in @('.height(100)', '.height(96)', '.maxHeight:')) {
  Assert-Excludes $gestureStatus $forbidden "live gesture status must not permanently cover the camera: $forbidden"
}

foreach ($status in @(
  'feature_runtime_live_camera_failed',
  'feature_runtime_live_camera_surface_missing',
  'feature_runtime_permission_denied',
  'feature_runtime_live_frame_failed',
  'feature_runtime_run_failed',
  'feature_runtime_pending_adapter',
  'feature_runtime_gesture_failed'
)) { Assert-Contains $retryMapping "'$status'" "live gesture Retry mapping is missing $status." }
Assert-Contains $retryMapping 'if (!usesAndroidLiveGestureLayout(workflow)) {' 'live gesture Retry must remain route specific.'
Assert-Contains $preparingPolicy '!usesAndroidLiveGestureLayout(workflow) || !hasGestureOverlayOrRetry;' `
  'live gesture preparing state must retain durable success/failure.'
Assert-Contains $runAsync 'shouldPublishLiveGesturePreparingStatus(' 'automatic gesture frames must preserve last valid state.'
Assert-Contains $runAsync "this.gestureDetections.length > 0 || this.liveGestureRetryAction() !== 'none'" `
  'gesture preparing state must account for last overlay and Retry.'
foreach ($marker in @(
  'const action = liveGestureRetryActionForStatus(workflow, this.statusKey);',
  'this.liveCameraInputSelected = true;',
  'this.startLiveCameraPreview();',
  'this.stopLiveRuntimeLoop();',
  'this.startLiveRuntimeLoop(workflow);'
)) { Assert-Contains $retry $marker "live gesture Retry is missing: $marker" }
Assert-Excludes $retry "this.prepareInput('camera')" 'live gesture Retry must not replace the active camera input.'
$stopIndex = $retry.IndexOf('this.stopLiveRuntimeLoop();', [StringComparison]::Ordinal)
$startIndex = $retry.IndexOf('this.startLiveRuntimeLoop(workflow);', [StringComparison]::Ordinal)
if ($stopIndex -lt 0 -or $startIndex -lt 0 -or $stopIndex -gt $startIndex) {
  Fail 'gesture inference Retry must stop the old loop before restarting.'
}

Assert-Contains $clearPolicy '!usesAndroidLiveGestureLayout(workflow)' 'gesture startup must retain the last valid overlay.'
Assert-Contains $textPreservation 'usesAndroidLiveGestureLayout(workflow)' 'gesture failures must retain the last valid text state.'
Assert-Contains $visualPreservation 'if (usesAndroidLiveGestureLayout(workflow)) {' 'gesture visual preservation is missing.'
Assert-Contains $visualPreservation "return !resultOk || dataKind === 'gesture';" 'gesture failures must retain the last valid overlay.'
Assert-Contains $updateGesture "if (!result.ok) {`n        return;`n      }" 'gesture failure must not clear the last valid overlay.'
Assert-Contains $cameraInputPreservation 'return usesAndroidLiveGestureLayout(workflow);' `
  'only live gesture failures may preserve the active camera input.'
foreach ($marker in @(
  'const preserveCameraInput = shouldPreserveLiveCameraInputOnFailure(workflow);',
  'if (result.ok || !preserveCameraInput) {',
  'if (!preserveCameraInput) {',
  'this.liveCameraInputSelected = false;'
)) { Assert-Contains $previewResult $marker "camera failure preservation is incomplete: $marker" }

Assert-TopLevelBuildExecution $buildPath 'check-live-gesture-runtime-ui.ps1'
Assert-TopLevelBuildExecution $buildPath 'test-live-gesture-runtime-ui-guard.ps1'

Write-Output 'Live gesture runtime UI parity is present.'
