$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$catalogPath = Join-Path $root 'entry\src\main\ets\features\runtime\FeatureWorkflowCatalog.ets'
$catalog = (Get-Content -Raw -Encoding UTF8 -LiteralPath $catalogPath) -replace "`r`n", "`n"
$startMarker = 'routeName: AppRoute.TEXT_TRANSLATION.name,'
$endMarker = 'routeName: AppRoute.OBJECT_PHOTO.name,'
$start = $catalog.IndexOf($startMarker)
$end = $catalog.IndexOf($endMarker, $start + $startMarker.Length)

if ($start -lt 0 -or $end -le $start) {
  throw 'Text translation input parity guard failed: workflow block was not found.'
}

$workflow = $catalog.Substring($start, $end - $start)
if ($workflow.Contains("'liveCamera'")) {
  throw 'Text translation input parity guard failed: liveCamera is not an Android input.'
}
if (-not $workflow.Contains("inputKinds: ['text', 'camera', 'photo']")) {
  throw 'Text translation input parity guard failed: expected exactly text, camera, and photo inputs.'
}

$pagePath = Join-Path $root 'entry\src\main\ets\pages\FeatureRuntimePage.ets'
$page = (Get-Content -Raw -Encoding UTF8 -LiteralPath $pagePath) -replace "`r`n", "`n"
foreach ($marker in @(
  'shouldShowTranslationSnapshotSaveAction',
  'translationSnapshotPreview',
  'translationSnapshotComponentId'
)) {
  if ($page.Contains($marker)) {
    throw "Text translation parity guard failed: Android has no reachable translation snapshot save action ($marker)."
  }
}

Write-Output 'Text translation input parity guard passed.'
