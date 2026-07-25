param(
  [string]$SourceRoot = ''
)

$ErrorActionPreference = 'Stop'

function Get-NormalizedText([string]$Path) {
  return ([IO.File]::ReadAllText($Path)).Replace("`r`n", "`n").Replace("`r", "`n")
}

function ConvertTo-ArkTsStructuralText([string]$Text) {
  $result = [Text.StringBuilder]::new($Text.Length)
  for ($index = 0; $index -lt $Text.Length; $index++) {
    $current = $Text[$index]
    $next = if ($index + 1 -lt $Text.Length) { $Text[$index + 1] } else { [char]0 }

    if ($current -eq '/' -and $next -eq '/') {
      [void]$result.Append('  ')
      $index += 2
      while ($index -lt $Text.Length -and $Text[$index] -ne "`n") {
        [void]$result.Append(' ')
        $index++
      }
      if ($index -lt $Text.Length) { [void]$result.Append("`n") }
      continue
    }

    if ($current -eq '/' -and $next -eq '*') {
      [void]$result.Append('  ')
      $index += 2
      $closed = $false
      while ($index -lt $Text.Length) {
        if ($index + 1 -lt $Text.Length -and $Text[$index] -eq '*' -and $Text[$index + 1] -eq '/') {
          [void]$result.Append('  ')
          $index++
          $closed = $true
          break
        }
        [void]$result.Append($(if ($Text[$index] -eq "`n") { "`n" } else { ' ' }))
        $index++
      }
      if (-not $closed) { throw 'Runtime layout closure guard failed: unterminated block comment.' }
      continue
    }

    if ($current -eq "'" -or $current -eq '"') {
      $quote = $current
      $literal = [Text.StringBuilder]::new()
      $escaped = $false
      $closed = $false
      for ($literalIndex = $index + 1; $literalIndex -lt $Text.Length; $literalIndex++) {
        $literalChar = $Text[$literalIndex]
        if ($escaped) {
          [void]$literal.Append($literalChar)
          $escaped = $false
        } elseif ($literalChar -eq '\') {
          [void]$literal.Append($literalChar)
          $escaped = $true
        } elseif ($literalChar -eq $quote) {
          $closed = $true
          break
        } else {
          [void]$literal.Append($literalChar)
        }
      }
      if (-not $closed) { throw 'Runtime layout closure guard failed: unterminated quoted string.' }
      $encoded = -join @($literal.ToString().ToCharArray() | ForEach-Object { ([int]$_).ToString('X4') })
      [void]$result.Append($quote)
      [void]$result.Append("__STR_${encoded}__")
      [void]$result.Append($quote)
      $index = $literalIndex
      continue
    }

    if ($current -eq '`') {
      [void]$result.Append('`__TEMPLATE__')
      $escaped = $false
      $closed = $false
      for ($templateIndex = $index + 1; $templateIndex -lt $Text.Length; $templateIndex++) {
        $templateChar = $Text[$templateIndex]
        if ($escaped) {
          $escaped = $false
        } elseif ($templateChar -eq '\') {
          $escaped = $true
        } elseif ($templateChar -eq '`') {
          $closed = $true
          break
        }
        if ($templateChar -eq "`n") { [void]$result.Append("`n") }
      }
      if (-not $closed) { throw 'Runtime layout closure guard failed: unterminated template string.' }
      [void]$result.Append('`')
      $index = $templateIndex
      continue
    }

    [void]$result.Append($current)
  }
  return $result.ToString()
}

function Get-BracedSection([string]$Text, [int]$OpenBraceIndex) {
  $depth = 0
  for ($index = $OpenBraceIndex; $index -lt $Text.Length; $index++) {
    if ($Text[$index] -eq '{') { $depth++ }
    elseif ($Text[$index] -eq '}') {
      $depth--
      if ($depth -eq 0) {
        return $Text.Substring($OpenBraceIndex + 1, $index - $OpenBraceIndex - 1)
      }
    }
  }
  throw 'Runtime layout closure guard failed: method has no matching closing brace.'
}

if ([string]::IsNullOrWhiteSpace($SourceRoot)) { $SourceRoot = Split-Path -Parent $PSScriptRoot }
$SourceRoot = [IO.Path]::GetFullPath($SourceRoot)
$pagePath = Join-Path $SourceRoot 'entry\src\main\ets\pages\FeatureRuntimePage.ets'
$buildScriptPath = Join-Path $SourceRoot 'scripts\build-hap.ps1'
$page = ConvertTo-ArkTsStructuralText (Get-NormalizedText $pagePath)

$structMatches = [regex]::Matches(
  $page,
  '(?m)^[\t ]*(?:export[\t ]+)?struct[\t ]+FeatureRuntimePage[\t ]*\{[\t ]*$'
)
if ($structMatches.Count -ne 1) {
  throw "Runtime layout closure guard failed: expected one real FeatureRuntimePage struct, found $($structMatches.Count)."
}
$structOpenBrace = $page.IndexOf('{', $structMatches[0].Index, [StringComparison]::Ordinal)
$featureRuntimePageBody = Get-BracedSection $page $structOpenBrace

$contentMatches = [regex]::Matches(
  $featureRuntimePageBody,
  '(?m)^[\t ]*runtimeLayoutContent\(\)[\t ]*\{[\t ]*$'
)
if ($contentMatches.Count -ne 1) {
  throw "Runtime layout closure guard failed: expected one real runtimeLayoutContent() method, found $($contentMatches.Count)."
}
$openBrace = $featureRuntimePageBody.IndexOf('{', $contentMatches[0].Index, [StringComparison]::Ordinal)
$contentBody = Get-BracedSection $featureRuntimePageBody $openBrace
$actualLines = @($contentBody.Split("`n") | ForEach-Object { $_.Trim() } | Where-Object { $_.Length -gt 0 })

$rawExpectedLines = @(
  'if (usesAndroidTextTranslationLayout(workflowForRoute(this.routeName))) {',
  'this.textTranslationAndroidLayout()',
  '} else if (usesAndroidTextRecognitionLayout(workflowForRoute(this.routeName))) {',
  'this.textRecognitionAndroidLayout()',
  '} else if (usesAndroidPoseNetStillLayout(workflowForRoute(this.routeName))) {',
  'this.poseNetStillAndroidLayout()',
  '} else if (usesAndroidGestureStillLayout(workflowForRoute(this.routeName))) {',
  'this.gestureStillAndroidLayout()',
  '} else if (usesAndroidObjectPhotoLayout(workflowForRoute(this.routeName))) {',
  'this.objectPhotoAndroidLayout()',
  '} else if (usesAndroidStyleTransferLayout(workflowForRoute(this.routeName))) {',
  'this.styleTransferAndroidLayout()',
  '} else if (usesAndroidCustomModelLayout(workflowForRoute(this.routeName))) {',
  'this.customModelAndroidLayout()',
  '} else if (usesAndroidStillSegmentationLayout(workflowForRoute(this.routeName))) {',
  'this.stillSegmentationAndroidLayout()',
  '} else if (usesAndroidStillSceneLayout(workflowForRoute(this.routeName))) {',
  'this.stillSceneAndroidLayout()',
  '} else if (usesAndroidPortraitSegmentationLayout(workflowForRoute(this.routeName))) {',
  'this.portraitSegmentationAndroidLayout()',
  '} else if (specializedAndroidLiveLayoutForWorkflow(workflowForRoute(this.routeName)) === ''segmentation'') {',
  'this.segmentationAndroidLiveLayout()',
  '} else if (specializedAndroidLiveLayoutForWorkflow(workflowForRoute(this.routeName)) === ''gesture'') {',
  'this.gestureAndroidLiveLayout()',
  '} else if (specializedAndroidLiveLayoutForWorkflow(workflowForRoute(this.routeName)) === ''scene'') {',
  'this.sceneAndroidLiveLayout()',
  '} else if (specializedAndroidLiveLayoutForWorkflow(workflowForRoute(this.routeName)) === ''skeleton'') {',
  'this.skeletonAndroidLiveLayout()',
  '} else if (specializedAndroidLiveLayoutForWorkflow(workflowForRoute(this.routeName)) === ''imageClassification'') {',
  'this.imageClassificationAndroidLiveLayout()',
  '} else if (specializedAndroidLiveLayoutForWorkflow(workflowForRoute(this.routeName)) === ''objectDetection'') {',
  'this.objectDetectionAndroidLiveLayout()',
  '} else if (usesSimpleAndroidLiveLayout(workflowForRoute(this.routeName))) {',
  'this.simpleAndroidLiveLayout()',
  '} else {'
)
$expectedLines = @($rawExpectedLines | ForEach-Object { (ConvertTo-ArkTsStructuralText $_).Trim() })
if ($actualLines.Count -lt $expectedLines.Count) {
  throw 'Runtime layout closure guard failed: runtimeLayoutContent() ends before the complete selector chain.'
}
for ($index = 0; $index -lt $expectedLines.Count; $index++) {
  if ($actualLines[$index] -cne $expectedLines[$index]) {
    throw "Runtime layout closure guard failed: runtimeLayoutContent() line $($index + 1) must be '$($rawExpectedLines[$index])'."
  }
}
for ($index = 0; $index -lt $expectedLines.Count - 1; $index++) {
  $count = @($actualLines | Where-Object { $_ -ceq $expectedLines[$index] }).Count
  if ($count -ne 1) {
    throw "Runtime layout closure guard failed: selector/builder line must occur exactly once: $($rawExpectedLines[$index])"
  }
}

$buildMatches = [regex]::Matches($featureRuntimePageBody, '(?m)^[\t ]*build\(\)[\t ]*\{[\t ]*$')
if ($buildMatches.Count -ne 1) {
  throw "Runtime layout closure guard failed: expected one real FeatureRuntimePage.build() method, found $($buildMatches.Count)."
}
$buildOpenBrace = $featureRuntimePageBody.IndexOf('{', $buildMatches[0].Index, [StringComparison]::Ordinal)
$buildBody = Get-BracedSection $featureRuntimePageBody $buildOpenBrace
$buildLines = @($buildBody.Split("`n") | ForEach-Object { $_.Trim() } | Where-Object { $_.Length -gt 0 })
$expectedBuildLines = @(
  'Stack({ alignContent: Alignment.TopStart }) {',
  'this.runtimeLayoutContent()',
  'this.runtimePermissionRecoveryOverlay()',
  '}',
  '.width(''100%'')',
  '.height(''100%'')',
  '.key(this.routeName)'
)
if ($buildLines.Count -ne $expectedBuildLines.Count) {
  throw 'Runtime layout closure guard failed: build() must contain only the shared runtime content/overlay stack.'
}
for ($index = 0; $index -lt $expectedBuildLines.Count; $index++) {
  $expected = (ConvertTo-ArkTsStructuralText $expectedBuildLines[$index]).Trim()
  if ($buildLines[$index] -cne $expected) {
    throw "Runtime layout closure guard failed: build() line $($index + 1) must be '$($expectedBuildLines[$index])'."
  }
}

$tokens = $null
$parseErrors = $null
$ast = [Management.Automation.Language.Parser]::ParseFile($buildScriptPath, [ref]$tokens, [ref]$parseErrors)
if ($parseErrors.Count -ne 0) {
  throw 'Runtime layout closure guard failed: build-hap.ps1 must parse cleanly.'
}
$requiredCalls = @(
  "& (Join-Path `$PSScriptRoot 'test-runtime-layout-closure-guard.ps1')",
  "& (Join-Path `$PSScriptRoot 'check-runtime-layout-closure.ps1')"
)
$callOffsets = @()
foreach ($call in $requiredCalls) {
  $matches = @($ast.EndBlock.Statements | Where-Object {
      $_.Extent.Text.Replace("`r`n", "`n").Trim() -ceq $call
    })
  if ($matches.Count -ne 1) {
    throw "Runtime layout closure guard failed: build-hap must execute one top-level call: $call"
  }
  $callOffsets += $matches[0].Extent.StartOffset
}
if ($callOffsets[0] -ge $callOffsets[1]) {
  throw 'Runtime layout closure guard failed: mutation suite must run before the production guard.'
}
$hvigorStatements = @($ast.EndBlock.Statements | Where-Object {
    $_.Extent.Text -match '(?m)^\s*\$hvigor\s*='
  })
if ($hvigorStatements.Count -ne 1 -or $callOffsets[1] -ge $hvigorStatements[0].Extent.StartOffset) {
  throw 'Runtime layout closure guard failed: layout checks must run before Hvigor assembly.'
}

Write-Output 'Runtime layout closure guard passed.'
