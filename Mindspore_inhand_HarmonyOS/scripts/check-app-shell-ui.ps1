$root = Split-Path -Parent $PSScriptRoot
$permission = Get-Content (Join-Path $root 'entry/src/main/ets/services/permissions/PermissionService.ets') -Raw
$splash = Get-Content (Join-Path $root 'entry/src/main/ets/pages/SplashPage.ets') -Raw
$dance = Get-Content (Join-Path $root 'entry/src/main/ets/pages/DancePage.ets') -Raw
$appTheme = Get-Content (Join-Path $root 'entry/src/main/ets/common/theme/AppTheme.ets') -Raw

if ($permission -match 'requestStartup|startupPermissionNames') {
  throw 'Startup permission API must not exist.'
}
if ($splash -match 'PermissionService|showPermissionDialog|permissionDialog|requestPermissionsFromUser|abilityAccessCtrl|ohos\.permission\.CAMERA|ohos\.permission\.READ_IMAGEVIDEO') {
  throw 'Splash must not request or recover runtime permissions.'
}
if ($splash -notmatch 'aboutToAppear\(\)\s*\{\s*const service = this\.privacyConsentService\(\);\s*if \(service !== undefined && service\.hasAcceptedPrivacy\(\)\) \{\s*this\.onFinished\(\);\s*return;\s*\}\s*this\.showPrivacyDialog = true;\s*\}') {
  throw 'Stored privacy consent must finish Splash immediately.'
}
if ($splash -match 'countdownTimer|countdownValue|startCountdown|countdownButton|setInterval') {
  throw 'Returning users must not wait on a second splash countdown.'
}
if ($splash -notmatch 'private\s+acceptPrivacy\(\):\s*void\s*\{\s*const service = this\.privacyConsentService\(\);\s*if \(service !== undefined\) \{\s*service\.acceptPrivacy\(\);\s*\}\s*this\.showPrivacyDialog = false;\s*this\.finishSplash\(\);\s*\}') {
  throw 'First privacy consent must persist and finish Splash immediately.'
}
if ($permission -notmatch 'async\s+requestCamera\([^)]*\)[\s\S]*?\{\s*return\s+this\.requestPermissionNames\(context,\s*\[\s*cameraPermissionName\s*\]\);\s*\}') {
  throw 'Dance camera permission must have an explicit camera-only API.'
}
if ($dance -notmatch 'new PermissionService\(\)\.requestCamera\(context\)') {
  throw 'Dance must request camera only.'
}
if ($splash -match '\.height\(180\)|\.height\(38\)') {
  throw 'Consent must not use fixed text or action heights.'
}
function Get-BracedBody([string]$source, [string]$marker) {
  $markerIndex = $source.IndexOf($marker, [System.StringComparison]::Ordinal)
  if ($markerIndex -lt 0) { throw "Missing marker: $marker" }
  $openIndex = $source.IndexOf('{', $markerIndex)
  if ($openIndex -lt 0) { throw "Missing block after: $marker" }
  $depth = 0
  for ($index = $openIndex; $index -lt $source.Length; $index += 1) {
    if ($source[$index] -eq '{') { $depth += 1 }
    if ($source[$index] -eq '}') {
      $depth -= 1
      if ($depth -eq 0) {
        return $source.Substring($openIndex + 1, $index - $openIndex - 1)
      }
    }
  }
  throw "Unclosed block after: $marker"
}

$privacyDialog = Get-BracedBody $splash 'privacyDialog()'
if ([regex]::Matches($privacyDialog, 'Scroll\(\)').Count -ne 1) {
  throw 'Consent must contain exactly one Scroll.'
}
$consentScroll = Get-BracedBody $privacyDialog 'Scroll()'
@('me_user_agreements', 'me_privacy', 'me_user_agreement', 'me_disagree_and_exit', 'me_agree') |
  ForEach-Object {
    if ($consentScroll -notmatch [regex]::Escape($_)) {
      throw "Consent Scroll is missing: $_"
    }
  }
if ($consentScroll.IndexOf('me_user_agreements') -gt $consentScroll.IndexOf('me_agree')) {
  throw 'Consent actions must follow the title and copy.'
}
@('me_user_agreement', 'me_disagree_and_exit', 'me_agree') |
  ForEach-Object {
    $actionPattern = "Button\(appString\('$($_)'\)(?:,\s*\{[^}]*\})?\)(?:(?!Button\()[\s\S])*?\.constraintSize\(\{\s*minHeight:\s*48\s*\}"
    if ($consentScroll -notmatch $actionPattern) {
      throw "Consent action must be at least 48vp: $_"
    }
  }
$build = Get-BracedBody $splash 'build()'
$brandBackgroundPattern = "Column\(\)\s*\{[\s\S]*?\}\s*\.width\('100%'\)\s*\.height\('100%'\)\s*\.backgroundColor\(AppColor\.pageBackground\)\s*\.accessibilityLevel\(this\.showPrivacyDialog\s*\?\s*'no-hide-descendants'\s*:\s*'auto'\)"
if ($build -notmatch $brandBackgroundPattern) {
  throw 'Consent background accessibility hiding must be limited to the active dialog.'
}
if ($build -match "Column\(\)\s*\{[\s\S]*?\}\s*\.width\('100%'\)\s*\.height\('100%'\)\s*\.backgroundColor\(AppColor\.pageBackground\)\s*\.accessibilityLevel\('no-hide-descendants'\)") {
  throw 'Consent background accessibility hiding must not be unconditional.'
}
if ($appTheme -notmatch 'readonly\s+textAccent:\s*string' -or
  $appTheme -notmatch "cardBackground:\s*'#FFFFFF'" -or
  $appTheme -notmatch "textAccent:\s*'#0B3A82'") {
  throw 'Theme must retain the approved 10.81:1 text accent on the white card.'
}
if ($splash -notmatch 'Button\(appString\(''me_user_agreement''\),\s*\{\s*type:\s*ButtonType\.Normal\s*\}\)[\s\S]*?\.fontColor\(AppColor\.textAccent\)') {
  throw 'Consent agreement link must use the text accent button style.'
}
