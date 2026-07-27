param(
  [string]$SourceRoot = ''
)

$ErrorActionPreference = 'Stop'

function Fail([string]$Message) {
  throw "Live scene runtime UI guard failed: $Message"
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
      if ($escaped) {
        [void]$literal.Append($current)
        $escaped = $false
      } elseif ($current -eq [char]0x5C) {
        [void]$literal.Append($current)
        $escaped = $true
      } elseif ($current -eq $quote) {
        $bytes = [Text.Encoding]::UTF8.GetBytes($literal.ToString())
        $hex = [BitConverter]::ToString($bytes).Replace('-', '')
        [void]$result.Append("__ARK_LITERAL_${hex}__")
        $literal.Clear() | Out-Null
        $state = 'code'
      } elseif ($current -eq [char]0x0A) {
        [void]$literal.Append($current)
        [void]$result.Append($current)
      } else {
        [void]$literal.Append($current)
      }
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
$page = Convert-ArkTsToGuardCode $pageRaw
$catalog = Convert-ArkTsToGuardCode $catalogRaw

$sceneLayout = Balanced-Section $page '  sceneAndroidLiveLayout() {' 'live scene layout'
$sceneActionLane = Balanced-Section $page '  sceneLiveOverlayAndCameraActionLane() {' 'live scene overlay and camera action lane'
$sceneSurface = Balanced-Section $page '  liveCameraSurfaceContent() {' 'live camera surface'
$sceneStatus = Balanced-Section $page '  liveSceneStatusOverlay() {' 'live scene status overlay'
$sceneOverlay = Balanced-Section $page '  liveSceneOverlay() {' 'live scene overlay'
$sceneUpdate = Balanced-Section $page '  private updateSceneOverlay(result: AiRunResult): void {' 'live scene publication'
$sceneRetry = Balanced-Section $page '  private retryLiveScene(): void {' 'live scene retry'
$runAsync = Balanced-Section $page '  private async runWorkflowAsync(' 'workflow execution'
$previewResult = Balanced-Section $page '  private applyLiveCameraPreviewResult(result: LiveCameraPreviewResult): void {' 'live camera preview result'
$layoutRouter = Balanced-Section $page '  runtimeLayoutContent() {' 'runtime layout router'
$initialCamera = Balanced-Section $catalog 'export function initialLiveCameraPositionForWorkflow(' 'initial live camera policy'
$cameraMemory = Balanced-Section $catalog 'export function rememberedLiveCameraPositionForWorkflow(' 'camera memory restore'
$cameraRemember = Balanced-Section $catalog 'export function rememberLiveCameraPositionForRoute(' 'camera memory update'
$sceneRoute = Balanced-Section $catalog 'export function usesAndroidLiveSceneLayout(' 'live scene route policy'
$retryMapping = Balanced-Section $catalog 'export function liveSceneRetryActionForStatus(' 'live scene retry mapping'
$preparingPolicy = Balanced-Section $catalog 'export function shouldPublishLiveScenePreparingStatus(' 'live scene preparing policy'
$clearPolicy = Balanced-Section $catalog 'export function shouldClearRuntimeResultAtWorkflowStart(' 'live scene result clear policy'
$textPreservation = Balanced-Section $catalog 'export function shouldPreserveRuntimeTextResultOnAiResult(' 'live scene text preservation'
$visualPreservation = Balanced-Section $catalog 'export function shouldPreserveRuntimeVisualResultOnAiResult(' 'live scene visual preservation'
$cameraInputPreservation = Balanced-Section $catalog 'export function shouldPreserveLiveCameraInputOnFailure(' 'live scene camera input preservation'
$sceneWorkflowMatch = [regex]::Match(
  $catalog,
  '(?s)\{\s*routeName:\s*AppRoute\.SCENE_LIVE\.name,.*?\n\s*\},'
)
if (-not $sceneWorkflowMatch.Success) { Fail 'missing live scene workflow definition.' }
$sceneWorkflow = $sceneWorkflowMatch.Value
$aboutToAppear = Balanced-Section $page '  aboutToAppear() {' 'runtime page startup'
$sceneUpdateCode = Balanced-Section $page '  private updateSceneOverlay(result: AiRunResult): void {' 'live scene publication code'

Assert-Contains $catalog 'export type LiveSceneRetryAction =' 'missing live scene Retry action type.'
Assert-Contains $sceneRoute 'return workflow?.routeName === AppRoute.SCENE_LIVE.name;' 'live scene behavior must be route isolated.'
Assert-Contains $catalog "return 'scene';" 'live scene must select its own layout.'
$simpleLayout = Balanced-Section $catalog 'export function usesSimpleAndroidLiveLayout(' 'shared simple live layout routes'
Assert-Excludes $simpleLayout 'AppRoute.SCENE_LIVE.name' 'live scene must leave the shared simple live layout.'
Assert-Contains $layoutRouter "specializedAndroidLiveLayoutForWorkflow(workflowForRoute(this.routeName)) === 'scene'" 'runtime router must select the live scene layout.'
Assert-Contains $layoutRouter 'this.sceneAndroidLiveLayout()' 'runtime router must render the live scene layout.'

foreach ($marker in @('workflow.routeName === AppRoute.SCENE_LIVE.name', "return 'front';")) {
  Assert-Contains $initialCamera $marker "live scene must default to the front camera: $marker"
}
foreach ($marker in @('rememberedLiveCameraPositions.get(routeName)', 'return rememberedPosition ?? initialLiveCameraPositionForWorkflow(workflow);')) {
  Assert-Contains $cameraMemory $marker "live scene must restore camera position per route: $marker"
}
Assert-Contains $cameraRemember 'rememberedLiveCameraPositions.set(routeName, position);' 'camera switch must persist per route.'
Assert-Contains $sceneWorkflow "inputKinds: ['camera']" 'live scene may use only the camera input.'
Assert-Contains $sceneWorkflow "requiredPermissions: ['camera']" 'live scene must request CAMERA only.'
Assert-Excludes $sceneWorkflow 'media' 'live scene must not request media.'
Assert-Excludes $aboutToAppear 'requestForWorkflow' 'runtime page startup must stay permission-free.'

foreach ($marker in @(
  'this.runtimeActionToolbar(true)',
  'this.liveCameraSurfaceContent()',
  'this.sceneLiveOverlayAndCameraActionLane()',
  'this.liveSceneStatusOverlay()',
  ".width('100%')",
  '.layoutWeight(1)'
)) { Assert-Contains $sceneLayout $marker "live scene layout is incomplete: $marker" }
foreach ($marker in @(
  'Row({ space: AppSpacing.sm }) {',
  'if (this.sceneOverlayRows.length > 0 && this.shouldShowLiveSceneOverlay()) {',
  'this.liveSceneOverlay()',
  'if (this.liveCameraSwitchAvailable) {',
  'this.runtimeCameraSwitchAction()',
  '.padding({ left: AppSpacing.md, right: AppSpacing.md })',
  '.justifyContent(FlexAlign.End)'
)) { Assert-Contains $sceneActionLane $marker "live scene overlay/action lane is incomplete: $marker" }
Assert-Excludes $sceneSurface 'this.liveSceneOverlay()' `
  'live scene result card must not be layered directly over the camera surface.'

foreach ($marker in @(
  'ForEach(this.sceneOverlayRows, (row: SceneDetectionOverlayRow) => {',
  'Scroll() {',
  '.constraintSize({ maxWidth: 360, maxHeight: 176 })',
  '.layoutWeight(1)',
  '.maxLines(3)',
  '.maxFontScale(3.2)',
  ".backgroundColor('#B31F2937')"
)) { Assert-Contains $sceneOverlay $marker "live scene labels must be multiple, bounded, and legible: $marker" }
Assert-Excludes $sceneOverlay ".width('calc(100% - 32vp)')" `
  'live scene result card must use the independent action lane width, not an overlapping full camera width.'
Assert-Excludes $sceneOverlay '.margin({ left: AppSpacing.md' `
  'live scene result card must not be positioned into the camera action safe lane.'
Assert-Excludes $sceneOverlay '.textOverflow({ overflow: TextOverflow.Ellipsis })' `
  'live scene labels must remain fully accessible at 3.2x instead of being ellipsized.'
Assert-Contains $sceneOverlay '.width(96)' `
  'live scene labels need a 96vp column so localized labels remain visible at 3.2x.'
$sceneValue = [regex]::Match($sceneOverlay, '(?s)Text\(row\.value\).*?\.layoutWeight\(1\)')
if (-not $sceneValue.Success) { Fail 'live scene result value renderer is missing.' }
Assert-Excludes $sceneValue.Value '.maxLines(' `
  'live scene result values must remain vertically scroll-accessible instead of being line-clipped.'
foreach ($forbidden in @('.width(190)', '.height(100)', '.height(96)', '.maxLines(4)')) {
  Assert-Excludes $sceneOverlay $forbidden "live scene overlay must not become a permanent large canvas panel: $forbidden"
}

foreach ($marker in @(
  'Text(appString(this.statusKey))',
  'LoadingProgress()',
  "if (this.liveSceneRetryAction() !== 'none')",
  '.onClick(() => this.retryLiveScene())',
  '.constraintSize({ minWidth: 72, minHeight: 48 })',
  '.constraintSize({ maxWidth: 520 })',
  ".width('calc(100% - 32vp)')",
  '.maxLines(2)',
  '.textOverflow({ overflow: TextOverflow.Ellipsis })',
  '.maxFontScale(3.2)',
  ".backgroundColor('#B31F2937')"
)) { Assert-Contains $sceneStatus $marker "live scene status is incomplete: $marker" }
foreach ($forbidden in @('.height(100)', '.height(96)', '.maxHeight:')) {
  Assert-Excludes $sceneStatus $forbidden "live scene status must not permanently cover the camera: $forbidden"
}

foreach ($status in @(
  'feature_runtime_live_camera_failed',
  'feature_runtime_live_camera_surface_missing',
  'feature_runtime_permission_denied',
  'feature_runtime_live_frame_failed',
  'feature_runtime_run_failed',
  'feature_runtime_pending_adapter',
  'feature_runtime_scene_runner_unavailable',
  'feature_runtime_scene_failed'
)) { Assert-Contains $retryMapping "'$status'" "live scene Retry mapping is missing $status." }
Assert-Contains $retryMapping 'if (!usesAndroidLiveSceneLayout(workflow)) {' 'live scene Retry must remain route specific.'
Assert-Contains $preparingPolicy '!usesAndroidLiveSceneLayout(workflow) || !hasSceneOverlayOrRetry;' `
  'live scene preparing state must retain durable success/failure.'
Assert-Contains $runAsync 'shouldPublishLiveScenePreparingStatus(' 'automatic scene frames must preserve last valid state.'
Assert-Contains $runAsync "this.sceneOverlayRows.length > 0 || this.liveSceneRetryAction() !== 'none'" `
  'scene preparing state must account for last labels and Retry.'
foreach ($marker in @(
  'const action = liveSceneRetryActionForStatus(workflow, this.statusKey);',
  'this.liveCameraInputSelected = true;',
  'this.startLiveCameraPreview();',
  'this.stopLiveRuntimeLoop();',
  'this.startLiveRuntimeLoop(workflow);'
)) { Assert-Contains $sceneRetry $marker "live scene Retry is missing: $marker" }
Assert-Excludes $sceneRetry "this.prepareInput('camera')" 'live scene Retry must not replace the active camera input.'
$stopIndex = $sceneRetry.IndexOf('this.stopLiveRuntimeLoop();', [StringComparison]::Ordinal)
$startIndex = $sceneRetry.IndexOf('this.startLiveRuntimeLoop(workflow);', [StringComparison]::Ordinal)
if ($stopIndex -lt 0 -or $startIndex -lt 0 -or $stopIndex -gt $startIndex) {
  Fail 'scene inference Retry must stop the old loop before restarting.'
}

Assert-Contains $clearPolicy '!usesAndroidLiveSceneLayout(workflow)' 'scene startup must retain the last valid labels.'
Assert-Contains $textPreservation 'usesAndroidLiveSceneLayout(workflow)' 'scene failures must retain the last valid result labels.'
Assert-Contains $visualPreservation 'if (usesAndroidLiveSceneLayout(workflow)) {' 'scene visual preservation is missing.'
Assert-Contains $visualPreservation "return !resultOk || dataKind === 'scenes';" 'scene failures must retain the last valid labels.'
Assert-Contains $sceneUpdateCode "if (!result.ok) {`n      return;`n    }" 'scene failure must not clear the last valid labels.'
Assert-Contains $sceneUpdateCode 'this.sceneOverlayRows = sceneDetectionOverlayRows(data.result);' 'scene success must publish multiple labels.'
Assert-Contains $cameraInputPreservation 'usesAndroidLiveSceneLayout(workflow)' `
  'live scene failures must preserve the active camera input.'
foreach ($marker in @(
  'const preserveCameraInput = shouldPreserveLiveCameraInputOnFailure(workflow);',
  'if (result.ok || !preserveCameraInput) {',
  'if (!preserveCameraInput) {',
  'this.liveCameraInputSelected = false;'
)) { Assert-Contains $previewResult $marker "camera failure preservation is incomplete: $marker" }

Assert-TopLevelBuildExecution $buildPath 'check-live-scene-runtime-ui.ps1'
Assert-TopLevelBuildExecution $buildPath 'test-live-scene-runtime-ui-guard.ps1'

Write-Output 'Live scene runtime UI parity is present.'
