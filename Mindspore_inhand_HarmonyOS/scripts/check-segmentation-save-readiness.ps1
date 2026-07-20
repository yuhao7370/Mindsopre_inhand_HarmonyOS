$ErrorActionPreference = 'Stop'

$pagePath = Join-Path $PSScriptRoot '..\entry\src\main\ets\pages\FeatureRuntimePage.ets'
$catalogPath = Join-Path $PSScriptRoot '..\entry\src\main\ets\features\runtime\FeatureWorkflowCatalog.ets'
$page = Get-Content -Raw -LiteralPath $pagePath
$catalog = Get-Content -Raw -LiteralPath $catalogPath

function Assert-SourcePattern([string] $source, [string] $pattern, [string] $message) {
  if ($source -notmatch $pattern) {
    throw $message
  }
}

Assert-SourcePattern $catalog `
  'shouldShowResultSaveAction[\s\S]*?return[\s\S]*?resultImageReady' `
  'Direct segmentation save must require a ready result PixelMap.'
Assert-SourcePattern $page `
  '@State\s+resultImageSaveInFlight:\s*boolean\s*=\s*false' `
  'Result-image save must track a single in-flight operation.'
Assert-SourcePattern $page `
  'segmentationForegroundPixelMap\s*!==\s*undefined\s*&&\s*!this\.resultImageSaveInFlight' `
  'Segmentation save must require the current ready PixelMap and no save in flight.'
Assert-SourcePattern $page `
  'if\s*\(this\.resultImageSaveInFlight\)[\s\S]*?return;[\s\S]*?this\.resultImageSaveInFlight\s*=\s*true' `
  'Result-image save entry must reject overlapping save attempts.'
Assert-SourcePattern $page `
  'finally\s*\{\s*this\.resultImageSaveInFlight\s*=\s*false;?\s*\}' `
  'Result-image save must clear single-flight state in finally.'

Write-Output 'Segmentation save requires a current ready PixelMap and is single-flight.'
