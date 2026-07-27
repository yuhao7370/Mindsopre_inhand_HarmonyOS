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

function Assert-CodeCount([string]$Text, [string]$Marker, [int]$Expected, [string]$Message) {
  $actual = [regex]::Matches($Text, '(?m)^\s*' + [regex]::Escape($Marker)).Count
  if ($actual -ne $Expected) {
    throw "Custom Model parity guard failed: $Message Expected $Expected, found $actual."
  }
}

function Assert-CodeContains([string]$Text, [string]$Marker, [string]$Message) {
  if (-not [regex]::IsMatch($Text, '(?m)^\s*' + [regex]::Escape($Marker))) {
    throw "Custom Model parity guard failed: $Message"
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
$featureCatalogPath = Join-Path $SourceRoot 'entry\src\main\ets\common\data\FeatureCatalog.ets'
$pagePath = Join-Path $SourceRoot 'entry\src\main\ets\pages\FeatureRuntimePage.ets'
$cacheServicePath = Join-Path $SourceRoot 'entry\src\main\ets\services\picker\ModelFileCacheService.ets'
$buildScriptPath = Join-Path $SourceRoot 'scripts\build-hap.ps1'

$catalog = Remove-ArkTsComments (Get-NormalizedText $catalogPath)
$selector = Get-TextSection `
  $catalog `
  'export function usesAndroidCustomModelLayout' `
  'export function customModelExecutePreflightToastKey' `
  'Custom Model selector'
Assert-Contains $selector 'return workflow?.routeName === AppRoute.CUSTOM_MODEL.name;' 'selector must target only Custom Model.'
Assert-Count $selector 'AppRoute.' 1 'selector must contain exactly one route target.'

$featureCatalog = Remove-ArkTsComments (Get-NormalizedText $featureCatalogPath)
Assert-Contains $featureCatalog `
  "{ id: 'custom', title: 'Custom Model', titleKey: 'title_custom_model', icon: 'model', routeName: AppRoute.CUSTOM_MODEL.name, visibleByDefault: false }" `
  'Custom Model must remain hidden from the public catalog.'
Assert-Excludes $featureCatalog `
  "routeName: AppRoute.CUSTOM_MODEL.name, visibleByDefault: true" `
  'Custom Model must not be re-exposed by default'
Assert-Count $featureCatalog 'AppRoute.CUSTOM_MODEL.name' 1 `
  'Custom Model must have exactly one hidden catalog declaration.'

$page = Remove-ArkTsComments (Get-NormalizedText $pagePath)
$builder = Get-TextSection `
  $page `
  '  customModelAndroidLayout() {' `
  "`n`n  @Builder`n  poseNetStillPoseLine(line: PoseLine)" `
  'dedicated Custom Model builder'

foreach ($marker in @(
  'this.runtimeActionToolbar(true)',
  'Scroll() {',
  "Button(appString(workflowInputLabelKey(workflowForRoute(this.routeName), 'modelFile')), { type: ButtonType.Normal })",
  ".onClick(() => this.prepareInput('modelFile'))",
  "Button(appString(workflowInputLabelKey(workflowForRoute(this.routeName), 'photo')), { type: ButtonType.Normal })",
  ".onClick(() => this.prepareInput('photo'))",
  "Button(appString(workflowInputLabelKey(workflowForRoute(this.routeName), 'camera')), { type: ButtonType.Normal })",
  ".onClick(() => this.prepareInput('camera'))",
  '.enabled(!this.workflowRunning)',
  "if (this.imageInputUri.length > 0) {",
  'Image(this.imageInputUri)',
  "Image(`$r('app.media.feature_custom_model'))",
  '.aspectRatio(4 / 3)',
  '.constraintSize({ minHeight: 220, maxHeight: 420 })',
  '.objectFit(ImageFit.Contain)',
  "Button(appString(this.statusKey === 'feature_runtime_custom_model_failed' ||",
  "this.statusKey === 'feature_runtime_run_failed' ? 'web_retry' :",
  "'feature_runtime_custom_model_execute'), { type: ButtonType.Normal })",
  '.onClick(() => this.runCustomModelAndroidAction())',
  'Text(appString(this.statusKey))',
  'if (this.workflowRunning) {',
  'LoadingProgress()',
  "Text(appString('feature_runtime_custom_model_output_title'))",
  'Text(this.customModelOutputText())'
)) {
  Assert-CodeContains $builder $marker "dedicated builder is missing $marker."
}

Assert-Excludes $builder '`' 'dedicated builder must not contain template-literal marker decoys'
Assert-CodeCount $builder 'Scroll() {' 1 'dedicated builder must use one page-level Scroll.'
Assert-CodeCount $builder '.constraintSize({ minHeight: 48 })' 5 `
  'model, photo, camera, run, and status controls must keep 48vp targets.'
Assert-CodeCount $builder '.enabled(!this.workflowRunning)' 4 `
  'all four actions must be disabled while running.'
Assert-CodeCount $builder 'LoadingProgress()' 1 'running state must use one compact status spinner.'
Assert-CodeCount $builder '.width(20)' 1 'running status spinner must remain compact.'
Assert-CodeCount $builder '.height(20)' 1 'running status spinner must remain compact.'
Assert-CodeCount $builder '.layoutWeight(1)' 2 `
  'only the status text and page-level Scroll may consume remaining space.'

$modelIndex = $builder.IndexOf("this.prepareInput('modelFile')", [StringComparison]::Ordinal)
$photoIndex = $builder.IndexOf("this.prepareInput('photo')", [StringComparison]::Ordinal)
$cameraIndex = $builder.IndexOf("this.prepareInput('camera')", [StringComparison]::Ordinal)
$previewIndex = $builder.IndexOf('if (this.imageInputUri.length > 0) {', [StringComparison]::Ordinal)
$executeIndex = $builder.IndexOf(
  "Button(appString(this.statusKey === 'feature_runtime_custom_model_failed' ||",
  [StringComparison]::Ordinal
)
$outputIndex = $builder.IndexOf("Text(appString('feature_runtime_custom_model_output_title'))", [StringComparison]::Ordinal)
if ($modelIndex -lt 0 -or $photoIndex -le $modelIndex -or $cameraIndex -le $photoIndex -or
  $previewIndex -le $cameraIndex -or $executeIndex -le $previewIndex -or $outputIndex -le $executeIndex) {
  throw 'Custom Model parity guard failed: content order must be Model, Photo, Camera, conditional preview, Execute, output.'
}

$preview = Get-TextSection `
  $builder `
  '          Stack({ alignContent: Alignment.Center }) {' `
  "          Button(appString(this.statusKey === 'feature_runtime_custom_model_failed' ||" `
  'responsive image preview'
foreach ($marker in @(
  "if (this.imageInputUri.length > 0) {",
  'Image(this.imageInputUri)',
  '.objectFit(ImageFit.Contain)',
  "Image(`$r('app.media.feature_custom_model'))",
  '.aspectRatio(4 / 3)',
  '.constraintSize({ minHeight: 220, maxHeight: 420 })',
  '.backgroundColor(AppColor.cardBackground)',
  '.border({ width: 1, color: AppColor.divider, radius: AppRadius.card })'
)) {
  Assert-CodeContains $preview $marker "responsive preview is missing $marker."
}

$execute = Get-TextSection `
  $builder `
  "          Button(appString(this.statusKey === 'feature_runtime_custom_model_failed' ||" `
  "          Row() {`n            if (this.workflowRunning) {" `
  'Execute button'
foreach ($marker in @(
  '.width(''100%'')',
  '.constraintSize({ minHeight: 48 })',
  '.fontSize(16)',
  '.maxFontScale(3.2)',
  '.fontColor(Color.White)',
  '.backgroundColor(AppColor.accent)',
  '.enabled(!this.workflowRunning)',
  '.onClick(() => this.runCustomModelAndroidAction())'
)) {
  Assert-CodeContains $execute $marker "Execute button is missing $marker."
}

$output = Get-TextSection `
  $builder `
  "          Column() {`n            Text(appString('feature_runtime_custom_model_output_title'))" `
  "        }`n        .width('100%')" `
  'Custom Model output panel'
foreach ($marker in @(
  "Text(appString('feature_runtime_custom_model_output_title'))",
  'Text(this.customModelOutputText())',
  '.fontWeight(FontWeight.Medium)',
  '.fontColor(AppColor.textPrimary)',
  '.fontColor(AppColor.textSecondary)',
  '.maxFontScale(3.2)',
  '.backgroundColor(AppColor.cardBackground)',
  '.border({ width: 1, color: AppColor.divider, radius: AppRadius.card })'
)) {
  Assert-CodeContains $output $marker "output panel is missing $marker."
}

foreach ($marker in @(
  '.height(37)',
  '.height(40)',
  '.height(265)',
  '.objectFit(ImageFit.Fill)',
  "backgroundColor('#E4E4E4')",
  "backgroundColor('#F4F3F8')",
  "fontColor('#666666')"
)) {
  Assert-Excludes $builder $marker 'dedicated builder contains legacy fixed or nested layout'
}

$preserveText = Get-TextSection $catalog 'export function shouldPreserveRuntimeTextResultOnAiResult' `
  'export function shouldPreserveRuntimeVisualResultOnAiResult' 'Custom Model failure result preservation'
Assert-Contains $preserveText 'hasTextResult: boolean = true' `
  'Custom Model failure preservation must distinguish first failure from an existing output.'
Assert-Contains $preserveText '(usesAndroidCustomModelLayout(workflow) && hasTextResult) ||' `
  'failed Custom Model runs must preserve only an existing valid output.'
$startClear = Get-TextSection $catalog 'export function shouldClearRuntimeResultAtWorkflowStart' `
  'export function shouldKeepScreenOnForWorkflow' 'Custom Model run-start preservation'
Assert-Contains $startClear '!usesAndroidCustomModelLayout(workflow) &&' `
  'Custom Model must retain its last output while a retry starts.'

$restore = Get-TextSection $page '  private restoreCachedModelFileInputsIfNeeded(): void {' "`n`n  private applyCachedModelFileInputState" 'cache restore gate'
Assert-Contains $restore 'shouldRestoreCachedModelFileInputs(workflowForRoute(this.routeName))' 'cache restore must use the Task 1 route policy.'
$gateIndex = $restore.IndexOf('shouldRestoreCachedModelFileInputs', [StringComparison]::Ordinal)
$restoreCallIndex = $restore.IndexOf('cachedModelFileInputStateForRoute(', [StringComparison]::Ordinal)
if ($gateIndex -lt 0 -or $restoreCallIndex -le $gateIndex) {
  throw 'Custom Model parity guard failed: cache restore policy must run before reading the cache.'
}

$cacheCaller = Get-TextSection $page '  private async cacheAndApplyPickedModelFile(' "`n`n  private applyModelFileCacheResult" 'model cache caller'
$cacheAwaitIndex = $cacheCaller.IndexOf('.cachePickedModelFile(', [StringComparison]::Ordinal)
$requestTokenIndex = $cacheCaller.IndexOf('        requestId,', $cacheAwaitIndex, [StringComparison]::Ordinal)
$predicateIndex = $cacheCaller.IndexOf('(): boolean => isInputPreparationRequestCurrent(requestId, this.inputPreparationRequestId)', $requestTokenIndex, [StringComparison]::Ordinal)
$currentIndex = $cacheCaller.IndexOf('if (!isInputPreparationRequestCurrent(requestId, this.inputPreparationRequestId))', $predicateIndex, [StringComparison]::Ordinal)
$staleIndex = $cacheCaller.IndexOf('if (cacheResult === undefined) {', $currentIndex, [StringComparison]::Ordinal)
$applyCacheIndex = $cacheCaller.IndexOf('this.applyModelFileCacheResult(cacheResult, inputKind);', [StringComparison]::Ordinal)
if ($cacheAwaitIndex -lt 0 -or $requestTokenIndex -le $cacheAwaitIndex -or $predicateIndex -le $requestTokenIndex -or
  $currentIndex -le $predicateIndex -or $staleIndex -le $currentIndex -or $applyCacheIndex -le $staleIndex) {
  throw 'Custom Model parity guard failed: cache publication must pass request token/predicate, then suppress stale UI before applying feedback.'
}
Assert-Contains $cacheCaller "if (cacheResult === undefined) {`n      return;`n    }" 'stale cache publication must return without status or Toast feedback.'

$cacheService = Remove-ArkTsComments (Get-NormalizedText $cacheServicePath)
$cacheMethod = Get-TextSection $cacheService '  cachePickedModelFile(' "`n`n  private async isCompatibleModelFile" 'model cache service method'
foreach ($marker in @(
  'requestToken: number',
  'isCurrent: () => boolean',
  'this.writer.writeModelFile(cacheDir, fileName, content, requestToken, isCurrent)',
  'if (uri === undefined) {',
  'return undefined;'
)) {
  Assert-Contains $cacheMethod $marker "model cache service is missing publication contract: $marker."
}
$writer = Get-TextSection $cacheService 'export class HarmonyModelFileCacheWriter' 'export class HarmonyCachedModelFileExistenceChecker' 'atomic model cache writer'
foreach ($marker in @(
  'const stablePath = modelFileCachePath(cacheDir, fileName);',
  'Date.now()',
  '++modelFileCacheTempSequence',
  '${requestToken}',
  'this.backend.open(',
  'tempPath,',
  'fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC',
  'await this.backend.close(file);',
  'if (!isCurrent()) {',
  'this.backend.replace(tempPath, stablePath);',
  'this.backend.remove(path);'
)) {
  Assert-Contains $writer $marker "atomic writer is missing $marker."
}
Assert-Count $writer 'fileIo.OpenMode.TRUNC' 1 'TRUNC must occur exactly once on the request-private temp open.'
Assert-Excludes $writer 'this.backend.open(stablePath' 'stable cache must never be opened or truncated for staging'
Assert-Count $writer 'this.removeTempFile(tempPath);' 2 'stale and catch paths must each clean only their request temp.'
$writerCurrentIndex = $writer.IndexOf('if (!isCurrent()) {', [StringComparison]::Ordinal)
$writerReplaceIndex = $writer.IndexOf('this.backend.replace(tempPath, stablePath);', $writerCurrentIndex, [StringComparison]::Ordinal)
if ($writerCurrentIndex -lt 0 -or $writerReplaceIndex -le $writerCurrentIndex) {
  throw 'Custom Model parity guard failed: current predicate must precede atomic replace.'
}
$publicationCriticalSection = $writer.Substring($writerCurrentIndex, $writerReplaceIndex - $writerCurrentIndex)
Assert-Excludes $publicationCriticalSection 'await ' 'no await is allowed between the current predicate and synchronous replace'
$backend = Get-TextSection $cacheService 'class HarmonyModelFileCacheFileBackend' 'let modelFileCacheTempSequence' 'Harmony cache file backend'
Assert-Contains $backend 'fileIo.moveFileSync(sourcePath, targetPath, 0);' 'production publication must synchronously overwrite the stable path.'
Assert-Contains $backend 'fileIo.unlinkSync(path);' 'temp cleanup must be synchronous.'

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

$aiResult = Get-TextSection $page '  private async applyAiResult(result: AiRunResult, runtimeRequestId: number): Promise<void> {' "`n`n  private showGestureStillFailureToastIfNeeded" 'AI result handling'
Assert-Contains $aiResult 'result.ok ? result.detailText : this.customModelTerminalFailureText()' 'failed Custom Model results must store the localized terminal failure output.'

$outputResolver = Get-TextSection $page '  private customModelOutputText(): ResourceStr {' "`n`n  private runCustomModelAndroidAction(): void" 'output resolver'
Assert-Contains $outputResolver 'customModelOutputFallbackKey(' 'visible output must use the Task 1 priority policy.'
Assert-Contains $outputResolver 'return fallbackKey === undefined ? this.resultText : appString(fallbackKey);' 'terminal output must render directly only when no fallback key applies.'

$build = $page.Substring($page.IndexOf(
    "`n  @Builder`n  runtimeLayoutContent() {",
    [StringComparison]::Ordinal
  ))
Assert-Excludes $build ([string][char]0x60) 'runtime selector region must not contain template literals.'
$selectorMatch = [regex]::Match(
  $build,
  '(?m)^\s*} else if \(usesAndroidCustomModelLayout\(workflowForRoute\(this\.routeName\)\)\) \{\s*\n\s*this\.customModelAndroidLayout\(\)\s*$'
)
$genericMatch = [regex]::Match($build, '(?m)^\s*} else \{\s*\n\s*Scroll\(\) \{')
$selectorIndex = if ($selectorMatch.Success) { $selectorMatch.Index } else { -1 }
$genericIndex = if ($genericMatch.Success) { $genericMatch.Index } else { -1 }
if ($selectorIndex -lt 0 -or $genericIndex -lt 0 -or $selectorIndex -ge $genericIndex) {
  throw 'Custom Model parity guard failed: dedicated selector must precede the generic fallback.'
}
Assert-CodeCount $build '} else if (usesAndroidCustomModelLayout(workflowForRoute(this.routeName))) {' 1 `
  'build must select the dedicated route exactly once.'

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
