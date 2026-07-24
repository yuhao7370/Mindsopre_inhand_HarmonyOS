param(
  [switch]$ExpectRed
)

$ErrorActionPreference = 'Stop'
$sourceRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$guard = Join-Path $PSScriptRoot 'check-live-segmentation-runtime-ui.ps1'

if ($ExpectRed) {
  $rejected = $false
  try { & $guard -SourceRoot $sourceRoot *> $null } catch { $rejected = $true }
  if (-not $rejected) { throw 'Live segmentation RED runner expected the baseline guard to reject missing behavior.' }
  throw 'Live segmentation RED confirmed: baseline lacks the route-specific runtime UI contract.'
}

$tempPrefix = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$tempRoot = Join-Path $tempPrefix ('mih-live-segmentation-guard-' + [Guid]::NewGuid().ToString('N'))

function Copy-Fixture() {
  $fixture = Join-Path $tempRoot ([Guid]::NewGuid().ToString('N'))
  foreach ($directory in @('entry\src\main\ets\pages', 'entry\src\main\ets\features\runtime', 'scripts')) {
    [IO.Directory]::CreateDirectory((Join-Path $fixture $directory)) | Out-Null
  }
  foreach ($file in @(
    'entry\src\main\ets\pages\FeatureRuntimePage.ets',
    'entry\src\main\ets\features\runtime\FeatureWorkflowCatalog.ets',
    'scripts\build-hap.ps1',
    'scripts\check-live-segmentation-runtime-ui.ps1'
  )) { [IO.File]::Copy((Join-Path $sourceRoot $file), (Join-Path $fixture $file)) }
  return $fixture
}

function Replace-Once([string]$Text, [string]$From, [string]$To, [string]$Name) {
  $count = ([regex]::Matches($Text, [regex]::Escape($From))).Count
  if ($count -ne 1) { throw "Live segmentation fixture '$Name' expected one marker, found $count." }
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
  if ($ShouldReject -and -not $rejected) { throw "Live segmentation mutation '$Name' was incorrectly accepted." }
  if (-not $ShouldReject -and $rejected) { throw "Live segmentation decoy '$Name' was incorrectly rejected." }
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
  if ($startIndex -lt 0 -or $endIndex -lt 0) { throw "Live segmentation fixture '$Name' could not isolate its section." }
  $section = $text.Substring($startIndex, $endIndex - $startIndex)
  $mutated = Replace-Once $section $From $To $Name
  [IO.File]::WriteAllText($path, $text.Substring(0, $startIndex) + $mutated + $text.Substring($endIndex))
  $rejected = $false
  try { & $guard -SourceRoot $fixture *> $null } catch { $rejected = $true }
  if (-not $rejected) { throw "Live segmentation section mutation '$Name' was incorrectly accepted." }
}

try {
  [IO.Directory]::CreateDirectory($tempRoot) | Out-Null
  & $guard -SourceRoot $sourceRoot
  if ($LASTEXITCODE -ne 0) { throw 'Baseline live segmentation guard failed.' }

  $page = 'entry\src\main\ets\pages\FeatureRuntimePage.ets'
  $catalog = 'entry\src\main\ets\features\runtime\FeatureWorkflowCatalog.ets'
  $build = 'scripts\build-hap.ps1'
  $layoutStart = "  segmentationAndroidLiveLayout() {`n    Column() {"
  $overlayStart = "  liveSegmentationStatusOverlay() {`n    Row({ space: AppSpacing.sm }) {"
  $retryStart = "  private retryLiveSegmentation(): void {`n    const workflow = workflowForRoute(this.routeName);"
  $foregroundFailure = "        this.segmentationForegroundPixelMapOwner.invalidatePendingReplacement();`n        this.statusKey = 'feature_runtime_segmentation_failed';"
  $initialFront = "  if (workflow.routeName === AppRoute.SEGMENTATION_LIVE.name ||`n    workflow.routeName === AppRoute.PORTRAIT_SEGMENTATION.name ||`n    workflow.routeName === AppRoute.SCENE_LIVE.name) {`n    return 'front';"
  $memoryWrite = '  rememberedLiveCameraPositions.set(routeName, position);'
  $switchHorizontalInset = '.padding({ left: AppSpacing.md, right: AppSpacing.md })'
  $retryMappingStart = 'export function liveSegmentationRetryActionForStatus('
  $retryMappingEnd = 'export function shouldPublishLiveSegmentationPreparingStatus('

  Mutate-And-Run 'forced-rear-camera' $catalog $initialFront ($initialFront.Replace("return 'front';", "return 'back';"))
  Mutate-Section-And-Reject 'remove-camera-switch' $page `
    '  segmentationAndroidLiveLayout() {' `
    '  liveObjectDetectionStatusOverlay() {' `
    '            this.runtimeCameraSwitchAction()' '            this.runtimeStatusBar()'
  Mutate-Section-And-Reject 'remove-switch-horizontal-inset' $page `
    '  segmentationAndroidLiveLayout() {' `
    '  liveObjectDetectionStatusOverlay() {' `
    $switchHorizontalInset ''
  Mutate-And-Run 'drop-per-route-memory' $catalog $memoryWrite '    return;'
  Mutate-Section-And-Reject 'remove-segmentation-failure-retry-mapping' $catalog `
    $retryMappingStart $retryMappingEnd `
    "    statusKey === 'feature_runtime_segmentation_failed') {" "    statusKey === 'feature_runtime_text_recognition_failed') {"
  Mutate-And-Run 'remove-retry' $page '.onClick(() => this.retryLiveSegmentation())' '.onClick(() => this.runPrimaryAction())'
  Mutate-Section-And-Reject 'clear-last-foreground' $page `
    '  private async updateSegmentationForegroundPreview(' `
    '  private updatePosePreview(' `
    $foregroundFailure ($foregroundFailure + "`n        this.segmentationForegroundPixelMapOwner.clear();`n        this.segmentationForegroundPixelMap = undefined;")
  Mutate-And-Run 'comment-decoy' $page $layoutStart ($layoutStart + "`n      // this.runtimeCameraSwitchAction();") $false
  Mutate-And-Run 'string-decoy' $page $layoutStart ($layoutStart + "`n      const ignored = 'this.runtimeCameraSwitchAction();';") $false
  Mutate-And-Run 'template-decoy' $page $layoutStart ($layoutStart + "`n      const ignored = ``this.runtimeCameraSwitchAction();``;") $false
  Mutate-And-Run 'unused-sibling-overlay' $page $overlayStart `
    ("  liveSegmentationStatusOverlay() {`n  }`n`n  @Builder`n  unusedLiveSegmentationStatusOverlay() {`n    Row({ space: AppSpacing.sm }) {")
  Mutate-Section-And-Reject 'retry-through-cleared-surface-gate' $page `
    '  private retryLiveSegmentation(): void {' `
    '  private retryLiveClassification(): void {' `
    "    if (action === 'restartCamera') {`n      this.liveCameraInputSelected = true;`n      this.startLiveCameraPreview();" `
    "    if (action === 'restartCamera') {`n      this.prepareInput('camera');"
  Mutate-And-Run 'comment-production-wire' $build `
    "& (Join-Path `$PSScriptRoot 'check-live-segmentation-runtime-ui.ps1')" `
    "# & (Join-Path `$PSScriptRoot 'check-live-segmentation-runtime-ui.ps1')"

  Write-Output 'Live segmentation runtime UI guard negative fixtures passed.'
} finally {
  if ($tempRoot.StartsWith($tempPrefix, [StringComparison]::OrdinalIgnoreCase) -and [IO.Directory]::Exists($tempRoot)) {
    [IO.Directory]::Delete($tempRoot, $true)
  }
}
