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

$androidAppName = Decode-Utf8Base64 'TWluZFNwb3Jl5o6M5Lit5a6d'
$androidEnglishShareRecommendation = Decode-Utf8Base64 'TWluZFNwb3Jl5o6M5Lit5a6d77yaQSBvbmUtc3RvcCBwbGF0Zm9ybSBvZiBjb2xsYWJvcmF0aXZlIGxlYXJuaW5nLCBkZW1vbnN0cmF0aW5nLCBhbmQgZXhwZXJpZW5jaW5nIGZvciBBSSB1c2Vycy4J'

$appScopeStringPath = Join-Path $root 'AppScope/resources/base/element/string.json'
$appScopeJson = Get-Content -Raw -Encoding UTF8 -LiteralPath $appScopeStringPath | ConvertFrom-Json
$appScopeAppName = @($appScopeJson.string | Where-Object { $_.name -eq 'app_name' })[0].value
if ($appScopeAppName -ne $androidAppName) {
  throw "AppScope app_name must match Android app_name '$androidAppName', got '$appScopeAppName'"
}

foreach ($locale in $locales) {
  if ($valueTables[$locale]['EntryAbility_label'] -ne $androidAppName) {
    throw "EntryAbility_label for $locale must match Android app_name '$androidAppName', got '$($valueTables[$locale]['EntryAbility_label'])'"
  }
}

if ($enValues['title_share_commend'] -ne $androidEnglishShareRecommendation) {
  throw "en_US title_share_commend must match Android values-en copy."
}

$visibleAndroidZhStringExpectations = @{
  experience_head_title = (Decode-Utf8Base64 '5L2T6aqM5Lit5b+D')
  experience_head_subtitle = (Decode-Utf8Base64 '5paw5LiA5Luj5YWo5Zy65pmvQUnorqHnrpfmoYbmnrbvvIzpgoDmgqjpqazkuIrkvZPpqow=')
  title_splash_welcome = (Decode-Utf8Base64 'QUnniLHlpb3ogIXnmoTkuIDnq5nlvI/ljY/lkIzlrabkuaDjgIHmvJTnpLrjgIHkvZPpqozlubPlj7A=')
  title_share_commend = (Decode-Utf8Base64 'TWluZFNwb3Jl5o6M5Lit5a6d77yaQUnniLHlpb3ogIXnmoTkuIDnq5nlvI/ljY/lkIzlrabkuaDjgIHmvJTnpLrjgIHkvZPpqozlubPlj7AJ')
  me_share_title = (Decode-Utf8Base64 '5LiA6ZSu5YiG5Lqr')
  me_version_title = (Decode-Utf8Base64 '54mI5pys5Y+3')
  title_pose_net = (Decode-Utf8Base64 '6aqo6aq85qOA5rWL')
  title_scene_detection = (Decode-Utf8Base64 '5Zy65pmv5qOA5rWL')
  title_object_photo_detection = (Decode-Utf8Base64 '54Wn54mH5qOA5rWL')
  title_object_camera_detection = (Decode-Utf8Base64 '6KeG6aKR5qOA5rWL')
  college_summary_title = (Decode-Utf8Base64 'TWluZFNwb3Jl566A5LuL')
  college_cloud_title = (Decode-Utf8Base64 'MeWwj+aXtuS9k+mqjOerr+S6keWNj+WQjOWFqOa1geeoi+W8gOWPkQ==')
  college_train_title = (Decode-Utf8Base64 '6K6t57uD5qih5Z6L')
  college_execute_title = (Decode-Utf8Base64 '5omn6KGM5o6o55CG')
  college_app_title = (Decode-Utf8Base64 '56uv5L6n5bqU55So')
  college_video_title = (Decode-Utf8Base64 '5Y+C6ICD6KeG6aKR')
  me_user_agreement = (Decode-Utf8Base64 '44CK55So5oi35Y2P6K6u5ZKM6ZqQ56eB5pS/562W44CL')
  title_intelligent_poetry = (Decode-Utf8Base64 '5pm66IO95YaZ6K+X')
  poem_save_poster = (Decode-Utf8Base64 '5L+d5a2Y5Zu+54mH')
  poem_share_poster = (Decode-Utf8Base64 '5YiG5Lqr5Zu+54mH')
  poem_save_success = (Decode-Utf8Base64 '5L+d5a2Y5oiQ5Yqf')
  poem_save_failed = (Decode-Utf8Base64 '5L+d5a2Y5aSx6LSl')
  poem_ai_credit = (Decode-Utf8Base64 '55SxTWluZFNwb3JlIEFJ5oqA5pyv55Sf5oiQ')
  dance_reference_video_downloading = (Decode-Utf8Base64 '6Iie6LmI6KeG6aKR5LiL6L295LitIC4uLg==')
  dance_reference_video_failed = (Decode-Utf8Base64 '5LiL6L295aSx6LSl')
  dance_score_prefix = (Decode-Utf8Base64 '5oGt5Zac5a6M5oiQ77yM57u85ZCI5b6X5YiG77ya')
  dance_score_level_no_action = (Decode-Utf8Base64 '6K+35Yqo6LW35p2l5ZOm77yB')
  dance_score_level_no_point = (Decode-Utf8Base64 '6K+35YWo6Lqr5Ye66ZWc5bGV56S65L2g55qE6aOO6YeH77yB')
  dance_score_level_try_again = (Decode-Utf8Base64 '5pyJ54K56YKj5Liq5ZGz5LqG77yB')
  dance_score_level_warmup = (Decode-Utf8Base64 '6JCM5paw6K+05b6X5bCx5piv5L2g77yB')
  dance_score_level_good = (Decode-Utf8Base64 '5aW95Y6J5a6z77yM5L2g5piv5LiT5Lia55qE5ZCX77yf')
  dance_score_level_great = (Decode-Utf8Base64 '5L2g5piv6L+Z5p2h6KGX5pyA6Z2T55qE5LuU77yB')
  dance_score_level_excellent = (Decode-Utf8Base64 '6ZqQ6JeP5Zyo5rCR6Ze055qE6auY5omL77yB')
  dance_score_level_perfect = (Decode-Utf8Base64 '57uZ5aSn56We54yu5LiK6Iad55uW77yB')
  dance_score_level_full = (Decode-Utf8Base64 '6L+Z5Liq6Iie5Y+w5bGe5LqO5L2g77yB')
  feature_runtime_preview_title = (Decode-Utf8Base64 '5Zu+54mH6aKE6KeI')
  feature_runtime_object_select_model = (Decode-Utf8Base64 '6YCJ5oup5qih5Z6L')
  feature_runtime_result_score = (Decode-Utf8Base64 '5b6X5YiG')
  feature_runtime_result_scene_count = (Decode-Utf8Base64 '5Zy65pmv6K6h5pWw')
  feature_runtime_scene_overlay_count = (Decode-Utf8Base64 '5Zy65pmv6K6h5pWw')
  feature_runtime_scene_overlay_score = (Decode-Utf8Base64 '5b6X5YiG')
  feature_runtime_result_execution_time = (Decode-Utf8Base64 '5o6o55CG5pe26Ze077ya')
  title_source = (Decode-Utf8Base64 '5Luj56CB')
}

$visibleAndroidStringExpectations = @{
  base = $visibleAndroidZhStringExpectations
  zh_CN = $visibleAndroidZhStringExpectations
  en_US = @{
    experience_head_title = 'Experience Center'
    experience_head_subtitle = 'Invite you to explore a new generation of ALL-Scenario AI Computing Framework'
    title_pose_net = 'PoseNet'
    title_object_photo_detection = 'Photo Detection'
    title_object_camera_detection = 'Camera Detection'
    college_cloud_title = 'A One-Hour Trip to MindSpore'
    college_train_title = 'Train'
    college_execute_title = 'Inference'
    college_app_title = 'Applications'
    college_video_title = 'Video'
    title_intelligent_poetry = 'Intelligent poetry'
    poem_save_poster = 'save the picture'
    poem_share_poster = 'share the picture'
    poem_save_success = 'save successfully'
    poem_save_failed = 'Save failure'
    dance_reference_video_failed = 'Download failed'
    dance_reference_video_downloading = 'Downloading dance video ...'
    feature_runtime_preview_title = 'Image Preview'
    feature_runtime_object_select_model = 'Select Model'
    feature_runtime_result_score = 'Score'
    feature_runtime_result_scene_count = 'Scene Count'
    feature_runtime_scene_overlay_count = 'Scene Count'
    feature_runtime_scene_overlay_score = 'Score'
    feature_runtime_result_execution_time = 'Inference Time:'
    title_source = 'Code'
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
