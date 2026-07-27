$ErrorActionPreference = 'Stop'

function Get-NormalizedText([string]$Path) {
  return (Get-Content -Raw -Encoding UTF8 -LiteralPath $Path).Replace("`r`n", "`n").Replace("`r", "`n")
}

function Get-TextSection(
  [string]$Text,
  [string]$StartMarker,
  [string]$EndMarker,
  [string]$Description
) {
  $start = $Text.IndexOf($StartMarker, [StringComparison]::Ordinal)
  if ($start -lt 0) { throw "Text translation parity guard failed: $Description start was not found." }
  $end = $Text.IndexOf($EndMarker, $start + $StartMarker.Length, [StringComparison]::Ordinal)
  if ($end -le $start) { throw "Text translation parity guard failed: $Description end was not found." }
  return $Text.Substring($start, $end - $start)
}

function Assert-Contains([string]$Text, [string]$Marker, [string]$Message) {
  if (-not $Text.Contains($Marker)) { throw "Text translation parity guard failed: $Message" }
}

function Assert-Excludes([string]$Text, [string]$Marker, [string]$Message) {
  if ($Text.Contains($Marker)) { throw "Text translation parity guard failed: $Message ($Marker)." }
}

function Assert-Count([string]$Text, [string]$Marker, [int]$Expected, [string]$Message) {
  $count = ($Text.Length - $Text.Replace($Marker, '').Length) / $Marker.Length
  if ($count -ne $Expected) {
    throw "Text translation parity guard failed: $Message Expected $Expected, found $count."
  }
}

$root = Split-Path -Parent $PSScriptRoot
$catalog = Get-NormalizedText (Join-Path $root 'entry\src\main\ets\features\runtime\FeatureWorkflowCatalog.ets')
$workflow = Get-TextSection $catalog `
  'routeName: AppRoute.TEXT_TRANSLATION.name,' `
  'routeName: AppRoute.OBJECT_PHOTO.name,' `
  'workflow block'
Assert-Contains $workflow "inputKinds: ['text', 'camera', 'photo']" `
  'workflow must keep exactly text, camera, and photo inputs.'
Assert-Excludes $workflow "'liveCamera'" 'liveCamera is not a translation input'

$clearPolicy = Get-TextSection $catalog `
  'export function shouldClearRuntimeResultAtWorkflowStart' `
  'export function shouldKeepScreenOnForWorkflow' `
  'workflow-start preservation policy'
Assert-Contains $clearPolicy '!usesAndroidTextTranslationLayout(workflow)' `
  'translation must preserve the last valid result when a run starts.'

$readyPolicy = Get-TextSection $catalog `
  'export function shouldPreserveRuntimeResultAfterInputReady' `
  'export function shouldPreserveRuntimeTextResultOnAiResult' `
  'input-ready preservation policy'
Assert-Contains $readyPolicy `
  "(usesAndroidTextTranslationLayout(workflow) && (inputKind === 'photo' || inputKind === 'camera'))" `
  'photo and camera input readiness must preserve the last valid translation.'

$resultPolicy = Get-TextSection $catalog `
  'export function shouldPreserveRuntimeTextResultOnAiResult' `
  'export function shouldPreserveRuntimeVisualResultOnAiResult' `
  'failed-result preservation policy'
Assert-Contains $resultPolicy 'usesAndroidTextTranslationLayout(workflow)' `
  'a failed translation must preserve the last valid translation.'
Assert-Contains $resultPolicy '&& !resultOk' `
  'successful translations must still replace the previous result.'

$inputPolicy = Get-TextSection $catalog `
  'export function shouldAllowRuntimeInputChange' `
  'export function workflowInputReadyAction' `
  'running-input policy'
Assert-Contains $inputPolicy `
  "if (usesAndroidTextTranslationLayout(workflow)) {`n    return false;`n  }" `
  'translation inputs must be frozen while a request is running.'

$labelPolicy = Get-TextSection $catalog `
  'export function textTranslationRunActionLabelKey' `
  'export function shouldShowResultSaveAction' `
  'translation retry label policy'
foreach ($status in @(
  'feature_runtime_text_translation_failed',
  'feature_runtime_text_recognition_failed',
  'feature_runtime_run_failed',
  'feature_runtime_text_translation_offline_unsupported'
)) {
  Assert-Contains $labelPolicy $status "retry mapping is missing $status."
}
Assert-Contains $labelPolicy "? 'web_retry' : runActionKey" `
  'stable states must keep the normal translation action label.'

$aiService = Get-NormalizedText (Join-Path $root 'entry\src\main\ets\services\ai\AiService.ets')
$projection = Get-TextSection $aiService `
  'export function translatedTextForAiResult' `
  'export function segmentationMetadataWithBackground' `
  'translated-only projection'
Assert-Contains $projection "'feature_runtime_result_translated_text'" `
  'translated-only projection must read the translated row.'
Assert-Excludes $projection "'feature_runtime_result_text'" `
  'translated-only projection must not fall back to source text'

$page = Get-NormalizedText (Join-Path $root 'entry\src\main\ets\pages\FeatureRuntimePage.ets')
$copyEnabled = Get-TextSection $page `
  '  private translationCopyEnabled(): boolean {' `
  "`n  }`n`n  private copyTranslatedText" `
  'Copy enablement method'
Assert-Contains $copyEnabled '!this.workflowRunning' 'Copy must be disabled while translation is running.'
Assert-Contains $copyEnabled 'translatedTextForAiResult(this.resultRows).length > 0' `
  'Copy must require non-empty translated-only output.'

$copyMethod = Get-TextSection $page `
  '  private copyTranslatedText(): void {' `
  "`n`n  private updateUserText" `
  'translated-only Copy method'
Assert-Contains $copyMethod 'translatedTextForAiResult(this.resultRows)' `
  'Copy must use translated-only output.'
Assert-Contains $copyMethod 'this.showRuntimeToast(this.statusKey)' `
  'Copy must show visible feedback.'
Assert-Excludes $copyMethod 'copyableTextForAiResult' `
  'Copy must not use the generic source fallback'

$builder = Get-TextSection $page `
  '  textTranslationAndroidLayout() {' `
  "`n`n  @Builder`n  runtimeLayoutContent() {" `
  'dedicated Text Translation builder'
foreach ($marker in @(
  'this.runtimeActionToolbar(false)',
  'Scroll() {',
  'TextArea({',
  'Image(this.imageInputUri)',
  'LoadingProgress()',
  'Text(appString(this.statusKey))',
  'Text(translatedTextForAiResult(this.resultRows))',
  'textTranslationRunActionLabelKey(this.statusKey, this.runActionKey)',
  "this.prepareInput('photo')",
  "this.prepareInput('camera')",
  'this.translationCopyEnabled()',
  'this.copyTranslatedText()'
)) {
  Assert-Contains $builder $marker "dedicated builder is missing $marker."
}
Assert-Count $builder 'Scroll() {' 1 'the page must have one top-level content Scroll.'
Assert-Count $builder 'this.resultRows' 1 'the result card must render resultRows exactly once.'
Assert-Excludes $builder '.copyOption(CopyOptions.LocalDevice)' `
  'translated output must not become a separate undersized clickable target; use the Copy button.'
Assert-Contains $builder `
  '.padding({ left: AppSpacing.page, right: AppSpacing.page, top: AppSpacing.md, bottom: AppSpacing.xl + AppSpacing.page * 2 })' `
  'the translation Scroll must leave enough tail room for 3.2x text without clipping a target.'

foreach ($button in @(
  'Button(appString(textTranslationRunActionLabelKey(this.statusKey, this.runActionKey)))',
  "Button(appString('feature_input_photo_android'), { type: ButtonType.Normal })",
  "Button(appString('feature_input_camera_android'), { type: ButtonType.Normal })",
  "Button(appString('feature_runtime_copy_text'), { type: ButtonType.Normal })"
)) {
  Assert-Contains $builder "$button`n            .width('100%')`n            .constraintSize({ minHeight: 48 })" `
    "$button must be full-width and at least 48vp."
}

foreach ($marker in @(
  '.height(37)',
  '.height(50)',
  "fontColor('#000000')",
  "fontColor('#666666')",
  "color: '#B6B2B2'",
  '.layoutWeight(4)',
  '.layoutWeight(5)'
)) {
  Assert-Excludes $builder $marker 'dedicated builder contains legacy Android geometry or colors'
}

$photoIndex = $builder.IndexOf("Button(appString('feature_input_photo_android')", [StringComparison]::Ordinal)
$cameraIndex = $builder.IndexOf("Button(appString('feature_input_camera_android')", [StringComparison]::Ordinal)
$copyIndex = $builder.IndexOf("Button(appString('feature_runtime_copy_text')", [StringComparison]::Ordinal)
if ($photoIndex -lt 0 -or $cameraIndex -le $photoIndex -or $copyIndex -le $cameraIndex) {
  throw 'Text translation parity guard failed: secondary actions must remain Photo, Camera, Copy.'
}

foreach ($marker in @(
  'this.summaryKey',
  'feature_runtime_permissions_title',
  'this.resultRow(',
  'this.resultText',
  'resultImageSaveControl(',
  'resultComponentImageSaveControl(',
  'styleRecoveryControl(',
  'saveResult'
)) {
  Assert-Excludes $builder $marker 'dedicated builder contains generic debug/result/save UI'
}

Write-Output 'Text translation input parity guard passed.'
