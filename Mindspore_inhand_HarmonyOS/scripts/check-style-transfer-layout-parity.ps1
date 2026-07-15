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
      if ($current -eq [char]0x0A) { [void]$result.Append($current); $state = 'code' } else { [void]$result.Append(' ') }
      continue
    }
    if ($state -eq 'blockComment') {
      if ($current -eq [char]0x2A -and $next -eq [char]0x2F) {
        [void]$result.Append('  '); $index++; $state = 'code'
      } elseif ($current -eq [char]0x0A) { [void]$result.Append($current) } else { [void]$result.Append(' ') }
      continue
    }
    if ($state -eq 'quotedLiteral') {
      [void]$result.Append($current)
      if ($escaped) { $escaped = $false }
      elseif ($current -eq [char]0x5C) { $escaped = $true }
      elseif ($current -eq $terminator) { $state = 'code' }
      continue
    }
    if ($state -eq 'templateRaw') {
      if ($escaped) { [void]$result.Append(' '); $escaped = $false }
      elseif ($current -eq [char]0x5C) { [void]$result.Append(' '); $escaped = $true }
      elseif ($current -eq [char]0x0A) { [void]$result.Append($current) }
      elseif ($current -eq [char]0x60) { [void]$result.Append($current); $state = 'code' }
      elseif ($current -eq [char]0x24 -and $next -eq [char]0x7B) {
        [void]$result.Append('${'); $index++; $interpolationDepths.Add(1); $state = 'code'
      } else { [void]$result.Append(' ') }
      continue
    }
    if ($current -eq [char]0x2F -and $next -eq [char]0x2F) {
      [void]$result.Append('  '); $index++; $state = 'lineComment'
    } elseif ($current -eq [char]0x2F -and $next -eq [char]0x2A) {
      [void]$result.Append('  '); $index++; $state = 'blockComment'
    } elseif ($current -eq [char]0x27 -or $current -eq [char]0x22) {
      [void]$result.Append($current); $terminator = $current; $escaped = $false; $state = 'quotedLiteral'
    } elseif ($current -eq [char]0x60) {
      [void]$result.Append($current); $escaped = $false; $state = 'templateRaw'
    } elseif ($interpolationDepths.Count -gt 0 -and $current -eq [char]0x7B) {
      $last = $interpolationDepths.Count - 1; $interpolationDepths[$last]++; [void]$result.Append($current)
    } elseif ($interpolationDepths.Count -gt 0 -and $current -eq [char]0x7D) {
      $last = $interpolationDepths.Count - 1; $interpolationDepths[$last]--; [void]$result.Append($current)
      if ($interpolationDepths[$last] -eq 0) { $interpolationDepths.RemoveAt($last); $state = 'templateRaw' }
    } else { [void]$result.Append($current) }
  }
  return $result.ToString()
}

function Get-TextSection([string]$Text, [string]$StartMarker, [string]$EndMarker, [string]$Description) {
  $start = $Text.IndexOf($StartMarker, [StringComparison]::Ordinal)
  $end = if ($start -ge 0) {
    $Text.IndexOf($EndMarker, $start + $StartMarker.Length, [StringComparison]::Ordinal)
  } else { -1 }
  if ($start -lt 0 -or $end -le $start) {
    throw "Style Transfer parity guard failed: $Description was not found."
  }
  return $Text.Substring($start, $end - $start)
}

function Test-CodeLine([string]$Text, [string]$Line) {
  return [regex]::IsMatch($Text, "(?m)^[\t ]*$([regex]::Escape($Line))[\t ]*$")
}

function Assert-CodeLine([string]$Text, [string]$Line, [string]$Message) {
  if (-not (Test-CodeLine $Text $Line)) { throw "Style Transfer parity guard failed: $Message" }
}

function Assert-Contains([string]$Text, [string]$Marker, [string]$Message) {
  if (-not $Text.Contains($Marker)) { throw "Style Transfer parity guard failed: $Message" }
}

function Assert-Excludes([string]$Text, [string]$Marker, [string]$Message) {
  if ($Text.Contains($Marker)) { throw "Style Transfer parity guard failed: $Message ($Marker)." }
}

function Assert-Count([string]$Text, [string]$Marker, [int]$Expected, [string]$Message) {
  $actual = ($Text.Length - $Text.Replace($Marker, '').Length) / $Marker.Length
  if ($actual -ne $Expected) {
    throw "Style Transfer parity guard failed: $Message Expected $Expected, found $actual."
  }
}

function Assert-CodeLineCount([string]$Text, [string]$Line, [int]$Expected, [string]$Message) {
  $matches = [regex]::Matches($Text, "(?m)^[\t ]*$([regex]::Escape($Line))[\t ]*$")
  if ($matches.Count -ne $Expected) {
    throw "Style Transfer parity guard failed: $Message Expected $Expected, found $($matches.Count)."
  }
}

function Get-CodeLineIndex([string]$Text, [string]$Line, [int]$StartAt = 0) {
  $pattern = "^[\t ]*$([regex]::Escape($Line))[\t ]*$"
  $match = [regex]::new($pattern, [Text.RegularExpressions.RegexOptions]::Multiline).Match($Text, $StartAt)
  return $(if ($match.Success) { $match.Index } else { -1 })
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
  throw 'Style Transfer parity guard failed: comments, strings, and template raw text must not spoof code lines.'
}
Assert-CodeLine $strippedProbe 'executableCall()' 'template/comment stripper must preserve executable code.'
Assert-Count $strippedProbe 'executableCall()' 2 'template interpolation code must remain executable.'
Assert-Excludes $strippedProbe 'INTERPOLATION_COMMENT' 'interpolation comments must be removed'
Assert-Excludes $strippedProbe 'BLOCK_COMMENT' 'block comments must be removed'

if ([string]::IsNullOrWhiteSpace($SourceRoot)) { $SourceRoot = Split-Path -Parent $PSScriptRoot }
$SourceRoot = [IO.Path]::GetFullPath($SourceRoot)
$catalogPath = Join-Path $SourceRoot 'entry\src\main\ets\features\runtime\FeatureWorkflowCatalog.ets'
$pagePath = Join-Path $SourceRoot 'entry\src\main\ets\pages\FeatureRuntimePage.ets'
$buildScriptPath = Join-Path $SourceRoot 'scripts\build-hap.ps1'

$catalog = Remove-ArkTsCommentsAndTemplateRaw (Get-NormalizedText $catalogPath)
$selector = Get-TextSection $catalog 'export function usesAndroidStyleTransferLayout' `
  'export function styleTransferResultToastKey' 'Style Transfer selector'
Assert-CodeLine $selector 'return workflow?.routeName === AppRoute.STYLE_TRANSFER.name;' `
  'selector must target only Style Transfer.'
Assert-Count $selector 'AppRoute.' 1 'selector must contain exactly one route target.'

$page = Remove-ArkTsCommentsAndTemplateRaw (Get-NormalizedText $pagePath)
$builder = Get-TextSection $page '  styleTransferAndroidLayout() {' `
  "`n`n  @Builder`n  customModelAndroidLayout()" 'dedicated Style Transfer builder'
$grid = Get-TextSection $page '  styleTransferStyleGrid() {' `
  "`n`n  @Builder`n  styleTransferStyleItem" 'Style Transfer grid'

foreach ($line in @(
  'Stack({ alignContent: Alignment.TopStart }) {',
  'this.runtimeActionToolbar(true)',
  '.height(1)',
  ".backgroundColor('#E4E4E4')",
  'Stack({ alignContent: Alignment.Center }) {',
  'if (this.styledImagePixelMap !== undefined && !this.styleOriginalPreviewRecovered) {',
  'Image(this.styledImagePixelMap)',
  '} else if (this.styleTransferContentInputReady()) {',
  "Image(this.contentImageUri.length > 0 ? this.contentImageUri : this.imageInputUri)",
  "Image(`$r('app.media.icon_default'))",
  "Text(appString('feature_runtime_style_choose_image'))",
  'if (this.workflowRunning) {',
  'LoadingProgress()',
  '.width(80)',
  '.height(80)',
  '.height(265)',
  "Button(appString('feature_runtime_style_album'), { type: ButtonType.Normal })",
  ".onClick(() => this.prepareInput('contentImage'))",
  "Button(appString(workflowInputLabelKey(workflowForRoute(this.routeName), 'camera')), { type: ButtonType.Normal })",
  ".onClick(() => this.prepareInput('camera'))",
  "Button(appString('feature_runtime_style_recovery'), { type: ButtonType.Normal })",
  '.onClick(() => this.recoverStyleOriginalPreview())',
  'SaveButton({',
  '.enabled(!this.workflowRunning)',
  'this.saveStyleTransferResultImage()',
  "this.statusKey = 'feature_runtime_save_image_failed';",
  'this.showRuntimeToast(this.statusKey);',
  "Button(appString(workflowInputLabelKey(workflowForRoute(this.routeName), 'stylePredictModelFile')), { type: ButtonType.Normal })",
  ".onClick(() => this.prepareInput('stylePredictModelFile'))",
  "Button(appString(workflowInputLabelKey(workflowForRoute(this.routeName), 'styleTransferModelFile')), { type: ButtonType.Normal })",
  ".onClick(() => this.prepareInput('styleTransferModelFile'))",
  'this.styleTransferStyleGrid()',
  'this.runtimePermissionRecoveryOverlay()',
  ".width('100%')",
  ".height('100%')",
  '.backgroundColor(Color.White)'
)) { Assert-CodeLine $builder $line "dedicated builder is missing executable line: $line." }
Assert-CodeLineCount $builder '.width(256)' 2 `
  'styled and original previews must each be exactly 256vp wide.'
Assert-CodeLineCount $builder '.height(256)' 2 `
  'styled and original previews must each be exactly 256vp high.'

foreach ($line in @(
  ".columnsTemplate('1fr 1fr 1fr 1fr')",
  '.columnsGap(10)',
  '.rowsGap(10)',
  '.layoutWeight(1)',
  '.scrollBar(BarState.Auto)',
  ".margin({ left: 20, right: 20, top: 10 })"
)) { Assert-CodeLine $grid $line "style grid is missing executable line: $line." }

$toolbarIndex = Get-CodeLineIndex $builder 'this.runtimeActionToolbar(true)'
$previewIndex = Get-CodeLineIndex $builder 'Stack({ alignContent: Alignment.Center }) {' ($toolbarIndex + 1)
$albumIndex = Get-CodeLineIndex $builder ".onClick(() => this.prepareInput('contentImage'))" ($previewIndex + 1)
$cameraIndex = Get-CodeLineIndex $builder ".onClick(() => this.prepareInput('camera'))" ($albumIndex + 1)
$recoveryButtonIndex = Get-CodeLineIndex $builder `
  "Button(appString('feature_runtime_style_recovery'), { type: ButtonType.Normal })" ($cameraIndex + 1)
$recoveryIndex = Get-CodeLineIndex $builder '.onClick(() => this.recoverStyleOriginalPreview())' ($recoveryButtonIndex + 1)
$saveIndex = Get-CodeLineIndex $builder 'SaveButton({' ($recoveryIndex + 1)
$predictButtonIndex = Get-CodeLineIndex $builder `
  "Button(appString(workflowInputLabelKey(workflowForRoute(this.routeName), 'stylePredictModelFile')), { type: ButtonType.Normal })" `
  ($saveIndex + 1)
$predictIndex = Get-CodeLineIndex $builder ".onClick(() => this.prepareInput('stylePredictModelFile'))" ($predictButtonIndex + 1)
$transferIndex = Get-CodeLineIndex $builder ".onClick(() => this.prepareInput('styleTransferModelFile'))" ($predictIndex + 1)
$gridIndex = Get-CodeLineIndex $builder 'this.styleTransferStyleGrid()' ($transferIndex + 1)
if ($toolbarIndex -lt 0 -or $previewIndex -le $toolbarIndex -or $albumIndex -le $previewIndex -or
  $cameraIndex -le $albumIndex -or $recoveryButtonIndex -le $cameraIndex -or $recoveryIndex -le $recoveryButtonIndex -or
  $saveIndex -le $recoveryIndex -or $predictButtonIndex -le $saveIndex -or
  $predictIndex -le $predictButtonIndex -or $transferIndex -le $predictIndex -or $gridIndex -le $transferIndex) {
  throw 'Style Transfer parity guard failed: content order must match Android.'
}
$recoveryControl = $builder.Substring($recoveryButtonIndex, $saveIndex - $recoveryButtonIndex)
$saveControl = $builder.Substring($saveIndex, $predictButtonIndex - $saveIndex)
Assert-CodeLine $recoveryControl '.enabled(!this.workflowRunning)' `
  'Recovery must render disabled while Style Transfer is running.'
Assert-CodeLine $saveControl '.enabled(!this.workflowRunning)' `
  'secure Save must render disabled while Style Transfer is running.'
Assert-CodeLine $saveControl 'this.showRuntimeToast(this.statusKey);' `
  'denied secure Save must immediately show failure Toast.'
$saveOnClick = Get-TextSection $saveControl `
  '.onClick((_event: ClickEvent, result: SaveButtonOnClickResult) => {' `
  "`n              })" 'secure Save click handler'
Assert-CodeLineCount $saveOnClick 'if (this.workflowRunning) {' 1 `
  'secure Save click handler must reject delayed/programmatic callbacks while running.'
$saveRunningIndex = Get-CodeLineIndex $saveOnClick 'if (this.workflowRunning) {'
$saveResultIndex = Get-CodeLineIndex $saveOnClick 'if (result === SaveButtonOnClickResult.SUCCESS) {'
if ($saveRunningIndex -lt 0 -or $saveResultIndex -le $saveRunningIndex) {
  throw 'Style Transfer parity guard failed: secure Save running guard must precede result handling.'
}

foreach ($marker in @(
  'this.summaryKey', 'feature_runtime_inputs_title', 'feature_runtime_permissions_title',
  'workflowResultTitleKey(', 'this.resultRow(', 'Text(appString(this.statusKey))', 'this.resultText',
  'feature_runtime_debug', 'filePreview(', 'pixelMapPreview(', 'resultImageSaveControl(',
  'shouldShowPrimaryRunAction(', 'this.runPrimaryAction()'
)) { Assert-Excludes $builder $marker 'dedicated builder contains generic UI' }

$pick = Get-TextSection $page '  private applyPickResult(' "`n`n  private aiRunInputs" 'pick-result handler'
Assert-CodeLine $pick "if (usesAndroidStyleTransferLayout(workflow) && (inputKind === 'contentImage' ||" `
  'accepted Style Transfer picks must enter the pending-replacement invalidation branch.'
Assert-CodeLine $pick 'this.styledImagePixelMapOwner.invalidatePendingReplacement();' `
  'accepted Style Transfer picks must invalidate pending styled replacement.'
Assert-CodeLine $pick 'if (shouldShowStyleOriginalAfterInputReady(workflow, inputKind)) {' `
  'content/camera picks must switch to original preview.'
Assert-CodeLine $pick "} else if (inputKind === 'camera' && usesAndroidStyleTransferLayout(workflow)) {" `
  'Style Transfer camera input must replace the effective content image.'
Assert-CodeLineCount $pick 'this.contentImageUri = result.uri;' 2 `
  'Album and Camera must each replace the effective Style Transfer content image.'
Assert-CodeLineCount $pick "this.imageInputUri = '';" 2 `
  'Album and Camera must clear the alternate primary-image slot.'

$builtIn = Get-TextSection $page '  private selectBuiltInStyle(' `
  "`n`n  private shouldRunStyleTransferAfterStyleReady" 'built-in style selection'
Assert-CodeLine $builtIn 'this.styledImagePixelMapOwner.invalidatePendingReplacement();' `
  'built-in style selection must invalidate pending styled replacement.'

$cacheCaller = Get-TextSection $page '  private async cacheAndApplyPickedModelFile(' `
  "`n`n  private applyModelFileCacheResult" 'model-cache caller'
$currentIndex = Get-CodeLineIndex $cacheCaller 'if (!isInputPreparationRequestCurrent(requestId, this.inputPreparationRequestId)) {'
$undefinedIndex = Get-CodeLineIndex $cacheCaller 'if (cacheResult === undefined) {' ($currentIndex + 1)
$applyIndex = Get-CodeLineIndex $cacheCaller 'this.applyModelFileCacheResult(cacheResult, inputKind);' ($undefinedIndex + 1)
if ($currentIndex -lt 0 -or $undefinedIndex -le $currentIndex -or $applyIndex -le $undefinedIndex) {
  throw 'Style Transfer parity guard failed: stale/undefined cache results must be rejected before apply/reset/Toast.'
}
$preStaleCache = $cacheCaller.Substring(0, $currentIndex)
Assert-CodeLineCount $cacheCaller 'this.applyModelFileCacheResult(cacheResult, inputKind);' 1 `
  'model-cache result must be applied exactly once.'
Assert-CodeLineCount $preStaleCache 'this.applyModelFileCacheResult(cacheResult, inputKind);' 0 `
  'model-cache result must not be applied before the stale gate.'
Assert-Excludes $preStaleCache 'resetStyleTransferPageAfterModelCacheSuccess' `
  'model-cache reset must not run before the stale gate'
Assert-Excludes $preStaleCache 'showStyleTransferModelCacheToastIfNeeded' `
  'model-cache Toast must not run before the stale gate'

$cacheResult = Get-TextSection $page '  private applyModelFileCacheResult(' `
  "`n`n  private showCustomModelCacheToastIfNeeded" 'model-cache result handler'
foreach ($line in @(
  'if (!shouldPreserveRuntimeResultAfterInputReady(workflow, inputKind)) {',
  'this.showStyleTransferModelCacheToastIfNeeded(inputKind, result.messageKey);',
  'if (shouldResetStyleTransferPageAfterModelCacheResult(workflow, inputKind, result.ok)) {',
  'this.resetStyleTransferPageAfterModelCacheSuccess();'
)) { Assert-CodeLine $cacheResult $line "model-cache state edge is missing: $line." }

$permission = Get-TextSection $page '  private async runWorkflowAsync(' `
  "`n`n  private applyRuntimeFailure" 'run and permission flow'
Assert-CodeLine $permission 'if (!usesAndroidStyleTransferLayout(workflow)) {' `
  'permission failure must preserve Style Transfer visuals.'
Assert-CodeLine $permission 'await this.applyAiResult(result, runtimeRequestId);' `
  'run lifecycle must await styled PixelMap conversion.'

$failure = Get-TextSection $page '  private applyRuntimeFailure()' `
  "`n`n  private async prepareLiveFrameImageInput" 'thrown-run failure handler'
Assert-CodeLine $failure "if (!shouldPreserveRuntimeVisualResultOnAiResult(workflow, false, '')) {" `
  'thrown Style Transfer runs must preserve visuals.'
Assert-CodeLine $failure 'this.showStyleTransferFailureToastIfNeeded(false);' `
  'thrown Style Transfer runs must show the route-scoped Toast.'

$aiResult = Get-TextSection $page '  private async applyAiResult(' `
  "`n`n  private showObjectPhotoFailureToastIfNeeded" 'AI result handler'
Assert-CodeLine $aiResult 'await this.updateStyledImagePreview(result, runtimeRequestId);' `
  'successful Style Transfer result must await atomic PixelMap replacement.'
Assert-CodeLine $aiResult 'this.showStyleTransferFailureToastIfNeeded(result.ok);' `
  'failed AI result must show the route-scoped Toast.'

$styled = Get-TextSection $page '  private async updateStyledImagePreview(' `
  "`n`n  private openHelpPage" 'styled PixelMap replacement'
foreach ($line in @(
  'this.styledImagePixelMapOwner.invalidatePendingReplacement();',
  'const requestId = this.styledImagePixelMapOwner.beginReplacement();',
  'const pixelMap = await styleTransferPixelMapFromRgbaOutput(rgba, width, height);',
  'this.styledImagePixelMapOwner.accept(requestId, pixelMap);',
  'if (this.styledImagePixelMapOwner.accept(requestId, pixelMap)) {',
  'this.styleOriginalPreviewRecovered = false;',
  "this.statusKey = 'feature_runtime_style_transfer_failed';",
  'this.showStyleTransferFailureToastIfNeeded(false);'
)) { Assert-CodeLine $styled $line "atomic styled replacement is missing: $line." }
Assert-CodeLineCount $styled 'this.styledImagePixelMapOwner.invalidatePendingReplacement();' 3 `
  'invalid, stale, and rejected conversions must each invalidate pending replacement.'
Assert-CodeLineCount $styled 'this.showStyleTransferFailureToastIfNeeded(false);' 2 `
  'invalid and rejected current conversions must each show one failure Toast.'
Assert-CodeLineCount $styled "this.statusKey = 'feature_runtime_style_transfer_failed';" 2 `
  'invalid and rejected current conversions must each map to the Style Transfer failure status.'
Assert-Excludes $styled 'this.styledImagePixelMapOwner.clear();' `
  'conversion failure/success must not clear the previous styled owner before atomic acceptance'
Assert-Excludes $styled 'this.styledImagePixelMap = undefined;' `
  'conversion failure must preserve the previous styled Save target'

$recovery = Get-TextSection $page '  private recoverStyleOriginalPreview()' `
  "`n`n  private selectPortraitBackgroundPreset" 'Style Transfer Recovery handler'
Assert-CodeLine $recovery 'if (this.workflowRunning) {' 'Recovery must be handler-guarded while running.'
Assert-CodeLine $recovery 'this.showRuntimeToast(this.statusKey);' `
  'Recovery without an original must show a Toast.'

$save = Get-TextSection $page '  private saveStyleTransferResultImage()' `
  "`n`n  private async saveResultComponentImageAsync" 'Style Transfer Save wrapper'
Assert-CodeLine $save 'if (this.workflowRunning) {' 'Save must be handler-guarded while running.'
Assert-CodeLineCount $save 'if (this.workflowRunning) {' 2 `
  'both the Save click wrapper and async service path must reject while running.'
Assert-CodeLine $save 'await this.saveResultPixelMapAsync(this.styledImagePixelMap);' `
  'Style Transfer Save must reuse the shared save service.'
Assert-CodeLine $save 'this.showRuntimeToast(this.statusKey);' `
  'Style Transfer Save must Toast its route-scoped result.'

$sharedSave = Get-TextSection $page '  private saveResultPixelMap(' `
  "`n`n  private saveStyleTransferResultImage" 'shared segmentation save path'
Assert-Excludes $sharedSave 'showRuntimeToast' 'shared segmentation save path must not gain Toast feedback'

$build = $page.Substring($page.IndexOf("`n  build() {", [StringComparison]::Ordinal))
$styleSelector = '} else if (usesAndroidStyleTransferLayout(workflowForRoute(this.routeName))) {'
$objectIndex = Get-CodeLineIndex $build '} else if (usesAndroidObjectPhotoLayout(workflowForRoute(this.routeName))) {'
$styleIndex = Get-CodeLineIndex $build $styleSelector ($objectIndex + 1)
$customIndex = Get-CodeLineIndex $build '} else if (usesAndroidCustomModelLayout(workflowForRoute(this.routeName))) {' ($styleIndex + 1)
$genericIndex = Get-CodeLineIndex $build '} else {' ($customIndex + 1)
if ($objectIndex -lt 0 -or $styleIndex -le $objectIndex -or $customIndex -le $styleIndex -or $genericIndex -le $customIndex) {
  throw 'Style Transfer parity guard failed: dedicated selector must be after Object Photo and before generic fallback.'
}
Assert-CodeLine $build $styleSelector 'build must select Style Transfer in executable code.'
$styleBranch = Get-TextSection $build $styleSelector `
  '} else if (usesAndroidCustomModelLayout(workflowForRoute(this.routeName))) {' 'Style Transfer build branch'
Assert-CodeLineCount $styleBranch 'this.styleTransferAndroidLayout()' 1 `
  'Style Transfer selector must render the dedicated builder exactly once.'
$styleBranchBuilderCalls = @([regex]::Matches(
    $styleBranch,
    '(?m)^[\t ]*this\.([A-Za-z_][A-Za-z0-9_]*Layout)\(\)[\t ]*$'
  ))
if ($styleBranchBuilderCalls.Count -ne 1 -or
  $styleBranchBuilderCalls[0].Value.Trim() -ne 'this.styleTransferAndroidLayout()') {
  throw 'Style Transfer parity guard failed: Style Transfer selector must not render a sibling builder.'
}

$buildScript = Get-NormalizedText $buildScriptPath
$guardCall = "& (Join-Path `$PSScriptRoot 'check-style-transfer-layout-parity.ps1')"
$fixtureCall = "& (Join-Path `$PSScriptRoot 'test-style-transfer-layout-parity-guard.ps1')"
Assert-Count $buildScript $guardCall 1 'build-hap must invoke the production Style Transfer guard once.'
Assert-Count $buildScript $fixtureCall 1 'build-hap must invoke the Style Transfer mutation fixture once.'
$tokens = $null
$parseErrors = $null
$ast = [Management.Automation.Language.Parser]::ParseFile($buildScriptPath, [ref]$tokens, [ref]$parseErrors)
if ($parseErrors.Count -ne 0) { throw 'Style Transfer parity guard failed: build-hap.ps1 must parse cleanly.' }
foreach ($call in @($guardCall, $fixtureCall)) {
  $topLevel = @($ast.EndBlock.Statements | Where-Object {
      $_.Extent.Text.Replace("`r`n", "`n").Trim() -eq $call
    })
  if ($topLevel.Count -ne 1) {
    throw "Style Transfer parity guard failed: build-hap must execute one top-level guard call: $call"
  }
}

Write-Output 'Style Transfer layout parity guard passed.'
