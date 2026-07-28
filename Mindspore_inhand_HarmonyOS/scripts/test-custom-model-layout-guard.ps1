$ErrorActionPreference = 'Stop'
$sourceRoot = Split-Path -Parent $PSScriptRoot
& (Join-Path $PSScriptRoot 'check-custom-model-layout-parity.ps1') -SourceRoot $sourceRoot | Out-Null

$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("custom-model-guard-" + [guid]::NewGuid().ToString('N'))
try {
  $required = @(
    'entry\src\main\ets\common\data\FeatureCatalog.ets',
    'entry\src\main\ets\features\runtime\FeatureWorkflowCatalog.ets',
    'entry\src\main\ets\pages\FeatureRuntimePage.ets',
    'entry\src\main\ets\services\picker\ModelFileCacheService.ets'
  )
  foreach ($relative in $required) {
    $target = Join-Path $tempRoot $relative
    New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $sourceRoot $relative) -Destination $target
  }
  $catalog = Join-Path $tempRoot 'entry\src\main\ets\common\data\FeatureCatalog.ets'
  $text = Get-Content -Raw -Encoding UTF8 -LiteralPath $catalog
  $text = $text.Replace(
    "routeName: AppRoute.CUSTOM_MODEL.name, visibleByDefault: true",
    "routeName: AppRoute.CUSTOM_MODEL.name, visibleByDefault: false"
  )
  Set-Content -Encoding UTF8 -LiteralPath $catalog -Value $text
  $rejected = $false
  try { & (Join-Path $PSScriptRoot 'check-custom-model-layout-parity.ps1') -SourceRoot $tempRoot | Out-Null }
  catch { $rejected = $true }
  if (-not $rejected) { throw 'Custom Model guard accepted a hidden Custom Model entry.' }
  Write-Output 'Custom Model layout guard fixtures passed.'
}
finally {
  if (Test-Path -LiteralPath $tempRoot) { Remove-Item -LiteralPath $tempRoot -Recurse -Force }
}
