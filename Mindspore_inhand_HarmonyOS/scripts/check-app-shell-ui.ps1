$root = Split-Path -Parent $PSScriptRoot
$permission = Get-Content (Join-Path $root 'entry/src/main/ets/services/permissions/PermissionService.ets') -Raw
$splash = Get-Content (Join-Path $root 'entry/src/main/ets/pages/SplashPage.ets') -Raw
$dance = Get-Content (Join-Path $root 'entry/src/main/ets/pages/DancePage.ets') -Raw
$appTheme = Get-Content (Join-Path $root 'entry/src/main/ets/common/theme/AppTheme.ets') -Raw
$entryAbility = Get-Content (Join-Path $root 'entry/src/main/ets/entryability/EntryAbility.ets') -Raw
$module = Get-Content (Join-Path $root 'entry/src/main/module.json5') -Raw
$darkColor = Get-Content (Join-Path $root 'entry/src/main/resources/dark/element/color.json') -Raw
$bottomTab = Get-Content (Join-Path $root 'entry/src/main/ets/common/components/BottomTabBar.ets') -Raw
$bottomTabLayoutSpec = Get-Content (Join-Path $root 'entry/src/main/ets/common/data/BottomTabBarLayoutSpec.ets') -Raw
$mainPage = Get-Content (Join-Path $root 'entry/src/main/ets/pages/MainPage.ets') -Raw

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

function Test-PublicRootTabContract([string]$source) {
  try {
    $mainPageSource = Remove-SourceComments $source
    if ($mainPageSource -match '\bCollegePage\b|\bcurrentPageBuilder\b') { return $false }
    if ([regex]::Matches($mainPageSource, '\bExperiencePage\s*\(\s*\)').Count -ne 1) { return $false }
    if ([regex]::Matches($mainPageSource, '\bMePage\s*\(\s*\)').Count -ne 1) { return $false }

    $build = Get-BracedBody $mainPageSource 'build()'
    if ([regex]::Matches($build, '\bStack\s*\(\s*\)').Count -ne 1) { return $false }
    $stack = Get-BracedBody $build 'Stack()'
    if ($stack -match '\bif\s*\(') { return $false }
    $experienceRoot = 'ExperiencePage\s*\(\s*\)\s*\.visibility\(\s*this\.selectedTab\s*===\s*MainTab\.EXPERIENCE\s*\?\s*Visibility\.Visible\s*:\s*Visibility\.Hidden\s*\)\s*\.hitTestBehavior\(\s*this\.selectedTab\s*===\s*MainTab\.EXPERIENCE\s*\?\s*HitTestMode\.Default\s*:\s*HitTestMode\.None\s*\)'
    $meRoot = 'MePage\s*\(\s*\)\s*\.visibility\(\s*this\.selectedTab\s*===\s*MainTab\.ME\s*\?\s*Visibility\.Visible\s*:\s*Visibility\.Hidden\s*\)\s*\.hitTestBehavior\(\s*this\.selectedTab\s*===\s*MainTab\.ME\s*\?\s*HitTestMode\.Default\s*:\s*HitTestMode\.None\s*\)'
    return $stack -match $experienceRoot -and $stack -match $meRoot
  } catch {
    return $false
  }
}

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
$agreementButton = [regex]::Match(
  $consentScroll,
  "Button\(appString\('me_user_agreement'\),\s*\{\s*type:\s*ButtonType\.Normal\s*\}\)(?<chain>(?:(?!Button\()[\s\S])*)"
)
if (-not $agreementButton.Success -or
  $agreementButton.Groups['chain'].Value -notmatch '\.fontColor\(AppColor\.textAccent\)' -or
  $agreementButton.Groups['chain'].Value -notmatch '\.backgroundColor\((?:AppColor\.cardBackground|Color\.Transparent)\)') {
  throw 'Consent agreement link must use textAccent on the white or transparent card background.'
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
if (-not (Test-EntryAbilityLightColorMode $entryAbility)) { throw 'Application must explicitly use the implemented light theme.' }
if ((Get-Json5StringProperty $module 'icon') -cne '$media:logo_splash') { throw 'Application icon must use the flat MindSpore logo.' }
if ((Get-Json5StringProperty $module 'startWindowIcon') -cne '$media:logo_splash') { throw 'Start icon must use the flat MindSpore logo.' }
if (-not (Test-DarkStartWindowBackground $darkColor)) { throw 'Dark-qualified start window must remain light.' }
$bottomTab = Remove-SourceComments $bottomTab
@(
  'accessibilityGroup\(true\)',
  'accessibilityText\(appString\(tab\.titleKey\) as Resource\)',
  'accessibilityRole\(AccessibilityRoleType\.BUTTON\)',
  'accessibilitySelected\(this\.selected === tab\.id\)',
  'constraintSize\(\{\s*minHeight:\s*bottomTabBarMinHeightVp,\s*maxWidth:\s*bottomTabBarMaxWidthVp\s*\}\)'
) | ForEach-Object {
  if ($bottomTab -notmatch $_) { throw "Bottom tab contract missing: $_" }
}
if (-not (Test-BottomTabBarContract $bottomTab $bottomTabLayoutSpec)) {
  throw 'Bottom tab accessibility and wide-window contract must hold structurally.'
}
if (-not (Test-PublicRootTabContract $mainPage)) {
  throw 'Public roots must remain mounted once in one Stack with hidden pages excluded from hit testing.'
}
