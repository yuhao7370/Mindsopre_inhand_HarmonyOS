function Remove-SourceComments([string]$source) {
  $withoutBlockComments = [regex]::Replace($source, '/\*[\s\S]*?\*/', '')
  return [regex]::Replace($withoutBlockComments, '(?m)//.*$', '')
}

function Test-EntryAbilityLightColorMode([string]$source) {
  $withoutComments = Remove-SourceComments $source
  return $withoutComments -match '(?m)^\s*this\.context\.getApplicationContext\(\)\.setColorMode\(\s*ConfigurationConstant\.ColorMode\.COLOR_MODE_LIGHT\s*\);\s*$'
}

function Get-Json5StringProperty([string]$source, [string]$property) {
  $withoutComments = Remove-SourceComments $source
  $escapedProperty = [regex]::Escape($property)
  $pattern = "(?m)^\s*`"$escapedProperty`"\s*:\s*`"(?<value>[^`"]*)`"\s*,?\s*$"
  $matches = [regex]::Matches($withoutComments, $pattern)
  if ($matches.Count -ne 1) { return $null }
  return $matches[0].Groups['value'].Value
}

function Test-DarkStartWindowBackground([string]$source) {
  try {
    $resource = $source | ConvertFrom-Json -ErrorAction Stop
    $startWindowColors = @($resource.color | Where-Object { $_.name -ceq 'start_window_background' })
    return $startWindowColors.Count -eq 1 -and $startWindowColors[0].value -ceq '#FFFFFF'
  } catch {
    return $false
  }
}

function Test-BottomTabBarContract([string]$source, [string]$layoutSpec) {
  try {
    $bottomTabSource = Remove-SourceComments $source
    $layoutSpecSource = Remove-SourceComments $layoutSpec
    if ($layoutSpecSource -notmatch '(?m)^\s*export\s+const\s+bottomTabBarMaxWidthVp:\s*number\s*=\s*500\s*;\s*$') { return $false }

    $build = Get-BracedBody $bottomTabSource 'build()'
    $tabItemPattern = 'ForEach\(this\.tabs,\s*\(tab:\s*TabItem\)\s*=>\s*\{\s*Column\(\)\s*\{[\s\S]*?\}\s*\.layoutWeight\(1\)[\s\S]*?\.accessibilityGroup\(true\)[\s\S]*?\.accessibilityText\(appString\(tab\.titleKey\) as Resource\)[\s\S]*?\.accessibilityRole\(AccessibilityRoleType\.BUTTON\)[\s\S]*?\.accessibilitySelected\(this\.selected === tab\.id\)[\s\S]*?\.onClick\(\(\) => this\.onChange\(tab\.id\)\)'
    if ($build -notmatch $tabItemPattern) { return $false }
    if ($build -notmatch "Image\(mainTabIconMediaResource\(tab,\s*this\.selected === tab\.id\)\)\s*\.width\(22\)\s*\.height\(22\)\s*\.objectFit\(ImageFit\.Contain\)\s*\.accessibilityLevel\('no'\)\s*Text\(appString\(tab\.titleKey\)\)") { return $false }
    if ($build -notmatch 'Text\(appString\(tab\.titleKey\)\)[\s\S]*?\.fontSize\(11\)[\s\S]*?\.fontColor\(this\.selected === tab\.id \? AppColor\.textAccent : AppColor\.textSecondary\)') { return $false }
    if ($build -notmatch "Row\(\)\s*\{[\s\S]*?\}\s*\.width\('90%'\)\s*\.constraintSize\(\{\s*minHeight:\s*bottomTabBarMinHeightVp,\s*maxWidth:\s*bottomTabBarMaxWidthVp\s*\}\)\s*\.margin\([\s\S]*?\.borderRadius\(31\)[\s\S]*?\.shadow\(") { return $false }
    return $true
  } catch {
    return $false
  }
}

function Test-AppShellUiGuard {
  param(
    [string]$Permission,
    [string]$Splash,
    [string]$Dance,
    [string]$EntryAbility = $script:entryAbility,
    [string]$Module = $script:module,
    [string]$DarkColor = $script:darkColor,
    [string]$AppTheme = $script:appTheme,
    [string]$BottomTab = $script:bottomTab,
    [string]$BottomTabLayoutSpec = $script:bottomTabLayoutSpec
  )

  try {
    if ($Permission -match 'requestStartup|startupPermissionNames') { return $false }
    if ($Splash -match 'PermissionService|showPermissionDialog|permissionDialog|requestPermissionsFromUser|abilityAccessCtrl|ohos\.permission\.CAMERA|ohos\.permission\.READ_IMAGEVIDEO') { return $false }
    if ($Splash -notmatch 'aboutToAppear\(\)\s*\{\s*const service = this\.privacyConsentService\(\);\s*if \(service !== undefined && service\.hasAcceptedPrivacy\(\)\) \{\s*this\.onFinished\(\);\s*return;\s*\}\s*this\.showPrivacyDialog = true;\s*\}') { return $false }
    if ($Splash -match 'countdownTimer|countdownValue|startCountdown|countdownButton|setInterval') { return $false }
    if ($Splash -notmatch 'private\s+acceptPrivacy\(\):\s*void\s*\{\s*const service = this\.privacyConsentService\(\);\s*if \(service !== undefined\) \{\s*service\.acceptPrivacy\(\);\s*\}\s*this\.showPrivacyDialog = false;\s*this\.finishSplash\(\);\s*\}') { return $false }
    if ($Permission -notmatch 'async\s+requestCamera\([^)]*\)[\s\S]*?\{\s*return\s+this\.requestPermissionNames\(context,\s*\[\s*cameraPermissionName\s*\]\);\s*\}') { return $false }
    if ($Dance -notmatch 'new PermissionService\(\)\.requestCamera\(context\)') { return $false }
    if ($Splash -match '\.height\(180\)|\.height\(38\)') { return $false }
    $privacyDialog = Get-BracedBody $Splash 'privacyDialog()'
    if ([regex]::Matches($privacyDialog, 'Scroll\(\)').Count -ne 1) { return $false }
    $consentScroll = Get-BracedBody $privacyDialog 'Scroll()'
    @('me_user_agreements', 'me_privacy', 'me_user_agreement', 'me_disagree_and_exit', 'me_agree') | ForEach-Object {
      if ($consentScroll -notmatch [regex]::Escape($_)) { throw "Consent Scroll is missing: $_" }
    }
    if ($consentScroll.IndexOf('me_user_agreements') -gt $consentScroll.IndexOf('me_agree')) { return $false }
    @('me_user_agreement', 'me_disagree_and_exit', 'me_agree') | ForEach-Object {
      $actionPattern = "Button\(appString\('$($_)'\)(?:,\s*\{[^}]*\})?\)(?:(?!Button\()[\s\S])*?\.constraintSize\(\{\s*minHeight:\s*48\s*\}"
      if ($consentScroll -notmatch $actionPattern) { throw "Consent action must be at least 48vp: $_" }
    }
    $build = Get-BracedBody $Splash 'build()'
    $brandBackgroundPattern = "Column\(\)\s*\{[\s\S]*?\}\s*\.width\('100%'\)\s*\.height\('100%'\)\s*\.backgroundColor\(AppColor\.pageBackground\)\s*\.accessibilityLevel\(this\.showPrivacyDialog\s*\?\s*'no-hide-descendants'\s*:\s*'auto'\)"
    if ($build -notmatch $brandBackgroundPattern) { return $false }
    if ($build -match "Column\(\)\s*\{[\s\S]*?\}\s*\.width\('100%'\)\s*\.height\('100%'\)\s*\.backgroundColor\(AppColor\.pageBackground\)\s*\.accessibilityLevel\('no-hide-descendants'\)") { return $false }
    if (-not (Test-EntryAbilityLightColorMode $EntryAbility)) { return $false }
    if ((Get-Json5StringProperty $Module 'icon') -cne '$media:logo_splash') { return $false }
    if ((Get-Json5StringProperty $Module 'startWindowIcon') -cne '$media:logo_splash') { return $false }
    if (-not (Test-DarkStartWindowBackground $DarkColor)) { return $false }
    return $AppTheme -match 'readonly\s+textAccent:\s*string' -and
      $AppTheme -match "cardBackground:\s*'#FFFFFF'" -and
      $AppTheme -match "textAccent:\s*'#0B3A82'" -and
      (Test-BottomTabBarContract $BottomTab $BottomTabLayoutSpec)
  } catch {
    return $false
  }
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
      if ($depth -eq 0) { return $source.Substring($openIndex + 1, $index - $openIndex - 1) }
    }
  }
  throw "Unclosed block after: $marker"
}

function Assert-RejectedMutation {
  param(
    [string]$Name,
    [string]$Permission,
    [string]$Splash,
    [string]$Dance,
    [string]$EntryAbility = $script:entryAbility,
    [string]$Module = $script:module,
    [string]$DarkColor = $script:darkColor,
    [string]$AppTheme = $script:appTheme,
    [string]$BottomTab = $script:bottomTab,
    [string]$BottomTabLayoutSpec = $script:bottomTabLayoutSpec
  )

  if (Test-AppShellUiGuard $Permission $Splash $Dance $EntryAbility $Module $DarkColor $AppTheme $BottomTab $BottomTabLayoutSpec) {
    throw "Guard accepted mutation: $Name"
  }
}

function Assert-BalancedBraces {
  param([string]$Name, [string]$Source)

  $depth = 0
  foreach ($character in $Source.ToCharArray()) {
    if ($character -eq '{') { $depth += 1 }
    if ($character -eq '}') { $depth -= 1 }
    if ($depth -lt 0) { throw "Mutation has unbalanced braces: $Name" }
  }
  if ($depth -ne 0) { throw "Mutation has unbalanced braces: $Name" }
}

$root = Split-Path -Parent $PSScriptRoot
$permission = Get-Content (Join-Path $root 'entry/src/main/ets/services/permissions/PermissionService.ets') -Raw
$splash = Get-Content (Join-Path $root 'entry/src/main/ets/pages/SplashPage.ets') -Raw
$dance = Get-Content (Join-Path $root 'entry/src/main/ets/pages/DancePage.ets') -Raw
$script:appTheme = Get-Content (Join-Path $root 'entry/src/main/ets/common/theme/AppTheme.ets') -Raw
$script:entryAbility = Get-Content (Join-Path $root 'entry/src/main/ets/entryability/EntryAbility.ets') -Raw
$script:module = Get-Content (Join-Path $root 'entry/src/main/module.json5') -Raw
$script:darkColor = Get-Content (Join-Path $root 'entry/src/main/resources/dark/element/color.json') -Raw
$script:bottomTab = Get-Content (Join-Path $root 'entry/src/main/ets/common/components/BottomTabBar.ets') -Raw
$script:bottomTabLayoutSpec = Get-Content (Join-Path $root 'entry/src/main/ets/common/data/BottomTabBarLayoutSpec.ets') -Raw

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
Assert-RejectedMutation 'shared consent Scroll removed' $permission ($splash -replace 'Scroll\(\)', 'Column()') $dance
$secondConsentScroll = $splash -replace "\.accessibilityGroup\(true\)", ".accessibilityGroup(true)`n      Scroll() {`n        Text(appString('me_privacy'))`n      }`n      .width('86%')`n      .height('82%')"
Assert-BalancedBraces 'second consent Scroll added' $secondConsentScroll
Assert-RejectedMutation 'second consent Scroll added' $permission $secondConsentScroll $dance
$agreeButtonPattern = "(?s)\s*Button\(appString\('me_agree'\)\)\s*\.constraintSize\(\{ minHeight: 48 \}\)\s*\.width\('100%'\)\s*\.margin\(\{ top: AppSpacing\.sm \}\)\s*\.onClick\(\(\) => this\.acceptPrivacy\(\)\)"
$agreeButton = [regex]::Match($splash, $agreeButtonPattern).Value
if ([string]::IsNullOrWhiteSpace($agreeButton)) { throw 'Agree mutation fixture could not find the complete action.' }
$agreeOutsideConsentScroll = [regex]::Replace($splash, $agreeButtonPattern, '', 1)
$agreeOutsideConsentScroll = $agreeOutsideConsentScroll -replace '(\.accessibilityGroup\(true\))', ('$1' + $agreeButton)
Assert-BalancedBraces 'agree action moved outside consent Scroll' $agreeOutsideConsentScroll
Assert-RejectedMutation 'agree action moved outside consent Scroll' $permission $agreeOutsideConsentScroll $dance
@('me_user_agreement', 'me_disagree_and_exit', 'me_agree') | ForEach-Object {
  $actionPattern = "(?s)(Button\(appString\('$($_)'\).*?)\.constraintSize\(\{ minHeight: 48 \}\)"
  Assert-RejectedMutation "consent action minimum height removed: $_" $permission ($splash -replace $actionPattern, '$1') $dance
}
Assert-RejectedMutation 'consent background accessibility hiding made unconditional' $permission ($splash -replace "this\.showPrivacyDialog \? 'no-hide-descendants' : 'auto'", "'no-hide-descendants'") $dance
$wrongScopeAccessibility = $splash -replace "\.accessibilityLevel\(this\.showPrivacyDialog \? 'no-hide-descendants' : 'auto'\)", ''
$wrongScopeAccessibility = $wrongScopeAccessibility -replace '(\.accessibilityGroup\(true\))', "`$1`n      .accessibilityLevel(this.showPrivacyDialog ? 'no-hide-descendants' : 'auto')"
Assert-RejectedMutation 'consent background accessibility hiding moved to card' $permission $wrongScopeAccessibility $dance
Assert-RejectedMutation -Name 'text accent contrast lowered' -Permission $permission -Splash $splash -Dance $dance -AppTheme ($script:appTheme -replace "textAccent:\s*'#0B3A82'", "textAccent: '#FFFFFF'")
Assert-RejectedMutation -Name 'light color mode removed' -Permission $permission -Splash $splash -Dance $dance -EntryAbility ($script:entryAbility -replace 'COLOR_MODE_LIGHT', 'COLOR_MODE_NOT_SET')
Assert-RejectedMutation -Name 'application icon restored to template asset' -Permission $permission -Splash $splash -Dance $dance -Module ($script:module -replace '"icon": "\$media:logo_splash"', '"icon": "\$media:layered_image"')
Assert-RejectedMutation -Name 'start-window icon restored to template asset' -Permission $permission -Splash $splash -Dance $dance -Module ($script:module -replace '"startWindowIcon": "\$media:logo_splash"', '"startWindowIcon": "\$media:startIcon"')
Assert-RejectedMutation -Name 'dark start-window background restored' -Permission $permission -Splash $splash -Dance $dance -DarkColor ($script:darkColor -replace '"value": "#FFFFFF"', '"value": "#000000"')
Assert-RejectedMutation -Name 'light color mode comment decoy' -Permission $permission -Splash $splash -Dance $dance -EntryAbility (($script:entryAbility -replace 'ConfigurationConstant\.ColorMode\.COLOR_MODE_LIGHT', 'ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET') + "`n// COLOR_MODE_LIGHT")
Assert-RejectedMutation -Name 'application icon comment decoy' -Permission $permission -Splash $splash -Dance $dance -Module ($script:module -replace '"icon": "\$media:logo_splash"', '"icon": "\$media:layered_image" // "icon": "$media:logo_splash"')
Assert-RejectedMutation -Name 'start-window icon comment decoy' -Permission $permission -Splash $splash -Dance $dance -Module ($script:module -replace '"startWindowIcon": "\$media:logo_splash"', '"startWindowIcon": "$media:startIcon" // "startWindowIcon": "$media:logo_splash"')
$darkStartWindowBackgroundDecoy = @'
{
  "color": [
    {
      "name": "start_window_background",
      "value": "#000000"
    },
    {
      "name": "unrelated",
      "value": "#FFFFFF"
    }
  ]
}
'@
Assert-RejectedMutation -Name 'dark start-window background unrelated-color decoy' -Permission $permission -Splash $splash -Dance $dance -DarkColor $darkStartWindowBackgroundDecoy
Assert-RejectedMutation -Name 'bottom tab localized accessibility text removed' -Permission $permission -Splash $splash -Dance $dance -BottomTab ($script:bottomTab -replace '\.accessibilityText\(appString\(tab\.titleKey\) as Resource\)', '')
Assert-RejectedMutation -Name 'bottom tab selected state made constant' -Permission $permission -Splash $splash -Dance $dance -BottomTab ($script:bottomTab -replace 'accessibilitySelected\(this\.selected === tab\.id\)', 'accessibilitySelected(true)')
Assert-RejectedMutation -Name 'bottom tab decorative image announced' -Permission $permission -Splash $splash -Dance $dance -BottomTab ($script:bottomTab -replace "\.accessibilityLevel\('no'\)", '')
Assert-RejectedMutation -Name 'bottom tab accessibility group removed' -Permission $permission -Splash $splash -Dance $dance -BottomTab ($script:bottomTab -replace '\.accessibilityGroup\(true\)', '')
Assert-RejectedMutation -Name 'bottom tab button role removed' -Permission $permission -Splash $splash -Dance $dance -BottomTab ($script:bottomTab -replace '\.accessibilityRole\(AccessibilityRoleType\.BUTTON\)', '')
Assert-RejectedMutation -Name 'bottom tab wide-window cap removed' -Permission $permission -Splash $splash -Dance $dance -BottomTab ($script:bottomTab -replace ',\s*maxWidth:\s*bottomTabBarMaxWidthVp', '')
Assert-RejectedMutation -Name 'bottom tab max width changed' -Permission $permission -Splash $splash -Dance $dance -BottomTabLayoutSpec ($script:bottomTabLayoutSpec -replace 'bottomTabBarMaxWidthVp:\s*number\s*=\s*500', 'bottomTabBarMaxWidthVp: number = 501')
