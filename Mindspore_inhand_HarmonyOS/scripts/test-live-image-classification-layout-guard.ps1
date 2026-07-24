$ErrorActionPreference = 'Stop'

$sourceRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$guard = Join-Path $PSScriptRoot 'check-live-image-classification-layout-parity.ps1'
$tempPrefix = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$tempRoot = Join-Path $tempPrefix ('mih-live-classification-guard-' + [Guid]::NewGuid().ToString('N'))

function Copy-Fixture() {
  $fixture = Join-Path $tempRoot ([Guid]::NewGuid().ToString('N'))
  [IO.Directory]::CreateDirectory((Join-Path $fixture 'entry\src\main\ets\pages')) | Out-Null
  [IO.Directory]::CreateDirectory((Join-Path $fixture 'entry\src\main\ets\features\runtime')) | Out-Null
  [IO.Directory]::CreateDirectory((Join-Path $fixture 'scripts')) | Out-Null
  [IO.File]::Copy(
    (Join-Path $sourceRoot 'entry\src\main\ets\pages\FeatureRuntimePage.ets'),
    (Join-Path $fixture 'entry\src\main\ets\pages\FeatureRuntimePage.ets')
  )
  [IO.File]::Copy(
    (Join-Path $sourceRoot 'entry\src\main\ets\features\runtime\FeatureWorkflowCatalog.ets'),
    (Join-Path $fixture 'entry\src\main\ets\features\runtime\FeatureWorkflowCatalog.ets')
  )
  [IO.File]::Copy(
    (Join-Path $sourceRoot 'scripts\build-hap.ps1'),
    (Join-Path $fixture 'scripts\build-hap.ps1')
  )
  return $fixture
}

function Replace-Once([string]$Text, [string]$From, [string]$To, [string]$Name) {
  $matches = ([regex]::Matches($Text, [regex]::Escape($From))).Count
  if ($matches -ne 1) {
    throw "Live classification fixture '$Name' expected one source marker, found $matches."
  }
  $index = $Text.IndexOf($From, [StringComparison]::Ordinal)
  return $Text.Substring(0, $index) + $To + $Text.Substring($index + $From.Length)
}

function Mutate-And-Reject([string]$Name, [string]$RelativePath, [string]$From, [string]$To) {
  $fixture = Copy-Fixture
  $path = Join-Path $fixture $RelativePath
  $text = ([IO.File]::ReadAllText($path)).Replace("`r`n", "`n").Replace("`r", "`n")
  [IO.File]::WriteAllText($path, (Replace-Once $text $From $To $Name))
  $rejected = $false
  try {
    & $guard -SourceRoot $fixture *> $null
  } catch {
    $rejected = $true
  }
  if (-not $rejected) {
    throw "Live classification mutation fixture '$Name' was incorrectly accepted."
  }
}

function Mutate-And-Accept([string]$Name, [string]$RelativePath, [string]$From, [string]$To) {
  $fixture = Copy-Fixture
  $path = Join-Path $fixture $RelativePath
  $text = ([IO.File]::ReadAllText($path)).Replace("`r`n", "`n").Replace("`r", "`n")
  [IO.File]::WriteAllText($path, (Replace-Once $text $From $To $Name))
  try {
    & $guard -SourceRoot $fixture *> $null
  } catch {
    throw "Live classification decoy fixture '$Name' was incorrectly rejected."
  }
}

try {
  [IO.Directory]::CreateDirectory($tempRoot) | Out-Null
  & $guard -SourceRoot $sourceRoot
  if ($LASTEXITCODE -ne 0) { throw 'Baseline live classification guard failed.' }

  $page = 'entry\src\main\ets\pages\FeatureRuntimePage.ets'
  $catalog = 'entry\src\main\ets\features\runtime\FeatureWorkflowCatalog.ets'
  $build = 'scripts\build-hap.ps1'
  $labelFrom = "      Text(this.liveClassificationOverlayValue())`n        .width('100%')" +
    "`n        .fontSize(18)`n        .fontWeight(FontWeight.Medium)" +
    "`n        .fontColor(Color.White)`n        .maxFontScale(1.6)"
  $labelTruncated = $labelFrom + "`n        .maxLines(2)"
  $labelTail = "        .fontColor(Color.White)`n        .maxFontScale(1.6)" +
    "`n      Row({ space: AppSpacing.sm }) {"
  $labelEllipsis = "        .fontColor(Color.White)`n        .maxFontScale(1.6)" +
    "`n        .textOverflow({ overflow: TextOverflow.Ellipsis })" +
    "`n      Row({ space: AppSpacing.sm }) {"
  $overlayStart = "  liveClassificationStatusOverlay() {`n    Column({ space: AppSpacing.sm }) {"
  $overlayWithSwitch = $overlayStart + "`n      this.runtimeCameraSwitchAction()"
  $cameraRetry = "    if (action === 'restartCamera') {" +
    "`n      this.liveCameraInputSelected = true;" +
    "`n      this.startLiveCameraPreview();`n      return;"
  $cameraRetryThroughInput = "    if (action === 'restartCamera') {" +
    "`n      this.prepareInput('camera');`n      return;"
  $previewClearGate = "    this.statusKey = 'feature_runtime_status_preparing';" +
    "`n    if (shouldClearRuntimeResultAtWorkflowStart(workflow)) {" +
    "`n      this.resultRows = [];"
  $previewUnconditionalClear = "    this.statusKey = 'feature_runtime_status_preparing';" +
    "`n    if (true) {`n      this.resultRows = [];"
  $frameClearGate = '      const workflow = workflowForRoute(this.routeName);' +
    "`n      if (!shouldPreserveRuntimeTextResultOnAiResult(workflow, false)) {" +
    "`n        this.resultText = '';"
  $frameUnconditionalClear = '      const workflow = workflowForRoute(this.routeName);' +
    "`n      if (true) {`n        this.resultText = '';"
  $preparingGate = '    if (shouldPublishLiveClassificationPreparingStatus(workflow, this.resultRows.length > 0)) {' +
    "`n      this.statusKey = 'feature_runtime_status_preparing';`n    }"
  $alwaysPreparing = "    this.statusKey = 'feature_runtime_status_preparing';"
  $preserveClassification = '(usesAndroidStillSceneLayout(workflow) || usesAndroidObjectPhotoLayout(workflow) ||' +
    "`n    shouldShowLiveClassificationCameraOverlay(workflow)) && !resultOk;"
  $fixedBack = "  if (workflow.routeName === AppRoute.IMAGE_CAMERA.name ||" +
    "`n    workflow.routeName === AppRoute.OBJECT_CAMERA.name) {`n    return 'back';`n  }"
  $fixedFront = "  if (workflow.routeName === AppRoute.IMAGE_CAMERA.name ||" +
    "`n    workflow.routeName === AppRoute.OBJECT_CAMERA.name) {`n    return 'front';`n  }"
  $stringMutationWireTo =
    '$classificationMutationDecoy = "& (Join-Path $PSScriptRoot ''test-live-image-classification-layout-guard.ps1'')"'
  $commentDecoy = "// this.runtimeCameraSwitchAction(); .height(96); .maxLines(2)`n" + $labelFrom
  $stringDecoy = "      const classificationLayoutDecoy = " +
    "'this.switchLiveCamera(); .maxLines(2)';`n" + $labelFrom
  $templateDecoy = '      const classificationTemplateDecoy = ' +
    '`this.runtimeCameraSwitchAction(); .height(100)`;' + "`n" +
    $labelFrom

  Mutate-And-Reject 'remove-overlay' $page `
    '        this.liveClassificationStatusOverlay()' `
    '        this.runtimeStatusBar()'
  Mutate-And-Reject 'fixed-overlay-height' $page `
    "    .constraintSize({ maxWidth: 520 })`n    .padding" `
    "    .constraintSize({ maxWidth: 520 })`n    .height(96)`n    .padding"
  Mutate-And-Reject 'fixed-overlay-max-height' $page `
    '    .constraintSize({ maxWidth: 520 })' `
    '    .constraintSize({ maxWidth: 520, maxHeight: 100 })'
  Mutate-And-Reject 'truncate-long-label' $page $labelFrom $labelTruncated
  Mutate-And-Reject 'ellipsis-long-label' $page $labelTail $labelEllipsis
  Mutate-And-Reject 'add-switch-inside-overlay' $page $overlayStart $overlayWithSwitch
  Mutate-And-Reject 'wrong-retry-callback' $page `
    '.onClick(() => this.retryLiveClassification())' `
    '.onClick(() => this.runPrimaryAction())'
  Mutate-And-Reject 'surface-retry-through-cleared-id-gate' $page $cameraRetry $cameraRetryThroughInput
  Mutate-And-Reject 'restart-live-loop-without-stop' $page `
    "    this.stopLiveRuntimeLoop();`n    if (this.liveCameraInputSelected && this.liveCameraActive) {" `
    '    if (this.liveCameraInputSelected && this.liveCameraActive) {'
  Mutate-And-Reject 'hide-success-behind-next-frame-preparing' $page $preparingGate $alwaysPreparing
  Mutate-And-Reject 'retry-without-preparing-feedback' $page `
    "    this.statusKey = 'feature_runtime_status_preparing';`n    this.stopLiveRuntimeLoop();" `
    '    this.stopLiveRuntimeLoop();'
  Mutate-And-Reject 'clear-result-on-camera-restart' $page $previewClearGate $previewUnconditionalClear
  Mutate-And-Reject 'clear-result-on-frame-failure' $page $frameClearGate $frameUnconditionalClear
  Mutate-And-Reject 'drop-transient-result-preservation' $catalog $preserveClassification `
    '(usesAndroidStillSceneLayout(workflow) || usesAndroidObjectPhotoLayout(workflow)) && !resultOk;'
  Mutate-And-Reject 'change-fixed-camera-to-front' $catalog $fixedBack $fixedFront
  Mutate-And-Reject 'remove-camera-failure-retry' $catalog `
    "statusKey === 'feature_runtime_live_camera_failed'" `
    "statusKey === 'feature_runtime_live_camera_ready'"
  Mutate-And-Reject 'always-publish-preparing-status' $catalog `
    'return !shouldShowLiveClassificationCameraOverlay(workflow) || !hasClassificationResult;' `
    'return true;'
  Mutate-And-Reject 'comment-production-wire' $build `
    "& (Join-Path `$PSScriptRoot 'check-live-image-classification-layout-parity.ps1')" `
    "# & (Join-Path `$PSScriptRoot 'check-live-image-classification-layout-parity.ps1')"
  Mutate-And-Reject 'string-mutation-wire' $build `
    "& (Join-Path `$PSScriptRoot 'test-live-image-classification-layout-guard.ps1')" `
    $stringMutationWireTo

  Mutate-And-Accept 'comment-decoy' $page $labelFrom $commentDecoy
  Mutate-And-Accept 'string-decoy' $page $labelFrom $stringDecoy
  Mutate-And-Accept 'template-decoy' $page $labelFrom $templateDecoy

  Write-Output 'Live image-classification layout guard negative fixtures passed.'
} finally {
  if ($tempRoot.StartsWith($tempPrefix, [StringComparison]::OrdinalIgnoreCase) -and
    [IO.Directory]::Exists($tempRoot)) {
    [IO.Directory]::Delete($tempRoot, $true)
  }
}
