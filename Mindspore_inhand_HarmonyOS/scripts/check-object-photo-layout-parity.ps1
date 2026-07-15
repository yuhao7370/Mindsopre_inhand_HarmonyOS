param(
  [string]$SourceRoot = ''
)

$ErrorActionPreference = 'Stop'

function Get-NormalizedText([string]$Path) {
  return (Get-Content -Raw -Encoding UTF8 -LiteralPath $Path).Replace("`r`n", "`n").Replace("`r", "`n")
}

function Remove-ArkTsCommentsAndTemplateRaw([string]$Text) {
  $result = [Text.StringBuilder]::new($Text.Length)
  $state = 'code'
  $terminator = [char]0
  $escaped = $false
  $interpolationDepths = [Collections.Generic.List[int]]::new()
  for ($index = 0; $index -lt $Text.Length; $index++) {
    $current = $Text[$index]
    $next = if ($index + 1 -lt $Text.Length) { $Text[$index + 1] } else { [char]0 }
    if ($state -eq 'lineComment') {
      if ($current -eq [char]0x0A) {
        [void]$result.Append($current)
        $state = 'code'
      } else {
        [void]$result.Append(' ')
      }
      continue
    }
    if ($state -eq 'blockComment') {
      if ($current -eq [char]0x2A -and $next -eq [char]0x2F) {
        [void]$result.Append('  ')
        $index++
        $state = 'code'
      } elseif ($current -eq [char]0x0A) {
        [void]$result.Append($current)
      } else {
        [void]$result.Append(' ')
      }
      continue
    }
    if ($state -eq 'quotedLiteral') {
      [void]$result.Append($current)
      if ($escaped) {
        $escaped = $false
      } elseif ($current -eq [char]0x5C) {
        $escaped = $true
      } elseif ($current -eq $terminator) {
        $state = 'code'
      }
      continue
    }
    if ($state -eq 'templateRaw') {
      if ($escaped) {
        [void]$result.Append(' ')
        $escaped = $false
      } elseif ($current -eq [char]0x5C) {
        [void]$result.Append(' ')
        $escaped = $true
      } elseif ($current -eq [char]0x0A) {
        [void]$result.Append($current)
      } elseif ($current -eq [char]0x60) {
        [void]$result.Append($current)
        $state = 'code'
      } elseif ($current -eq [char]0x24 -and $next -eq [char]0x7B) {
        [void]$result.Append('${')
        $index++
        $interpolationDepths.Add(1)
        $state = 'code'
      } else {
        [void]$result.Append(' ')
      }
      continue
    }
    if ($current -eq [char]0x2F -and $next -eq [char]0x2F) {
      [void]$result.Append('  ')
      $index++
      $state = 'lineComment'
    } elseif ($current -eq [char]0x2F -and $next -eq [char]0x2A) {
      [void]$result.Append('  ')
      $index++
      $state = 'blockComment'
    } elseif ($current -eq [char]0x27 -or $current -eq [char]0x22) {
      [void]$result.Append($current)
      $terminator = $current
      $escaped = $false
      $state = 'quotedLiteral'
    } elseif ($current -eq [char]0x60) {
      [void]$result.Append($current)
      $escaped = $false
      $state = 'templateRaw'
    } elseif ($interpolationDepths.Count -gt 0 -and $current -eq [char]0x7B) {
      $last = $interpolationDepths.Count - 1
      $interpolationDepths[$last]++
      [void]$result.Append($current)
    } elseif ($interpolationDepths.Count -gt 0 -and $current -eq [char]0x7D) {
      $last = $interpolationDepths.Count - 1
      $interpolationDepths[$last]--
      [void]$result.Append($current)
      if ($interpolationDepths[$last] -eq 0) {
        $interpolationDepths.RemoveAt($last)
        $state = 'templateRaw'
      }
    } else {
      [void]$result.Append($current)
    }
  }
  return $result.ToString()
}

function Get-TextSection(
  [string]$Text,
  [string]$StartMarker,
  [string]$EndMarker,
  [string]$Description
) {
  $start = $Text.IndexOf($StartMarker, [StringComparison]::Ordinal)
  $end = $Text.IndexOf($EndMarker, $start + $StartMarker.Length, [StringComparison]::Ordinal)
  if ($start -lt 0 -or $end -le $start) {
    throw "Object Photo parity guard failed: $Description was not found."
  }
  return $Text.Substring($start, $end - $start)
}

function Test-CodeLine([string]$Text, [string]$Line) {
  return [regex]::IsMatch($Text, "(?m)^[\t ]*$([regex]::Escape($Line))[\t ]*$")
}

function Assert-CodeLine([string]$Text, [string]$Line, [string]$Message) {
  if (-not (Test-CodeLine $Text $Line)) {
    throw "Object Photo parity guard failed: $Message"
  }
}

function Assert-Contains([string]$Text, [string]$Marker, [string]$Message) {
  if (-not $Text.Contains($Marker)) {
    throw "Object Photo parity guard failed: $Message"
  }
}

function Assert-Excludes([string]$Text, [string]$Marker, [string]$Message) {
  if ($Text.Contains($Marker)) {
    throw "Object Photo parity guard failed: $Message ($Marker)."
  }
}

function Assert-Count([string]$Text, [string]$Marker, [int]$Expected, [string]$Message) {
  $actual = ($Text.Length - $Text.Replace($Marker, '').Length) / $Marker.Length
  if ($actual -ne $Expected) {
    throw "Object Photo parity guard failed: $Message Expected $Expected, found $actual."
  }
}

$stripperProbe = @'
// this.runtimeActionToolbar(true)
const quoted = 'this.runtimeActionToolbar(true)';
const template = `this.runtimeActionToolbar(true) ${/* INTERPOLATION_COMMENT */ executableCall()}`;
/* BLOCK_COMMENT */
executableCall()
'@
$strippedProbe = Remove-ArkTsCommentsAndTemplateRaw $stripperProbe
if (Test-CodeLine $strippedProbe 'this.runtimeActionToolbar(true)') {
  throw 'Object Photo parity guard failed: comments, strings, and template raw text must not spoof code-line checks.'
}
Assert-CodeLine $strippedProbe 'executableCall()' 'comment/template stripper must preserve executable lines.'
Assert-Contains $strippedProbe '${' 'template interpolation boundary must remain executable.'
Assert-Count $strippedProbe 'executableCall()' 2 'template interpolation code must remain executable.'
Assert-Excludes $strippedProbe 'INTERPOLATION_COMMENT' 'comments inside template interpolation must be removed'
Assert-Excludes $strippedProbe 'BLOCK_COMMENT' 'block comments must be removed'

if ([string]::IsNullOrWhiteSpace($SourceRoot)) {
  $SourceRoot = Split-Path -Parent $PSScriptRoot
}
$SourceRoot = [IO.Path]::GetFullPath($SourceRoot)
$catalogPath = Join-Path $SourceRoot 'entry\src\main\ets\features\runtime\FeatureWorkflowCatalog.ets'
$pagePath = Join-Path $SourceRoot 'entry\src\main\ets\pages\FeatureRuntimePage.ets'
$buildScriptPath = Join-Path $SourceRoot 'scripts\build-hap.ps1'

$catalog = Remove-ArkTsCommentsAndTemplateRaw (Get-NormalizedText $catalogPath)
$selector = Get-TextSection `
  $catalog `
  'export function usesAndroidObjectPhotoLayout' `
  'export function objectPhotoResultToastKey' `
  'Object Photo selector'
Assert-CodeLine $selector 'return workflow?.routeName === AppRoute.OBJECT_PHOTO.name;' 'selector must target only Object Photo.'
Assert-Count $selector 'AppRoute.' 1 'selector must contain exactly one route target.'

$page = Remove-ArkTsCommentsAndTemplateRaw (Get-NormalizedText $pagePath)
$builder = Get-TextSection `
  $page `
  '  objectPhotoAndroidLayout() {' `
  "`n`n  @Builder`n  customModelAndroidLayout()" `
  'dedicated Object Photo builder'

foreach ($line in @(
  'this.runtimeActionToolbar(true)',
  'Stack({ alignContent: Alignment.Center }) {',
  'if (this.objectDetectionImageUri.length > 0 && this.objectDetections.length > 0) {',
  'Image(this.objectDetectionImageUri)',
  '.orientation(this.objectDetectionImageOrientation)',
  '.aspectRatio(this.objectDetectionAspectRatio())',
  'this.objectDetectionBox(detection, index)',
  '} else if (this.imageInputUri.length > 0) {',
  'Image(this.imageInputUri)',
  '.objectFit(ImageFit.Contain)',
  "Button(appString(workflowInputLabelKey(workflowForRoute(this.routeName), 'modelFile')), { type: ButtonType.Normal })",
  '.fontSize(16)',
  '.fontColor(Color.White)',
  ".backgroundColor('#33B5E5')",
  '.enabled(!this.workflowRunning)',
  ".onClick(() => this.prepareInput('modelFile'))",
  '.padding({ right: 16, bottom: 16 })',
  '.justifyContent(FlexAlign.End)',
  '.alignItems(HorizontalAlign.End)',
  'this.runtimePermissionRecoveryOverlay()'
)) {
  Assert-CodeLine $builder $line "dedicated builder is missing executable line: $line."
}

$toolbarIndex = $builder.IndexOf('this.runtimeActionToolbar(true)', [StringComparison]::Ordinal)
$previewIndex = $builder.IndexOf('Image(this.objectDetectionImageUri)', [StringComparison]::Ordinal)
$buttonIndex = $builder.IndexOf("Button(appString(workflowInputLabelKey(workflowForRoute(this.routeName), 'modelFile'))", [StringComparison]::Ordinal)
if ($toolbarIndex -lt 0 -or $previewIndex -le $toolbarIndex -or $buttonIndex -le $previewIndex) {
  throw 'Object Photo parity guard failed: content order must be toolbar, centered preview, Select Model.'
}

foreach ($marker in @(
  'this.summaryKey',
  'feature_runtime_inputs_title',
  'feature_runtime_permissions_title',
  'workflowResultTitleKey(',
  'this.resultRow(',
  'this.statusKey',
  'this.resultText',
  'feature_runtime_debug',
  'resultImageSaveControl(',
  'resultComponentImageSaveControl(',
  'shouldShowPrimaryRunAction(',
  'this.runPrimaryAction()'
)) {
  Assert-Excludes $builder $marker 'dedicated builder contains generic card/result/debug/save/Run UI'
}
Assert-Count $builder 'this.runtimeActionToolbar(true)' 1 'dedicated builder must contain one Android toolbar.'
Assert-Count $builder ".onClick(() => this.prepareInput('modelFile'))" 1 'dedicated builder must contain one Select Model action.'
Assert-Contains $builder ".width('100%')`n    .height('100%')`n    .backgroundColor(Color.White)" 'dedicated page must fill the screen with a white surface.'

$aiResult = Get-TextSection `
  $page `
  '  private applyAiResult(result: AiRunResult, runtimeRequestId: number): void {' `
  "`n`n  private showObjectPhotoFailureToastIfNeeded" `
  'AI result Object Photo Toast call site'
Assert-CodeLine $aiResult 'this.showObjectPhotoFailureToastIfNeeded(result.ok);' 'failed AI results must reach the Object Photo Toast policy.'

$toastHelper = Get-TextSection `
  $page `
  '  private showObjectPhotoFailureToastIfNeeded' `
  "`n`n  private showGestureStillFailureToastIfNeeded" `
  'Object Photo failure Toast helper'
Assert-Contains $toastHelper 'objectPhotoResultToastKey(workflowForRoute(this.routeName), resultOk)' 'Toast helper must use the route-scoped policy.'
Assert-CodeLine $toastHelper 'this.showRuntimeToast(toastKey);' 'mapped Object Photo failure must use the existing Toast path.'

$cacheCaller = Get-TextSection `
  $page `
  '  private async cacheAndApplyPickedModelFile(' `
  "`n`n  private applyModelFileCacheResult" `
  'model cache caller'
$currentIndex = $cacheCaller.IndexOf('if (!isInputPreparationRequestCurrent(requestId, this.inputPreparationRequestId))', [StringComparison]::Ordinal)
$staleIndex = $cacheCaller.IndexOf('if (cacheResult === undefined) {', $currentIndex, [StringComparison]::Ordinal)
$applyIndex = $cacheCaller.IndexOf('this.applyModelFileCacheResult(cacheResult, inputKind);', $staleIndex, [StringComparison]::Ordinal)
if ($currentIndex -lt 0 -or $staleIndex -le $currentIndex -or $applyIndex -le $staleIndex) {
  throw 'Object Photo parity guard failed: stale model-cache work must be rejected before applying success.'
}

$cacheResult = Get-TextSection `
  $page `
  '  private applyModelFileCacheResult(' `
  "`n`n  private showCustomModelCacheToastIfNeeded" `
  'model cache success handler'
$failureReturnIndex = $cacheResult.IndexOf("      return;`n    }", [StringComparison]::Ordinal)
$applyPickIndex = $cacheResult.IndexOf('this.applyPickResult({', $failureReturnIndex, [StringComparison]::Ordinal)
$followupIndex = $cacheResult.IndexOf('objectPhotoFollowupInputKindAfterModelCacheSuccess(workflow, inputKind)', $applyPickIndex, [StringComparison]::Ordinal)
$initialPickIndex = $cacheResult.IndexOf('this.prepareInput(followupInputKind, true);', $followupIndex, [StringComparison]::Ordinal)
if ($failureReturnIndex -lt 0 -or $applyPickIndex -le $failureReturnIndex -or
  $followupIndex -le $applyPickIndex -or $initialPickIndex -le $followupIndex) {
  throw 'Object Photo parity guard failed: only successful cached models may open the follow-up initial photo picker.'
}

$build = $page.Substring($page.IndexOf("`n  build() {", [StringComparison]::Ordinal))
$selectorIndex = $build.IndexOf('usesAndroidObjectPhotoLayout(workflowForRoute(this.routeName))', [StringComparison]::Ordinal)
$genericIndex = $build.IndexOf("    } else {`n      Scroll() {", [StringComparison]::Ordinal)
if ($selectorIndex -lt 0 -or $genericIndex -lt 0 -or $selectorIndex -ge $genericIndex) {
  throw 'Object Photo parity guard failed: dedicated selector must precede the generic fallback.'
}
Assert-Count $build 'usesAndroidObjectPhotoLayout(workflowForRoute(this.routeName))' 1 'build must select Object Photo exactly once.'

$buildScript = Get-NormalizedText $buildScriptPath
$guardCall = "& (Join-Path `$PSScriptRoot 'check-object-photo-layout-parity.ps1')"
Assert-Count $buildScript $guardCall 1 'build-hap must contain one Object Photo guard invocation.'
$tokens = $null
$parseErrors = $null
$buildAst = [Management.Automation.Language.Parser]::ParseFile($buildScriptPath, [ref]$tokens, [ref]$parseErrors)
if ($parseErrors.Count -ne 0) {
  throw 'Object Photo parity guard failed: build-hap.ps1 must parse cleanly.'
}
$topLevelGuardCalls = @($buildAst.EndBlock.Statements | Where-Object {
    $_.Extent.Text.Replace("`r`n", "`n").Trim() -eq $guardCall
  })
if ($topLevelGuardCalls.Count -ne 1) {
  throw "Object Photo parity guard failed: build-hap must execute exactly one top-level Object Photo guard; found $($topLevelGuardCalls.Count)."
}

Write-Output 'Object Photo layout parity guard passed.'
