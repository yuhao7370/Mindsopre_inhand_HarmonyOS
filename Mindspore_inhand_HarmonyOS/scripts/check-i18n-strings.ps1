$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$resourceRoot = Join-Path $root 'entry/src/main/resources'
$locales = @('base', 'en_US', 'zh_CN')
$tables = @{}

foreach ($locale in $locales) {
  $path = Join-Path $resourceRoot "$locale/element/string.json"
  try {
    $json = Get-Content -Raw -Encoding UTF8 -LiteralPath $path | ConvertFrom-Json
  } catch {
    throw "Invalid string resource JSON: $path`n$($_.Exception.Message)"
  }
  $names = @($json.string | ForEach-Object { $_.name })
  $duplicates = @($names | Group-Object | Where-Object { $_.Count -gt 1 } | ForEach-Object { $_.Name })
  if ($duplicates.Count -gt 0) {
    throw "Duplicate string keys for ${locale}: $($duplicates -join ', ')"
  }
  $tables[$locale] = $names
}

$baseNames = @($tables['base'])
foreach ($locale in @('en_US', 'zh_CN')) {
  $names = @($tables[$locale])
  $missing = @($baseNames | Where-Object { $_ -notin $names })
  $extra = @($names | Where-Object { $_ -notin $baseNames })
  if ($missing.Count -gt 0 -or $extra.Count -gt 0) {
    throw "String key mismatch for $locale. Missing: $($missing -join ', ') Extra: $($extra -join ', ')"
  }
}

Write-Host "i18n string resources are valid and aligned for $($locales -join ', ')"
