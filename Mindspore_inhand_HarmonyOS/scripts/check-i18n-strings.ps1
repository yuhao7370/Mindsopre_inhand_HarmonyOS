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

$appStringsPath = Join-Path $root 'entry/src/main/ets/common/i18n/AppStrings.ets'
$appStringsSource = Get-Content -Raw -Encoding UTF8 -LiteralPath $appStringsPath

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

function Get-AppStringArrayKeys([string] $text) {
  return @([regex]::Matches($text, "(?m)^\s*'([^']+)'\s*,?\s*(?://.*)?$") | ForEach-Object { $_.Groups[1].Value })
}

function Get-AppStringCaseKeys([string] $text) {
  return @([regex]::Matches($text, "(?m)^\s*case\s+'([^']+)'\s*:\s*$") | ForEach-Object { $_.Groups[1].Value })
}

$appStringKeysSlice = Get-SourceSlice `
  $appStringsSource `
  'const APP_STRING_KEYS: AppStringKey[] = [' `
  '];'
$typedKeys = Get-AppStringArrayKeys $appStringKeysSlice
$typedDuplicates = @($typedKeys | Group-Object | Where-Object { $_.Count -gt 1 } | ForEach-Object { $_.Name })
if ($typedDuplicates.Count -gt 0) {
  throw "Duplicate APP_STRING_KEYS entries: $($typedDuplicates -join ', ')"
}

$appStringSwitchSlice = Get-SourceSlice `
  $appStringsSource `
  'export function appString(key: AppStringKey): ResourceStr {' `
  '  }
}'
$caseKeys = Get-AppStringCaseKeys $appStringSwitchSlice
$caseDuplicates = @($caseKeys | Group-Object | Where-Object { $_.Count -gt 1 } | ForEach-Object { $_.Name })
if ($caseDuplicates.Count -gt 0) {
  throw "Duplicate appString switch cases: $($caseDuplicates -join ', ')"
}

$typedMissing = @($baseNames | Where-Object { $_ -notin $typedKeys })
$typedExtra = @($typedKeys | Where-Object { $_ -notin $baseNames })
if ($typedMissing.Count -gt 0 -or $typedExtra.Count -gt 0) {
  throw "APP_STRING_KEYS mismatch with base resources. Missing: $($typedMissing -join ', ') Extra: $($typedExtra -join ', ')"
}

$caseMissing = @($baseNames | Where-Object { $_ -ne 'empty' -and $_ -notin $caseKeys })
$caseExtra = @($caseKeys | Where-Object { $_ -notin $baseNames })
if ($caseMissing.Count -gt 0 -or $caseExtra.Count -gt 0) {
  throw "appString switch mismatch with base resources. Missing: $($caseMissing -join ', ') Extra: $($caseExtra -join ', ')"
}

Write-Host "i18n string resources and typed AppStrings are valid and aligned for $($locales -join ', ')"
