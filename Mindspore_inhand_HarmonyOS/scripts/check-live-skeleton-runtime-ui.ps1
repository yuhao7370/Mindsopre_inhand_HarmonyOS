param(
  [string]$SourceRoot = ''
)

$ErrorActionPreference = 'Stop'

function Fail([string]$Message) {
  throw "Live skeleton runtime UI guard failed: $Message"
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
      if ($escaped) {
        [void]$literal.Append($current); $escaped = $false
      } elseif ($current -eq [char]0x5C) {
        [void]$literal.Append($current); $escaped = $true
      } elseif ($current -eq $quote) {
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

function Balanced-BuilderSection([string]$CodeText, [string]$Start, [string]$Name) {
  $startIndex = $CodeText.IndexOf($Start, [StringComparison]::Ordinal)
  if ($startIndex -lt 0) { Fail "missing $Name start marker: $Start" }
  $openIndex = $startIndex + $Start.LastIndexOf('{', [StringComparison]::Ordinal)
  if ($openIndex -lt $startIndex) { Fail "missing $Name opening brace." }
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
$page = Convert-ArkTsToGuardCode (Read-Normalized $pagePath)
$catalog = Convert-ArkTsToGuardCode (Read-Normalized $catalogPath)

$skeletonLayout = Balanced-Section $page '  skeletonAndroidLiveLayout() {' 'live skeleton layout'
$skeletonCanvas = Balanced-BuilderSection $skeletonLayout 'Stack({ alignContent: Alignment.TopStart }) {' 'live skeleton camera canvas'
$skeletonStatus = Balanced-Section $page '  liveSkeletonStatusOverlay() {' 'live skeleton status overlay'
$surface = Balanced-Section $page '  liveCameraSurfaceContent() {' 'shared live camera surface'
$poseTemplate = Balanced-Section $page '  livePoseTemplateOverlay() {' 'live pose template overlay'
$posePointStyle = Balanced-Section $page '  private posePointStyle(point: PosePoint): PosePointPercent {' 'pose point coordinate style'
$poseLineStyle = Balanced-Section $page '  private poseLineStyle(line: PoseLine): PoseLinePercent {' 'pose limb coordinate style'
$updatePose = Balanced-Section $page '  private updatePosePreview(result: AiRunResult): void {' 'live pose publication'
$retry = Balanced-Section $page '  private retryLiveSkeleton(): void {' 'live skeleton retry'
$runAsync = Balanced-Section $page '  private async runWorkflowAsync(' 'workflow execution'
$previewResult = Balanced-Section $page '  private applyLiveCameraPreviewResult(result: LiveCameraPreviewResult): void {' 'live camera preview result'
$layoutRouter = Balanced-Section $page '  runtimeLayoutContent() {' 'runtime layout router'
$aboutToAppear = Balanced-Section $page '  aboutToAppear() {' 'runtime page startup'
$initialCamera = Balanced-Section $catalog 'export function initialLiveCameraPositionForWorkflow(' 'initial live camera policy'
$cameraMemory = Balanced-Section $catalog 'export function rememberedLiveCameraPositionForWorkflow(' 'camera memory restore'
$cameraRemember = Balanced-Section $catalog 'export function rememberLiveCameraPositionForRoute(' 'camera memory update'
$skeletonRoute = Balanced-Section $catalog 'export function usesAndroidLiveSkeletonLayout(' 'live skeleton route policy'
$specializedLayout = Balanced-Section $catalog 'export function specializedAndroidLiveLayoutForWorkflow(' 'specialized live layout policy'
$retryMapping = Balanced-Section $catalog 'export function liveSkeletonRetryActionForStatus(' 'live skeleton retry mapping'
$preparingPolicy = Balanced-Section $catalog 'export function shouldPublishLiveSkeletonPreparingStatus(' 'live skeleton preparing policy'
$clearPolicy = Balanced-Section $catalog 'export function shouldClearRuntimeResultAtWorkflowStart(' 'live skeleton result clear policy'
$textPreservation = Balanced-Section $catalog 'export function shouldPreserveRuntimeTextResultOnAiResult(' 'live skeleton text preservation'
$visualPreservation = Balanced-Section $catalog 'export function shouldPreserveRuntimeVisualResultOnAiResult(' 'live skeleton visual preservation'
$cameraInputPreservation = Balanced-Section $catalog 'export function shouldPreserveLiveCameraInputOnFailure(' 'live skeleton camera input preservation'
$skeletonWorkflowMatch = [regex]::Match($catalog, '(?s)\{\s*routeName:\s*AppRoute\.LIVE_SKELETON\.name,.*?\n\s*\},')
if (-not $skeletonWorkflowMatch.Success) { Fail 'missing live skeleton workflow definition.' }
$skeletonWorkflow = $skeletonWorkflowMatch.Value

Assert-Contains $catalog 'export type LiveSkeletonRetryAction =' 'missing live skeleton Retry action type.'
Assert-Contains $skeletonRoute 'return workflow?.routeName === AppRoute.LIVE_SKELETON.name;' 'live skeleton behavior must be route isolated.'
Assert-Contains $specializedLayout "if (usesAndroidLiveSkeletonLayout(workflow)) {`n    return 'skeleton';`n  }" `
  'live skeleton must select its own layout in the specialized runtime branch.'
$simpleLayout = Balanced-Section $catalog 'export function usesSimpleAndroidLiveLayout(' 'shared simple live layout routes'
Assert-Excludes $simpleLayout 'AppRoute.LIVE_SKELETON.name' 'live skeleton must leave the shared simple live layout.'
Assert-Contains $layoutRouter "specializedAndroidLiveLayoutForWorkflow(workflowForRoute(this.routeName)) === 'skeleton'" 'runtime router must select the live skeleton layout.'
Assert-Contains $layoutRouter 'this.skeletonAndroidLiveLayout()' 'runtime router must render the live skeleton layout.'

Assert-Contains $initialCamera "if (workflow.routeName === AppRoute.LIVE_SKELETON.name) {`n    return 'back';`n  }" `
  'live skeleton must default to the rear camera.'
foreach ($marker in @('rememberedLiveCameraPositions.get(routeName)', 'return rememberedPosition ?? initialLiveCameraPositionForWorkflow(workflow);')) {
  Assert-Contains $cameraMemory $marker "live skeleton must restore camera position per route: $marker"
}
Assert-Contains $cameraRemember 'rememberedLiveCameraPositions.set(routeName, position);' 'camera switch must persist per route.'
Assert-Contains $skeletonWorkflow "inputKinds: ['camera']" 'live skeleton may use only the camera input.'
Assert-Contains $skeletonWorkflow "requiredPermissions: ['camera']" 'live skeleton must request CAMERA only.'
Assert-Excludes $skeletonWorkflow 'media' 'live skeleton must not request media.'
Assert-Excludes $aboutToAppear 'requestForWorkflow' 'runtime page startup must stay permission-free.'

foreach ($marker in @(
  'this.runtimeActionToolbar(true)',
  'this.liveCameraSurfaceContent()',
  'this.liveSkeletonStatusOverlay()',
  'if (this.liveCameraSwitchAvailable) {',
  'this.runtimeCameraSwitchAction()',
  ".width('100%')",
  '.layoutWeight(1)'
)) { Assert-Contains $skeletonLayout $marker "live skeleton layout is incomplete: $marker" }
Assert-Contains $skeletonCanvas 'this.liveCameraSurfaceContent()' 'live skeleton camera canvas is incomplete.'
Assert-Excludes $skeletonCanvas 'this.runtimeCameraSwitchAction()' `
  'live skeleton camera switch must not cover the pose canvas.'
Assert-Excludes $skeletonCanvas 'this.liveSkeletonStatusOverlay()' `
  'live skeleton status must not cover the pose canvas.'
Assert-Contains $skeletonLayout "Row({ space: AppSpacing.sm }) {`n        this.liveSkeletonStatusOverlay()" `
  'live skeleton needs an independent status/action lane below the camera canvas.'
Assert-Contains $skeletonLayout "if (this.liveCameraSwitchAvailable) {`n          this.runtimeCameraSwitchAction()" `
  'live skeleton action lane must keep the camera switch outside pose content.'
foreach ($marker in @(
  'Text(appString(this.statusKey))',
  'LoadingProgress()',
  "if (this.liveSkeletonRetryAction() !== 'none')",
  '.onClick(() => this.retryLiveSkeleton())',
  '.constraintSize({ minWidth: 72, minHeight: 48 })',
  '.constraintSize({ maxWidth: 520 })',
  '.layoutWeight(1)',
  '.constraintSize({ maxWidth: 520 })',
  '.maxLines(2)',
  '.textOverflow({ overflow: TextOverflow.Ellipsis })',
  '.maxFontScale(3.2)',
  ".backgroundColor('#B31F2937')"
)) { Assert-Contains $skeletonStatus $marker "live skeleton status is incomplete: $marker" }
Assert-Excludes $skeletonStatus ".width('calc(100% - 32vp)')" `
  'live skeleton status must share the bounded action lane instead of covering the camera.'
foreach ($forbidden in @('.height(100)', '.height(96)', '.maxHeight:')) {
  Assert-Excludes $skeletonStatus $forbidden "live skeleton status must not permanently cover the camera: $forbidden"
}

Assert-Contains $surface 'this.poseLine(line)' 'live skeleton surface must render pose limbs.'
Assert-Contains $surface 'this.posePoint(point)' 'live skeleton surface must render pose points.'
Assert-Contains $surface 'this.livePoseTemplateOverlay()' 'live skeleton surface must render the route-specific template.'
$templateIndex = $surface.IndexOf('this.livePoseTemplateOverlay()', [StringComparison]::Ordinal)
$lineIndex = $surface.IndexOf('this.poseLine(line)', [StringComparison]::Ordinal)
$pointIndex = $surface.IndexOf('this.posePoint(point)', [StringComparison]::Ordinal)
if ($templateIndex -lt 0 -or $lineIndex -lt 0 -or $pointIndex -lt 0 -or
  $templateIndex -gt $lineIndex -or $templateIndex -gt $pointIndex) {
  Fail 'live skeleton template must paint before pose limbs and points.'
}
Assert-Contains $poseTemplate 'Text(`Similarity:${this.livePoseSimilarityPercent()}`)' `
  'pose template must expose the complete Similarity label.'
Assert-Contains $poseTemplate '.width(196)' 'pose template similarity label needs a bounded two-line width at 3.2x.'
Assert-Contains $poseTemplate '.maxLines(2)' 'pose template similarity label must remain fully visible at 3.2x.'
Assert-Excludes $poseTemplate '.height(18)' 'pose template similarity label must not use a clipping fixed height.'
Assert-Excludes $poseTemplate '.textOverflow(' 'pose template similarity label must not hide text with ellipsis.'
Assert-Excludes $poseTemplate '.maxFontScale(' 'pose template similarity label must not cap 3.2x text.'
Assert-Contains $catalog "return shouldShowLivePoseCameraOverlay(workflow) && liveCameraPosition === 'front';" `
  'front live skeleton overlays must mirror and rear overlays must remain unmirrored.'
Assert-Contains $posePointStyle 'shouldMirrorLivePoseCameraOverlay(workflowForRoute(this.routeName), this.liveCameraPosition)' `
  'pose points must use the front-only mirror policy.'
Assert-Contains $poseLineStyle 'shouldMirrorLivePoseCameraOverlay(workflowForRoute(this.routeName), this.liveCameraPosition)' `
  'pose limbs must use the same front-only mirror policy.'
Assert-Contains $posePointStyle 'posePointPercent(' 'pose points must retain the preview coordinate transform.'
Assert-Contains $poseLineStyle 'poseLinePercent(' 'pose limbs must retain the preview coordinate transform.'

foreach ($status in @(
  'feature_runtime_live_camera_failed',
  'feature_runtime_live_camera_surface_missing',
  'feature_runtime_permission_denied',
  'feature_runtime_live_frame_failed',
  'feature_runtime_run_failed',
  'feature_runtime_pending_adapter',
  'feature_runtime_pose_failed'
)) { Assert-Contains $retryMapping "'$status'" "live skeleton Retry mapping is missing $status." }
Assert-Contains $retryMapping 'if (!usesAndroidLiveSkeletonLayout(workflow)) {' 'live skeleton Retry must remain route specific.'
Assert-Contains $preparingPolicy '!usesAndroidLiveSkeletonLayout(workflow) || !hasPoseOverlayOrRetry;' `
  'live skeleton preparing state must retain durable success/failure.'
Assert-Contains $runAsync 'shouldPublishLiveSkeletonPreparingStatus(' 'automatic skeleton frames must preserve last valid state.'
Assert-Contains $runAsync "this.posePoints.length > 0 || this.liveSkeletonRetryAction() !== 'none'" `
  'skeleton preparing state must account for last overlay and Retry.'
foreach ($marker in @(
  'const action = liveSkeletonRetryActionForStatus(workflow, this.statusKey);',
  'this.liveCameraInputSelected = true;',
  'this.startLiveCameraPreview();',
  'this.stopLiveRuntimeLoop();',
  'this.startLiveRuntimeLoop(workflow);'
)) { Assert-Contains $retry $marker "live skeleton Retry is missing: $marker" }
Assert-Excludes $retry "this.prepareInput('camera')" 'live skeleton Retry must not replace the active camera input.'
$stopIndex = $retry.IndexOf('this.stopLiveRuntimeLoop();', [StringComparison]::Ordinal)
$startIndex = $retry.IndexOf('this.startLiveRuntimeLoop(workflow);', [StringComparison]::Ordinal)
if ($stopIndex -lt 0 -or $startIndex -lt 0 -or $stopIndex -gt $startIndex) {
  Fail 'skeleton inference Retry must stop the old loop before restarting.'
}

Assert-Contains $clearPolicy '!usesAndroidLiveSkeletonLayout(workflow)' 'skeleton startup must retain the last valid overlay.'
Assert-Contains $textPreservation 'usesAndroidLiveSkeletonLayout(workflow)' 'skeleton failures must retain the last valid result state.'
Assert-Contains $visualPreservation 'if (usesAndroidLiveSkeletonLayout(workflow)) {' 'skeleton visual preservation is missing.'
Assert-Contains $visualPreservation "return !resultOk || dataKind === 'pose';" 'skeleton failures must retain the last valid pose overlay.'
Assert-Contains $updatePose "if (usesAndroidLiveSkeletonLayout(workflowForRoute(this.routeName))) {`n      if (!result.ok) {`n        return;`n      }`n    }" `
  'skeleton failure must not clear the last valid overlay.'
Assert-Contains $cameraInputPreservation 'usesAndroidLiveSkeletonLayout(workflow)' `
  'live skeleton failures must preserve the active camera input.'
foreach ($marker in @(
  'const preserveCameraInput = shouldPreserveLiveCameraInputOnFailure(workflow);',
  'if (result.ok || !preserveCameraInput) {',
  'if (!preserveCameraInput) {',
  'this.liveCameraInputSelected = false;'
)) { Assert-Contains $previewResult $marker "camera failure preservation is incomplete: $marker" }

Assert-TopLevelBuildExecution $buildPath 'check-live-skeleton-runtime-ui.ps1'
Assert-TopLevelBuildExecution $buildPath 'test-live-skeleton-runtime-ui-guard.ps1'

Write-Output 'Live skeleton runtime UI parity is present.'
