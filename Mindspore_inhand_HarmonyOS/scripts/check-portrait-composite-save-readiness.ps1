$ErrorActionPreference = 'Stop'

$pagePath = Join-Path $PSScriptRoot '..\entry\src\main\ets\pages\FeatureRuntimePage.ets'
$catalogPath = Join-Path $PSScriptRoot '..\entry\src\main\ets\features\runtime\FeatureWorkflowCatalog.ets'
$page = (Get-Content -Raw -LiteralPath $pagePath).Replace("`r`n", "`n")
$catalog = (Get-Content -Raw -LiteralPath $catalogPath).Replace("`r`n", "`n")

function Section([string]$Text, [string]$Start, [string]$End, [string]$Label) {
  $startIndex = $Text.IndexOf($Start, [StringComparison]::Ordinal)
  $endIndex = if ($startIndex -ge 0) { $Text.IndexOf($End, $startIndex + $Start.Length, [StringComparison]::Ordinal) } else { -1 }
  if ($startIndex -lt 0 -or $endIndex -le $startIndex) { throw "Missing portrait composite $Label section." }
  return $Text.Substring($startIndex, $endIndex - $startIndex)
}

function Compact([string]$Text) {
  return [regex]::Replace($Text, '\s+', '')
}

$control = Section $page '  resultComponentImageSaveControl(componentId: string) {' "`n`n  @Builder`n  filePreview" 'control'
$toolbar = Section $page '  portraitSegmentationToolbar() {' "`n`n  @Builder`n  portraitSegmentationComposite" 'toolbar'
$entry = Section $page '  private async saveResultComponentImageAsync(componentId: string): Promise<void> {' "`n`n  private async saveResultPixelMapAsync" 'async entry'
$helper = Section $catalog 'export function compositeSegmentationSaveReady(' "`n}`n" 'readiness helper'

$requiredCall = 'compositeSegmentationSaveReady(this.workflowRunning, this.segmentationForegroundPixelMap !== undefined, this.resultImageSaveInFlight)'
$compactControl = Compact $control
$compactToolbar = Compact $toolbar
$compactEntry = Compact $entry
$compactControlCall = Compact ".enabled($requiredCall)"
$compactEntryCall = Compact "if (!$requiredCall)"
if (-not $compactControl.Contains($compactControlCall)) {
  throw 'Portrait composite rendered save control must require idle workflow, current PixelMap, and no save in flight.'
}
if (-not $compactToolbar.Contains($compactControlCall)) {
  throw 'Portrait composite toolbar save must require idle workflow, current PixelMap, and no save in flight.'
}
if (-not $compactEntry.Contains($compactEntryCall)) {
  throw 'Portrait composite async save entry must recheck idle workflow, current PixelMap, and no save in flight.'
}
if (-not $entry.Contains('this.resultImageSaveInFlight = true') -or
    -not $entry.Contains('finally {') -or
    -not $entry.Contains('this.resultImageSaveInFlight = false')) {
  throw 'Portrait composite async entry must hold and release the single-flight gate around the save.'
}
foreach ($condition in @('!workflowRunning', 'foregroundReady', '!saveInFlight')) {
  if (-not $helper.Contains($condition)) { throw "Portrait composite readiness helper is missing $condition." }
}

Write-Host 'Portrait composite save requires an idle workflow, current PixelMap, and single-flight ownership.'
