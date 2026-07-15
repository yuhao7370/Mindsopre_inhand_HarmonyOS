$ErrorActionPreference = 'Stop'

$sourceRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$guardPath = Join-Path $PSScriptRoot 'check-still-segmentation-layout-parity.ps1'
$tempParent = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd(
  [IO.Path]::DirectorySeparatorChar,
  [IO.Path]::AltDirectorySeparatorChar
)
$tempRoot = [IO.Path]::GetFullPath((Join-Path $tempParent ("mindspore-still-segmentation-guard-" + [guid]::NewGuid().ToString('N'))))
$tempPrefix = $tempParent + [IO.Path]::DirectorySeparatorChar
$utf8 = [Text.UTF8Encoding]::new($false)
if (-not $tempRoot.StartsWith($tempPrefix, [StringComparison]::OrdinalIgnoreCase)) {
  throw 'Still segmentation guard fixture refused an unsafe temporary path.'
}

function Normalize-Newlines([string]$Text) {
  return $Text.Replace("`r`n", "`n").Replace("`r", "`n")
}

function Copy-GuardedSources([string]$Destination) {
  foreach ($relativePath in @(
    'entry\src\main\ets\features\runtime\FeatureWorkflowCatalog.ets',
    'entry\src\main\ets\pages\FeatureRuntimePage.ets',
    'scripts\build-hap.ps1'
  )) {
    $target = Join-Path $Destination $relativePath
    [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($target)) | Out-Null
    [IO.File]::Copy((Join-Path $sourceRoot $relativePath), $target, $true)
  }
}

function Replace-Once([string]$Path, [string]$Before, [string]$After) {
  $text = Normalize-Newlines ([IO.File]::ReadAllText($Path))
  $Before = Normalize-Newlines $Before
  $After = Normalize-Newlines $After
  $first = $text.IndexOf($Before, [StringComparison]::Ordinal)
  if ($first -lt 0 -or $text.IndexOf($Before, $first + $Before.Length, [StringComparison]::Ordinal) -ge 0) {
    throw "Still segmentation guard fixture expected one mutation target: $Before"
  }
  [IO.File]::WriteAllText(
    $Path,
    $text.Substring(0, $first) + $After + $text.Substring($first + $Before.Length),
    $utf8
  )
}

function Replace-OnceInSection(
  [string]$Path,
  [string]$StartMarker,
  [string]$EndMarker,
  [string]$Before,
  [string]$After
) {
  $text = Normalize-Newlines ([IO.File]::ReadAllText($Path))
  $StartMarker = Normalize-Newlines $StartMarker
  $EndMarker = Normalize-Newlines $EndMarker
  $Before = Normalize-Newlines $Before
  $After = Normalize-Newlines $After
  $start = $text.IndexOf($StartMarker, [StringComparison]::Ordinal)
  $end = if ($start -ge 0) { $text.IndexOf($EndMarker, $start + $StartMarker.Length, [StringComparison]::Ordinal) } else { -1 }
  if ($start -lt 0 -or $end -le $start) { throw "Still segmentation guard fixture could not bound: $StartMarker" }
  $section = $text.Substring($start, $end - $start)
  $relative = $section.IndexOf($Before, [StringComparison]::Ordinal)
  if ($relative -lt 0 -or $section.IndexOf($Before, $relative + $Before.Length, [StringComparison]::Ordinal) -ge 0) {
    throw "Still segmentation guard fixture expected one section target: $Before"
  }
  $absolute = $start + $relative
  [IO.File]::WriteAllText(
    $Path,
    $text.Substring(0, $absolute) + $After + $text.Substring($absolute + $Before.Length),
    $utf8
  )
}

function Assert-GuardFails([string]$Root, [string]$Description) {
  $failed = $false
  try { & $guardPath -SourceRoot $Root | Out-Null } catch { $failed = $true }
  if (-not $failed) { throw "Still segmentation guard fixture accepted mutation: $Description" }
}

function New-MutationRoot([string]$Name) {
  $root = Join-Path $tempRoot $Name
  Copy-GuardedSources $root
  return $root
}

try {
  $validRoot = Join-Path $tempRoot 'valid'
  Copy-GuardedSources $validRoot
  & $guardPath -SourceRoot $validRoot | Out-Null

  $root = New-MutationRoot 'selector'
  Replace-OnceInSection (Join-Path $root 'entry\src\main\ets\features\runtime\FeatureWorkflowCatalog.ets') `
    'export function usesAndroidStillSegmentationLayout' `
    'export function usesAndroidStillSceneLayout' `
    'return workflow?.routeName === AppRoute.SEGMENTATION_STILL.name;' `
    'return workflow?.routeName === AppRoute.SEGMENTATION_LIVE.name;'
  Assert-GuardFails $root 'selector targets live segmentation'

  $root = New-MutationRoot 'toolbar'
  Replace-OnceInSection (Join-Path $root 'entry\src\main\ets\pages\FeatureRuntimePage.ets') `
    '  stillSegmentationAndroidLayout() {' "`n`n  @Builder`n  customModelAndroidLayout()" `
    'this.runtimeActionToolbar(false)' 'this.runtimeActionToolbar(true)'
  Assert-GuardFails $root 'Help/More toolbar is exposed'

  $root = New-MutationRoot 'photo-order'
  $pagePath = Join-Path $root 'entry\src\main\ets\pages\FeatureRuntimePage.ets'
  Replace-OnceInSection $pagePath '  stillSegmentationAndroidLayout() {' "`n`n  @Builder`n  customModelAndroidLayout()" `
    ".onClick(() => this.prepareInput('photo'))" ".onClick(() => this.prepareInput('camera'))"
  Assert-GuardFails $root 'Photo/Camera action order is changed'

  $root = New-MutationRoot 'generic-card'
  Replace-OnceInSection (Join-Path $root 'entry\src\main\ets\pages\FeatureRuntimePage.ets') `
    '  stillSegmentationAndroidLayout() {' "`n`n  @Builder`n  customModelAndroidLayout()" `
    'this.runtimePermissionRecoveryOverlay()' "Text(appString(this.summaryKey))`n      this.runtimePermissionRecoveryOverlay()"
  Assert-GuardFails $root 'generic summary is injected'

  $root = New-MutationRoot 'input-owner-clear'
  Replace-OnceInSection (Join-Path $root 'entry\src\main\ets\pages\FeatureRuntimePage.ets') `
    '  private applyPickResult(' "`n`n  private aiRunInputs" `
    'this.segmentationForegroundPixelMapOwner.invalidatePendingReplacement();' `
    'this.segmentationForegroundPixelMapOwner.clear();'
  Assert-GuardFails $root 'new input clears the old Save target'

  $root = New-MutationRoot 'fire-and-forget'
  Replace-OnceInSection (Join-Path $root 'entry\src\main\ets\pages\FeatureRuntimePage.ets') `
    '  private async updateSegmentationPreview(' "`n`n  private updatePosePreview" `
    'await foregroundUpdate;' 'foregroundUpdate;'
  Assert-GuardFails $root 'foreground conversion is no longer awaited'

  $root = New-MutationRoot 'throw-toast'
  Replace-OnceInSection (Join-Path $root 'entry\src\main\ets\pages\FeatureRuntimePage.ets') `
    '  private applyRuntimeFailure(): void {' "`n`n  private async prepareLiveFrameImageInput" `
    'this.showStillSegmentationFailureToastIfNeeded(false);' `
    '// this.showStillSegmentationFailureToastIfNeeded(false);'
  Assert-GuardFails $root 'thrown-run Toast is removed'

  $root = New-MutationRoot 'build-wiring'
  Replace-Once (Join-Path $root 'scripts\build-hap.ps1') `
    "& (Join-Path `$PSScriptRoot 'check-still-segmentation-layout-parity.ps1')" `
    "# & (Join-Path `$PSScriptRoot 'check-still-segmentation-layout-parity.ps1')"
  Assert-GuardFails $root 'production guard is removed from build'

  Write-Host 'Still image segmentation parity guard mutation fixtures passed.'
} finally {
  if ($tempRoot.StartsWith($tempPrefix, [StringComparison]::OrdinalIgnoreCase) -and [IO.Directory]::Exists($tempRoot)) {
    [IO.Directory]::Delete($tempRoot, $true)
  }
}
