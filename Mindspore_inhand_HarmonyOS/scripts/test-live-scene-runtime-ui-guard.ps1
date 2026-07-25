$ErrorActionPreference = 'Stop'

function Fail([string]$Message) {
  throw "Live scene runtime UI guard mutation failed: $Message"
}

function Normalize-Newlines([string]$Text) {
  return $Text.Replace("`r`n", "`n").Replace("`r", "`n")
}

$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$guardPath = Join-Path $PSScriptRoot 'check-live-scene-runtime-ui.ps1'
if (-not [IO.File]::Exists($guardPath)) { Fail 'missing live scene runtime UI guard.' }
$tempPrefix = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$tempRoot = Join-Path $tempPrefix ("live-scene-runtime-ui-guard-" + [Guid]::NewGuid().ToString('N'))
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
  [string]$ValidRoot,
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
  $failed = $false
  try { & $guardPath -SourceRoot $fixtureRoot | Out-Null } catch { $failed = $true }
  if (-not $failed) { Fail "guard accepted mutation: $Name" }
}

try {
  $validRoot = Join-Path $tempRoot 'valid'
  Copy-Fixture $validRoot
  & $guardPath -SourceRoot $validRoot | Out-Null

  $catalogPath = 'entry\src\main\ets\features\runtime\FeatureWorkflowCatalog.ets'
  $pagePath = 'entry\src\main\ets\pages\FeatureRuntimePage.ets'
  $buildPath = 'scripts\build-hap.ps1'

  Assert-MutationRejected $validRoot 'default-front-comment-decoy' $catalogPath `
    "return 'front';" `
    "// return 'front';"
  Assert-MutationRejected $validRoot 'default-front-string-decoy' $catalogPath `
    "return 'front';" `
    "const defaultFrontDecoy = 'front'; return 'back';"
  Assert-MutationRejected $validRoot 'default-front-template-decoy' $catalogPath `
    "return 'front';" `
    'const defaultFrontDecoy = `front`; return ''back'';'
  Assert-MutationRejected $validRoot 'default-front-unused-sibling-decoy' $catalogPath `
    "return 'front';" `
    "return 'back';" `
    "function unusedDefaultFrontDecoy(): string { return 'front'; }"
  Assert-MutationRejected $validRoot 'default-front-camera' $catalogPath `
    "workflow.routeName === AppRoute.SCENE_LIVE.name) {`n    return 'front';" `
    "workflow.routeName === AppRoute.SCENE_LIVE.name) {`n    return 'back';"
  Assert-MutationRejected $validRoot 'route-comment-decoy' $catalogPath `
    'return workflow?.routeName === AppRoute.SCENE_LIVE.name;' `
    "// return workflow?.routeName === AppRoute.SCENE_LIVE.name;`n  return false;"
  Assert-MutationRejected $validRoot 'route-string-decoy' $catalogPath `
    'return workflow?.routeName === AppRoute.SCENE_LIVE.name;' `
    "const routeDecoy = 'return workflow?.routeName === AppRoute.SCENE_LIVE.name;';`n  return false;"
  Assert-MutationRejected $validRoot 'route-template-decoy' $catalogPath `
    'return workflow?.routeName === AppRoute.SCENE_LIVE.name;' `
    'const routeDecoy = `return workflow?.routeName === AppRoute.SCENE_LIVE.name;`; return false;'
  Assert-MutationRejected $validRoot 'route-unused-sibling-decoy' $catalogPath `
    'return workflow?.routeName === AppRoute.SCENE_LIVE.name;' `
    'return false;' `
    'function unusedSceneRouteDecoy(workflow: FeatureWorkflow | undefined): boolean { return workflow?.routeName === AppRoute.SCENE_LIVE.name; }'
  Assert-MutationRejected $validRoot 'per-route-camera-memory' $catalogPath `
    'return rememberedPosition ?? initialLiveCameraPositionForWorkflow(workflow);' `
    'return initialLiveCameraPositionForWorkflow(workflow);'
  Assert-MutationRejected $validRoot 'multiple-label-rendering' $pagePath `
    'ForEach(this.sceneOverlayRows, (row: SceneDetectionOverlayRow) => {' `
    'ForEach([], (row: SceneDetectionOverlayRow) => {'
  Assert-MutationRejected $validRoot 'template-publication-decoy' $pagePath `
    'this.sceneOverlayRows = sceneDetectionOverlayRows(data.result);' `
    'const publicationDecoy = `this.sceneOverlayRows = sceneDetectionOverlayRows(data.result);`;'
  Assert-MutationRejected $validRoot 'unbounded-overlay' $pagePath `
    '.constraintSize({ maxWidth: 360, maxHeight: 176 })' `
    '.constraintSize({ maxWidth: 360, maxHeight: 480 })'
  Assert-MutationRejected $validRoot 'bounded-overlay-comment-decoy' $pagePath `
    '.constraintSize({ maxWidth: 360, maxHeight: 176 })' `
    '// .constraintSize({ maxWidth: 360, maxHeight: 176 })'
  Assert-MutationRejected $validRoot 'bounded-overlay-string-decoy' $pagePath `
    '.constraintSize({ maxWidth: 360, maxHeight: 176 })' `
    'const boundedOverlayDecoy = ''.constraintSize({ maxWidth: 360, maxHeight: 176 })'';'
  Assert-MutationRejected $validRoot 'bounded-overlay-template-decoy' $pagePath `
    '.constraintSize({ maxWidth: 360, maxHeight: 176 })' `
    'const boundedOverlayDecoy = `.constraintSize({ maxWidth: 360, maxHeight: 176 })`;'
  Assert-MutationRejected $validRoot 'bounded-overlay-unused-sibling-decoy' $pagePath `
    '.constraintSize({ maxWidth: 360, maxHeight: 176 })' `
    '.constraintSize({ maxWidth: 360, maxHeight: 480 })' `
    'function unusedBoundedOverlayDecoy() { Scroll().constraintSize({ maxWidth: 360, maxHeight: 176 }) }'
  Assert-MutationRejected $validRoot 'action-lane-comment-decoy' $pagePath `
    'this.liveSceneOverlay()' `
    '// this.liveSceneOverlay()'
  Assert-MutationRejected $validRoot 'action-lane-string-decoy' $pagePath `
    'this.liveSceneOverlay()' `
    'const actionLaneDecoy = ''this.liveSceneOverlay()'';'
  Assert-MutationRejected $validRoot 'action-lane-template-decoy' $pagePath `
    'this.liveSceneOverlay()' `
    'const actionLaneDecoy = `this.liveSceneOverlay()`;'
  Assert-MutationRejected $validRoot 'action-lane-unused-sibling-decoy' $pagePath `
    'this.liveSceneOverlay()' `
    'this.liveSceneStatusOverlay()' `
    'function unusedActionLaneDecoy() { this.liveSceneOverlay() }'
  Assert-MutationRejected $validRoot 'narrow-label-column' $pagePath `
    ".maxFontScale(3.2)`n              .width(96)`n            Text(row.value)" `
    ".maxFontScale(3.2)`n              .width(64)`n            Text(row.value)"
  Assert-MutationRejected $validRoot 'long-label-truncation' $pagePath `
    ".fontColor(Color.White)`n              .fontWeight(FontWeight.Medium)`n              .maxFontScale(3.2)`n              .layoutWeight(1)" `
    ".fontColor(Color.White)`n              .fontWeight(FontWeight.Medium)`n              .maxLines(3)`n              .maxFontScale(3.2)`n              .layoutWeight(1)"
  Assert-MutationRejected $validRoot 'missing-retry-mapping' $catalogPath `
    'if (!usesAndroidLiveSceneLayout(workflow)) {' `
    'if (false) {'
  Assert-MutationRejected $validRoot 'retry-comment-decoy' $pagePath `
    'const action = liveSceneRetryActionForStatus(workflow, this.statusKey);' `
    '// const action = liveSceneRetryActionForStatus(workflow, this.statusKey);'
  Assert-MutationRejected $validRoot 'retry-string-decoy' $pagePath `
    'const action = liveSceneRetryActionForStatus(workflow, this.statusKey);' `
    'const retryDecoy = ''const action = liveSceneRetryActionForStatus(workflow, this.statusKey);'';'
  Assert-MutationRejected $validRoot 'retry-template-decoy' $pagePath `
    'const action = liveSceneRetryActionForStatus(workflow, this.statusKey);' `
    'const retryDecoy = `const action = liveSceneRetryActionForStatus(workflow, this.statusKey);`;'
  Assert-MutationRejected $validRoot 'retry-unused-sibling-decoy' $pagePath `
    'const action = liveSceneRetryActionForStatus(workflow, this.statusKey);' `
    'const action = undefined;' `
    'function unusedRetryDecoy() { const action = liveSceneRetryActionForStatus(workflow, this.statusKey); }'
  Assert-MutationRejected $validRoot 'failure-clears-last-labels' $pagePath `
    "if (!result.ok) {`n      return;`n    }" `
    'if (false) {'
  Assert-MutationRejected $validRoot 'preservation-comment-decoy' $catalogPath `
    "return !resultOk || dataKind === 'scenes';" `
    "// return !resultOk || dataKind === 'scenes';`n    return false;"
  Assert-MutationRejected $validRoot 'preservation-string-decoy' $catalogPath `
    "return !resultOk || dataKind === 'scenes';" `
    'const preservationDecoy = ''return !resultOk || dataKind === ''scenes'';''; return false;'
  Assert-MutationRejected $validRoot 'preservation-template-decoy' $catalogPath `
    "return !resultOk || dataKind === 'scenes';" `
    'const preservationDecoy = `return !resultOk || dataKind === ''scenes'';`; return false;'
  Assert-MutationRejected $validRoot 'preservation-unused-sibling-decoy' $catalogPath `
    "return !resultOk || dataKind === 'scenes';" `
    'return false;' `
    "function unusedPreservationDecoy(): boolean { return !resultOk || dataKind === 'scenes'; }"
  Assert-MutationRejected $validRoot 'failure-clears-camera-input' $catalogPath `
    'return usesAndroidLiveGestureLayout(workflow) || usesAndroidLiveSceneLayout(workflow);' `
    'return usesAndroidLiveGestureLayout(workflow);'
  Assert-MutationRejected $validRoot 'missing-production-build-wire' $buildPath `
    "& (Join-Path `$PSScriptRoot 'check-live-scene-runtime-ui.ps1')" `
    "# & (Join-Path `$PSScriptRoot 'check-live-scene-runtime-ui.ps1')"
  Assert-MutationRejected $validRoot 'nested-production-build-wire' $buildPath `
    "& (Join-Path `$PSScriptRoot 'test-live-scene-runtime-ui-guard.ps1')" `
    "function Invoke-LiveSceneGuard {`n  & (Join-Path `$PSScriptRoot 'test-live-scene-runtime-ui-guard.ps1')`n}"

  Write-Output 'Live scene runtime UI guard mutation fixtures passed.'
} finally {
  if ([IO.Directory]::Exists($tempRoot)) {
    $resolved = [IO.Path]::GetFullPath($tempRoot)
    if (-not $resolved.StartsWith($tempPrefix, [StringComparison]::OrdinalIgnoreCase)) {
      throw 'Live scene guard fixture refused unsafe cleanup.'
    }
    [IO.Directory]::Delete($resolved, $true)
  }
}
