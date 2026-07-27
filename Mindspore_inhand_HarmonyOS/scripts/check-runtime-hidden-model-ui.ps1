param(
  [string]$SourceRoot = ''
)

$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($SourceRoot)) {
  $SourceRoot = Split-Path -Parent $PSScriptRoot
}
$SourceRoot = [IO.Path]::GetFullPath($SourceRoot)

. (Join-Path $PSScriptRoot 'check-custom-model-layout-parity.ps1') -SourceRoot $SourceRoot | Out-Null

function Read-Normalized([string]$Path) {
  return (Get-Content -Raw -Encoding UTF8 -LiteralPath $Path).Replace("`r`n", "`n").Replace("`r", "`n")
}

function Assert-MatchCount([string]$Text, [string]$Pattern, [int]$Expected, [string]$Message) {
  $count = [regex]::Matches($Text, $Pattern).Count
  if ($count -ne $Expected) {
    throw "Hidden Model UI guard failed: $Message Expected $Expected, found $count."
  }
}

$catalog = Remove-ArkTsComments (Read-Normalized (Join-Path $SourceRoot 'entry\src\main\ets\common\data\FeatureCatalog.ets'))
$page = Remove-ArkTsComments (Read-Normalized (Join-Path $SourceRoot 'entry\src\main\ets\pages\ExperiencePage.ets'))
$buildPath = Join-Path $SourceRoot 'scripts\build-hap.ps1'
$build = Read-Normalized $buildPath

Assert-MatchCount $catalog `
  '(?m)^\s{4}items: section\.items\.filter\(\(item: FeatureItem\) => item\.visibleByDefault\)\s*$' 1 `
  'public sections must filter every hidden feature.'
Assert-MatchCount $catalog `
  '(?m)^export const visibleExperienceSections: FeatureSection\[\] = experienceSections\s*$' 1 `
  'the public catalog must start from the filtered section pipeline.'
Assert-MatchCount $page `
  "(?m)^import \{ FeatureItem, FeatureSection, visibleExperienceSections \} from '../common/data/FeatureCatalog';\s*$" 1 `
  'ExperiencePage must import only the public section list.'
Assert-MatchCount $page `
  '(?m)^\s+ForEach\(visibleExperienceSections, \(section: FeatureSection, sectionIndex: number\) => \{\s*$' 1 `
  'ExperiencePage must render only public sections.'
Assert-MatchCount $page '(?m)^\s+ForEach\((experienceSections|allExperienceFeatures),' 0 `
  'ExperiencePage must not render the unfiltered catalog.'
Assert-MatchCount $page "(?m)from '../common/data/FeatureCatalog';" 1 `
  'ExperiencePage must have exactly one FeatureCatalog import.'
Assert-MatchCount $catalog ([regex]::Escape('`')) 0 `
  'FeatureCatalog must not contain template-literal marker decoys.'
Assert-MatchCount $page ([regex]::Escape('`')) 0 `
  'ExperiencePage must not contain template-literal marker decoys.'

$requiredCalls = @(
  "& (Join-Path `$PSScriptRoot 'check-runtime-hidden-model-ui.ps1')",
  "& (Join-Path `$PSScriptRoot 'test-custom-model-layout-guard.ps1')",
  "& (Join-Path `$PSScriptRoot 'test-runtime-hidden-model-ui-guard.ps1')"
)
$tokens = $null
$errors = $null
$ast = [Management.Automation.Language.Parser]::ParseFile($buildPath, [ref]$tokens, [ref]$errors)
if ($errors.Count -ne 0) {
  throw 'Hidden Model UI guard failed: build-hap.ps1 must parse cleanly.'
}
foreach ($requiredCall in $requiredCalls) {
  Assert-MatchCount $build ([regex]::Escape($requiredCall)) 1 `
    "build-hap must invoke $requiredCall exactly once."
  $topLevelCalls = @($ast.EndBlock.Statements | Where-Object {
      $_.Extent.Text.Replace("`r`n", "`n").Trim() -eq $requiredCall
    })
  if ($topLevelCalls.Count -ne 1) {
    throw "Hidden Model UI guard failed: build-hap must execute one top-level $requiredCall; found $($topLevelCalls.Count)."
  }
}

Write-Output 'Hidden Model UI guard passed.'
