param([string]$SourceRoot = '')
$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($SourceRoot)) { $SourceRoot = Split-Path -Parent $PSScriptRoot }
$catalog = Get-Content -Raw -Encoding UTF8 -LiteralPath (
  Join-Path $SourceRoot 'entry\src\main\ets\common\data\FeatureCatalog.ets'
)
foreach ($marker in @(
  "{ id: 'dance', title: 'Dance Factory'",
  "routeName: AppRoute.DANCE.name, visibleByDefault: false",
  "{ id: 'poetry', title: 'Intelligent poetry'",
  "routeName: AppRoute.POETRY.name, visibleByDefault: false",
  'items: section.items.filter((item: FeatureItem) => item.visibleByDefault)'
)) {
  if (-not $catalog.Contains($marker)) { throw "Hidden feature guard missing: $marker" }
}
Write-Output 'Hidden feature UI guard passed.'
