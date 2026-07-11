$ErrorActionPreference = 'Stop'

$pagePath = Join-Path $PSScriptRoot '..\entry\src\main\ets\pages\FeatureRuntimePage.ets'
$source = Get-Content -Raw -Encoding UTF8 $pagePath
$segmentationViewId = 'segmentationBackgroundReplacementComponentId'
$translationViewId = 'translationSnapshotComponentId'

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

$segmentationPreview = Get-SourceSlice `
  $source `
  'segmentationBackgroundReplacementPreview(pixelMap: image.PixelMap)' `
  'segmentationBox(rectangle: SegmentationRectangle)'
$posePreview = Get-SourceSlice `
  $source `
  'posePreview(labelKey: AppStringKey, uri: string)' `
  'poseTemplatePreview()'
$translationPreview = Get-SourceSlice `
  $source `
  'translationSnapshotPreview()' `
  'filePreview(labelKey: AppStringKey, uri: string)'
$translationResultBranch = Get-SourceSlice `
  $source `
  'if (this.shouldShowTranslationSnapshotSave())' `
  '} else if (this.resultRows.length > 0)'

if ($segmentationPreview -notmatch ('\.id\(' + $segmentationViewId + '\)')) {
  throw "$segmentationViewId must be attached to the portrait background replacement preview Stack."
}

if ($posePreview -match ('\.id\(' + $segmentationViewId + '\)')) {
  throw "$segmentationViewId must not be attached to the pose preview Stack."
}

if ($translationPreview -notmatch ('\.id\(' + $translationViewId + '\)')) {
  throw "$translationViewId must be attached to the text-translation snapshot preview."
}

if ($segmentationPreview -match ('\.id\(' + $translationViewId + '\)')) {
  throw "$translationViewId must not be attached to the portrait background replacement preview Stack."
}

if ($translationResultBranch -notmatch 'this\.translationSnapshotPreview\(\)') {
  throw 'Text-translation image-result branch must render translationSnapshotPreview().'
}

if ($translationResultBranch -notmatch ('this\.resultComponentImageSaveControl\(' + $translationViewId + '\)')) {
  throw "Text-translation image-result branch must save $translationViewId."
}

Write-Output 'Feature runtime view ids are attached to the expected preview components.'
