$ErrorActionPreference = 'Stop'

$sourceRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$guardPath = Join-Path $PSScriptRoot 'check-style-transfer-layout-parity.ps1'
$tempParent = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd(
  [IO.Path]::DirectorySeparatorChar,
  [IO.Path]::AltDirectorySeparatorChar
)
$tempRoot = [IO.Path]::GetFullPath((Join-Path $tempParent ("mindspore-style-transfer-guard-" + [guid]::NewGuid().ToString('N'))))
$tempPrefix = $tempParent + [IO.Path]::DirectorySeparatorChar
if (-not $tempRoot.StartsWith($tempPrefix, [StringComparison]::OrdinalIgnoreCase)) {
  throw 'Style Transfer guard fixture refused an unsafe temporary path.'
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
  $text = [IO.File]::ReadAllText($Path)
  $first = $text.IndexOf($Before, [StringComparison]::Ordinal)
  if ($first -lt 0 -or $text.IndexOf($Before, $first + $Before.Length, [StringComparison]::Ordinal) -ge 0) {
    throw "Style Transfer guard fixture expected one mutation target: $Before"
  }
  [IO.File]::WriteAllText($Path, $text.Substring(0, $first) + $After + $text.Substring($first + $Before.Length))
}

function Assert-GuardFails([string]$Root, [string]$Description) {
  $failed = $false
  try { & $guardPath -SourceRoot $Root | Out-Null } catch { $failed = $true }
  if (-not $failed) { throw "Style Transfer guard fixture accepted mutation: $Description" }
}

try {
  $validRoot = Join-Path $tempRoot 'valid'
  Copy-GuardedSources $validRoot
  & $guardPath -SourceRoot $validRoot | Out-Null

  $selectorRoot = Join-Path $tempRoot 'wrong-selector'
  Copy-GuardedSources $selectorRoot
  Replace-Once `
    (Join-Path $selectorRoot 'entry\src\main\ets\features\runtime\FeatureWorkflowCatalog.ets') `
    'return workflow?.routeName === AppRoute.STYLE_TRANSFER.name;' `
    'return workflow?.routeName === AppRoute.OBJECT_PHOTO.name;'
  Assert-GuardFails $selectorRoot 'selector targets a sibling route'

  $builderRoot = Join-Path $tempRoot 'quoted-builder-decoy'
  Copy-GuardedSources $builderRoot
  Replace-Once `
    (Join-Path $builderRoot 'entry\src\main\ets\pages\FeatureRuntimePage.ets') `
    '      this.styleTransferAndroidLayout()' `
    "      const builderDecoy = 'this.styleTransferAndroidLayout()';"
  Assert-GuardFails $builderRoot 'builder selection exists only in a quoted decoy'
} finally {
  if ([IO.Directory]::Exists($tempRoot)) {
    $resolved = [IO.Path]::GetFullPath($tempRoot)
    if (-not $resolved.StartsWith($tempPrefix, [StringComparison]::OrdinalIgnoreCase)) {
      throw 'Style Transfer guard fixture refused unsafe cleanup.'
    }
    [IO.Directory]::Delete($resolved, $true)
  }
}

Write-Output 'Style Transfer layout parity guard fixture passed.'
