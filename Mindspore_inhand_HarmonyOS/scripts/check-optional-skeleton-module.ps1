$ErrorActionPreference = 'Stop'

$appRoot = Split-Path -Parent $PSScriptRoot
$paths = @(
  'entry\src\main\ets\services\ai\PoseService.ets',
  'entry\src\main\ets\services\dance\DanceSamplingService.ets'
)

foreach ($path in $paths) {
  $content = Get-Content -Raw -LiteralPath (Join-Path $appRoot $path)
  if ($content.Contains('skeletonDetection.SkeletonPointType')) {
    throw "Optional skeleton module guard failed: runtime enum access remains in $path"
  }
}

Write-Output 'Optional skeleton module guard passed.'
