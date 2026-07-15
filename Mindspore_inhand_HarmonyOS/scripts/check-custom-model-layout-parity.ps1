param(
  [string]$SourceRoot = ''
)

$ErrorActionPreference = 'Stop'

function Get-NormalizedText([string]$Path) {
  return (Get-Content -Raw -Encoding UTF8 -LiteralPath $Path).Replace("`r`n", "`n").Replace("`r", "`n")
}

function Remove-ArkTsComments([string]$Text) {
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
      [void]$result.Append($current)
      if ($escaped) {
        $escaped = $false
      } elseif ($current -eq [char]0x5C) {
        $escaped = $true
      } elseif ($current -eq [char]0x60) {
        $state = 'code'
      } elseif ($current -eq [char]0x24 -and $next -eq [char]0x7B) {
        [void]$result.Append($next)
        $index++
        $interpolationDepths.Add(1)
        $state = 'code'
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
    throw "Custom Model parity guard failed: $Description was not found."
  }
  return $Text.Substring($start, $end - $start)
}

function Assert-Contains([string]$Text, [string]$Marker, [string]$Message) {
  if (-not $Text.Contains($Marker)) {
    throw "Custom Model parity guard failed: $Message"
  }
}

function Assert-Excludes([string]$Text, [string]$Marker, [string]$Message) {
  if ($Text.Contains($Marker)) {
    throw "Custom Model parity guard failed: $Message ($Marker)."
  }
}

function Assert-Count([string]$Text, [string]$Marker, [int]$Expected, [string]$Message) {
  $actual = ($Text.Length - $Text.Replace($Marker, '').Length) / $Marker.Length
  if ($actual -ne $Expected) {
    throw "Custom Model parity guard failed: $Message Expected $Expected, found $actual."
  }
}

$commentStripperProbe = @'
const single = 'it\'s https://single.example/*STRING_RAW_MARKER*/'; /* SINGLE_COMMENT_MARKER */
const double = "say \"hello\" https://double.example/*DOUBLE_RAW_MARKER*/"; // DOUBLE_COMMENT_MARKER
const template = `raw \` tick https://template.example/*TEMPLATE_RAW_MARKER*/ ${/* INTERPOLATION_COMMENT_MARKER */ value}`;
const nested = `outer ${`inner /*NESTED_TEMPLATE_RAW_MARKER*/ ${/* NESTED_INTERPOLATION_COMMENT_MARKER */ value}`}`;
/* BLOCK_COMMENT_MARKER
   BLOCK_COMMENT_CONTINUATION */
const after = true;
'@
$strippedProbe = Remove-ArkTsComments $commentStripperProbe
foreach ($marker in @(
  'https://single.example/*STRING_RAW_MARKER*/',
  'https://double.example/*DOUBLE_RAW_MARKER*/',
  'https://template.example/*TEMPLATE_RAW_MARKER*/',
  '/*NESTED_TEMPLATE_RAW_MARKER*/',
  'const after = true;'
)) {
  Assert-Contains $strippedProbe $marker "comment stripper must preserve literal content: $marker."
}
foreach ($marker in @(
  'SINGLE_COMMENT_MARKER',
  'DOUBLE_COMMENT_MARKER',
  'INTERPOLATION_COMMENT_MARKER',
  'NESTED_INTERPOLATION_COMMENT_MARKER',
  'BLOCK_COMMENT_MARKER',
  'BLOCK_COMMENT_CONTINUATION'
)) {
  Assert-Excludes $strippedProbe $marker 'comment stripper must remove executable-code comments'
}
$probeNewlines = $commentStripperProbe.Length - $commentStripperProbe.Replace("`n", '').Length
$strippedProbeNewlines = $strippedProbe.Length - $strippedProbe.Replace("`n", '').Length
if ($probeNewlines -ne $strippedProbeNewlines) {
  throw 'Custom Model parity guard failed: comment stripper must preserve source newlines.'
}

if ([string]::IsNullOrWhiteSpace($SourceRoot)) {
  $SourceRoot = Split-Path -Parent $PSScriptRoot
}
$SourceRoot = [IO.Path]::GetFullPath($SourceRoot)
$catalogPath = Join-Path $SourceRoot 'entry\src\main\ets\features\runtime\FeatureWorkflowCatalog.ets'
$pagePath = Join-Path $SourceRoot 'entry\src\main\ets\pages\FeatureRuntimePage.ets'
$buildScriptPath = Join-Path $SourceRoot 'scripts\build-hap.ps1'

$catalog = Remove-ArkTsComments (Get-NormalizedText $catalogPath)
$selector = Get-TextSection `
  $catalog `
  'export function usesAndroidCustomModelLayout' `
  'export function customModelExecutePreflightToastKey' `
  'Custom Model selector'
Assert-Contains $selector 'return workflow?.routeName === AppRoute.CUSTOM_MODEL.name;' 'selector must target only Custom Model.'
Assert-Count $selector 'AppRoute.' 1 'selector must contain exactly one route target.'

$page = Remove-ArkTsComments (Get-NormalizedText $pagePath)
$builder = Get-TextSection `
  $page `
  '  customModelAndroidLayout() {' `
  "`n`n  @Builder`n  poseNetStillPoseLine(line: PoseLine)" `
  'dedicated Custom Model builder'

foreach ($marker in @(
  'this.runtimeActionToolbar(true)',
  "Button(appString(workflowInputLabelKey(workflowForRoute(this.routeName), 'modelFile')), { type: ButtonType.Normal })",
  "Button(appString(workflowInputLabelKey(workflowForRoute(this.routeName), 'photo')), { type: ButtonType.Normal })",
  "Button(appString(workflowInputLabelKey(workflowForRoute(this.routeName), 'camera')), { type: ButtonType.Normal })",
  '.enabled(!this.workflowRunning)',
  'if (this.imageInputUri.length > 0) {',
  'Image(this.imageInputUri)',
  '.objectFit(ImageFit.Fill)',
  'if (this.workflowRunning) {',
  'LoadingProgress()',
  "Button(appString('feature_runtime_custom_model_execute'), { type: ButtonType.Normal })",
  '.onClick(() => this.runCustomModelAndroidAction())',
  "Text(appString('feature_runtime_custom_model_output_title'))",
  'Scroll() {',
  'Text(this.customModelOutputText())',
  'this.runtimePermissionRecoveryOverlay()'
)) {
  Assert-Contains $builder $marker "dedicated builder is missing $marker."
}

Assert-Count $builder '.height(1)' 1 'dedicated builder must keep exactly one divider.'
Assert-Count $builder ".backgroundColor('#E4E4E4')" 1 'dedicated builder must keep the Android divider color exactly once.'
Assert-Count $builder '.enabled(!this.workflowRunning)' 3 'only the three input buttons must be disabled while running.'
Assert-Count $builder '.layoutWeight(1)' 5 'three equal input buttons plus the output panel and its Scroll must use weight 1.'
Assert-Count $builder '.height(37)' 3 'all three input buttons must be 37vp.'

$modelIndex = $builder.IndexOf("this.prepareInput('modelFile')", [StringComparison]::Ordinal)
$photoIndex = $builder.IndexOf("this.prepareInput('photo')", [StringComparison]::Ordinal)
$cameraIndex = $builder.IndexOf("this.prepareInput('camera')", [StringComparison]::Ordinal)
$previewIndex = $builder.IndexOf('if (this.imageInputUri.length > 0) {', [StringComparison]::Ordinal)
$executeIndex = $builder.IndexOf("Button(appString('feature_runtime_custom_model_execute')", [StringComparison]::Ordinal)
$outputIndex = $builder.IndexOf("Text(appString('feature_runtime_custom_model_output_title'))", [StringComparison]::Ordinal)
if ($modelIndex -lt 0 -or $photoIndex -le $modelIndex -or $cameraIndex -le $photoIndex -or
  $previewIndex -le $cameraIndex -or $executeIndex -le $previewIndex -or $outputIndex -le $executeIndex) {
  throw 'Custom Model parity guard failed: content order must be Model, Photo, Camera, conditional preview, Execute, output.'
}

$inputRow = Get-TextSection `
  $builder `
  "        Row() {`n          Button(appString(workflowInputLabelKey(workflowForRoute(this.routeName), 'modelFile'))" `
  "        if (this.imageInputUri.length > 0) {" `
  'Custom Model input row'
foreach ($marker in @(
  '.margin({ left: 20, right: 5 })',
  '.margin({ left: 5, right: 5 })',
  '.margin({ left: 5, right: 20 })',
  '.fontSize(14)',
  ".fontColor('#666666')",
  ".backgroundColor('#F4F3F8')",
  '.borderRadius(5)',
  ".margin({ top: 14 })"
)) {
  Assert-Contains $inputRow $marker "input row is missing $marker."
}

$preview = Get-TextSection `
  $builder `
  '        if (this.imageInputUri.length > 0) {' `
  "        Button(appString('feature_runtime_custom_model_execute')" `
  'conditional image preview'
foreach ($marker in @(
  "Stack({ alignContent: Alignment.Center })",
  '.width(256)',
  '.height(256)',
  '.width(80)',
  '.height(80)',
  '.height(265)',
  ".backgroundColor('#E6E6E6')",
  '.margin({ top: 14 })'
)) {
  Assert-Contains $preview $marker "conditional preview is missing $marker."
}

$execute = Get-TextSection `
  $builder `
  "        Button(appString('feature_runtime_custom_model_execute')" `
  "        Column() {`n          Text(appString('feature_runtime_custom_model_output_title'))" `
  'Execute button'
foreach ($marker in @(
  '.width(''100%'')',
  '.height(40)',
  '.margin({ left: 20, right: 20, top: 14 })',
  '.fontSize(16)',
  '.fontColor(Color.Black)',
  '.backgroundColor(Color.White)',
  '.border({ width: 2, color: Color.White, radius: 30 })',
  '.onClick(() => this.runCustomModelAndroidAction())'
)) {
  Assert-Contains $execute $marker "Execute button is missing $marker."
}
Assert-Excludes $execute '.enabled(' 'Execute must remain clickable while a run is active'

$output = Get-TextSection `
  $builder `
  "        Column() {`n          Text(appString('feature_runtime_custom_model_output_title'))" `
  "      }`n      .width('100%')`n      .height('100%')" `
  'Custom Model output panel'
foreach ($marker in @(
  '.layoutWeight(1)',
  '.margin({ left: 20, right: 20, top: 14, bottom: 20 })',
  '.padding(16)',
  '.fontSize(16)',
  '.fontWeight(FontWeight.Bold)',
  '.fontColor(Color.Black)',
  '.margin({ top: 8 })',
  ".backgroundColor('#E6E6E6')",
  '.padding(12)',
  '.fontSize(14)',
  ".fontColor('#666666')"
)) {
  Assert-Contains $output $marker "output panel is missing $marker."
}

foreach ($marker in @(
  'this.summaryKey',
  'feature_runtime_inputs_title',
  'feature_runtime_permissions_title',
  'this.selectedInputSummary',
  'this.statusKey',
  'this.resultRows',
  'this.resultRow(',
  'this.modelInputUri',
  'this.modelFilePreview(',
  'resultImageSaveControl(',
  'resultComponentImageSaveControl(',
  'feature_runtime_debug'
)) {
  Assert-Excludes $builder $marker 'dedicated builder contains generic status/input/model/result/debug/save UI'
}

$restore = Get-TextSection $page '  private restoreCachedModelFileInputsIfNeeded(): void {' "`n`n  private applyCachedModelFileInputState" 'cache restore gate'
Assert-Contains $restore 'shouldRestoreCachedModelFileInputs(workflowForRoute(this.routeName))' 'cache restore must use the Task 1 route policy.'
$gateIndex = $restore.IndexOf('shouldRestoreCachedModelFileInputs', [StringComparison]::Ordinal)
$restoreCallIndex = $restore.IndexOf('cachedModelFileInputStateForRoute(', [StringComparison]::Ordinal)
if ($gateIndex -lt 0 -or $restoreCallIndex -le $gateIndex) {
  throw 'Custom Model parity guard failed: cache restore policy must run before reading the cache.'
}

$cacheCaller = Get-TextSection $page '  private async cacheAndApplyPickedModelFile(' "`n`n  private applyModelFileCacheResult" 'model cache caller'
$currentIndex = $cacheCaller.IndexOf('isInputPreparationRequestCurrent(requestId, this.inputPreparationRequestId)', [StringComparison]::Ordinal)
$applyCacheIndex = $cacheCaller.IndexOf('this.applyModelFileCacheResult(cacheResult, inputKind);', [StringComparison]::Ordinal)
if ($currentIndex -lt 0 -or $applyCacheIndex -le $currentIndex) {
  throw 'Custom Model parity guard failed: model cache feedback must remain behind the current-request check.'
}

$cacheResult = Get-TextSection $page '  private applyModelFileCacheResult(' "`n`n  private isLiveCameraInput" 'model cache result handler'
Assert-Count $cacheResult 'this.showCustomModelCacheToastIfNeeded(result.messageKey);' 2 'current model-cache success and failure must each show one mapped Toast.'
Assert-Contains $cacheResult 'shouldPreserveRuntimeResultAfterInputReady(workflow, inputKind)' 'model-cache failure must preserve Custom Model terminal output.'
$cacheToast = Get-TextSection $page '  private showCustomModelCacheToastIfNeeded(' "`n`n  private isLiveCameraInput" 'model cache Toast helper'
Assert-Contains $cacheToast 'customModelModelCacheToastKey(workflowForRoute(this.routeName), messageKey)' 'model cache Toast must use the route-scoped Task 1 mapping.'
Assert-Contains $cacheToast 'if (toastKey !== undefined) {' 'model cache Toast must ignore unrelated routes.'
Assert-Contains $cacheToast 'this.showRuntimeToast(toastKey)' 'mapped model-cache feedback must use the existing Toast path.'

$executeHandler = Get-TextSection $page '  private runCustomModelAndroidAction(): void {' "`n`n  private runWorkflow(): void" 'Custom Model Execute handler'
Assert-Contains $executeHandler 'customModelExecutePreflightToastKey(' 'Execute must use the pure preflight policy.'
Assert-Contains $executeHandler 'this.showRuntimeToast(toastKey);' 'preflight failures must show a Toast.'
Assert-Contains $executeHandler 'this.runWorkflow();' 'ready preflight must call the shared runtime.'
$preflightIndex = $executeHandler.IndexOf('customModelExecutePreflightToastKey(', [StringComparison]::Ordinal)
$runIndex = $executeHandler.IndexOf('this.runWorkflow();', [StringComparison]::Ordinal)
if ($preflightIndex -lt 0 -or $runIndex -le $preflightIndex) {
  throw 'Custom Model parity guard failed: preflight must occur before runWorkflow.'
}

$runAsync = Get-TextSection $page '  private async runWorkflowAsync(' "`n`n  private applyRuntimeFailure(): void" 'shared workflow execution'
Assert-Count $runAsync 'usesAndroidCustomModelLayout(workflow)' 2 'both missing-context and denied-request Custom Model permission paths must clear persistent output.'
Assert-Contains $runAsync 'usesAndroidCustomModelLayout(workflow) ?' 'Custom Model permission denial must be route scoped.'
Assert-Contains $runAsync "'' : permission.requested.join(', ')" 'Custom Model permission denial must not persist requested permission names.'

$runtimeFailure = Get-TextSection $page '  private applyRuntimeFailure(): void {' "`n`n  private async prepareLiveFrameImageInput" 'runtime failure handling'
Assert-Contains $runtimeFailure "this.customModelTerminalFailureText()" 'runtime exceptions must store the localized terminal failure output.'

$aiResult = Get-TextSection $page '  private applyAiResult(result: AiRunResult, runtimeRequestId: number): void {' "`n`n  private showGestureStillFailureToastIfNeeded" 'AI result handling'
Assert-Contains $aiResult 'result.ok ? result.detailText : this.customModelTerminalFailureText()' 'failed Custom Model results must store the localized terminal failure output.'

$outputResolver = Get-TextSection $page '  private customModelOutputText(): ResourceStr {' "`n`n  private runCustomModelAndroidAction(): void" 'output resolver'
Assert-Contains $outputResolver 'customModelOutputFallbackKey(' 'visible output must use the Task 1 priority policy.'
Assert-Contains $outputResolver 'return fallbackKey === undefined ? this.resultText : appString(fallbackKey);' 'terminal output must render directly only when no fallback key applies.'

$build = $page.Substring($page.IndexOf("`n  build() {", [StringComparison]::Ordinal))
$selectorIndex = $build.IndexOf('usesAndroidCustomModelLayout(workflowForRoute(this.routeName))', [StringComparison]::Ordinal)
$genericIndex = $build.IndexOf("    } else {`n      Scroll() {", [StringComparison]::Ordinal)
if ($selectorIndex -lt 0 -or $genericIndex -lt 0 -or $selectorIndex -ge $genericIndex) {
  throw 'Custom Model parity guard failed: dedicated selector must precede the generic fallback.'
}
Assert-Count $build 'usesAndroidCustomModelLayout(workflowForRoute(this.routeName))' 1 'build must select the dedicated route exactly once.'

$buildScript = Get-NormalizedText $buildScriptPath
$guardCall = "& (Join-Path `$PSScriptRoot 'check-custom-model-layout-parity.ps1')"
Assert-Count $buildScript $guardCall 1 'build-hap must contain one Custom Model guard invocation.'
$tokens = $null
$parseErrors = $null
$buildAst = [Management.Automation.Language.Parser]::ParseFile($buildScriptPath, [ref]$tokens, [ref]$parseErrors)
if ($parseErrors.Count -ne 0) {
  throw 'Custom Model parity guard failed: build-hap.ps1 must parse cleanly.'
}
$topLevelGuardCalls = @($buildAst.EndBlock.Statements | Where-Object {
    $_.Extent.Text.Replace("`r`n", "`n").Trim() -eq $guardCall
  })
if ($topLevelGuardCalls.Count -ne 1) {
  throw "Custom Model parity guard failed: build-hap must execute exactly one top-level Custom Model guard; found $($topLevelGuardCalls.Count)."
}

Write-Output 'Custom Model layout parity guard passed.'
