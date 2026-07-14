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
  $end = $Text.IndexOf($EndMarker, $start + $StartMarker.Length, [StringComparison]::Ordinal)
  if ($start -lt 0 -or $end -le $start) {
    throw "Text translation parity guard failed: $Description was not found."
  }
  return $Text.Substring($start, $end - $start)
}

function Assert-Contains([string]$Text, [string]$Marker, [string]$Message) {
  if (-not $Text.Contains($Marker)) {
    throw "Text translation parity guard failed: $Message"
  }
}

function Assert-Excludes([string]$Text, [string]$Marker, [string]$Message) {
  if ($Text.Contains($Marker)) {
    throw "Text translation parity guard failed: $Message ($Marker)."
  }
}

$root = Split-Path -Parent $PSScriptRoot
$catalogPath = Join-Path $root 'entry\src\main\ets\features\runtime\FeatureWorkflowCatalog.ets'
$catalog = Get-NormalizedText $catalogPath
$workflow = Get-TextSection `
  $catalog `
  'routeName: AppRoute.TEXT_TRANSLATION.name,' `
  'routeName: AppRoute.OBJECT_PHOTO.name,' `
  'workflow block'

Assert-Excludes $workflow "'liveCamera'" 'liveCamera is not an Android input'
Assert-Contains $workflow "inputKinds: ['text', 'camera', 'photo']" `
  'expected exactly text, camera, and photo inputs.'

$selector = Get-TextSection `
  $catalog `
  'export function usesAndroidTextTranslationLayout' `
  'export function runtimeInputKindsForWorkflow' `
  'exact layout selector'
Assert-Contains $selector 'AppRoute.TEXT_TRANSLATION.name' 'selector must target Text Translation.'

$aiServicePath = Join-Path $root 'entry\src\main\ets\services\ai\AiService.ets'
$aiService = Get-NormalizedText $aiServicePath
$projection = Get-TextSection `
  $aiService `
  'export function translatedTextForAiResult' `
  'export function segmentationMetadataWithBackground' `
  'translated-only projection'
Assert-Contains $projection "'feature_runtime_result_translated_text'" `
  'translated-only projection must read the translated row.'
Assert-Excludes $projection "'feature_runtime_result_text'" `
  'translated-only projection must not fall back to source text'

$pagePath = Join-Path $root 'entry\src\main\ets\pages\FeatureRuntimePage.ets'
$page = Get-NormalizedText $pagePath
foreach ($marker in @(
  'shouldShowTranslationSnapshotSaveAction',
  'translationSnapshotPreview',
  'translationSnapshotComponentId'
)) {
  Assert-Excludes $page $marker 'Android has no reachable translation snapshot save action'
}

$copyMethod = Get-TextSection `
  $page `
  '  private copyTranslatedText(): void {' `
  "`n`n  private updateUserText" `
  'translated-only Copy method'
Assert-Contains $copyMethod 'translatedTextForAiResult(this.resultRows)' `
  'dedicated Copy must use translated-only output.'
Assert-Contains $copyMethod 'this.showRuntimeToast(this.statusKey)' `
  'dedicated Copy must show Android-equivalent visible feedback.'
Assert-Excludes $copyMethod 'copyableTextForAiResult' `
  'dedicated Copy must not use the generic source fallback'

$builder = Get-TextSection `
  $page `
  '  textTranslationAndroidLayout() {' `
  "`n  build() {" `
  'dedicated Text Translation builder'
foreach ($marker in @(
  'this.runtimeActionToolbar(false)',
  'Text(translatedTextForAiResult(this.resultRows))',
  "this.prepareInput('photo')",
  "this.prepareInput('camera')",
  'this.copyTranslatedText()',
  'this.runtimePermissionRecoveryOverlay()'
)) {
  Assert-Contains $builder $marker "dedicated builder is missing $marker."
}

$photoIndex = $builder.IndexOf("Button(appString('feature_input_photo_android')", [StringComparison]::Ordinal)
$cameraIndex = $builder.IndexOf("Button(appString('feature_input_camera_android')", [StringComparison]::Ordinal)
$copyIndex = $builder.IndexOf("Button(appString('feature_runtime_copy_text')", [StringComparison]::Ordinal)
$permissionIndex = $builder.IndexOf('this.runtimePermissionRecoveryOverlay()', [StringComparison]::Ordinal)
if ($photoIndex -lt 0 -or $cameraIndex -le $photoIndex -or $copyIndex -le $cameraIndex) {
  throw 'Text translation parity guard failed: bottom actions must be Photo, Camera, Copy.'
}
if ($permissionIndex -le $copyIndex) {
  throw 'Text translation parity guard failed: permission recovery must render last.'
}

foreach ($marker in @(
  'this.summaryKey',
  'feature_runtime_inputs_title',
  'feature_runtime_permissions_title',
  'workflowResultTitleKey(',
  'this.resultRow(',
  'this.resultText',
  'resultImageSaveControl(',
  'resultComponentImageSaveControl(',
  'styleRecoveryControl(',
  'saveResult'
)) {
  Assert-Excludes $builder $marker 'dedicated builder contains generic debug/result/save UI'
}

$buildStart = $page.IndexOf("`n  build() {", [StringComparison]::Ordinal)
if ($buildStart -lt 0) {
  throw 'Text translation parity guard failed: page build method was not found.'
}
$build = $page.Substring($buildStart)
$selectorBranch = 'if (usesAndroidTextTranslationLayout(workflowForRoute(this.routeName)))'
$selectorIndex = $build.IndexOf($selectorBranch, [StringComparison]::Ordinal)
$genericIndex = $build.IndexOf("    } else {`n      Scroll() {", [StringComparison]::Ordinal)
if ($selectorIndex -lt 0 -or $genericIndex -lt 0 -or $selectorIndex -ge $genericIndex) {
  throw 'Text translation parity guard failed: dedicated selector must precede the generic fallback.'
}

Write-Output 'Text translation input parity guard passed.'
