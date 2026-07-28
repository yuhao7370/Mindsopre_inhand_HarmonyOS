$ErrorActionPreference = 'Stop'
$sourceRoot = Split-Path -Parent $PSScriptRoot
& (Join-Path $PSScriptRoot 'check-runtime-hidden-model-ui.ps1') -SourceRoot $sourceRoot | Out-Null

$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("hidden-feature-guard-" + [guid]::NewGuid().ToString('N'))
try {
  New-Item -ItemType Directory -Path (Join-Path $tempRoot 'entry\src\main\ets\common\data') -Force | Out-Null
  $relative = 'entry\src\main\ets\common\data\FeatureCatalog.ets'
  Copy-Item -LiteralPath (Join-Path $sourceRoot $relative) -Destination (Join-Path $tempRoot $relative)
  $path = Join-Path $tempRoot $relative
  $text = (Get-Content -Raw -Encoding UTF8 -LiteralPath $path).Replace(
    'routeName: AppRoute.DANCE.name, visibleByDefault: false',
    'routeName: AppRoute.DANCE.name, visibleByDefault: true'
  )
  Set-Content -Encoding UTF8 -LiteralPath $path -Value $text
  $rejected = $false
  try { & (Join-Path $PSScriptRoot 'check-runtime-hidden-model-ui.ps1') -SourceRoot $tempRoot | Out-Null }
  catch { $rejected = $true }
  if (-not $rejected) { throw 'Hidden feature guard accepted Dance Factory as public.' }
  Write-Output 'Hidden feature UI guard fixtures passed.'
}
finally {
  if (Test-Path -LiteralPath $tempRoot) { Remove-Item -LiteralPath $tempRoot -Recurse -Force }
}
