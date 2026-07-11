$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$pagePath = Join-Path $root 'entry/src/main/ets/pages/FeatureRuntimePage.ets'
$source = Get-Content -Raw -Encoding UTF8 -LiteralPath $pagePath

$forbiddenPatterns = @(
  'Text\s*\(\s*this\.(aiMethod|selectedInputSummary)\s*\)',
  'this\.resultText\s*=\s*this\.aiMethod',
  'this\.resultText\s*=\s*result\.detailText\.length\s*>\s*0\s*\?\s*result\.detailText\s*:\s*`\$\{result\.aiMethod\}'
)

$matches = @($forbiddenPatterns | Where-Object { $source -match $_ })
if ($matches.Count -gt 0) {
  throw "FeatureRuntimePage renders internal debug fields: $($matches -join ', ')"
}

Write-Host 'runtime UI debug-field check passed'
