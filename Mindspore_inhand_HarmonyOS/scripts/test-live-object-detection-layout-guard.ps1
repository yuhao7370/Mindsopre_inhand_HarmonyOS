$ErrorActionPreference = 'Stop'

$sourceRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$guard = Join-Path $PSScriptRoot 'check-live-object-detection-layout-parity.ps1'
$tempPrefix = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$tempRoot = Join-Path $tempPrefix ('mih-live-object-guard-' + [Guid]::NewGuid().ToString('N'))

function Copy-Fixture() {
  $fixture = Join-Path $tempRoot ([Guid]::NewGuid().ToString('N'))
  foreach ($directory in @(
    'entry\src\main\ets\pages',
    'entry\src\main\ets\features\runtime',
    'entry\src\main\ets\services\ai',
    'scripts'
  )) { [IO.Directory]::CreateDirectory((Join-Path $fixture $directory)) | Out-Null }
  foreach ($file in @(
    'entry\src\main\ets\pages\FeatureRuntimePage.ets',
    'entry\src\main\ets\features\runtime\FeatureWorkflowCatalog.ets',
    'entry\src\main\ets\services\ai\ObjectDetectionService.ets',
    'scripts\build-hap.ps1'
  )) { [IO.File]::Copy((Join-Path $sourceRoot $file), (Join-Path $fixture $file)) }
  return $fixture
}

function Replace-Once([string]$Text, [string]$From, [string]$To, [string]$Name) {
  $count = ([regex]::Matches($Text, [regex]::Escape($From))).Count
  if ($count -ne 1) { throw "Live object fixture '$Name' expected one marker, found $count." }
  $index = $Text.IndexOf($From, [StringComparison]::Ordinal)
  return $Text.Substring(0, $index) + $To + $Text.Substring($index + $From.Length)
}

function Mutate-And-Run(
  [string]$Name,
  [string]$RelativePath,
  [string]$From,
  [string]$To,
  [bool]$ShouldReject = $true
) {
  $fixture = Copy-Fixture
  $path = Join-Path $fixture $RelativePath
  $text = ([IO.File]::ReadAllText($path)).Replace("`r`n", "`n").Replace("`r", "`n")
  [IO.File]::WriteAllText($path, (Replace-Once $text $From $To $Name))
  $rejected = $false
  try { & $guard -SourceRoot $fixture *> $null } catch { $rejected = $true }
  if ($ShouldReject -and -not $rejected) {
    throw "Live object mutation fixture '$Name' was incorrectly accepted."
  }
  if (-not $ShouldReject -and $rejected) {
    throw "Live object decoy fixture '$Name' was incorrectly rejected."
  }
}

function Mutate-Section-And-Reject(
  [string]$Name,
  [string]$RelativePath,
  [string]$Start,
  [string]$End,
  [string]$From,
  [string]$To
) {
  $fixture = Copy-Fixture
  $path = Join-Path $fixture $RelativePath
  $text = ([IO.File]::ReadAllText($path)).Replace("`r`n", "`n").Replace("`r", "`n")
  $startIndex = $text.IndexOf($Start, [StringComparison]::Ordinal)
  $endIndex = $text.IndexOf($End, $startIndex + $Start.Length, [StringComparison]::Ordinal)
  if ($startIndex -lt 0 -or $endIndex -lt 0) {
    throw "Live object fixture '$Name' could not isolate its section."
  }
  $section = $text.Substring($startIndex, $endIndex - $startIndex)
  $mutated = Replace-Once $section $From $To $Name
  [IO.File]::WriteAllText(
    $path,
    $text.Substring(0, $startIndex) + $mutated + $text.Substring($endIndex)
  )
  $rejected = $false
  try { & $guard -SourceRoot $fixture *> $null } catch { $rejected = $true }
  if (-not $rejected) { throw "Live object section mutation '$Name' was incorrectly accepted." }
}

try {
  [IO.Directory]::CreateDirectory($tempRoot) | Out-Null
  & $guard -SourceRoot $sourceRoot

  $page = 'entry\src\main\ets\pages\FeatureRuntimePage.ets'
  $catalog = 'entry\src\main\ets\features\runtime\FeatureWorkflowCatalog.ets'
  $service = 'entry\src\main\ets\services\ai\ObjectDetectionService.ets'
  $build = 'scripts\build-hap.ps1'
  $layoutStart = "  objectDetectionAndroidLiveLayout() {`n    Column() {"
  $boxLabel = '      Text(this.objectDetectionLabel(detection, index))'
  $cameraRetry = "    if (action === 'restartCamera') {`n      this.liveCameraInputSelected = true;" +
    "`n      this.startLiveCameraPreview();"
  $preparing = "      if (shouldPublishLiveObjectDetectionPreparingStatus(" +
    "`n        workflow,`n        this.resultRows.length > 0 || this.liveObjectDetectionRetryAction() !== 'none'" +
    "`n      )) {`n        if (shouldPublishLiveSegmentationPreparingStatus(" +
    "`n          workflow,`n          this.segmentationForegroundPixelMap !== undefined || this.liveSegmentationRetryAction() !== 'none'" +
    "`n        )) {`n          if (shouldPublishLiveGesturePreparingStatus(" +
    "`n            workflow,`n            this.gestureDetections.length > 0 || this.liveGestureRetryAction() !== 'none'" +
    "`n          )) {`n            this.statusKey = 'feature_runtime_status_preparing';`n          }`n        }`n      }"
  $fixedBack = "  if (workflow.routeName === AppRoute.IMAGE_CAMERA.name ||" +
    "`n    workflow.routeName === AppRoute.OBJECT_CAMERA.name) {`n    return 'back';`n  }"
  $preserve = '    shouldShowLiveClassificationCameraOverlay(workflow) ||' +
    "`n    shouldShowLiveObjectDetectionCameraOverlay(workflow) ||" +
    "`n    usesAndroidLiveSegmentationLayout(workflow) ||" +
    "`n    usesAndroidLiveGestureLayout(workflow)) && !resultOk;"

  Mutate-And-Run 'remove-status-overlay' $page `
    '        this.liveObjectDetectionStatusOverlay()' '        this.runtimeStatusBar()'
  Mutate-And-Run 'restore-public-model-picker' $page $layoutStart `
    ($layoutStart + "`n      Button('选择模型').onClick(() => this.prepareInput('modelFile'))")
  Mutate-And-Run 'add-camera-switch' $page $layoutStart `
    ($layoutStart + "`n      this.runtimeCameraSwitchAction()")
  Mutate-And-Run 'template-expression-switch' $page $layoutStart `
    ($layoutStart + "`n      const hiddenSwitch = ``ordinary `${this.switchLiveCamera()}` text``;")
  Mutate-And-Run 'ordinary-template-decoy' $page $layoutStart `
    ($layoutStart + "`n      const harmless = ``this.switchLiveCamera();``;") $false
  Mutate-And-Run 'comment-decoy' $page $layoutStart `
    ($layoutStart + "`n      // this.runtimeCameraSwitchAction();") $false
  Mutate-And-Run 'unused-sibling-status-builder' $page `
    "  liveObjectDetectionStatusOverlay() {`n    Row({ space: AppSpacing.sm }) {" `
    ("  liveObjectDetectionStatusOverlay() {`n  }`n`n  @Builder`n" +
      "  unusedLiveObjectDetectionStatusOverlay() {`n    Row({ space: AppSpacing.sm }) {")
  Mutate-And-Run 'unused-sibling-retry-helper' $page `
    "  private retryLiveObjectDetection(): void {`n    const workflow = workflowForRoute(this.routeName);" `
    ("  private retryLiveObjectDetection(): void {`n  }`n`n" +
      "  private unusedLiveObjectDetectionRetry(): void {`n" +
      "    const workflow = workflowForRoute(this.routeName);")
  Mutate-Section-And-Reject 'truncate-label' $page `
    '  liveObjectDetectionBox(detection: ObjectDetection, index: number) {' `
    '  pixelMapPreview(labelKey: AppStringKey, pixelMap: image.PixelMap) {' `
    $boxLabel ($boxLabel + "`n        .maxLines(1)")
  Mutate-Section-And-Reject 'ellipsis-label' $page `
    '  liveObjectDetectionBox(detection: ObjectDetection, index: number) {' `
    '  pixelMapPreview(labelKey: AppStringKey, pixelMap: image.PixelMap) {' `
    $boxLabel ($boxLabel + "`n        .textOverflow({ overflow: TextOverflow.Ellipsis })")
  Mutate-Section-And-Reject 'box-owned-label-root' $page `
    '  liveObjectDetectionBox(detection: ObjectDetection, index: number) {' `
    '  pixelMapPreview(labelKey: AppStringKey, pixelMap: image.PixelMap) {' `
    "    .width('100%')`n    .height('100%')`n  }" `
    ("    .width(this.liveObjectDetectionBoxStyle(detection).width)`n" +
      "    .height(this.liveObjectDetectionBoxStyle(detection).height)`n  }")
  Mutate-And-Run 'wrong-retry-callback' $page `
    '.onClick(() => this.retryLiveObjectDetection())' '.onClick(() => this.runPrimaryAction())'
  Mutate-Section-And-Reject 'camera-retry-through-picker' $page `
    '  private retryLiveObjectDetection(): void {' '  private liveClassificationRetryAction' `
    $cameraRetry "    if (action === 'restartCamera') {`n      this.prepareInput('camera');"
  Mutate-Section-And-Reject 'restart-without-stop' $page `
    '  private retryLiveObjectDetection(): void {' '  private liveClassificationRetryAction' `
    "    this.stopLiveRuntimeLoop();`n    if (this.liveCameraInputSelected && this.liveCameraActive) {" `
    '    if (this.liveCameraInputSelected && this.liveCameraActive) {'
  Mutate-And-Run 'always-preparing' $page $preparing `
    "      this.statusKey = 'feature_runtime_status_preparing';"
  Mutate-And-Run 'drop-object-text-preservation' $catalog $preserve `
    ('    shouldShowLiveClassificationCameraOverlay(workflow) ||' +
      "`n    usesAndroidLiveSegmentationLayout(workflow) ||" +
      "`n    usesAndroidLiveGestureLayout(workflow)) && !resultOk;")
  Mutate-And-Run 'front-camera' $catalog $fixedBack ($fixedBack.Replace("return 'back';", "return 'front';"))
  Mutate-And-Run 'drop-right-clamp' $service `
    'Math.max(0, overlayWidth - maxWidth)' 'overlayWidth'
  Mutate-And-Run 'weak-detection-key' $page `
    '`${detection.imageId}-${detection.labelId}-${detection.score}-${detection.left}-${detection.top}` +' `
    '`${detection.imageId}-${detection.labelId}-${detection.score}` +'
  Mutate-And-Run 'remove-model-runtime-input' $page `
    '      modelUri: this.modelInputUri,' '      modelUri: '''','
  Mutate-And-Run 'comment-production-wire' $build `
    "& (Join-Path `$PSScriptRoot 'check-live-object-detection-layout-parity.ps1')" `
    "# & (Join-Path `$PSScriptRoot 'check-live-object-detection-layout-parity.ps1')"
  Mutate-And-Run 'uncalled-function-wire' $build `
    "& (Join-Path `$PSScriptRoot 'test-live-object-detection-layout-guard.ps1')" `
    "function Invoke-ObjectGuard { & (Join-Path `$PSScriptRoot 'test-live-object-detection-layout-guard.ps1') }"
  Mutate-And-Run 'duplicate-production-wire' $build `
    "& (Join-Path `$PSScriptRoot 'check-live-object-detection-layout-parity.ps1')" `
    ("& (Join-Path `$PSScriptRoot 'check-live-object-detection-layout-parity.ps1')`n" +
      "& (Join-Path `$PSScriptRoot 'check-live-object-detection-layout-parity.ps1')")

  Write-Output 'Live object-detection layout guard negative fixtures passed.'
} finally {
  if ($tempRoot.StartsWith($tempPrefix, [StringComparison]::OrdinalIgnoreCase) -and
    [IO.Directory]::Exists($tempRoot)) {
    [IO.Directory]::Delete($tempRoot, $true)
  }
}
