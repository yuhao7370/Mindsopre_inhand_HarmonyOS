$root = Split-Path -Parent $PSScriptRoot
$permission = Get-Content (Join-Path $root 'entry/src/main/ets/services/permissions/PermissionService.ets') -Raw
$splash = Get-Content (Join-Path $root 'entry/src/main/ets/pages/SplashPage.ets') -Raw
$dance = Get-Content (Join-Path $root 'entry/src/main/ets/pages/DancePage.ets') -Raw

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
