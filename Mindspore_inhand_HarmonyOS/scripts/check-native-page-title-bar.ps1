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
    'accessibilityText\(\$r\(\s*\x27\s*\x27\s*\)\)',
    ("\.onClick\(\(\)\s*=>\s*this\.{0}\(\)\)" -f [regex]::Escape($CallbackName))
  )
  foreach ($pattern in $requiredPatterns) {
    if ($container -notmatch $pattern) {
      throw "NativePageTitleBar $SymbolName action is missing contract: $pattern"
    }
  }
  $literalAccessibilityPattern = ("accessibilityText\(\`$r\('app.string.{0}'\)\)" -f [regex]::Escape($AccessibilityKey))
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
  $webBranchCount = @([regex]::Matches($webContent.Text, '\bWeb\s*\(')).Count
  if ($webBranchCount -ne 3) {
    throw "WebPage webContent() must contain exactly 3 Web branches, found $webBranchCount"
  }
  $pageBeginCount = @([regex]::Matches($webContent.Text, '\.onPageBegin\s*\(')).Count
  if ($pageBeginCount -ne 3) {
    throw "WebPage webContent() must reset failure state in all 3 Web branches, found $pageBeginCount onPageBegin callbacks"
  }
  $errorReceiveCount = @([regex]::Matches($webContent.Text, '\.onErrorReceive\s*\(')).Count
  if ($errorReceiveCount -ne 3) {
    throw "WebPage webContent() must handle errors in all 3 Web branches, found $errorReceiveCount onErrorReceive callbacks"
  }
  if ($errorHandler.Text -notmatch 'event\.request\.isMainFrame\s*\(\s*\)') {
    throw 'WebPage must only fail for main-frame errors'
  }
  $retry = Get-WebPageMethodSlice $cleanSource 'retryWebPage'
  if ($retry.Text -notmatch 'this\.webController\.refresh\s*\(\s*\)') {
    throw 'WebPage retryWebPage() must refresh the web controller'
  }
}

function Assert-QrCodePageNativeShellContract([string]$Source) {
  $cleanSource = Remove-ArkTsCommentsAndTemplateRaw $Source $false
  $literalSource = Remove-ArkTsCommentsAndTemplateRaw $Source $true
  if ($cleanSource -match 'app\.media\.icon_back|#66000000') {
    throw 'QrCodePage must not use Android back media or a custom full-screen scrim'
  }
  if ($cleanSource -match "Text\s*\(\s*'[^']*'\s*\)") {
    throw 'QrCodePage must not use hard-coded Text literals'
  }

  $build = Get-ArkTsMethodSlice `
    $cleanSource `
    'build\s*\(\s*\)' `
    'QrCodePage is missing build()' `
    'QrCodePage build() is missing an opening brace' `
    'QrCodePage build() is missing a closing brace'
  $literalBuild = Get-ArkTsMethodSlice `
    $literalSource `
    'build\s*\(\s*\)' `
    'QrCodePage is missing build()' `
    'QrCodePage build() is missing an opening brace' `
    'QrCodePage build() is missing a closing brace'
  $sheet = Get-ArkTsMethodSlice `
    $cleanSource `
    'saveActionSheet\s*\(\s*\)' `
    'QrCodePage is missing saveActionSheet()' `
    'QrCodePage saveActionSheet() is missing an opening brace' `
    'QrCodePage saveActionSheet() is missing a closing brace'
  $literalSheet = Get-ArkTsMethodSlice `
    $literalSource `
    'saveActionSheet\s*\(\s*\)' `
    'QrCodePage is missing saveActionSheet()' `
    'QrCodePage saveActionSheet() is missing an opening brace' `
    'QrCodePage saveActionSheet() is missing a closing brace'

  foreach ($requirement in @(
    @{ Pattern = 'NativePageTitleBar\s*\('; Message = 'QrCodePage build() must use NativePageTitleBar' },
    @{ Pattern = 'showMore\s*:\s*true'; Message = 'QrCodePage title bar must expose the more action' },
    @{ Pattern = 'onMore\s*:'; Message = 'QrCodePage title bar must expose the more callback' },
    @{ Pattern = '\.bindSheet\s*\('; Message = 'QrCodePage must use a native bindSheet' },
    @{ Pattern = 'SheetSize\.FIT_CONTENT'; Message = 'QrCodePage native sheet must fit its content' },
    @{ Pattern = 'qrCodeSheetActionForNativeDismiss\s*\('; Message = 'QrCodePage native dismisses must map to existing reducer actions' },
    @{ Pattern = 'DismissReason\.PRESS_BACK'; Message = 'QrCodePage must map the native back dismiss reason' },
    @{ Pattern = '\.constraintSize\(\{\s*maxWidth:\s*300'; Message = 'QrCodePage QR card must cap its width at 300vp' }
  )) {
    if ($build.Text -notmatch $requirement.Pattern) {
      throw $requirement.Message
    }
  }
  if ($literalBuild.Text -notmatch 'Image\(\$r\(''app\.media\.my_qr_code''\)\)[\s\S]*?\.accessibilityText\(appString\(this\.titleKey\)\s+as\s+Resource\)') {
    throw 'QrCodePage QR image must resolve its localized accessible name as Resource'
  }
  foreach ($requirement in @(
    @{ Pattern = 'SaveButton\s*\('; Message = 'QrCodePage native sheet must use SaveButton' },
    @{ Pattern = '\.enabled\(\s*!this\.saveInFlight\s*\)'; Message = 'QrCodePage SaveButton must disable while saving' }
  )) {
    if ($sheet.Text -notmatch $requirement.Pattern) {
      throw $requirement.Message
    }
  }
  if ($literalSheet.Text -notmatch "appString\('image_save_failed'\)") {
    throw 'QrCodePage native sheet must show save failures'
  }
}

function Get-PoetryPosterMethodSlice([string]$Code, [string]$MethodName) {
  return Get-ArkTsMethodSlice `
    $Code `
    ("{0}\s*\(\s*\)" -f [regex]::Escape($MethodName)) `
    "PoetryPosterPage is missing $MethodName()" `
    "PoetryPosterPage $MethodName() is missing an opening brace" `
    "PoetryPosterPage $MethodName() is missing a closing brace"
}

function Assert-PoetryPosterNativeShellContract([string]$Source) {
  $cleanSource = Remove-ArkTsCommentsAndTemplateRaw $Source $false
  $literalSource = Remove-ArkTsCommentsAndTemplateRaw $Source $true
  $poster = Get-PoetryPosterMethodSlice $cleanSource 'posterCard'
  $literalPoster = Get-PoetryPosterMethodSlice $literalSource 'posterCard'
  $pixelMap = Get-PoetryPosterMethodSlice $cleanSource 'posterPixelMap'
  $saveImage = Get-PoetryPosterMethodSlice $cleanSource 'savePosterImage'
  $save = Get-PoetryPosterMethodSlice $cleanSource 'savePoster'
  $share = Get-PoetryPosterMethodSlice $cleanSource 'sharePoster'
  $build = Get-PoetryPosterMethodSlice $cleanSource 'build'
  $literalBuild = Get-PoetryPosterMethodSlice $literalSource 'build'

  if ($literalSource -match 'app\.media\.icon_back|app\.media\.back|\.width\(\s*''48%''\s*\)') {
    throw 'PoetryPosterPage must not use Android back media or two-column actions'
  }
  foreach ($requirement in @(
    @{ Slice = $build.Text; Pattern = 'NativePageTitleBar\s*\('; Message = 'PoetryPosterPage build() must use NativePageTitleBar' },
    @{ Slice = $build.Text; Pattern = 'router\.back\s*\(\s*\)'; Message = 'PoetryPosterPage title bar must navigate back through router.back()' },
    @{ Slice = $poster.Text; Pattern = '\.constraintSize\(\{\s*minHeight:\s*poetryPosterVisualSpec\.posterMinHeightVp,\s*maxWidth:\s*poetryPosterVisualSpec\.posterMaxWidthVp\s*\}\)'; Message = 'Poetry poster card must use responsive min height and max width' },
    @{ Slice = $literalPoster.Text; Pattern = 'backgroundImage\(\$r\(''app\.media\.poem_frame''\)\)\s*\.backgroundImageSize\(ImageSize\.Cover\)'; Message = 'Poem frame must use ImageSize.Cover' },
    @{ Slice = $literalPoster.Text; Pattern = 'backgroundImage\(\$r\(''app\.media\.poem_bg''\)\)\s*\.backgroundImageSize\(ImageSize\.Cover\)'; Message = 'Poem background must use ImageSize.Cover' },
    @{ Slice = $poster.Text; Pattern = '\.padding\(poetryPosterVisualSpec\.poemTextPaddingVp\)'; Message = 'Poem text must use visual spec padding' },
    @{ Slice = $pixelMap.Text; Pattern = 'componentSnapshot\.get\(poetryPosterComponentId,\s*\{\s*waitUntilRenderFinished:\s*true\s*\}\)'; Message = 'Poster snapshot must wait for rendering' },
    @{ Slice = $saveImage.Text; Pattern = 'withCallerOwnedPixelMap'; Message = 'Poster saving must retain caller-owned pixel map cleanup' },
    @{ Slice = $save.Text; Pattern = 'shouldStartPoetryPosterAction\(this\.actionInFlight\)'; Message = 'savePoster must gate concurrent actions' },
    @{ Slice = $save.Text; Pattern = '\.finally\(\(\)\s*=>\s*\{\s*this\.actionInFlight\s*=\s*false;\s*\}\)'; Message = 'savePoster must release its action gate in finally' },
    @{ Slice = $share.Text; Pattern = 'shouldStartPoetryPosterAction\(this\.actionInFlight\)'; Message = 'sharePoster must gate concurrent actions' },
    @{ Slice = $share.Text; Pattern = 'return\s+this\.shareSavedPosterImage\('; Message = 'sharePoster must return the system share promise before release' },
    @{ Slice = $share.Text; Pattern = '\.finally\(\(\)\s*=>\s*\{\s*this\.actionInFlight\s*=\s*false;\s*\}\)'; Message = 'sharePoster must release its action gate in finally' },
    @{ Slice = $build.Text; Pattern = 'Column\(\{\s*space:\s*AppSpacing\.md\s*\}\)'; Message = 'Poster actions must be a single vertical column' },
    @{ Slice = $literalBuild.Text; Pattern = 'SaveButton\([\s\S]*?\.width\(''100%''\)\s*\.height\(48\)\s*\.enabled\(!this\.actionInFlight\)'; Message = 'SaveButton must be full-width, 48vp, and disabled in flight' },
    @{ Slice = $literalBuild.Text; Pattern = 'Button\(appString\(''poem_share_poster''\)\)[\s\S]*?\.width\(''100%''\)\s*\.height\(48\)\s*\.enabled\(!this\.actionInFlight\)'; Message = 'Share button must be full-width, 48vp, and disabled in flight' }
  )) {
    if ($requirement.Slice -notmatch $requirement.Pattern) {
      throw $requirement.Message
    }
  }
  if ($literalPoster.Text -match '\.lineHeight\(28\)|SaveButton\s*\(|Button\s*\(|Text\(appString\(this\.statusKey\)\)') {
    throw 'Poster snapshot region must exclude fixed line height, actions, and status text'
  }
  if (@([regex]::Matches($cleanSource, '\.id\(poetryPosterComponentId\)')).Count -ne 1) {
    throw 'PoetryPosterPage must contain exactly one poetryPosterComponentId outside comments and string literals'
  }
  if (@([regex]::Matches($poster.Text, '\.id\(poetryPosterComponentId\)')).Count -ne 1) {
    throw 'Poster snapshot region must contain exactly one poetryPosterComponentId'
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
  $qrCodePagePath = Join-Path $root 'entry/src/main/ets/pages/QrCodePage.ets'
  if (-not (Test-Path -LiteralPath $qrCodePagePath -PathType Leaf)) {
    throw 'Missing QrCodePage.ets'
  }
  Assert-QrCodePageNativeShellContract (Get-Content -Raw -Encoding UTF8 -LiteralPath $qrCodePagePath)
  $poetryPosterPagePath = Join-Path $root 'entry/src/main/ets/pages/PoetryPosterPage.ets'
  if (-not (Test-Path -LiteralPath $poetryPosterPagePath -PathType Leaf)) {
    throw 'Missing PoetryPosterPage.ets'
  }
  Assert-PoetryPosterNativeShellContract (Get-Content -Raw -Encoding UTF8 -LiteralPath $poetryPosterPagePath)
  Write-Host 'NativePageTitleBar contract is present'
}
