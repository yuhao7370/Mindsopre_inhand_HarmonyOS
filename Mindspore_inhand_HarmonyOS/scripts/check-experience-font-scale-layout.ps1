$ErrorActionPreference = 'Stop'

$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$headerPath = Join-Path $projectRoot 'entry\src\main\ets\common\components\ExperienceHeader.ets'
$pagePath = Join-Path $projectRoot 'entry\src\main\ets\pages\ExperiencePage.ets'
$bottomTabPath = Join-Path $projectRoot 'entry\src\main\ets\common\components\BottomTabBar.ets'

$header = Get-Content -LiteralPath $headerPath -Raw
$page = Get-Content -LiteralPath $pagePath -Raw
$bottomTab = Get-Content -LiteralPath $bottomTabPath -Raw

function Get-NthIndex(
  [string]$Source,
  [string]$Literal,
  [int]$Occurrence,
  [string]$Description
) {
  $index = -1
  for ($count = 1; $count -le $Occurrence; $count += 1) {
    $index = $Source.IndexOf($Literal, $index + 1, [StringComparison]::Ordinal)
    if ($index -lt 0) {
      throw "Experience font-scale guard could not find $Description occurrence $Occurrence."
    }
  }
  return $index
}

function Get-BracedBlockAfterLiteral(
  [string]$Source,
  [string]$Literal,
  [string]$Description,
  [int]$Occurrence = 1
) {
  $start = Get-NthIndex $Source $Literal $Occurrence $Description
  $openingBrace = $Source.IndexOf('{', $start + $Literal.LastIndexOf('{'))
  if ($openingBrace -lt 0) {
    throw "Experience font-scale guard could not find opening brace for $Description."
  }

  $depth = 0
  for ($index = $openingBrace; $index -lt $Source.Length; $index += 1) {
    if ($Source[$index] -eq '{') {
      $depth += 1
    } elseif ($Source[$index] -eq '}') {
      $depth -= 1
      if ($depth -eq 0) {
        return @{
          Start = $start
          OpeningBrace = $openingBrace
          ClosingBrace = $index
          Text = $Source.Substring($start, $index - $start + 1)
        }
      }
    }
  }

  throw "Experience font-scale guard could not find closing brace for $Description."
}

function Get-ModifierChainAfter(
  [string]$Source,
  [int]$Start,
  [string]$Description
) {
  $position = $Start
  $chainStart = -1
  $chainEnd = -1

  while ($position -lt $Source.Length) {
    while ($position -lt $Source.Length -and [char]::IsWhiteSpace($Source[$position])) {
      $position += 1
    }
    if ($position -ge $Source.Length -or $Source[$position] -ne '.') {
      break
    }
    if ($chainStart -lt 0) {
      $chainStart = $position
    }

    $openingParenthesis = $Source.IndexOf('(', $position)
    if ($openingParenthesis -lt 0) {
      throw "Experience font-scale guard found an incomplete modifier in $Description."
    }
    $depth = 0
    $quote = [char]0
    $escaped = $false
    $closed = $false
    for ($index = $openingParenthesis; $index -lt $Source.Length; $index += 1) {
      $character = $Source[$index]
      if ($quote -ne [char]0) {
        if ($escaped) {
          $escaped = $false
        } elseif ($character -eq '\') {
          $escaped = $true
        } elseif ($character -eq $quote) {
          $quote = [char]0
        }
        continue
      }
      if ($character -eq "'" -or $character -eq '"' -or $character -eq '`') {
        $quote = $character
      } elseif ($character -eq '(') {
        $depth += 1
      } elseif ($character -eq ')') {
        $depth -= 1
        if ($depth -eq 0) {
          $position = $index + 1
          $chainEnd = $position
          $closed = $true
          break
        }
      }
    }
    if (-not $closed) {
      throw "Experience font-scale guard found an unclosed modifier in $Description."
    }
  }

  if ($chainStart -lt 0) {
    return ''
  }
  return $Source.Substring($chainStart, $chainEnd - $chainStart)
}

function Get-ContainerModifierChain(
  [string]$Scope,
  [string]$Literal,
  [string]$Description,
  [int]$Occurrence = 1
) {
  $block = Get-BracedBlockAfterLiteral $Scope $Literal $Description $Occurrence
  return Get-ModifierChainAfter $Scope ($block.ClosingBrace + 1) $Description
}

function Get-CallModifierChain(
  [string]$Scope,
  [string]$Literal,
  [string]$Description,
  [int]$Occurrence = 1
) {
  $start = Get-NthIndex $Scope $Literal $Occurrence $Description
  return Get-ModifierChainAfter $Scope ($start + $Literal.Length) $Description
}

function Assert-ContainsMinimum(
  [string]$Chain,
  [string]$MinimumName,
  [string]$Description
) {
  $pattern = '\.constraintSize\(\{\s*minHeight:\s*' +
    [regex]::Escape($MinimumName) + '\s*\}\)'
  if ($Chain -notmatch $pattern) {
    throw "$Description must expose $MinimumName as its content-adaptive minimum height."
  }
}

function Assert-NoFixedHeight([string]$Chain, [string]$Description) {
  if ($Chain -match '\.height\s*\(') {
    throw "$Description must not impose a fixed height."
  }
  if ($Chain -match '\bmaxHeight\s*:') {
    throw "$Description must not impose a maximum height."
  }
}

function Assert-AdaptiveText([string]$Chain, [string]$Description) {
  Assert-NoFixedHeight $Chain $Description
  if ($Chain -match '\.maxLines\s*\(') {
    throw "$Description must not impose a fixed line-count ceiling."
  }
}

function Assert-NoAbsolutePosition([string]$Chain, [string]$Description) {
  if ($Chain -match '\.position\s*\(') {
    throw "$Description must participate in native layout measurement."
  }
}

$headerBuild = (
  Get-BracedBlockAfterLiteral $header 'build() {' 'ExperienceHeader build method'
).Text
$heroStackChain = Get-ContainerModifierChain `
  $headerBuild 'Stack({ alignContent: Alignment.TopStart }) {' 'Experience hero Stack'
$heroOwnerChain = Get-ContainerModifierChain `
  $headerBuild 'Column() {' 'Experience hero content owner' 1
$heroTextOwnerChain = Get-ContainerModifierChain `
  $headerBuild 'Column() {' 'Experience hero text owner' 2
$heroTitleChain = Get-CallModifierChain `
  $headerBuild "Text(appString('experience_head_title'))" 'Experience hero title'
$heroSubtitleChain = Get-CallModifierChain `
  $headerBuild "Text(appString('experience_head_subtitle'))" 'Experience hero subtitle'

Assert-ContainsMinimum $heroStackChain 'experienceHeaderMinHeightVp' 'Experience hero Stack'
Assert-ContainsMinimum $heroOwnerChain 'experienceHeaderMinHeightVp' 'Experience hero content owner'
foreach ($target in @(
  @{ Chain = $heroStackChain; Description = 'Experience hero Stack' },
  @{ Chain = $heroOwnerChain; Description = 'Experience hero content owner' },
  @{ Chain = $heroTextOwnerChain; Description = 'Experience hero text owner' }
)) {
  Assert-NoFixedHeight $target.Chain $target.Description
  Assert-NoAbsolutePosition $target.Chain $target.Description
}
foreach ($target in @(
  @{ Chain = $heroTitleChain; Description = 'Experience hero title' },
  @{ Chain = $heroSubtitleChain; Description = 'Experience hero subtitle' }
)) {
  Assert-AdaptiveText $target.Chain $target.Description
  Assert-NoAbsolutePosition $target.Chain $target.Description
}

$groupTitle = (
  Get-BracedBlockAfterLiteral $page `
    'private groupTitle(titleKey: AppStringKey, topMargin: number) {' `
    'groupTitle builder'
).Text
$groupTitleTextChain = Get-CallModifierChain `
  $groupTitle 'Text(appString(titleKey))' 'groupTitle text'
Assert-ContainsMinimum `
  $groupTitleTextChain 'experienceGroupTitleMinHeightVp' 'Experience group title'
Assert-AdaptiveText $groupTitleTextChain 'Experience group title'

$sectionTitle = (
  Get-BracedBlockAfterLiteral $page `
    'private sectionTitle(titleKey: AppStringKey) {' `
    'sectionTitle builder'
).Text
$sectionTitleRowChain = Get-ContainerModifierChain `
  $sectionTitle 'Row() {' 'Experience section title row'
$sectionTitleTextChain = Get-CallModifierChain `
  $sectionTitle 'Text(appString(titleKey))' 'Experience section title text'
Assert-ContainsMinimum `
  $sectionTitleRowChain 'experienceSectionTitleMinHeightVp' 'Experience section title row'
Assert-NoFixedHeight $sectionTitleRowChain 'Experience section title row'
Assert-AdaptiveText $sectionTitleTextChain 'Experience section title text'

$stickyTitle = (
  Get-BracedBlockAfterLiteral $page 'private stickyTitle() {' 'stickyTitle builder'
).Text
$stickyTitleRowChain = Get-ContainerModifierChain `
  $stickyTitle 'Row() {' 'Experience sticky title row'
$stickyTitleTextChain = Get-CallModifierChain `
  $stickyTitle "Text(appString('experience_head_title'))" 'Experience sticky title text'
Assert-ContainsMinimum `
  $stickyTitleRowChain 'experienceStickyTitleMinHeightVp' 'Experience sticky title row'
Assert-NoFixedHeight $stickyTitleRowChain 'Experience sticky title row'
Assert-AdaptiveText $stickyTitleTextChain 'Experience sticky title text'

$bottomTabBuild = (
  Get-BracedBlockAfterLiteral $bottomTab 'build() {' 'BottomTabBar build method'
).Text
$bottomTabBarChain = Get-ContainerModifierChain `
  $bottomTabBuild 'Row() {' 'Floating bottom bar'
$bottomTabItemChain = Get-ContainerModifierChain `
  $bottomTabBuild 'Column() {' 'Bottom-tab item'
$bottomTabLabelChain = Get-CallModifierChain `
  $bottomTabBuild 'Text(appString(tab.titleKey))' 'Bottom-tab label'
Assert-ContainsMinimum $bottomTabItemChain 'bottomTabItemMinHeightVp' 'Bottom-tab item'
Assert-NoFixedHeight $bottomTabItemChain 'Bottom-tab item'
Assert-ContainsMinimum $bottomTabBarChain 'bottomTabBarMinHeightVp' 'Floating bottom bar'
Assert-NoFixedHeight $bottomTabBarChain 'Floating bottom bar'
Assert-AdaptiveText $bottomTabLabelChain 'Bottom-tab label'

Write-Output (
  'Experience font-scale layout guard verified scoped content-adaptive builder chains.'
)
