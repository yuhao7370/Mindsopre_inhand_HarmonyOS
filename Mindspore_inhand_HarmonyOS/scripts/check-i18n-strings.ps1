$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$resourceRoot = Join-Path $root 'entry/src/main/resources'
$locales = @('base', 'en_US', 'zh_CN')
$tables = @{}
$valueTables = @{}

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
  $values = @{}
  foreach ($entry in @($json.string)) {
    $values[$entry.name] = $entry.value
  }
  $valueTables[$locale] = $values
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

$baseValues = $valueTables['base']
$zhValues = $valueTables['zh_CN']
$baseZhMismatches = @($baseNames | Where-Object { $baseValues[$_] -ne $zhValues[$_] })
if ($baseZhMismatches.Count -gt 0) {
  throw "Base string resources must match zh_CN Android-style fallback values. Mismatched keys: $($baseZhMismatches -join ', ')"
}

$enValues = $valueTables['en_US']
foreach ($englishKey in @('main_tab_title_one', 'title_image', 'feature_runtime_run')) {
  if ($enValues[$englishKey] -eq $baseValues[$englishKey]) {
    throw "en_US string resource should remain localized separately from base for key: $englishKey"
  }
}

function Decode-Utf8Base64([string] $encoded) {
  return [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($encoded))
}

$visibleAndroidZhStringExpectations = @{
  experience_head_title = (Decode-Utf8Base64 '5L2T6aqM5Lit5b+D')
  experience_head_subtitle = (Decode-Utf8Base64 '5paw5LiA5Luj5YWo5Zy65pmvQUnorqHnrpfmoYbmnrbvvIzpgoDmgqjpqazkuIrkvZPpqow=')
  title_pose_net = (Decode-Utf8Base64 '6aqo6aq85qOA5rWL')
  college_cloud_title = (Decode-Utf8Base64 'MeWwj+aXtuS9k+mqjOerr+S6keWNj+WQjOWFqOa1geeoi+W8gOWPkQ==')
  college_train_title = (Decode-Utf8Base64 '6K6t57uD5qih5Z6L')
  college_execute_title = (Decode-Utf8Base64 '5omn6KGM5o6o55CG')
  college_app_title = (Decode-Utf8Base64 '56uv5L6n5bqU55So')
  college_video_title = (Decode-Utf8Base64 '5Y+C6ICD6KeG6aKR')
}

$visibleAndroidStringExpectations = @{
  base = $visibleAndroidZhStringExpectations
  zh_CN = $visibleAndroidZhStringExpectations
  en_US = @{
    experience_head_title = 'Experience Center'
    experience_head_subtitle = 'Invite you to explore a new generation of ALL-Scenario AI Computing Framework'
    title_pose_net = 'PoseNet'
    college_cloud_title = 'A One-Hour Trip to MindSpore'
    college_train_title = 'Train'
    college_execute_title = 'Inference'
    college_app_title = 'Applications'
    college_video_title = 'Video'
  }
}

foreach ($locale in $visibleAndroidStringExpectations.Keys) {
  $localeValues = $valueTables[$locale]
  foreach ($key in $visibleAndroidStringExpectations[$locale].Keys) {
    $expectedValue = $visibleAndroidStringExpectations[$locale][$key]
    if ($localeValues[$key] -ne $expectedValue) {
      throw "Visible Android string parity mismatch for ${locale}:$key. Expected '$expectedValue', got '$($localeValues[$key])'"
    }
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

$appStringUnionSlice = Get-SourceSlice `
  $appStringsSource `
  'export type AppStringKey =' `
  ';'
$unionKeys = @([regex]::Matches($appStringUnionSlice, "'([^']+)'") | ForEach-Object { $_.Groups[1].Value })
$unionDuplicates = @($unionKeys | Group-Object | Where-Object { $_.Count -gt 1 } | ForEach-Object { $_.Name })
if ($unionDuplicates.Count -gt 0) {
  throw "Duplicate AppStringKey union entries: $($unionDuplicates -join ', ')"
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

$unionMissing = @($baseNames | Where-Object { $_ -notin $unionKeys })
$unionExtra = @($unionKeys | Where-Object { $_ -notin $baseNames })
if ($unionMissing.Count -gt 0 -or $unionExtra.Count -gt 0) {
  throw "AppStringKey union mismatch with base resources. Missing: $($unionMissing -join ', ') Extra: $($unionExtra -join ', ')"
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
