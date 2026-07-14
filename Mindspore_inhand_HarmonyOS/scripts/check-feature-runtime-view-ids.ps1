param(
  [string] $PagePath = ''
)

$ErrorActionPreference = 'Stop'

if (-not $PagePath) {
  $PagePath = Join-Path $PSScriptRoot '..\entry\src\main\ets\pages\FeatureRuntimePage.ets'
}
$source = Get-Content -Raw -Encoding UTF8 $PagePath
$segmentationViewId = 'segmentationBackgroundReplacementComponentId'
$segmentationViewIdPattern = '\.id\(\s*' + [regex]::Escape($segmentationViewId) + '\s*\)'

function Get-SourceSlice([string] $text, [string] $startMarker, [string] $endMarker) {
  $start = $text.IndexOf($startMarker)
  if ($start -lt 0) {
    throw "Missing source marker: $startMarker"
  }
  $end = $text.IndexOf($endMarker, $start + $startMarker.Length)
  if ($end -lt 0) {
    throw "Missing source marker: $endMarker"
  }
  return $text.Substring($start, $end - $start)
}

$portraitComposite = Get-SourceSlice `
  $source `
  'portraitSegmentationComposite()' `
  'portraitSegmentationBackgroundStrip()'
$genericSegmentationPreview = Get-SourceSlice `
  $source `
  'segmentationBackgroundReplacementPreview(pixelMap: image.PixelMap)' `
  'segmentationBox(rectangle: SegmentationRectangle)'
$posePreview = Get-SourceSlice `
  $source `
  'posePreview(labelKey: AppStringKey, uri: string)' `
  'poseTemplatePreview()'

$bindingCount = [regex]::Matches($source, $segmentationViewIdPattern).Count
if ($bindingCount -ne 1) {
  throw "$segmentationViewId must appear exactly once in the full page source; found $bindingCount."
}

if ($genericSegmentationPreview -match $segmentationViewIdPattern) {
  throw "$segmentationViewId must not be attached to segmentationBackgroundReplacementPreview."
}

if ($posePreview -match $segmentationViewIdPattern) {
  throw "$segmentationViewId must not be attached to posePreview."
}

if ($portraitComposite -notmatch $segmentationViewIdPattern) {
  throw "$segmentationViewId must be attached to portraitSegmentationComposite."
}

Write-Output 'Feature runtime view ids are attached only to the expected portrait composite.'
