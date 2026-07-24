param(
  [string]$SourceRoot = ''
)

$ErrorActionPreference = 'Stop'

function Fail([string]$Message) {
  throw "Text recognition layout guard failed: $Message"
}

function Normalize-Text([string]$Text) {
  return $Text.Replace("`r`n", "`n").Replace("`r", "`n")
}

function Read-Normalized([string]$Path) {
  if (-not [IO.File]::Exists($Path)) {
    Fail "missing source file: $Path"
  }
  return Normalize-Text ([IO.File]::ReadAllText($Path))
}

function Remove-ArkTsCommentsAndStrings([string]$Text, [bool]$PreserveStrings = $false) {
  $result = [Text.StringBuilder]::new($Text.Length)
  $state = 'code'
  $quote = [char]0
  $escaped = $false
  for ($index = 0; $index -lt $Text.Length; $index++) {
    $current = $Text[$index]
    $next = if ($index + 1 -lt $Text.Length) { $Text[$index + 1] } else { [char]0 }
    if ($state -eq 'line') {
      if ($current -eq [char]0x0A) {
        [void]$result.Append($current)
        $state = 'code'
      } else {
        [void]$result.Append(' ')
      }
      continue
    }
    if ($state -eq 'block') {
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
    if ($state -eq 'string') {
      if ($PreserveStrings) {
        [void]$result.Append($current)
      } elseif ($current -eq [char]0x0A) {
        [void]$result.Append($current)
      } else {
        [void]$result.Append(' ')
      }
      if ($escaped) {
        $escaped = $false
      } elseif ($current -eq [char]0x5C) {
        $escaped = $true
      } elseif ($current -eq $quote) {
        $state = 'code'
      }
      continue
    }
    if ($current -eq [char]0x2F -and $next -eq [char]0x2F) {
      [void]$result.Append('  ')
      $index++
      $state = 'line'
    } elseif ($current -eq [char]0x2F -and $next -eq [char]0x2A) {
      [void]$result.Append('  ')
      $index++
      $state = 'block'
    } elseif ($current -eq [char]0x22 -or $current -eq [char]0x27 -or $current -eq [char]0x60) {
      [void]$result.Append($(if ($PreserveStrings) { $current } else { ' ' }))
      $quote = $current
      $escaped = $false
      $state = 'string'
    } else {
      [void]$result.Append($current)
    }
  }
  return $result.ToString()
}

function Section([string]$Text, [string]$Start, [string]$End, [string]$Name) {
  $startIndex = $Text.IndexOf($Start, [StringComparison]::Ordinal)
  if ($startIndex -lt 0) { Fail "missing $Name start marker: $Start" }
  $endIndex = $Text.IndexOf($End, $startIndex + $Start.Length, [StringComparison]::Ordinal)
  if ($endIndex -lt 0) { Fail "missing $Name end marker: $End" }
  return $Text.Substring($startIndex, $endIndex - $startIndex)
}

function Section-UsingLiteralBounds(
  [string]$Text,
  [string]$LiteralText,
  [string]$Start,
  [string]$End,
  [string]$Name
) {
  $startIndex = $LiteralText.IndexOf($Start, [StringComparison]::Ordinal)
  if ($startIndex -lt 0) { Fail "missing $Name start marker: $Start" }
  $endIndex = $LiteralText.IndexOf($End, $startIndex + $Start.Length, [StringComparison]::Ordinal)
  if ($endIndex -lt 0) { Fail "missing $Name end marker: $End" }
  return $Text.Substring($startIndex, $endIndex - $startIndex)
}

function Assert-Contains([string]$Text, [string]$Marker, [string]$Message) {
  if ($Text.IndexOf($Marker, [StringComparison]::Ordinal) -lt 0) { Fail $Message }
}

function Assert-Excludes([string]$Text, [string]$Marker, [string]$Message) {
  if ($Text.IndexOf($Marker, [StringComparison]::Ordinal) -ge 0) { Fail $Message }
}

function Assert-Count([string]$Text, [string]$Marker, [int]$Expected, [string]$Message) {
  $count = ([regex]::Matches($Text, [regex]::Escape($Marker))).Count
  if ($count -ne $Expected) { Fail "$Message Expected $Expected, found $count." }
}

$root = if ($SourceRoot) { [IO.Path]::GetFullPath($SourceRoot) } else {
  [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
}
$pagePath = Join-Path $root 'entry\src\main\ets\pages\FeatureRuntimePage.ets'
$catalogPath = Join-Path $root 'entry\src\main\ets\features\runtime\FeatureWorkflowCatalog.ets'
$buildPath = Join-Path $root 'scripts\build-hap.ps1'
$pageRaw = Read-Normalized $pagePath
$page = Remove-ArkTsCommentsAndStrings $pageRaw
$pageWithLiterals = Remove-ArkTsCommentsAndStrings $pageRaw $true
$catalogRaw = Read-Normalized $catalogPath
$catalog = Remove-ArkTsCommentsAndStrings $catalogRaw
$catalogWithLiterals = Remove-ArkTsCommentsAndStrings $catalogRaw $true
$build = Read-Normalized $buildPath
$preview = Section $page '  textRecognitionPreview() {' `
  "`n`n  @Builder`n  textRecognitionAndroidLayout()" 'preview'
$layout = Section $page '  textRecognitionAndroidLayout() {' `
  "`n`n  @Builder`n  textTranslationAndroidLayout()" 'layout'
$previewWithLiterals = Section $pageWithLiterals '  textRecognitionPreview() {' `
  "`n`n  @Builder`n  textRecognitionAndroidLayout()" 'preview literals'
$layoutWithLiterals = Section $pageWithLiterals '  textRecognitionAndroidLayout() {' `
  "`n`n  @Builder`n  textTranslationAndroidLayout()" 'layout literals'

foreach ($marker in @(
  'this.runtimeActionToolbar(false)',
  'Scroll() {',
  'Column({ space: AppSpacing.md }) {',
  'this.textRecognitionPreview()',
  '.aspectRatio(4 / 3)',
  'if (this.workflowRunning) {',
  'LoadingProgress()',
  'Text(appString(this.statusKey))',
  'if (!this.workflowRunning &&',
  'textRecognitionRunActionLabelKey(this.statusKey, this.runActionKey)',
  'Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceBetween }) {',
  'this.runPrimaryAction()',
  'this.copyRecognizedText()',
  'Text(this.textRecognitionOutputText())',
  '.copyOption(CopyOptions.LocalDevice)',
  '.scrollBar(BarState.Auto)'
)) { Assert-Contains $layout $marker "missing executable layout marker: $marker" }
foreach ($marker in @(
  'if (this.imageInputUri.length > 0) {',
  'Image(this.imageInputUri)',
  '.objectFit(ImageFit.Contain)',
  '.orientation(this.textRecognitionImageOrientation)'
)) { Assert-Contains $preview $marker "missing executable preview marker: $marker" }
foreach ($marker in @(
  "this.prepareInput('photo')",
  "this.prepareInput('camera')"
)) { Assert-Contains $layoutWithLiterals $marker "missing executable action marker: $marker" }
Assert-Contains $previewWithLiterals "Text(appString('workflow_summary_text_recognition_android_prompt'))" `
  'preview must retain its empty-state prompt.'

Assert-Count $layout 'Scroll() {' 1 'layout must have exactly one top-level content Scroll.'
Assert-Count $layoutWithLiterals ".width('calc(50% - 4vp)')" 4 'actions must form a 2x2 grid.'
Assert-Count $layout '.constraintSize({ minHeight: 48 })' 5 'status and four actions need 48vp minimum targets.'
Assert-Contains $layout '.constraintSize({ minWidth: 72, minHeight: 48 })' `
  'retry action needs a 48vp minimum target.'
Assert-Count $layout '.maxFontScale(1.6)' 8 'status, retry, result labels, and actions need bounded font scaling.'
Assert-Count $preview '.maxFontScale(1.6)' 1 'empty-state prompt needs bounded font scaling.'
Assert-Count $layout '.enabled(textRecognitionActionEnabled(this.workflowRunning))' 3 `
  'Photo, Camera, and Copy must disable during inference.'
Assert-Contains $layout '.enabled(this.runActionEnabled() && textRecognitionActionEnabled(this.workflowRunning))' `
  'Run must use both workflow readiness and the inference gate.'
foreach ($legacy in @('.height(37)', '.layoutWeight(5)', '.layoutWeight(3)', "backgroundColor('#E6E6E6')")) {
  Assert-Excludes $layoutWithLiterals $legacy "legacy fixed Android layout remains: $legacy"
}

$statusStart = '          Row({ space: AppSpacing.sm }) {'
$statusEnd = '          Column({ space: AppSpacing.sm }) {'
$status = Section-UsingLiteralBounds $layout $layoutWithLiterals $statusStart $statusEnd 'status card'
$statusWithLiterals = Section $layoutWithLiterals $statusStart $statusEnd 'status card literals'
foreach ($marker in @(
  'if (!this.workflowRunning &&',
  "this.statusKey === 'feature_runtime_text_recognition_failed'",
  "this.statusKey === 'feature_runtime_run_failed'",
  "Button(appString('web_retry'), { type: ButtonType.Normal })"
)) { Assert-Contains $statusWithLiterals $marker "status retry is missing local marker: $marker" }
$retryStart = "              Button(appString('web_retry'), { type: ButtonType.Normal })"
$retryEnd = "`n            }`n          }"
$retry = Section-UsingLiteralBounds $status $statusWithLiterals $retryStart $retryEnd 'retry action'
$retryWithLiterals = Section $statusWithLiterals $retryStart $retryEnd 'retry action literals'
Assert-Contains $retry '.onClick(() => this.runPrimaryAction())' `
  'failure retry must locally invoke runPrimaryAction.'
Assert-Count $retry '.onClick(' 1 'failure retry must have exactly one executable callback.'
Assert-Contains $retryWithLiterals '.constraintSize({ minWidth: 72, minHeight: 48 })' `
  'failure retry must retain its 48vp target.'

$resultStart = '          Column({ space: AppSpacing.sm }) {'
$resultEnd = '          Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceBetween }) {'
$resultCard = Section-UsingLiteralBounds $layout $layoutWithLiterals $resultStart $resultEnd 'recognized-text card'
$resultCardWithLiterals = Section $layoutWithLiterals $resultStart $resultEnd 'recognized-text card literals'
foreach ($marker in @(
  'Text(this.textRecognitionOutputText())',
  '.copyOption(CopyOptions.LocalDevice)',
  '.constraintSize({ minHeight: 112 })'
)) { Assert-Contains $resultCardWithLiterals $marker "recognized-text card is missing: $marker" }
foreach ($forbidden in @('.height(', 'maxHeight:', '.clip(true)')) {
  Assert-Excludes $resultCard $forbidden `
    "recognized-text card must grow naturally inside the page Scroll; forbidden: $forbidden"
}

$actionsStart = '          Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceBetween }) {'
$actionsEnd = "`n          }`n          .width('100%')"
$actions = Section-UsingLiteralBounds $layout $layoutWithLiterals $actionsStart $actionsEnd 'action grid'
$actionsWithLiterals = Section $layoutWithLiterals $actionsStart $actionsEnd 'action grid literals'
$photoStart = "            Button(appString(workflowInputLabelKey(workflowForRoute(this.routeName), 'photo')),"
$cameraStart = "            Button(appString(workflowInputLabelKey(workflowForRoute(this.routeName), 'camera')),"
$runStart = '            Button(appString(textRecognitionRunActionLabelKey(this.statusKey, this.runActionKey)))'
$copyStart = "            Button(appString('feature_runtime_copy_text'), { type: ButtonType.Normal })"
$photo = Section-UsingLiteralBounds $actions $actionsWithLiterals $photoStart $cameraStart 'Photo action'
$photoWithLiterals = Section $actionsWithLiterals $photoStart $cameraStart 'Photo action literals'
$camera = Section-UsingLiteralBounds $actions $actionsWithLiterals $cameraStart $runStart 'Camera action'
$cameraWithLiterals = Section $actionsWithLiterals $cameraStart $runStart 'Camera action literals'
$run = Section-UsingLiteralBounds $actions $actionsWithLiterals $runStart $copyStart 'Run action'
$runWithLiterals = Section $actionsWithLiterals $runStart $copyStart 'Run action literals'
$copy = Section-UsingLiteralBounds $layout $layoutWithLiterals $copyStart $actionsEnd 'Copy action'
$copyWithLiterals = Section $layoutWithLiterals $copyStart $actionsEnd 'Copy action literals'
foreach ($action in @(
  @{ Name = 'Photo'; Code = $photo; Literal = $photoWithLiterals; Callback = ".onClick(() => this.prepareInput('photo'))" },
  @{ Name = 'Camera'; Code = $camera; Literal = $cameraWithLiterals; Callback = ".onClick(() => this.prepareInput('camera'))" },
  @{ Name = 'Copy'; Code = $copy; Literal = $copyWithLiterals; Callback = '.onClick(() => this.copyRecognizedText())' }
)) {
  Assert-Contains $action.Code '.enabled(textRecognitionActionEnabled(this.workflowRunning))' `
    "$($action.Name) must locally bind the inference-running gate."
  Assert-Contains $action.Literal $action.Callback "$($action.Name) must retain its local callback."
  Assert-Count $action.Code '.onClick(' 1 "$($action.Name) must have exactly one executable callback."
}
Assert-Contains $run '.enabled(this.runActionEnabled() && textRecognitionActionEnabled(this.workflowRunning))' `
  'Run must locally bind workflow readiness and the inference-running gate.'
Assert-Contains $run '.onClick(() => this.runPrimaryAction())' 'Run must locally invoke runPrimaryAction.'
Assert-Contains $runWithLiterals 'textRecognitionRunActionLabelKey(this.statusKey, this.runActionKey)' `
  'Run must locally retain its Run-or-Retry label.'
Assert-Count $run '.onClick(' 1 'Run must have exactly one executable callback.'

$pick = Section $page '  private applyPickResult(' "`n`n  private aiRunInputs" 'pick result path'
Assert-Contains $pick 'usesAndroidTextRecognitionLayout(workflow)' `
  'accepted text-recognition image picks must update preview orientation.'
Assert-Contains $pick 'this.updateTextRecognitionImageOrientation(result.uri);' `
  'accepted text-recognition image picks must resolve EXIF orientation.'
Assert-Contains $pick 'this.textRecognitionImageOrientation = ImageRotateOrientation.UP;' `
  'each accepted text-recognition image must reset stale orientation before EXIF resolution.'
Assert-Contains $pick 'runtimePickedInputStateAfterCancelledPick(' `
  'picker cancellation must preserve the prior picked-input state.'

$orientation = Section $page '  private updateTextRecognitionImageOrientation(' `
  "`n`n  private updateObjectDetectionImageOrientation" 'orientation helper'
Assert-Contains $orientation 'this.updateOverlayPreviewImageOrientation(uri,' `
  'text-recognition orientation must reuse the shared EXIF helper.'
Assert-Contains $orientation 'if (this.imageInputUri === uri) {' `
  'stale orientation results must not replace the current preview orientation.'

$copyFeedback = Section $pageWithLiterals '  private copyRecognizedText(): void {' `
  "`n`n  private copyTranslatedText(): void {" 'copy feedback'
Assert-Contains $copyFeedback `
  "this.statusKey = result.ok ? 'feature_runtime_copy_done' : 'feature_runtime_copy_failed';`n      this.showRuntimeToast(this.statusKey);" `
  'copyRecognizedText must publish durable success/failure state and immediate visible feedback.'
Assert-Count $copyFeedback 'this.statusKey =' 1 `
  'copyRecognizedText must publish exactly one success/failure status.'
Assert-Count $copyFeedback 'this.showRuntimeToast(this.statusKey);' 1 `
  'copyRecognizedText must emit exactly one immediate toast from that status.'

$helpers = Section $catalogWithLiterals 'export function textRecognitionActionEnabled' `
  'export function shouldShowResultSaveAction' 'text recognition UI helpers'
Assert-Contains $helpers 'return !workflowRunning;' 'all actions must gate the running state.'
Assert-Contains $helpers "statusKey === 'feature_runtime_text_recognition_failed'" `
  'OCR failures must map the run action to retry.'
Assert-Contains $helpers "statusKey === 'feature_runtime_run_failed'" `
  'unexpected runtime failures must map the run action to retry.'

$guardCall = "& (Join-Path `$PSScriptRoot 'check-text-recognition-layout-parity.ps1')"
$mutationCall = "& (Join-Path `$PSScriptRoot 'test-text-recognition-layout-parity-guard.ps1')"
Assert-Count $build $guardCall 1 'build-hap must invoke the focused guard once.'
Assert-Count $build $mutationCall 1 'build-hap must invoke the mutation suite once.'

Write-Output 'Text recognition layout/state parity guard passed.'
