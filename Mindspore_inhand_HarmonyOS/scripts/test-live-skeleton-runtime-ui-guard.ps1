param(
  [switch]$ExpectRed
)

$ErrorActionPreference = 'Stop'

function Fail([string]$Message) {
  throw "Live skeleton runtime UI guard mutation failed: $Message"
}

function Normalize-Newlines([string]$Text) {
  return $Text.Replace("`r`n", "`n").Replace("`r", "`n")
}

$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$guardPath = Join-Path $PSScriptRoot 'check-live-skeleton-runtime-ui.ps1'
if (-not [IO.File]::Exists($guardPath)) { Fail 'missing live skeleton runtime UI guard.' }

if ($ExpectRed) {
  $rejected = $false
  try { & $guardPath -SourceRoot $root *> $null } catch { $rejected = $true }
  if (-not $rejected) { Fail 'Live skeleton RED runner expected the baseline guard to reject missing behavior.' }
  throw 'Live skeleton RED confirmed: baseline lacks the route-specific runtime UI contract.'
}

$tempPrefix = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$tempRoot = Join-Path $tempPrefix ('live-skeleton-runtime-ui-guard-' + [Guid]::NewGuid().ToString('N'))
$utf8 = [Text.UTF8Encoding]::new($false)

function Copy-Fixture([string]$Destination) {
  foreach ($relativePath in @(
    'entry\src\main\ets\pages\FeatureRuntimePage.ets',
    'entry\src\main\ets\features\runtime\FeatureWorkflowCatalog.ets',
    'scripts\build-hap.ps1'
  )) {
    $source = Join-Path $root $relativePath
    if (-not [IO.File]::Exists($source)) { Fail "missing fixture source: $relativePath" }
    $target = Join-Path $Destination $relativePath
    [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($target)) | Out-Null
    [IO.File]::Copy($source, $target, $true)
  }
}

function Replace-Once([string]$Path, [string]$Before, [string]$After) {
  $text = Normalize-Newlines ([IO.File]::ReadAllText($Path))
  $Before = Normalize-Newlines $Before
  $After = Normalize-Newlines $After
  $first = $text.IndexOf($Before, [StringComparison]::Ordinal)
  if ($first -lt 0 -or $text.IndexOf($Before, $first + $Before.Length, [StringComparison]::Ordinal) -ge 0) {
    Fail "expected one mutation target in ${Path}: $Before"
  }
  [IO.File]::WriteAllText(
    $Path,
    $text.Substring(0, $first) + $After + $text.Substring($first + $Before.Length),
    $utf8
  )
}

function Assert-MutationRejected(
  [string]$Name,
  [string]$RelativePath,
  [string]$Before,
  [string]$After,
  [string]$Append = ''
) {
  $fixtureRoot = Join-Path $tempRoot $Name
  Copy-Fixture $fixtureRoot
  $fixturePath = Join-Path $fixtureRoot $RelativePath
  Replace-Once $fixturePath $Before $After
  if ($Append.Length -gt 0) {
    [IO.File]::AppendAllText($fixturePath, "`n$Append`n", $utf8)
  }
  $rejected = $false
  try { & $guardPath -SourceRoot $fixtureRoot | Out-Null } catch { $rejected = $true }
  if (-not $rejected) { Fail "guard accepted mutation: $Name" }
}

try {
  $validRoot = Join-Path $tempRoot 'valid'
  Copy-Fixture $validRoot
  & $guardPath -SourceRoot $validRoot | Out-Null

  $catalogPath = 'entry\src\main\ets\features\runtime\FeatureWorkflowCatalog.ets'
  $pagePath = 'entry\src\main\ets\pages\FeatureRuntimePage.ets'
  $buildPath = 'scripts\build-hap.ps1'

  Assert-MutationRejected 'default-rear-comment-decoy' $catalogPath `
    "workflow.routeName === AppRoute.LIVE_SKELETON.name) {`n    return 'back';" `
    "workflow.routeName === AppRoute.LIVE_SKELETON.name) {`n    // return 'back';"
  Assert-MutationRejected 'default-rear-string-decoy' $catalogPath `
    "workflow.routeName === AppRoute.LIVE_SKELETON.name) {`n    return 'back';" `
    "workflow.routeName === AppRoute.LIVE_SKELETON.name) {`n    const defaultRearDecoy = 'back'; return 'front';"
  Assert-MutationRejected 'default-rear-template-decoy' $catalogPath `
    "workflow.routeName === AppRoute.LIVE_SKELETON.name) {`n    return 'back';" `
    "workflow.routeName === AppRoute.LIVE_SKELETON.name) {`n    const defaultRearDecoy = ``back``; return 'front';"
  Assert-MutationRejected 'default-rear-unused-sibling-decoy' $catalogPath `
    "workflow.routeName === AppRoute.LIVE_SKELETON.name) {`n    return 'back';" `
    "workflow.routeName === AppRoute.LIVE_SKELETON.name) {`n    return 'front';" `
    "function unusedDefaultRearDecoy(): string { return 'back'; }"
  Assert-MutationRejected 'route-comment-decoy' $catalogPath `
    "export function usesAndroidLiveSkeletonLayout(workflow: FeatureWorkflow | undefined): boolean {`n  return workflow?.routeName === AppRoute.LIVE_SKELETON.name;`n}" `
    "export function usesAndroidLiveSkeletonLayout(workflow: FeatureWorkflow | undefined): boolean {`n  // return workflow?.routeName === AppRoute.LIVE_SKELETON.name;`n  return false;`n}"
  Assert-MutationRejected 'route-string-decoy' $catalogPath `
    "export function usesAndroidLiveSkeletonLayout(workflow: FeatureWorkflow | undefined): boolean {`n  return workflow?.routeName === AppRoute.LIVE_SKELETON.name;`n}" `
    "export function usesAndroidLiveSkeletonLayout(workflow: FeatureWorkflow | undefined): boolean {`n  const routeDecoy = 'return workflow?.routeName === AppRoute.LIVE_SKELETON.name;';`n  return false;`n}"
  Assert-MutationRejected 'route-template-decoy' $catalogPath `
    "export function usesAndroidLiveSkeletonLayout(workflow: FeatureWorkflow | undefined): boolean {`n  return workflow?.routeName === AppRoute.LIVE_SKELETON.name;`n}" `
    "export function usesAndroidLiveSkeletonLayout(workflow: FeatureWorkflow | undefined): boolean {`n  const routeDecoy = ``return workflow?.routeName === AppRoute.LIVE_SKELETON.name;``; return false;`n}"
  Assert-MutationRejected 'route-unused-sibling-decoy' $catalogPath `
    "export function usesAndroidLiveSkeletonLayout(workflow: FeatureWorkflow | undefined): boolean {`n  return workflow?.routeName === AppRoute.LIVE_SKELETON.name;`n}" `
    "export function usesAndroidLiveSkeletonLayout(workflow: FeatureWorkflow | undefined): boolean {`n  return false;`n}" `
    'function unusedSkeletonRouteDecoy(workflow: FeatureWorkflow | undefined): boolean { return workflow?.routeName === AppRoute.LIVE_SKELETON.name; }'
  Assert-MutationRejected 'specialized-layout-real-branch-removed' $catalogPath `
    "if (usesAndroidLiveSkeletonLayout(workflow)) {`n    return 'skeleton';`n  }" `
    'return undefined;'
  Assert-MutationRejected 'specialized-layout-comment-decoy' $catalogPath `
    "if (usesAndroidLiveSkeletonLayout(workflow)) {`n    return 'skeleton';`n  }" `
    "// if (usesAndroidLiveSkeletonLayout(workflow)) { return 'skeleton'; }`n  return undefined;"
  Assert-MutationRejected 'specialized-layout-string-decoy' $catalogPath `
    "if (usesAndroidLiveSkeletonLayout(workflow)) {`n    return 'skeleton';`n  }" `
    ('const layoutDecoy = "return ''skeleton'';";' + "`n  return undefined;")
  Assert-MutationRejected 'specialized-layout-template-decoy' $catalogPath `
    "if (usesAndroidLiveSkeletonLayout(workflow)) {`n    return 'skeleton';`n  }" `
    'const layoutDecoy = `return ''skeleton'';`; return undefined;'
  Assert-MutationRejected 'specialized-layout-unused-sibling-decoy' $catalogPath `
    "if (usesAndroidLiveSkeletonLayout(workflow)) {`n    return 'skeleton';`n  }" `
    'return undefined;' `
    "function unusedSkeletonLayoutDecoy(): string { return 'skeleton'; }"
  Assert-MutationRejected 'per-route-camera-memory' $catalogPath `
    'return rememberedPosition ?? initialLiveCameraPositionForWorkflow(workflow);' `
    'return initialLiveCameraPositionForWorkflow(workflow);'
  Assert-MutationRejected 'front-mirror-points' $pagePath `
    "if (shouldMirrorLivePoseCameraOverlay(workflowForRoute(this.routeName), this.liveCameraPosition)) {`n      return {`n        x: 100 - position.x,`n        y: position.y`n      };`n    }" `
    "if (false) {`n      return {`n        x: 100 - position.x,`n        y: position.y`n      };`n    }"
  Assert-MutationRejected 'front-mirror-catalog-comment-decoy' $catalogPath `
    "return shouldShowLivePoseCameraOverlay(workflow) && liveCameraPosition === 'front';" `
    "return false; // return shouldShowLivePoseCameraOverlay(workflow) && liveCameraPosition === 'front';"
  Assert-MutationRejected 'template-comment-decoy' $pagePath `
    'this.livePoseTemplateOverlay()' `
    '// this.livePoseTemplateOverlay()'
  Assert-MutationRejected 'template-string-decoy' $pagePath `
    'this.livePoseTemplateOverlay()' `
    'const templateDecoy = ''this.livePoseTemplateOverlay()'';'
  Assert-MutationRejected 'template-template-decoy' $pagePath `
    'this.livePoseTemplateOverlay()' `
    'const templateDecoy = `this.livePoseTemplateOverlay()`;'
  Assert-MutationRejected 'template-unused-sibling-decoy' $pagePath `
    'this.livePoseTemplateOverlay()' `
    'this.liveSkeletonStatusOverlay()' `
    'function unusedTemplateDecoy() { this.livePoseTemplateOverlay() }'
  Assert-MutationRejected 'status-moved-back-into-camera-stack' $pagePath `
    ".backgroundColor('#111827')`n      Row({ space: AppSpacing.sm }) {`n        this.liveSkeletonStatusOverlay()" `
    ".backgroundColor('#111827')`n        this.liveSkeletonStatusOverlay()"
  Assert-MutationRejected 'camera-switch-moved-back-into-pose-canvas' $pagePath `
    "Column({ space: AppSpacing.sm }) {`n      this.runtimeActionToolbar(true)`n      Stack({ alignContent: Alignment.TopStart }) {`n        this.liveCameraSurfaceContent()`n      }" `
    "Column({ space: AppSpacing.sm }) {`n      this.runtimeActionToolbar(true)`n      Stack({ alignContent: Alignment.TopStart }) {`n        this.liveCameraSurfaceContent()`n        if (this.liveCameraSwitchAvailable) {`n          this.runtimeCameraSwitchAction()`n        }`n      }"
  Assert-MutationRejected 'similarity-label-truncated' $pagePath `
    'Text(`Similarity:${this.livePoseSimilarityPercent()}`)' `
    'Text(`ity:${this.livePoseSimilarityPercent()}`)'
  Assert-MutationRejected 'similarity-width-reduced' $pagePath `
    ('Text(`Similarity:${this.livePoseSimilarityPercent()}`)' + "`n        .fontSize(13)`n        .fontColor(Color.White)`n        .width(196)`n        .maxLines(2)") `
    ('Text(`Similarity:${this.livePoseSimilarityPercent()}`)' + "`n        .fontSize(13)`n        .fontColor(Color.White)`n        .width(80)`n        .maxLines(2)")
  Assert-MutationRejected 'similarity-fixed-height' $pagePath `
    ('Text(`Similarity:${this.livePoseSimilarityPercent()}`)' + "`n        .fontSize(13)`n        .fontColor(Color.White)`n        .width(196)`n        .maxLines(2)") `
    ('Text(`Similarity:${this.livePoseSimilarityPercent()}`)' + "`n        .fontSize(13)`n        .fontColor(Color.White)`n        .height(18)`n        .width(196)`n        .maxLines(2)")
  Assert-MutationRejected 'similarity-ellipsis' $pagePath `
    ('Text(`Similarity:${this.livePoseSimilarityPercent()}`)' + "`n        .fontSize(13)`n        .fontColor(Color.White)`n        .width(196)`n        .maxLines(2)") `
    ('Text(`Similarity:${this.livePoseSimilarityPercent()}`)' + "`n        .fontSize(13)`n        .fontColor(Color.White)`n        .width(196)`n        .maxLines(2)`n        .textOverflow({ overflow: TextOverflow.Ellipsis })")
  Assert-MutationRejected 'similarity-font-cap' $pagePath `
    ('Text(`Similarity:${this.livePoseSimilarityPercent()}`)' + "`n        .fontSize(13)`n        .fontColor(Color.White)`n        .width(196)`n        .maxLines(2)") `
    ('Text(`Similarity:${this.livePoseSimilarityPercent()}`)' + "`n        .fontSize(13)`n        .fontColor(Color.White)`n        .width(196)`n        .maxLines(2)`n        .maxFontScale(1.0)")
  Assert-MutationRejected 'pose-publication-clears-overlay' $pagePath `
    "if (usesAndroidLiveSkeletonLayout(workflowForRoute(this.routeName))) {`n      if (!result.ok) {`n        return;`n      }`n    }" `
    'if (usesAndroidLiveSkeletonLayout(workflowForRoute(this.routeName))) { this.posePoints = []; }'
  Assert-MutationRejected 'retry-comment-decoy' $pagePath `
    'const action = liveSkeletonRetryActionForStatus(workflow, this.statusKey);' `
    '// const action = liveSkeletonRetryActionForStatus(workflow, this.statusKey);'
  Assert-MutationRejected 'retry-string-decoy' $pagePath `
    'const action = liveSkeletonRetryActionForStatus(workflow, this.statusKey);' `
    'const retryDecoy = ''const action = liveSkeletonRetryActionForStatus(workflow, this.statusKey);'';'
  Assert-MutationRejected 'retry-template-decoy' $pagePath `
    'const action = liveSkeletonRetryActionForStatus(workflow, this.statusKey);' `
    'const retryDecoy = `const action = liveSkeletonRetryActionForStatus(workflow, this.statusKey);`;'
  Assert-MutationRejected 'retry-unused-sibling-decoy' $pagePath `
    'const action = liveSkeletonRetryActionForStatus(workflow, this.statusKey);' `
    'const action = undefined;' `
    'function unusedRetryDecoy() { const action = liveSkeletonRetryActionForStatus(workflow, this.statusKey); }'
  Assert-MutationRejected 'failure-clears-camera-input' $catalogPath `
    "return usesAndroidLiveSkeletonLayout(workflow) || usesAndroidLiveGestureLayout(workflow) ||`n    usesAndroidLiveSceneLayout(workflow);" `
    "return usesAndroidLiveGestureLayout(workflow) ||`n    usesAndroidLiveSceneLayout(workflow);"
  Assert-MutationRejected 'preservation-comment-decoy' $catalogPath `
    "return !resultOk || dataKind === 'pose';" `
    "// return !resultOk || dataKind === 'pose';`n    return false;"
  Assert-MutationRejected 'preservation-string-decoy' $catalogPath `
    "return !resultOk || dataKind === 'pose';" `
    'const preservationDecoy = ''return !resultOk || dataKind === ''pose'';''; return false;'
  Assert-MutationRejected 'preservation-template-decoy' $catalogPath `
    "return !resultOk || dataKind === 'pose';" `
    'const preservationDecoy = `return !resultOk || dataKind === ''pose'';`; return false;'
  Assert-MutationRejected 'preservation-unused-sibling-decoy' $catalogPath `
    "return !resultOk || dataKind === 'pose';" `
    'return false;' `
    "function unusedPreservationDecoy(): boolean { return !resultOk || dataKind === 'pose'; }"
  Assert-MutationRejected 'missing-production-build-wire' $buildPath `
    "& (Join-Path `$PSScriptRoot 'check-live-skeleton-runtime-ui.ps1')" `
    "# & (Join-Path `$PSScriptRoot 'check-live-skeleton-runtime-ui.ps1')"
  Assert-MutationRejected 'nested-mutation-build-wire' $buildPath `
    "& (Join-Path `$PSScriptRoot 'test-live-skeleton-runtime-ui-guard.ps1')" `
    "function Invoke-LiveSkeletonGuard {`n  & (Join-Path `$PSScriptRoot 'test-live-skeleton-runtime-ui-guard.ps1')`n}"

  Write-Output 'Live skeleton runtime UI guard mutation fixtures passed.'
} finally {
  if ([IO.Directory]::Exists($tempRoot)) {
    $resolved = [IO.Path]::GetFullPath($tempRoot)
    if (-not $resolved.StartsWith($tempPrefix, [StringComparison]::OrdinalIgnoreCase)) {
      throw 'Live skeleton guard fixture refused unsafe cleanup.'
    }
    [IO.Directory]::Delete($resolved, $true)
  }
}
