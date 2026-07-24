function Test-AppShellUiGuard {
  param(
    [string]$Permission,
    [string]$Splash,
    [string]$Dance
  )

  if ($Permission -match 'requestStartup|startupPermissionNames') {
    return $false
  }
  if ($Splash -match 'PermissionService|showPermissionDialog|permissionDialog|requestPermissionsFromUser|abilityAccessCtrl|ohos\.permission\.CAMERA|ohos\.permission\.READ_IMAGEVIDEO') {
    return $false
  }
  if ($Splash -notmatch 'aboutToAppear\(\)\s*\{\s*const service = this\.privacyConsentService\(\);\s*if \(service !== undefined && service\.hasAcceptedPrivacy\(\)\) \{\s*this\.onFinished\(\);\s*return;\s*\}\s*this\.showPrivacyDialog = true;\s*\}') {
    return $false
  }
  if ($Splash -match 'countdownTimer|countdownValue|startCountdown|countdownButton|setInterval') {
    return $false
  }
  if ($Splash -notmatch 'private\s+acceptPrivacy\(\):\s*void\s*\{\s*const service = this\.privacyConsentService\(\);\s*if \(service !== undefined\) \{\s*service\.acceptPrivacy\(\);\s*\}\s*this\.showPrivacyDialog = false;\s*this\.finishSplash\(\);\s*\}') {
    return $false
  }
  if ($Permission -notmatch 'async\s+requestCamera\([^)]*\)[\s\S]*?\{\s*return\s+this\.requestPermissionNames\(context,\s*\[\s*cameraPermissionName\s*\]\);\s*\}') {
    return $false
  }
  return $Dance -match 'new PermissionService\(\)\.requestCamera\(context\)'
}

function Assert-RejectedMutation {
  param(
    [string]$Name,
    [string]$Permission,
    [string]$Splash,
    [string]$Dance
  )

  if (Test-AppShellUiGuard $Permission $Splash $Dance) {
    throw "Guard accepted mutation: $Name"
  }
}

$root = Split-Path -Parent $PSScriptRoot
$permission = Get-Content (Join-Path $root 'entry/src/main/ets/services/permissions/PermissionService.ets') -Raw
$splash = Get-Content (Join-Path $root 'entry/src/main/ets/pages/SplashPage.ets') -Raw
$dance = Get-Content (Join-Path $root 'entry/src/main/ets/pages/DancePage.ets') -Raw

if (-not (Test-AppShellUiGuard $permission $splash $dance)) {
  throw 'Guard fixture must pass.'
}

Assert-RejectedMutation 'camera API removed' ($permission -replace 'requestCamera', 'request') $splash $dance
Assert-RejectedMutation 'camera-only list widened' ($permission -replace '\[cameraPermissionName\]', '[cameraPermissionName, mediaPermissionName]') $splash $dance
Assert-RejectedMutation 'startup API restored' ($permission + ' requestStartup') $splash $dance
Assert-RejectedMutation 'Splash permission service restored' $permission ($splash + ' PermissionService') $dance
Assert-RejectedMutation 'Splash permission dialog restored' $permission ($splash + ' showPermissionDialog') $dance
Assert-RejectedMutation 'Splash permission builder restored' $permission ($splash + ' permissionDialog') $dance
Assert-RejectedMutation 'Splash direct permission manager restored' $permission ($splash + "`nconst manager = abilityAccessCtrl.createAtManager(); manager.requestPermissionsFromUser(context, ['ohos.permission.CAMERA', 'ohos.permission.READ_IMAGEVIDEO']);") $dance
Assert-RejectedMutation 'Splash alias permission manager restored' $permission ($splash + "`nconst requestManager = abilityAccessCtrl.createAtManager(); requestManager.requestPermissionsFromUser(context, ['ohos.permission.CAMERA', 'ohos.permission.READ_IMAGEVIDEO']);") $dance
Assert-RejectedMutation 'stored consent no longer finishes immediately' $permission ($splash -replace 'this\.onFinished\(\);\s*return;', 'this.finishSplash(); return;') $dance
Assert-RejectedMutation 'countdown interval restored' $permission ($splash + "`nsetInterval(() => {}, 1000);") $dance
Assert-RejectedMutation 'first consent no longer persists before finishing' $permission ($splash -replace 'service\.acceptPrivacy\(\);', '') $dance
Assert-RejectedMutation 'Dance camera request removed' $permission $splash ($dance -replace 'requestCamera', 'request')
