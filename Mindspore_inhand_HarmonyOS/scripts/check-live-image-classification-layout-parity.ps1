param(
  [string]$SourceRoot = ''
)

$ErrorActionPreference = 'Stop'

function Fail([string]$Message) {
  throw "Live image-classification layout guard failed: $Message"
}

function Read-Normalized([string]$Path) {
  if (-not [IO.File]::Exists($Path)) {
    Fail "missing source file: $Path"
  }
  return ([IO.File]::ReadAllText($Path)).Replace("`r`n", "`n").Replace("`r", "`n")
}

function Remove-ArkTsCommentsAndStrings([string]$Text, [bool]$PreserveStrings = $false) {
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
      if ($PreserveStrings) {
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
      [void]$result.Append($(if ($PreserveStrings) { $current } else { ' ' }))
      $quote = $current
      $escaped = $false
      $state = 'string'
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

function Section-UsingLiteralBounds(
  [string]$Text,
  [string]$LiteralText,
  [string]$Start,
  [string]$End,
  [string]$Name
) {
  $startIndex = $LiteralText.IndexOf($Start, [StringComparison]::Ordinal)
  if ($startIndex -lt 0) { Fail "missing $Name start marker: $Start" }
  $endIndex = $LiteralText.IndexOf($End, $startIndex + $Start.Length, [StringComparison]::Ordinal)
  if ($endIndex -lt 0) { Fail "missing $Name end marker: $End" }
  return $Text.Substring($startIndex, $endIndex - $startIndex)
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

function Assert-BuildExecution([string]$BuildPath, [string]$ScriptName) {
  $tokens = $null
  $parseErrors = $null
  $ast = [Management.Automation.Language.Parser]::ParseFile(
    $BuildPath,
    [ref]$tokens,
    [ref]$parseErrors
  )
  if ($parseErrors.Count -gt 0) {
    Fail "build-hap.ps1 has parse errors."
  }
  $expected = "& (Join-Path `$PSScriptRoot '$ScriptName')"
  $matches = $ast.FindAll({
      param($node)
      return $node -is [Management.Automation.Language.CommandAst] -and
        $node.Extent.Text.Trim() -eq $expected
    }, $true)
  if ($matches.Count -ne 1) {
    Fail "build-hap.ps1 must execute $ScriptName exactly once; found $($matches.Count)."
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
$page = Remove-ArkTsCommentsAndStrings $pageRaw
$pageWithLiterals = Remove-ArkTsCommentsAndStrings $pageRaw $true
$catalog = Remove-ArkTsCommentsAndStrings $catalogRaw
$catalogWithLiterals = Remove-ArkTsCommentsAndStrings $catalogRaw $true

$overlay = Section $page '  liveClassificationStatusOverlay() {' `
  "`n`n  @Builder`n  liveSegmentationStatusOverlay()" 'classification status overlay'
$overlayWithLiterals = Section $pageWithLiterals '  liveClassificationStatusOverlay() {' `
  "`n`n  @Builder`n  liveSegmentationStatusOverlay()" 'classification status overlay literals'
$layout = Section $page '  imageClassificationAndroidLiveLayout() {' `
  "`n`n  @Builder`n  segmentationAndroidLiveLayout()" 'classification layout'
$layoutWithLiterals = Section $pageWithLiterals '  imageClassificationAndroidLiveLayout() {' `
  "`n`n  @Builder`n  segmentationAndroidLiveLayout()" 'classification layout literals'
$retry = Section $page '  private retryLiveClassification(): void {' `
  "`n`n  private runWorkflow(): void {" 'classification retry handler'
$retryWithLiterals = Section $pageWithLiterals '  private retryLiveClassification(): void {' `
  "`n`n  private runWorkflow(): void {" 'classification retry handler literals'
$runAsync = Section $page '  private async runWorkflowAsync(' `
  "`n`n  private applyRuntimeFailure(): void {" 'workflow run'
$runtimeFailure = Section $page '  private applyRuntimeFailure(): void {' `
  "`n`n  private async prepareLiveFrameImageInput" 'runtime failure'
$frameCapture = Section $page '  private async prepareLiveFrameImageInput(' `
  "`n`n  private async applyAiResult" 'live frame capture'
$frameCaptureWithLiterals = Section $pageWithLiterals '  private async prepareLiveFrameImageInput(' `
  "`n`n  private async applyAiResult" 'live frame capture literals'
$applyResult = Section $page '  private async applyAiResult(' `
  "`n`n  private showStillSceneFailureToastIfNeeded" 'AI result publication'
$previewStart = Section $page '  private async startLiveCameraPreviewAsync(): Promise<void> {' `
  "`n`n  private applyLiveCameraPreviewResult" 'camera preview start'
$previewStartWithLiterals = Section $pageWithLiterals '  private async startLiveCameraPreviewAsync(): Promise<void> {' `
  "`n`n  private applyLiveCameraPreviewResult" 'camera preview start literals'
$preserve = Section $catalog 'export function shouldPreserveRuntimeTextResultOnAiResult(' `
  "`n`nexport function shouldPreserveRuntimeVisualResultOnAiResult" 'text-result preservation'
$retryMapping = Section $catalog 'export function liveClassificationRetryActionForStatus(' `
  "`n`nexport function shouldClearRuntimeResultAtWorkflowStart" 'classification retry mapping'
$retryMappingWithLiterals = Section $catalogWithLiterals 'export function liveClassificationRetryActionForStatus(' `
  "`n`nexport function shouldPublishLiveClassificationPreparingStatus" 'classification retry mapping literals'
$preparingPolicy = Section $catalog 'export function shouldPublishLiveClassificationPreparingStatus(' `
  "`n`nexport function shouldClearRuntimeResultAtWorkflowStart" 'classification preparing-status policy'
$fixedCamera = Section $catalog 'export function fixedLiveCameraPositionForWorkflow(' `
  "`n`nconst rememberedLiveCameraPositions" 'fixed camera mapping'
$fixedCameraWithLiterals = Section $catalogWithLiterals 'export function fixedLiveCameraPositionForWorkflow(' `
  "`n`nconst rememberedLiveCameraPositions" 'fixed camera mapping'

foreach ($marker in @(
  'this.runtimeActionToolbar(true)',
  'this.liveCameraSurfaceContent()',
  'this.liveClassificationStatusOverlay()',
  '.layoutWeight(1)'
)) { Assert-Contains $layout $marker "missing executable layout marker: $marker" }
Assert-Contains $layoutWithLiterals ".backgroundColor('#111827')" `
  'classification canvas must retain its dark camera fallback.'
foreach ($forbidden in @(
  'this.runtimeCameraSwitchAction()',
  'this.switchLiveCamera()'
)) {
  Assert-Excludes $layout $forbidden "classification layout exposes camera switching: $forbidden"
  Assert-Excludes $overlay $forbidden "classification overlay exposes camera switching: $forbidden"
}

foreach ($marker in @(
  'Text(this.liveClassificationOverlayValue())',
  'Text(appString(this.statusKey))',
  'LoadingProgress()',
  'if (this.liveClassificationRetryAction() !==',
  '.constraintSize({ minWidth: 72, minHeight: 48 })',
  '.onClick(() => this.retryLiveClassification())',
  '.constraintSize({ maxWidth: 520 })'
)) { Assert-Contains $overlay $marker "missing executable compact-overlay marker: $marker" }
foreach ($marker in @(
  "if (this.statusKey === 'feature_runtime_status_preparing') {",
  "if (this.liveClassificationRetryAction() !== 'none') {",
  "Button(appString('web_retry'), { type: ButtonType.Normal })",
  ".width('calc(100% - 32vp)')",
  ".backgroundColor('#B31F2937')"
)) { Assert-Contains $overlayWithLiterals $marker "missing literal compact-overlay marker: $marker" }
Assert-Count $overlay '.maxFontScale(1.6)' 3 `
  'classification result, status, and retry must all bound font scaling.'
Assert-Count $overlay '.onClick(' 1 'classification overlay must expose exactly one local retry callback.'

$resultLabel = Section $overlay '      Text(this.liveClassificationOverlayValue())' `
  "`n      Row({ space: AppSpacing.sm }) {" 'classification result label'
$statusLabel = Section $overlay '          Text(appString(this.statusKey))' `
  "`n        }`n        .layoutWeight(1)" 'classification status label'
$ownerModifiers = Section $overlayWithLiterals "    .width('calc(100% - 32vp)')" `
  "`n  }" 'classification overlay owner modifiers'
foreach ($boundedText in @($resultLabel, $statusLabel)) {
  foreach ($forbidden in @('.height(', 'maxHeight:', '.maxLines(', '.textOverflow(', '.clip(true)')) {
    Assert-Excludes $boundedText $forbidden "classification text must wrap naturally: $forbidden"
  }
}
foreach ($forbidden in @('.height(', 'maxHeight:', '.clip(true)')) {
  Assert-Excludes $ownerModifiers $forbidden "classification overlay owner must size naturally: $forbidden"
}

foreach ($marker in @(
  'const action = liveClassificationRetryActionForStatus(workflow, this.statusKey);',
  'if (action ===',
  'this.liveCameraInputSelected = true;',
  'this.startLiveCameraPreview();',
  'if (action !==',
  'this.stopLiveRuntimeLoop();',
  'if (this.liveCameraInputSelected && this.liveCameraActive) {',
  'this.startLiveRuntimeLoop(workflow);'
)) { Assert-Contains $retry $marker "retry handler is missing: $marker" }
foreach ($marker in @(
  "if (action === 'restartCamera') {",
  "if (action !== 'restartInference' || workflow === undefined) {",
  "this.statusKey = 'feature_runtime_status_preparing';"
)) { Assert-Contains $retryWithLiterals $marker "retry handler is missing: $marker" }
Assert-Count $retry 'this.liveCameraInputSelected = true;' 2 `
  'camera retry and inference fallback must each restore the selected-camera state.'
Assert-Count $retry 'this.startLiveCameraPreview();' 2 `
  'camera retry and inference fallback must each directly restart the native preview.'
Assert-Excludes $retryWithLiterals "this.prepareInput('camera')" `
  'classification Retry must not depend on a cleared surface-id gate.'
$stopIndex = $retry.IndexOf('this.stopLiveRuntimeLoop();', [StringComparison]::Ordinal)
$startIndex = $retry.IndexOf('this.startLiveRuntimeLoop(workflow);', [StringComparison]::Ordinal)
if ($stopIndex -lt 0 -or $startIndex -lt 0 -or $stopIndex -gt $startIndex) {
  Fail 'inference Retry must stop the existing loop before restarting it.'
}

$previewClearBlock = Section-UsingLiteralBounds $previewStart $previewStartWithLiterals `
  '    if (shouldClearRuntimeResultAtWorkflowStart(workflow)) {' `
  "`n    }`n    try {" 'camera-preview clear gate'
$previewClearBlockWithLiterals = Section $previewStartWithLiterals `
  '    if (shouldClearRuntimeResultAtWorkflowStart(workflow)) {' `
  "`n    }`n    try {" 'camera-preview clear gate literals'
foreach ($marker in @('this.resultRows = [];', 'this.clearVisualResults();')) {
  Assert-Contains $previewClearBlock $marker "camera-preview clear gate is missing: $marker"
  Assert-Count $previewStart $marker 1 "camera-preview start must clear $marker only inside its policy gate."
}
Assert-Contains $previewClearBlockWithLiterals "this.resultText = '';" `
  'camera-preview clear gate must clear non-preserved detail text.'
Assert-Count $previewStartWithLiterals "this.resultText = '';" 1 `
  'camera-preview start must clear detail text only inside its policy gate.'

$frameFailure = Section-UsingLiteralBounds $frameCapture $frameCaptureWithLiterals `
  '    if (!result.ok) {' `
  '      if (shouldShowLiveObjectDetectionCameraOverlay(workflow)) {' 'frame failure branch'
$frameClearBlock = Section $frameFailure `
  '      if (!shouldPreserveRuntimeTextResultOnAiResult(workflow, false)) {' `
  "`n      }" 'frame-failure clear gate'
$frameFailureWithLiterals = Section $frameCaptureWithLiterals `
  '    if (!result.ok) {' `
  '      if (shouldShowLiveObjectDetectionCameraOverlay(workflow)) {' 'frame failure branch literals'
$frameClearBlockWithLiterals = Section $frameFailureWithLiterals `
  '      if (!shouldPreserveRuntimeTextResultOnAiResult(workflow, false)) {' `
  "`n      }" 'frame-failure clear gate literals'
foreach ($marker in @('this.resultRows = [];')) {
  Assert-Contains $frameClearBlock $marker "frame-failure clear gate is missing: $marker"
  Assert-Count $frameFailure $marker 1 "frame failure must clear $marker only inside its policy gate."
}
Assert-Contains $frameClearBlockWithLiterals "this.resultText = '';" `
  'frame-failure clear gate must clear non-preserved detail text.'
Assert-Count $frameFailureWithLiterals "this.resultText = '';" 1 `
  'frame failure must clear detail text only inside its policy gate.'

Assert-Contains $runAsync `
  'if (shouldPublishLiveClassificationPreparingStatus(workflow, this.resultRows.length > 0)) {' `
  'automatic live frames must not erase a durable classification success/failure status.'
Assert-Contains $runAsync 'if (shouldClearRuntimeResultAtWorkflowStart(workflow)) {' `
  'workflow start must retain route-specific result preservation.'
Assert-Contains $runAsync 'if (!shouldPreserveRuntimeTextResultOnAiResult(workflow, false)) {' `
  'permission failure must retain eligible classification results.'
Assert-Contains $runtimeFailure 'if (!shouldPreserveRuntimeTextResultOnAiResult(workflow, false)) {' `
  'runtime exceptions must retain eligible classification results.'
Assert-Contains $applyResult 'if (!shouldPreserveRuntimeTextResultOnAiResult(workflow, result.ok)) {' `
  'AI publication must atomically replace only accepted classification results.'
Assert-Contains $preserve 'shouldShowLiveClassificationCameraOverlay(workflow)' `
  'transient live-classification inference failures must preserve the last label.'
Assert-Contains $preserve '&& !resultOk' `
  'successful classifications must atomically replace the last label.'
Assert-Contains $preparingPolicy '!shouldShowLiveClassificationCameraOverlay(workflow) || !hasClassificationResult;' `
  'preparing status must remain automatic only before the first live-classification result.'

Assert-Contains $retryMapping 'if (!shouldShowLiveClassificationCameraOverlay(workflow)) {' `
  'retry mapping must be isolated to live image classification.'
Assert-Count $retryMapping 'statusKey ===' 7 `
  'retry mapping must enumerate exactly the seven supported failure statuses.'
foreach ($marker in @(
  "statusKey === 'feature_runtime_live_camera_failed'",
  "statusKey === 'feature_runtime_live_camera_surface_missing'",
  "statusKey === 'feature_runtime_permission_denied'",
  "statusKey === 'feature_runtime_live_frame_failed'",
  "statusKey === 'feature_runtime_run_failed'",
  "statusKey === 'feature_runtime_classification_runner_unavailable'",
  "statusKey === 'feature_runtime_classification_failed'",
  "return 'restartCamera';",
  "return 'restartInference';",
  "return 'none';"
)) { Assert-Contains $retryMappingWithLiterals $marker "retry mapping is missing: $marker" }

$fixedBranchMatch = [regex]::Match(
  $fixedCamera,
  '(?s)if \(workflow\.routeName === AppRoute\.IMAGE_CAMERA\.name \|\|\s+' +
    'workflow\.routeName === AppRoute\.OBJECT_CAMERA\.name\) \{\s+return\s+[^;]*;\s+\}'
)
if (-not $fixedBranchMatch.Success) {
  Fail 'IMAGE_CAMERA and OBJECT_CAMERA must share one executable fixed-camera branch.'
}
$fixedBranchWithLiterals = $fixedCameraWithLiterals.Substring(
  $fixedBranchMatch.Index,
  $fixedBranchMatch.Length
)
Assert-Contains $fixedBranchWithLiterals "return 'back';" `
  'IMAGE_CAMERA and OBJECT_CAMERA must remain fixed to the rear camera.'

Assert-BuildExecution $buildPath 'check-live-image-classification-layout-parity.ps1'
Assert-BuildExecution $buildPath 'test-live-image-classification-layout-guard.ps1'

Write-Output 'Live image-classification layout parity is present.'
