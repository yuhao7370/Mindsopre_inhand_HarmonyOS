param(
  [string]$SourceRoot = ''
)

$ErrorActionPreference = 'Stop'

function Fail([string]$Message) {
  throw "Live object-detection layout guard failed: $Message"
}

function Read-Normalized([string]$Path) {
  if (-not [IO.File]::Exists($Path)) {
    Fail "missing source file: $Path"
  }
  return ([IO.File]::ReadAllText($Path)).Replace("`r`n", "`n").Replace("`r", "`n")
}

function Remove-ArkTsCommentsAndLiteralText([string]$Text) {
  $result = [Text.StringBuilder]::new($Text.Length)
  $state = 'code'
  $quote = [char]0
  $escaped = $false
  $templateExpressionDepth = 0
  $returnState = 'code'
  for ($index = 0; $index -lt $Text.Length; $index++) {
    $current = $Text[$index]
    $next = if ($index + 1 -lt $Text.Length) { $Text[$index + 1] } else { [char]0 }

    if ($state -eq 'line') {
      [void]$result.Append($(if ($current -eq [char]0x0A) { "`n" } else { ' ' }))
      if ($current -eq [char]0x0A) { $state = $returnState }
      continue
    }
    if ($state -eq 'block') {
      if ($current -eq [char]0x2A -and $next -eq [char]0x2F) {
        [void]$result.Append('  ')
        $index++
        $state = $returnState
      } else {
        [void]$result.Append($(if ($current -eq [char]0x0A) { "`n" } else { ' ' }))
      }
      continue
    }
    if ($state -eq 'string') {
      [void]$result.Append($(if ($current -eq [char]0x0A) { "`n" } else { ' ' }))
      if ($escaped) {
        $escaped = $false
      } elseif ($current -eq [char]0x5C) {
        $escaped = $true
      } elseif ($current -eq $quote) {
        $state = $returnState
      }
      continue
    }
    if ($state -eq 'template') {
      if ($escaped) {
        [void]$result.Append($(if ($current -eq [char]0x0A) { "`n" } else { ' ' }))
        $escaped = $false
      } elseif ($current -eq [char]0x5C) {
        [void]$result.Append(' ')
        $escaped = $true
      } elseif ($current -eq [char]0x60) {
        [void]$result.Append(' ')
        $state = 'code'
      } elseif ($current -eq [char]0x24 -and $next -eq [char]0x7B) {
        [void]$result.Append('  ')
        $index++
        $templateExpressionDepth = 1
        $state = 'templateExpression'
      } else {
        [void]$result.Append($(if ($current -eq [char]0x0A) { "`n" } else { ' ' }))
      }
      continue
    }
    if ($state -eq 'templateExpression') {
      if ($current -eq [char]0x7B) {
        $templateExpressionDepth++
        [void]$result.Append($current)
      } elseif ($current -eq [char]0x7D) {
        $templateExpressionDepth--
        [void]$result.Append($(if ($templateExpressionDepth -eq 0) { ' ' } else { $current }))
        if ($templateExpressionDepth -eq 0) { $state = 'template' }
      } elseif ($current -eq [char]0x2F -and $next -eq [char]0x2F) {
        [void]$result.Append('  ')
        $index++
        $returnState = 'templateExpression'
        $state = 'line'
      } elseif ($current -eq [char]0x2F -and $next -eq [char]0x2A) {
        [void]$result.Append('  ')
        $index++
        $returnState = 'templateExpression'
        $state = 'block'
      } elseif ($current -eq [char]0x22 -or $current -eq [char]0x27) {
        [void]$result.Append(' ')
        $quote = $current
        $escaped = $false
        $returnState = 'templateExpression'
        $state = 'string'
      } elseif ($current -eq [char]0x60) {
        [void]$result.Append(' ')
        $escaped = $false
        $state = 'template'
      } else {
        [void]$result.Append($current)
      }
      continue
    }

    if ($current -eq [char]0x2F -and $next -eq [char]0x2F) {
      [void]$result.Append('  ')
      $index++
      $returnState = 'code'
      $state = 'line'
    } elseif ($current -eq [char]0x2F -and $next -eq [char]0x2A) {
      [void]$result.Append('  ')
      $index++
      $returnState = 'code'
      $state = 'block'
    } elseif ($current -eq [char]0x22 -or $current -eq [char]0x27) {
      [void]$result.Append(' ')
      $quote = $current
      $escaped = $false
      $returnState = 'code'
      $state = 'string'
    } elseif ($current -eq [char]0x60) {
      [void]$result.Append(' ')
      $escaped = $false
      $state = 'template'
    } else {
      [void]$result.Append($current)
    }
  }
  return $result.ToString()
}

function Section([string]$Text, [string]$Start, [string]$End, [string]$Name) {
  $startIndex = $Text.IndexOf($Start, [StringComparison]::Ordinal)
  if ($startIndex -lt 0) { Fail "missing $Name start marker: $Start" }
  $endIndex = $Text.IndexOf($End, $startIndex + $Start.Length, [StringComparison]::Ordinal)
  if ($endIndex -lt 0) { Fail "missing $Name end marker: $End" }
  return $Text.Substring($startIndex, $endIndex - $startIndex)
}

function Balanced-Section([string]$Text, [string]$Start, [string]$Name) {
  $startIndex = $Text.IndexOf($Start, [StringComparison]::Ordinal)
  if ($startIndex -lt 0) { Fail "missing $Name start marker: $Start" }
  $markerBraceIndex = $Start.LastIndexOf('{')
  $braceIndex = if ($markerBraceIndex -ge 0) {
    $startIndex + $markerBraceIndex
  } else {
    $Text.IndexOf('{', $startIndex + $Start.Length, [StringComparison]::Ordinal)
  }
  if ($braceIndex -lt 0) { Fail "missing $Name opening brace." }
  $depth = 0
  for ($index = $braceIndex; $index -lt $Text.Length; $index++) {
    if ($Text[$index] -eq [char]0x7B) {
      $depth++
    } elseif ($Text[$index] -eq [char]0x7D) {
      $depth--
      if ($depth -eq 0) {
        return $Text.Substring($startIndex, $index - $startIndex + 1)
      }
    }
  }
  Fail "missing $Name closing brace."
}

function Balanced-Section-UsingBounds(
  [string]$Text,
  [string]$BoundsText,
  [string]$Start,
  [string]$Name
) {
  $section = Balanced-Section $BoundsText $Start $Name
  $startIndex = $BoundsText.IndexOf($Start, [StringComparison]::Ordinal)
  return $Text.Substring($startIndex, $section.Length)
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
  $ast = [Management.Automation.Language.Parser]::ParseFile(
    $BuildPath,
    [ref]$tokens,
    [ref]$parseErrors
  )
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
$servicePath = Join-Path $root 'entry\src\main\ets\services\ai\ObjectDetectionService.ets'
$buildPath = Join-Path $root 'scripts\build-hap.ps1'
$pageRaw = Read-Normalized $pagePath
$catalogRaw = Read-Normalized $catalogPath
$serviceRaw = Read-Normalized $servicePath
$page = Remove-ArkTsCommentsAndLiteralText $pageRaw
$catalog = Remove-ArkTsCommentsAndLiteralText $catalogRaw
$service = Remove-ArkTsCommentsAndLiteralText $serviceRaw

$layout = Balanced-Section $page '  objectDetectionAndroidLiveLayout() {' 'live object layout'
$layoutRaw = Balanced-Section-UsingBounds $pageRaw $page `
  '  objectDetectionAndroidLiveLayout() {' 'live object layout literals'
$statusOverlay = Balanced-Section $page '  liveObjectDetectionStatusOverlay() {' 'live object status overlay'
$statusOverlayRaw = Balanced-Section-UsingBounds $pageRaw $page `
  '  liveObjectDetectionStatusOverlay() {' 'live object status overlay literals'
$box = Balanced-Section $page `
  '  liveObjectDetectionBox(detection: ObjectDetection, index: number) {' 'live object box'
$boxRaw = Balanced-Section-UsingBounds $pageRaw $page `
  '  liveObjectDetectionBox(detection: ObjectDetection, index: number) {' 'live object box literals'
$surface = Balanced-Section $page '  liveCameraSurfaceContent() {' 'live camera surface'
$retry = Balanced-Section $page '  private retryLiveObjectDetection(): void {' 'live object retry'
$retryRaw = Balanced-Section-UsingBounds $pageRaw $page `
  '  private retryLiveObjectDetection(): void {' 'live object retry literals'
$permissionRetry = Balanced-Section $page '  private retryRuntimeCameraInput(): void {' 'shared camera retry'
$permissionRetryRaw = Balanced-Section-UsingBounds $pageRaw $page `
  '  private retryRuntimeCameraInput(): void {' 'shared camera retry literals'
$runPrimary = Balanced-Section $page '  private runPrimaryAction(): void {' 'primary runtime action'
$permissionAction = Balanced-Section $page `
  '  private retryRuntimePermission(): void {' 'permission retry action'
$runAsync = Balanced-Section $page '  private async runWorkflowAsync(' 'workflow execution'
$frameCapture = Balanced-Section $page '  private async prepareLiveFrameImageInput(' 'frame capture'
$applyResult = Balanced-Section $page '  private async applyAiResult(' 'result publication'
$retryMapping = Balanced-Section $catalog `
  'export function liveObjectDetectionRetryActionForStatus(' 'live object retry mapping'
$preparingPolicy = Balanced-Section $catalog `
  'export function shouldPublishLiveObjectDetectionPreparingStatus(' 'live object preparing policy'
$preserveText = Balanced-Section $catalog `
  'export function shouldPreserveRuntimeTextResultOnAiResult(' 'text preservation'
$preserveVisual = Balanced-Section $catalog `
  'export function shouldPreserveRuntimeVisualResultOnAiResult(' 'visual preservation'
$fixedCamera = Balanced-Section $catalog `
  'export function fixedLiveCameraPositionForWorkflow(' 'fixed camera'
$fixedCameraRaw = Balanced-Section-UsingBounds $catalogRaw $catalog `
  'export function fixedLiveCameraPositionForWorkflow(' 'fixed camera literals'
$placement = Balanced-Section $service `
  'export function objectDetectionLiveLabelPlacement(' 'label placement'

foreach ($marker in @(
  'this.runtimeActionToolbar(true)',
  'this.liveCameraSurfaceContent()',
  'this.liveObjectDetectionStatusOverlay()',
  '.onAreaChange(',
  '.justifyContent(FlexAlign.Center)',
  '.layoutWeight(1)'
)) { Assert-Contains $layout $marker "missing executable layout marker: $marker" }
foreach ($forbidden in @(
  'this.runtimeCameraSwitchAction()',
  'this.switchLiveCamera()',
  'this.prepareInput(',
  'workflowInputLabelKey('
)) {
  Assert-Excludes $layout $forbidden "live object layout exposes forbidden control: $forbidden"
  Assert-Excludes $statusOverlay $forbidden "live object overlay exposes forbidden control: $forbidden"
}
Assert-Contains $layoutRaw ".backgroundColor('#111827')" 'camera fallback must remain dark.'

foreach ($marker in @(
  'LoadingProgress()',
  'Text(appString(this.statusKey))',
  "if (this.liveObjectDetectionRetryAction() !== 'none') {",
  "Button(appString('web_retry'), { type: ButtonType.Normal })",
  '.constraintSize({ minWidth: 72, minHeight: 48 })',
  '.onClick(() => this.retryLiveObjectDetection())',
  '.constraintSize({ maxWidth: 520 })'
)) { Assert-Contains $statusOverlayRaw $marker "missing status/retry marker: $marker" }
Assert-Count $statusOverlay '.onClick(' 1 'status overlay must expose exactly one retry callback.'
foreach ($forbidden in @('.height(96)', 'maxHeight:', '.clip(true)', '.maxLines(', '.textOverflow(')) {
  Assert-Excludes $statusOverlay $forbidden "status content must size naturally: $forbidden"
}

foreach ($marker in @(
  'this.liveObjectDetectionBoxStyle(detection).width',
  'this.liveObjectDetectionBoxStyle(detection).height',
  'this.liveObjectDetectionLabelPlacement(detection, index).maxWidth',
  '.maxFontScale(1.6)',
  '.width(''100%'')',
  '.height(''100%'')'
)) { Assert-Contains $boxRaw $marker "missing box/label marker: $marker" }
foreach ($forbidden in @('.maxLines(', '.textOverflow(', '.clip(true)')) {
  Assert-Excludes $box $forbidden "live detection labels must wrap naturally: $forbidden"
}
Assert-Contains $surface 'ForEach(this.objectDetections,' 'all detections must be rendered.'
foreach ($coordinate in @('detection.left', 'detection.top', 'detection.right', 'detection.bottom')) {
  Assert-Contains $surface $coordinate "live detection key must include $coordinate."
}

foreach ($marker in @(
  "if (action === 'restartCamera') {",
  'this.liveCameraInputSelected = true;',
  'this.startLiveCameraPreview();',
  "if (action !== 'restartInference' || workflow === undefined) {",
  "this.statusKey = 'feature_runtime_status_preparing';",
  'this.stopLiveRuntimeLoop();',
  'this.startLiveRuntimeLoop(workflow);'
)) { Assert-Contains $retryRaw $marker "retry handler is missing: $marker" }
Assert-Excludes $retryRaw "this.prepareInput('camera')" 'retry must not use the cleared surface-id input gate.'
$stopIndex = $retry.IndexOf('this.stopLiveRuntimeLoop();', [StringComparison]::Ordinal)
$startIndex = $retry.IndexOf('this.startLiveRuntimeLoop(workflow);', [StringComparison]::Ordinal)
if ($stopIndex -lt 0 -or $startIndex -lt 0 -or $stopIndex -gt $startIndex) {
  Fail 'inference retry must stop the old loop before restarting it.'
}
foreach ($marker in @(
  'if (liveRuntimeModeForWorkflow(workflow)) {',
  'this.liveCameraInputSelected = true;',
  'this.startLiveCameraPreview();',
  "this.prepareInput('camera');"
)) { Assert-Contains $permissionRetryRaw $marker "shared camera retry is missing: $marker" }
Assert-Contains $runPrimary 'this.retryRuntimeCameraInput();' `
  'primary action must share the direct live-camera recovery path.'
Assert-Contains $permissionAction 'this.retryRuntimeCameraInput();' `
  'permission retry must share the direct live-camera recovery path.'

Assert-Contains $runAsync 'shouldPublishLiveObjectDetectionPreparingStatus(' `
  'automatic frames must preserve durable object detection status.'
Assert-Contains $frameCapture 'shouldPreserveRuntimeTextResultOnAiResult(workflow, false, this.resultText.length > 0)' `
  'frame failures must preserve the last detection summary.'
Assert-Contains $applyResult 'shouldPreserveRuntimeTextResultOnAiResult(workflow, result.ok, this.resultText.length > 0)' `
  'AI failures must preserve the last detection summary.'
Assert-Contains $preserveText 'shouldShowLiveObjectDetectionCameraOverlay(workflow)' `
  'transient failures must preserve object detection text.'
Assert-Contains $preserveVisual 'if (shouldShowLiveObjectDetectionCameraOverlay(workflow)) {' `
  'transient failures must preserve detection boxes.'
Assert-Contains $preparingPolicy '!shouldShowLiveObjectDetectionCameraOverlay(workflow) || !hasObjectDetections;' `
  'preparing status must stop replacing a durable detection/failure status.'

Assert-Contains $retryMapping 'if (!shouldShowLiveObjectDetectionCameraOverlay(workflow)) {' `
  'retry mapping must be isolated to live object detection.'
Assert-Count $retryMapping 'statusKey ===' 7 'retry mapping must enumerate seven recoverable statuses.'
foreach ($status in @(
  'feature_runtime_live_camera_failed',
  'feature_runtime_live_camera_surface_missing',
  'feature_runtime_permission_denied',
  'feature_runtime_live_frame_failed',
  'feature_runtime_run_failed',
  'feature_runtime_pending_adapter',
  'feature_runtime_object_detection_failed'
)) { Assert-Contains $catalogRaw "'$status'" "retry mapping is missing $status." }

foreach ($marker in @(
  'Math.min(180, overlayWidth)',
  'Math.ceil(Math.max(1, labelCharacterCount) / 8)',
  'box.top >= estimatedHeight + gap',
  'boxBottom + gap + estimatedHeight <= overlayHeight',
  'Math.max(0, overlayWidth - maxWidth)',
  'Math.max(0, overlayHeight - estimatedHeight)'
)) { Assert-Contains $placement $marker "label placement is missing boundary logic: $marker" }

Assert-Contains $page 'modelUri: this.modelInputUri' 'optional cached object model must remain an inference input.'
Assert-Contains $page 'cachedModelFileInputStateForRoute(routeName, context.cacheDir)' `
  'cached optional model restoration must remain available.'
$fixedBranch = [regex]::Match(
  $fixedCamera,
  '(?s)workflow\.routeName === AppRoute\.OBJECT_CAMERA\.name\) \{\s+return\s+[^;]+;'
)
if (-not $fixedBranch.Success) { Fail 'OBJECT_CAMERA fixed-camera branch is missing.' }
$fixedRaw = $fixedCameraRaw.Substring($fixedBranch.Index, $fixedBranch.Length)
Assert-Contains $fixedRaw "return 'back';" 'OBJECT_CAMERA must remain fixed to the rear camera.'

Assert-TopLevelBuildExecution $buildPath 'check-live-object-detection-layout-parity.ps1'
Assert-TopLevelBuildExecution $buildPath 'test-live-object-detection-layout-guard.ps1'

Write-Output 'Live object-detection layout parity is present.'
