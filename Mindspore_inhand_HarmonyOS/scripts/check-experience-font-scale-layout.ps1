$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$headerPath = Join-Path $projectRoot 'entry\src\main\ets\common\components\ExperienceHeader.ets'
$pagePath = Join-Path $projectRoot 'entry\src\main\ets\pages\ExperiencePage.ets'
$bottomTabPath = Join-Path $projectRoot 'entry\src\main\ets\common\components\BottomTabBar.ets'

$header = Get-Content -LiteralPath $headerPath -Raw
$page = Get-Content -LiteralPath $pagePath -Raw
$bottomTab = Get-Content -LiteralPath $bottomTabPath -Raw

function Assert-SourceContains([string]$Source, [string]$Pattern, [string]$Message) {
  if ($Source -notmatch $Pattern) {
    throw $Message
  }
}

function Assert-SourceExcludes([string]$Source, [string]$Pattern, [string]$Message) {
  if ($Source -match $Pattern) {
    throw $Message
  }
}

Assert-SourceContains $header `
  '\.constraintSize\(\{\s*minHeight:\s*experienceHeaderMinHeightVp\s*\}\)' `
  'ExperienceHeader must expose 132vp as a minimum height.'
Assert-SourceExcludes $header `
  '\.height\(\s*experienceHeader(?:Min)?HeightVp\s*\)' `
  'ExperienceHeader must not impose a fixed text-bearing height.'
Assert-SourceExcludes $header '\.position\s*\(' `
  'ExperienceHeader text must participate in native layout measurement.'
Assert-SourceExcludes $header `
  '\.height\(\s*[''"]100%[''"]\s*\)' `
  'ExperienceHeader decorative layers must not claim the scroll viewport height.'
Assert-SourceExcludes $header '\.maxLines\s*\(' `
  'ExperienceHeader text must not have a fixed line-count ceiling.'

Assert-SourceContains $page `
  '\.constraintSize\(\{\s*minHeight:\s*experienceGroupTitleMinHeightVp\s*\}\)' `
  'Experience group titles must expose 30vp as a minimum height.'
Assert-SourceContains $page `
  '\.constraintSize\(\{\s*minHeight:\s*experienceSectionTitleMinHeightVp\s*\}\)' `
  'Experience section title rows must expose 20vp as a minimum height.'
Assert-SourceExcludes $page '\.height\(\s*30\s*\)' `
  'Experience group titles must not impose a fixed height.'
Assert-SourceExcludes $page '\.height\(\s*20\s*\)' `
  'Experience section title rows must not impose a fixed height.'
Assert-SourceExcludes $page '\.maxLines\s*\(' `
  'Experience titles must not have a fixed line-count ceiling.'

Assert-SourceContains $bottomTab `
  '\.constraintSize\(\{\s*minHeight:\s*bottomTabItemMinHeightVp\s*\}\)' `
  'Bottom-tab items must expose 50vp as a minimum height.'
Assert-SourceContains $bottomTab `
  '\.constraintSize\(\{\s*minHeight:\s*bottomTabBarMinHeightVp\s*\}\)' `
  'The floating bottom bar must expose 62vp as a minimum height.'
Assert-SourceExcludes $bottomTab '\.height\(\s*50\s*\)' `
  'Bottom-tab items must not impose a fixed text-bearing height.'
Assert-SourceExcludes $bottomTab '\.height\(\s*62\s*\)' `
  'The floating bottom bar must not impose a fixed text-bearing height.'
Assert-SourceExcludes $bottomTab '\.maxLines\s*\(' `
  'Bottom-tab labels must be allowed to wrap at large font scales.'

Write-Output 'Experience font-scale layout uses content-driven native minimum heights.'
