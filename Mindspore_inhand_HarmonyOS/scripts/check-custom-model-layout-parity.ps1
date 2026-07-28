param([string]$SourceRoot = '')
$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($SourceRoot)) { $SourceRoot = Split-Path -Parent $PSScriptRoot }

function Read-Text([string]$RelativePath) {
  Get-Content -Raw -Encoding UTF8 -LiteralPath (Join-Path $SourceRoot $RelativePath)
}
function Require([string]$Text, [string]$Marker) {
  if (-not $Text.Contains($Marker)) { throw "Custom Model guard missing: $Marker" }
}

$catalog = Read-Text 'entry\src\main\ets\common\data\FeatureCatalog.ets'
$workflow = Read-Text 'entry\src\main\ets\features\runtime\FeatureWorkflowCatalog.ets'
$page = Read-Text 'entry\src\main\ets\pages\FeatureRuntimePage.ets'
$cache = Read-Text 'entry\src\main\ets\services\picker\ModelFileCacheService.ets'

Require $catalog "{ id: 'custom', title: 'Custom Model', titleKey: 'title_custom_model', icon: 'model', routeName: AppRoute.CUSTOM_MODEL.name, visibleByDefault: true }"
foreach ($marker in @(
  'export function customModelVisibleInputs(',
  "return kind === 'image' ? ['photo', 'camera'] : ['text'];",
  'export function customModelCanExecute('
)) { Require $workflow $marker }
foreach ($marker in @(
  'customModelAndroidLayout() {',
  "this.prepareInput('modelFile')",
  "if (this.customModelInputKind === 'text') {",
  'TextArea({',
  "this.prepareInput('photo')",
  "this.prepareInput('camera')",
  'customModelCanExecute(',
  'this.customModelInputSummary',
  'Text(this.customModelOutputText())'
)) { Require $page $marker }
foreach ($marker in @(
  'customModelPackage?: CustomModelPackageDescriptor',
  'packageService.loadCurrentPackage(cacheDir)',
  'customModelPackage: customPackage'
)) { Require $cache $marker }

Write-Output 'Custom Model layout parity guard passed.'
