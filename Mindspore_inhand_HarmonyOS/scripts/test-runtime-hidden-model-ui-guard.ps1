$ErrorActionPreference = 'Stop'

$sourceRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$guard = Join-Path $PSScriptRoot 'check-runtime-hidden-model-ui.ps1'
$tempParent = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\', '/')
$tempRoot = Join-Path $tempParent ("mindspore-hidden-model-guard-" + [guid]::NewGuid().ToString('N'))
$prefix = $tempParent + [IO.Path]::DirectorySeparatorChar
$utf8 = [Text.UTF8Encoding]::new($false)
if (-not $tempRoot.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) {
  throw 'Hidden Model guard refused an unsafe temporary path.'
}

$paths = @(
  'entry\src\main\ets\common\data\FeatureCatalog.ets',
  'entry\src\main\ets\features\runtime\FeatureWorkflowCatalog.ets',
  'entry\src\main\ets\pages\ExperiencePage.ets',
  'entry\src\main\ets\pages\FeatureRuntimePage.ets',
  'entry\src\main\ets\services\picker\ModelFileCacheService.ets',
  'scripts\build-hap.ps1'
)

function New-Fixture([string]$Name) {
  $root = Join-Path $tempRoot $Name
  foreach ($relative in $paths) {
    $target = Join-Path $root $relative
    [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($target)) | Out-Null
    [IO.File]::WriteAllText($target, [IO.File]::ReadAllText((Join-Path $sourceRoot $relative)), $utf8)
  }
  return $root
}

function Replace-Once([string]$Path, [string]$Before, [string]$After) {
  $text = [IO.File]::ReadAllText($Path)
  $first = $text.IndexOf($Before, [StringComparison]::Ordinal)
  if ($first -lt 0 -or $text.IndexOf($Before, $first + $Before.Length, [StringComparison]::Ordinal) -ge 0) {
    throw "Hidden Model fixture expected one target: $Before"
  }
  [IO.File]::WriteAllText(
    $Path,
    $text.Substring(0, $first) + $After + $text.Substring($first + $Before.Length),
    $utf8
  )
}

function Assert-Rejected([string]$Name, [string]$RelativePath, [string]$Before, [string]$After) {
  $root = New-Fixture $Name
  Replace-Once (Join-Path $root $RelativePath) $Before $After
  $failed = $false
  try { & $guard -SourceRoot $root | Out-Null } catch { $failed = $true }
  if (-not $failed) { throw "Hidden Model guard accepted mutation: $Name" }
}

try {
  & $guard -SourceRoot (New-Fixture 'valid') | Out-Null

  Assert-Rejected 'public-entry' 'entry\src\main\ets\common\data\FeatureCatalog.ets' `
    "routeName: AppRoute.CUSTOM_MODEL.name, visibleByDefault: false" `
    "routeName: AppRoute.CUSTOM_MODEL.name, visibleByDefault: true"
  Assert-Rejected 'filter-removed' 'entry\src\main\ets\common\data\FeatureCatalog.ets' `
    'items: section.items.filter((item: FeatureItem) => item.visibleByDefault)' `
    'items: section.items'
  Assert-Rejected 'filter-template-decoy' 'entry\src\main\ets\common\data\FeatureCatalog.ets' `
    'items: section.items.filter((item: FeatureItem) => item.visibleByDefault)' `
    "items: section.items`n    // decoy`n    label: ``items: section.items.filter((item: FeatureItem) => item.visibleByDefault)``"
  Assert-Rejected 'unfiltered-page' 'entry\src\main\ets\pages\ExperiencePage.ets' `
    'ForEach(visibleExperienceSections, (section: FeatureSection, sectionIndex: number) => {' `
    "ForEach(experienceSections, (section: FeatureSection, sectionIndex: number) => {`n              // ForEach(visibleExperienceSections, (section: FeatureSection, sectionIndex: number) => {"
  Assert-Rejected 'aliased-unfiltered-page' 'entry\src\main\ets\pages\ExperiencePage.ets' `
    "import { FeatureItem, FeatureSection, visibleExperienceSections } from '../common/data/FeatureCatalog';" `
    "import { FeatureItem, FeatureSection, visibleExperienceSections, experienceSections as sections } from '../common/data/FeatureCatalog';"
  Assert-Rejected 'guard-unwired' 'scripts\build-hap.ps1' `
    "& (Join-Path `$PSScriptRoot 'check-runtime-hidden-model-ui.ps1')" `
    '# hidden model guard removed'
  Assert-Rejected 'custom-runner-unwired' 'scripts\build-hap.ps1' `
    "& (Join-Path `$PSScriptRoot 'test-custom-model-layout-guard.ps1')" `
    '# custom model runner removed'
  Assert-Rejected 'hidden-runner-unwired' 'scripts\build-hap.ps1' `
    "& (Join-Path `$PSScriptRoot 'test-runtime-hidden-model-ui-guard.ps1')" `
    '# hidden model runner removed'

  Write-Output 'Hidden Model UI guard fixtures passed.'
}
finally {
  if (Test-Path -LiteralPath $tempRoot) {
    $resolved = [IO.Path]::GetFullPath($tempRoot)
    if (-not $resolved.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) {
      throw 'Hidden Model guard refused unsafe cleanup.'
    }
    Remove-Item -LiteralPath $resolved -Recurse -Force
  }
}
