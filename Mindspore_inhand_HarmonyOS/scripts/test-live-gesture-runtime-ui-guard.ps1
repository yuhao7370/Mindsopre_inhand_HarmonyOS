param(
  [switch]$ExpectRed
)

$ErrorActionPreference = 'Stop'
$sourceRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$guard = Join-Path $PSScriptRoot 'check-live-gesture-runtime-ui.ps1'

if ($ExpectRed) {
  $rejected = $false
  try { & $guard -SourceRoot $sourceRoot *> $null } catch { $rejected = $true }
  if (-not $rejected) { throw 'Live gesture RED runner expected the baseline guard to reject missing behavior.' }
  throw 'Live gesture RED confirmed: baseline lacks the route-specific runtime UI contract.'
}

$tempPrefix = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$tempRoot = Join-Path $tempPrefix ('mih-live-gesture-guard-' + [Guid]::NewGuid().ToString('N'))

function Copy-Fixture() {
  $fixture = Join-Path $tempRoot ([Guid]::NewGuid().ToString('N'))
  foreach ($directory in @('entry\src\main\ets\pages', 'entry\src\main\ets\features\runtime', 'scripts')) {
    [IO.Directory]::CreateDirectory((Join-Path $fixture $directory)) | Out-Null
  }
  foreach ($file in @(
    'entry\src\main\ets\pages\FeatureRuntimePage.ets',
    'entry\src\main\ets\features\runtime\FeatureWorkflowCatalog.ets',
    'scripts\build-hap.ps1',
    'scripts\check-live-gesture-runtime-ui.ps1'
  )) { [IO.File]::Copy((Join-Path $sourceRoot $file), (Join-Path $fixture $file)) }
  return $fixture
}

function Replace-Once([string]$Text, [string]$From, [string]$To, [string]$Name) {
  $count = ([regex]::Matches($Text, [regex]::Escape($From))).Count
  if ($count -ne 1) { throw "Live gesture fixture '$Name' expected one marker, found $count." }
  $index = $Text.IndexOf($From, [StringComparison]::Ordinal)
  return $Text.Substring(0, $index) + $To + $Text.Substring($index + $From.Length)
}

function Assert-Rejected([string]$Name, [string]$RelativePath, [string]$From, [string]$To) {
  $fixture = Copy-Fixture
  $path = Join-Path $fixture $RelativePath
  $text = ([IO.File]::ReadAllText($path)).Replace("`r`n", "`n").Replace("`r", "`n")
  [IO.File]::WriteAllText($path, (Replace-Once $text $From $To $Name))
  $rejected = $false
  try { & $guard -SourceRoot $fixture *> $null } catch { $rejected = $true }
  if (-not $rejected) { throw "Live gesture mutation '$Name' was incorrectly accepted." }
}

function Assert-RejectedWithUnusedSibling(
  [string]$Name,
  [string]$RelativePath,
  [string]$From,
  [string]$To,
  [string]$SiblingBefore
) {
  $fixture = Copy-Fixture
  $path = Join-Path $fixture $RelativePath
  $text = ([IO.File]::ReadAllText($path)).Replace("`r`n", "`n").Replace("`r", "`n")
  $text = Replace-Once $text $From $To $Name
  $sibling = @"
  private unusedCameraInputPreservationDecoy(): boolean {
    return true;
  }

"@
  $text = Replace-Once $text $SiblingBefore ($sibling + $SiblingBefore) "$Name sibling"
  [IO.File]::WriteAllText($path, $text)
  $rejected = $false
  try { & $guard -SourceRoot $fixture *> $null } catch { $rejected = $true }
  if (-not $rejected) { throw "Live gesture mutation '$Name' was incorrectly accepted." }
}

function Assert-RejectedRearLabelClampDecoy() {
  $fixture = Copy-Fixture
  $path = Join-Path $fixture 'entry\src\main\ets\pages\FeatureRuntimePage.ets'
  $text = ([IO.File]::ReadAllText($path)).Replace("`r`n", "`n").Replace("`r", "`n")
  $text = Replace-Once $text 'const clampedLabelLeft = Math.min(Math.max(labelLeft, 0), canvasWidth - 176);' 'const clampedLabelLeft = labelLeft;' 'rear-label-unused-sibling-overflow'
  $sibling = @'
  private unusedLiveGestureLabelClampDecoy(): string {
    const canvasWidth = 377;
    const labelLeft = 300;
    const clampedLabelLeft = Math.min(Math.max(labelLeft, 0), canvasWidth - 176);
    return `${clampedLabelLeft}vp`;
  }

'@
  $text = Replace-Once $text '  private stopLiveCameraPreview(): void {' ($sibling + '  private stopLiveCameraPreview(): void {') 'rear-label-unused-sibling-decoy'
  [IO.File]::WriteAllText($path, $text)
  $rejected = $false
  try { & $guard -SourceRoot $fixture *> $null } catch { $rejected = $true }
  if (-not $rejected) { throw "Live gesture mutation 'rear-label-unused-sibling-decoy' was incorrectly accepted." }
}

try {
  & $guard -SourceRoot $sourceRoot | Out-Null
  [IO.Directory]::CreateDirectory($tempRoot) | Out-Null

  Assert-Rejected 'front-mirror-comment-decoy' 'entry\src\main\ets\features\runtime\FeatureWorkflowCatalog.ets' `
    "return shouldShowLiveGestureCameraOverlay(workflow) && liveCameraPosition === 'front';" `
    "return false; // return shouldShowLiveGestureCameraOverlay(workflow) && liveCameraPosition === 'front';"
  Assert-Rejected 'camera-memory-string-decoy' 'entry\src\main\ets\features\runtime\FeatureWorkflowCatalog.ets' `
    'return rememberedPosition ?? initialLiveCameraPositionForWorkflow(workflow);' `
    "const decoy = 'return rememberedPosition ?? initialLiveCameraPositionForWorkflow(workflow);';`n  return initialLiveCameraPositionForWorkflow(workflow);"
  Assert-Rejected 'long-label-one-line' 'entry\src\main\ets\pages\FeatureRuntimePage.ets' `
    "Text(this.gestureLabelResource(gesture))`n          .fontSize(12)`n          .fontColor(Color.White)`n          .fontWeight(FontWeight.Medium)`n          .maxFontScale(3.2)`n          .maxLines(2)" `
    "Text(this.gestureLabelResource(gesture))`n          .fontSize(12)`n          .fontColor(Color.White)`n          .fontWeight(FontWeight.Medium)`n          .maxFontScale(3.2)`n          .maxLines(1)"
  Assert-Rejected 'long-label-unbounded' 'entry\src\main\ets\pages\FeatureRuntimePage.ets' `
    '.constraintSize({ maxWidth: 176 })' '// .constraintSize({ maxWidth: 176 })'
  Assert-Rejected 'long-label-no-fixed-card-width' 'entry\src\main\ets\pages\FeatureRuntimePage.ets' `
    '.width(176)' '// .width(176)'
  Assert-Rejected 'front-label-edge-overflow' 'entry\src\main\ets\pages\FeatureRuntimePage.ets' `
    "return 'calc(100% - 176vp)';" "return this.percentLength(this.gestureBoxStyle(gesture).left);"
  Assert-Rejected 'rear-label-right-edge-overflow-comment-decoy' 'entry\src\main\ets\pages\FeatureRuntimePage.ets' `
    'const clampedLabelLeft = Math.min(Math.max(labelLeft, 0), canvasWidth - 176);' 'const clampedLabelLeft = labelLeft; // const clampedLabelLeft = Math.min(Math.max(labelLeft, 0), canvasWidth - 176);'
  Assert-Rejected 'rear-label-right-edge-overflow-template-decoy' 'entry\src\main\ets\pages\FeatureRuntimePage.ets' `
    'const clampedLabelLeft = Math.min(Math.max(labelLeft, 0), canvasWidth - 176);' 'const clampDecoy = `const clampedLabelLeft = Math.min(Math.max(labelLeft, 0), canvasWidth - 176);`; const clampedLabelLeft = labelLeft;'
  Assert-RejectedRearLabelClampDecoy
  Assert-Rejected 'retry-template-decoy' 'entry\src\main\ets\pages\FeatureRuntimePage.ets' `
    "if (this.liveGestureRetryAction() !== 'none') {" `
    "if (false) {`n        const retryDecoy = ``this.liveGestureRetryAction() !== 'none'``;"
  Assert-Rejected 'clear-last-overlay' 'entry\src\main\ets\pages\FeatureRuntimePage.ets' `
    "if (!result.ok) {`n        return;`n      }" `
    "if (!result.ok) {`n        this.applyLiveGestureResultState({ generation: this.liveRuntimeGeneration, imageUri: '', detections: [], imageWidth: 0, imageHeight: 0 });`n        return;`n      }"
  Assert-RejectedWithUnusedSibling 'clear-camera-input-unused-sibling-decoy' 'entry\src\main\ets\pages\FeatureRuntimePage.ets' `
    "if (!preserveCameraInput) {`n        this.liveCameraInputSelected = false;`n      }" `
    'this.liveCameraInputSelected = false;' `
    '  private stopLiveCameraPreview(): void {'
  Assert-Rejected 'remove-production-wire' 'scripts\build-hap.ps1' `
    "& (Join-Path `$PSScriptRoot 'check-live-gesture-runtime-ui.ps1')" `
    "# & (Join-Path `$PSScriptRoot 'check-live-gesture-runtime-ui.ps1')"
  Assert-Rejected 'remove-mutation-wire' 'scripts\build-hap.ps1' `
    "& (Join-Path `$PSScriptRoot 'test-live-gesture-runtime-ui-guard.ps1')" `
    "# & (Join-Path `$PSScriptRoot 'test-live-gesture-runtime-ui-guard.ps1')"

  Write-Output 'Live gesture runtime UI guard mutation fixtures passed.'
} finally {
  if ([IO.Directory]::Exists($tempRoot)) {
    $resolved = [IO.Path]::GetFullPath($tempRoot)
    if (-not $resolved.StartsWith($tempPrefix, [StringComparison]::OrdinalIgnoreCase)) {
      throw 'Live gesture guard fixture refused unsafe cleanup.'
    }
    [IO.Directory]::Delete($resolved, $true)
  }
}
