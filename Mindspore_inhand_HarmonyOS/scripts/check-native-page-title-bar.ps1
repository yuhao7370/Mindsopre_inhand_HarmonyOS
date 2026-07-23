$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'arkts-source-guard.ps1')

function Get-NativePageTitleBarComponentSlice([string]$Code) {
  return Get-ArkTsMethodSlice `
    $Code `
    '@Component\s+export\s+struct\s+NativePageTitleBar\s*' `
    'Missing NativePageTitleBar component declaration' `
    'NativePageTitleBar component is missing an opening brace' `
    'NativePageTitleBar component is missing a closing brace'
}

function Get-RowContainerSlice([string]$Build, [int]$SymbolIndex) {
  $rows = [regex]::Matches($Build, 'Row\s*\(\)\s*\{') | Where-Object { $_.Index -lt $SymbolIndex }
  if ($rows.Count -eq 0) {
    throw 'NativePageTitleBar symbol must be contained by a Row'
  }
  $row = $rows[$rows.Count - 1]
  $openingBrace = $Build.IndexOf('{', $row.Index + $row.Length - 1)
  $depth = 0
  for ($index = $openingBrace; $index -lt $Build.Length; $index++) {
    if ($Build[$index] -eq '{') {
      $depth++
    } elseif ($Build[$index] -eq '}') {
      $depth--
      if ($depth -eq 0) {
        $lineStart = $Build.LastIndexOf("`n", $row.Index)
        $indent = $Build.Substring($lineStart + 1, $row.Index - $lineStart - 1)
        $following = $Build.Substring($index + 1)
        $nextNode = [regex]::Match($following, ('(?m)^{0}(?![.\s])' -f [regex]::Escape($indent)))
        $nextBlockEnd = [regex]::Match($following, '(?m)^\s*\}')
        $endOffset = @($nextNode, $nextBlockEnd) |
          Where-Object { $_.Success } |
          ForEach-Object { $_.Index } |
          Measure-Object -Minimum |
          Select-Object -ExpandProperty Minimum
        $end = if ($null -ne $endOffset) { $index + 1 + $endOffset } else { $Build.Length }
        $end = [Math]::Min($end, $Build.Length)
        return $Build.Substring($row.Index, $end - $row.Index)
      }
    }
  }
  throw 'NativePageTitleBar Row container is missing a closing brace'
}

function Assert-IconAction(
  [string]$Build,
  [string]$LiteralBuild,
  [string]$SymbolName,
  [string]$AccessibilityKey,
  [string]$CallbackName
) {
  $symbolPattern = ('^SymbolGlyph\(\$r\(''sys\.symbol\.{0}''\)\)' -f [regex]::Escape($SymbolName))
  $symbol = @([regex]::Matches($Build, "SymbolGlyph\(\`$r\(\s*'\s*'\s*\)\)") | Where-Object {
    [regex]::IsMatch($LiteralBuild.Substring($_.Index), $symbolPattern)
  }) | Select-Object -First 1
  if (-not $symbol) {
    throw "Missing NativePageTitleBar system symbol: $SymbolName"
  }
  $container = Get-RowContainerSlice $Build $symbol.Index
  $literalLength = [Math]::Min($container.Length, $LiteralBuild.Length - $symbol.Index)
  $literalContainer = $LiteralBuild.Substring($symbol.Index, $literalLength)
  $requiredPatterns = @(
    '\.width\(48\)',
    '\.height\(48\)',
    'accessibilityText\(appString\(\s*\x27\s*\x27\s*\)\)',
    ("\.onClick\(\(\)\s*=>\s*this\.{0}\(\)\)" -f [regex]::Escape($CallbackName))
  )
  foreach ($pattern in $requiredPatterns) {
    if ($container -notmatch $pattern) {
      throw "NativePageTitleBar $SymbolName action is missing contract: $pattern"
    }
  }
  $literalAccessibilityPattern = ("accessibilityText\(appString\('{0}'\)\)" -f [regex]::Escape($AccessibilityKey))
  if ($literalContainer -notmatch $literalAccessibilityPattern) {
    throw "NativePageTitleBar $SymbolName action is missing accessible name: $AccessibilityKey"
  }
}

function Assert-NativePageTitleBarContract([string]$Source) {
  $cleanSource = Remove-ArkTsCommentsAndTemplateRaw $Source $false
  $literalSource = Remove-ArkTsCommentsAndTemplateRaw $Source $true
  $component = Get-NativePageTitleBarComponentSlice $cleanSource
  $literalComponent = Get-NativePageTitleBarComponentSlice $literalSource
  $build = Get-ArkTsMethodSlice `
    $component.Text `
    'build\s*\(\s*\)' `
    'NativePageTitleBar is missing build()' `
    'NativePageTitleBar build() is missing an opening brace' `
    'NativePageTitleBar build() is missing a closing brace'
  $literalBuild = $literalComponent.Text.Substring($build.Start, $build.Length)

  if ($literalComponent.Text -match 'app\.media\.icon_back|app\.media\.back') {
    throw 'NativePageTitleBar must use system symbols instead of Android back media'
  }
  if ($component.Text -match '\.height\(56\)') {
    throw 'NativePageTitleBar must not use a fixed 56vp height'
  }
  if ($build.Text -notmatch '\.maxLines\(2\)') {
    throw 'NativePageTitleBar title must allow two lines'
  }

  Assert-IconAction $build.Text $literalBuild 'chevron_backward' 'action_back' 'onBack'
  Assert-IconAction $build.Text $literalBuild 'more' 'action_more' 'onMore'
}

function Get-WebPageMethodSlice([string]$Code, [string]$MethodName) {
  return Get-ArkTsMethodSlice `
    $Code `
    ("{0}\s*\(\s*\)" -f [regex]::Escape($MethodName)) `
    "WebPage is missing $MethodName()" `
    "WebPage $MethodName() is missing an opening brace" `
    "WebPage $MethodName() is missing a closing brace"
}

function Assert-WebPageNativeShellContract([string]$Source) {
  $cleanSource = Remove-ArkTsCommentsAndTemplateRaw $Source $false
  if ($cleanSource -match 'app\.media\.icon_back|app\.media\.back') {
    throw 'WebPage must not use Android back media'
  }

  $build = Get-WebPageMethodSlice $cleanSource 'build'
  $webContent = Get-WebPageMethodSlice $cleanSource 'webContent'
  $errorHandler = Get-ArkTsMethodSlice `
    $cleanSource `
    'handleWebError\s*\(' `
    'WebPage is missing handleWebError()' `
    'WebPage handleWebError() is missing an opening brace' `
    'WebPage handleWebError() is missing a closing brace'

  foreach ($requirement in @(
    @{ Pattern = 'NativePageTitleBar\s*\('; Message = 'WebPage build() must use NativePageTitleBar' },
    @{ Pattern = 'router\.back\s*\(\s*\)'; Message = 'WebPage build() must navigate back through router.back()' },
    @{ Pattern = 'Progress\s*\(\s*\{'; Message = 'WebPage build() must always include Progress' },
    @{ Pattern = '\.opacity\(this\.progress\s*>\s*0\s*&&\s*this\.progress\s*<\s*100\s*&&\s*!this\.loadFailed\s*\?\s*1\s*:\s*0\)'; Message = 'WebPage Progress must hide with opacity instead of a conditional branch' }
  )) {
    if ($build.Text -notmatch $requirement.Pattern) {
      throw $requirement.Message
    }
  }
  if ($build.Text -match 'if\s*\(\s*this\.progress\s*>\s*0\s*&&\s*this\.progress\s*<\s*100') {
    throw 'WebPage Progress must not be conditionally rendered'
  }
  if ($webContent.Text -notmatch '\.onErrorReceive\s*\(') {
    throw 'WebPage webContent() must handle web errors'
  }
  if ($errorHandler.Text -notmatch 'event\.request\.isMainFrame\s*\(\s*\)') {
    throw 'WebPage must only fail for main-frame errors'
  }
  $retry = Get-WebPageMethodSlice $cleanSource 'retryWebPage'
  if ($retry.Text -notmatch 'this\.webController\.refresh\s*\(\s*\)') {
    throw 'WebPage retryWebPage() must refresh the web controller'
  }
}

if ($MyInvocation.InvocationName -ne '.') {
  $root = Split-Path -Parent $PSScriptRoot
  $sourcePath = Join-Path $root 'entry/src/main/ets/common/components/NativePageTitleBar.ets'
  if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
    throw 'Missing NativePageTitleBar.ets'
  }
  $source = Get-Content -Raw -Encoding UTF8 -LiteralPath $sourcePath
  Assert-NativePageTitleBarContract $source
  $webPagePath = Join-Path $root 'entry/src/main/ets/pages/WebPage.ets'
  if (-not (Test-Path -LiteralPath $webPagePath -PathType Leaf)) {
    throw 'Missing WebPage.ets'
  }
  Assert-WebPageNativeShellContract (Get-Content -Raw -Encoding UTF8 -LiteralPath $webPagePath)
  Write-Host 'NativePageTitleBar contract is present'
}
