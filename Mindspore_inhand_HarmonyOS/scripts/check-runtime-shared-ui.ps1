param(
  [string]$SourceRoot = ''
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($SourceRoot)) {
  $SourceRoot = Split-Path -Parent $PSScriptRoot
}
$SourceRoot = [IO.Path]::GetFullPath($SourceRoot)
$pagePath = Join-Path $SourceRoot 'entry\src\main\ets\pages\FeatureRuntimePage.ets'
$buildPath = Join-Path $SourceRoot 'scripts\build-hap.ps1'
$source = ([IO.File]::ReadAllText($pagePath)).Replace("`r`n", "`n").Replace("`r", "`n")
$source = [regex]::Replace($source, '(?ms)/\*.*?\*/|//[^\n]*', '')

function Get-Builder([string]$Name, [string]$NextName) {
  $startMarker = "  @Builder`n  $Name"
  $endMarker = "  @Builder`n  $NextName"
  $start = $source.IndexOf($startMarker, [StringComparison]::Ordinal)
  $end = $source.IndexOf($endMarker, $start + $startMarker.Length, [StringComparison]::Ordinal)
  if ($start -lt 0 -or $end -lt 0) {
    throw "Runtime shared UI guard failed: missing builder boundary for $Name."
  }
  return $source.Substring($start, $end - $start)
}

function Assert-Contains([string]$Text, [string]$Pattern, [string]$Message) {
  if ($Text -notmatch $Pattern) {
    throw "Runtime shared UI guard failed: $Message"
  }
}

function Assert-NotContains([string]$Text, [string]$Pattern, [string]$Message) {
  if ($Text -match $Pattern) {
    throw "Runtime shared UI guard failed: $Message"
  }
}

$toolbar = Get-Builder 'runtimeActionToolbar(showActions: boolean) {' 'runtimeStatusBar() {'
Assert-Contains $toolbar '\.constraintSize\(\{\s*minHeight:\s*56\s*\}\)' 'runtime title bar must be content-driven with a 56vp minimum.'
Assert-Contains $toolbar 'Text\(appString\(this\.titleKey\)\)[\s\S]*?\.maxFontScale\(1\.6\)[\s\S]*?\.maxLines\(2\)' 'runtime title must cap extreme font scaling and allow two lines.'
Assert-NotContains $toolbar '\.height\(56\)' 'runtime title bar must not have a fixed 56vp height.'

$status = Get-Builder 'runtimeStatusBar() {' 'runtimeCameraSwitchAction() {'
Assert-Contains $status 'Text\(appString\(this\.statusKey\)\)' 'shared status bar must expose the current status.'
Assert-Contains $status 'Text\(appString\(this\.statusKey\)\)[\s\S]*?\.maxFontScale\(1\.6\)' 'shared status bar must remain bounded at extreme font scale.'
Assert-Contains $status "(?m)^[\t ]*\.backgroundColor\('#B31F2937'\)[\t ]*$" 'shared status bar must use a bounded high-contrast surface.'
Assert-Contains $status '\.constraintSize\(\{\s*minHeight:\s*44\s*\}\)' 'shared status bar must remain readable at large font scale.'
Assert-NotContains $status '\.height\(' 'shared status bar must be content-driven.'

$switch = Get-Builder 'runtimeCameraSwitchAction() {' 'runtimePermissionRecoveryOverlay() {'
Assert-Contains $switch '\.width\(48\)[\s\S]*?\.height\(48\)' 'shared camera switch must expose a 48vp target.'
Assert-Contains $switch "\.accessibilityText\(appString\('feature_runtime_switch_camera'\) as Resource\)" 'shared camera switch must have a localized semantic name.'
Assert-Contains $switch 'this\.switchLiveCamera\(\)' 'shared camera switch must retain its handler.'

$recovery = Get-Builder 'runtimePermissionRecoveryOverlay() {' 'portraitSegmentationToolbar() {'
Assert-Contains $recovery "(?m)^[\t ]*\.backgroundColor\('#66000000'\)[\t ]*$" 'permission recovery must include a full-screen scrim.'
Assert-Contains $recovery '\.hitTestBehavior\(HitTestMode\.Default\)' 'permission recovery must keep child actions interactive while blocking underlying sibling targets.'
Assert-NotContains $recovery '\.hitTestBehavior\(HitTestMode\.Block\)' 'permission recovery must not block its own child actions.'
Assert-Contains $recovery 'Scroll\(\)\s*\{' 'permission recovery card must be scrollable/content-driven.'
Assert-Contains $recovery 'Text\(appString\(this\.statusKey\)\)(?:(?!Button\()[\s\S])*?\.maxFontScale\(1\.6\)' 'permission recovery message must not clip at extreme font scale.'
Assert-Contains $recovery "Button\(appString\('splash_permission_retry'\)\)(?:(?!\.onClick)[\s\S])*?\.constraintSize\(\{\s*minHeight:\s*48\s*\}\)(?:(?!\.onClick)[\s\S])*?\.maxFontScale\(1\.6\)(?:(?!\.onClick)[\s\S])*?\.onClick\(\(\)\s*=>\s*this\.retryRuntimePermission\(\)\)" 'Retry must remain the primary 48vp action with bounded text and its handler.'
Assert-Contains $recovery "Button\(appString\('app_permission_by_hand'\),\s*\{\s*type:\s*ButtonType\.Normal\s*\}\)(?:(?!\.onClick)[\s\S])*?\.constraintSize\(\{\s*minHeight:\s*48\s*\}\)(?:(?!\.onClick)[\s\S])*?\.maxFontScale\(1\.6\)(?:(?!\.onClick)[\s\S])*?\.onClick\(\(\)\s*=>\s*this\.openRuntimePermissionSettings\(\)\)" 'Settings must remain the secondary 48vp action with bounded text and its handler.'
$retryIndex = $recovery.IndexOf("Button(appString('splash_permission_retry'))", [StringComparison]::Ordinal)
$settingsIndex = $recovery.IndexOf("Button(appString('app_permission_by_hand')", [StringComparison]::Ordinal)
if ($retryIndex -lt 0 -or $settingsIndex -lt 0 -or $retryIndex -ge $settingsIndex) {
  throw 'Runtime shared UI guard failed: Retry must precede Settings.'
}
Assert-NotContains $recovery '\.height\(36\)' 'permission recovery actions must not use the old fixed 36vp height.'

$portrait = Get-Builder 'portraitSegmentationToolbar() {' 'portraitSegmentationComposite() {'
Assert-Contains $portrait '\.constraintSize\(\{\s*minHeight:\s*56\s*\}\)' 'portrait title bar must be content-driven with a 56vp minimum.'
Assert-Contains $portrait 'Text\(appString\(this\.titleKey\)\)[\s\S]*?\.maxFontScale\(1\.6\)[\s\S]*?\.maxLines\(2\)' 'portrait title must cap extreme font scaling and allow two lines.'
Assert-Contains $portrait "\.accessibilityText\(\`$r\('app\.string\.action_back'\)\)" 'portrait back action must have a localized semantic name.'
Assert-Contains $portrait "if \(this\.liveCameraSwitchAvailable\)[\s\S]*?\.width\(48\)[\s\S]*?\.height\(48\)[\s\S]*?\.accessibilityText\(appString\('feature_runtime_switch_camera'\) as Resource\)[\s\S]*?this\.switchLiveCamera\(\)" 'portrait camera switch must retain its policy and handler in a 48vp semantic target.'
Assert-Contains $portrait "SaveButton\([\s\S]*?\.width\(48\)[\s\S]*?\.height\(48\)[\s\S]*?compositeSegmentationSaveReady\([\s\S]*?this\.saveResultComponentImage\(segmentationBackgroundReplacementComponentId\)" 'portrait save action must retain its 48vp native control and readiness gate.'
Assert-NotContains $portrait '\.height\(56\)' 'portrait title bar must not have a fixed 56vp height.'

$simpleLive = Get-Builder 'simpleAndroidLiveLayout() {' 'imageClassificationAndroidLiveLayout() {'
Assert-Contains $simpleLive 'this\.runtimeStatusBar\(\)' 'simple live layouts must expose the shared status bar.'
Assert-Contains $simpleLive 'this\.runtimeCameraSwitchAction\(\)' 'simple live layouts must use the semantic camera switch action.'
Assert-Contains $simpleLive 'if \(this\.liveCameraSwitchAvailable\) \{\s*this\.runtimeCameraSwitchAction\(\)\s*\}' 'fixed-camera routes must not expose the shared switch action.'
Assert-Contains $simpleLive '\.padding\(\{\s*left:\s*AppSpacing\.page,\s*right:\s*AppSpacing\.page,\s*top:\s*AppSpacing\.sm,\s*bottom:\s*AppSpacing\.md\s*\}\)' 'simple live overlays must stay within responsive safe padding.'
Assert-NotContains $simpleLive '\.width\(35\)|\.height\(35\)|\.margin\(\{\s*bottom:\s*30\s*\}\)' 'simple live layout must not retain fixed Android switch geometry.'

$runtimeContentStart = $source.IndexOf("  @Builder`n  runtimeLayoutContent() {", [StringComparison]::Ordinal)
$buildStart = $source.IndexOf("  build() {", [StringComparison]::Ordinal)
if ($runtimeContentStart -lt 0 -or $buildStart -lt 0 -or $runtimeContentStart -ge $buildStart) {
  throw 'Runtime shared UI guard failed: missing runtimeLayoutContent()/build() boundary.'
}
$runtimeContent = $source.Substring($runtimeContentStart, $buildStart - $runtimeContentStart)
Assert-NotContains $runtimeContent 'this\.runtimePermissionRecoveryOverlay\(\)' 'permission recovery must not remain scoped inside a route/content layout.'
$build = $source.Substring($buildStart)
Assert-Contains $build 'build\(\) \{\s*Stack\(\{ alignContent: Alignment\.TopStart \}\) \{\s*this\.runtimeLayoutContent\(\)\s*this\.runtimePermissionRecoveryOverlay\(\)\s*\}\s*\.width\(''100%''\)\s*\.height\(''100%''\)\s*\.key\(this\.routeName\)\s*\}' 'build() must place one recovery overlay above the complete runtime content, including its toolbar, and bind the runtime route to the captured root.'
$overlayCalls = [regex]::Matches($source, '(?m)^[\t ]*this\.runtimePermissionRecoveryOverlay\(\)[\t ]*$')
if ($overlayCalls.Count -ne 1) {
  throw "Runtime shared UI guard failed: expected one top-level permission recovery call, found $($overlayCalls.Count)."
}

$tokens = $null
$parseErrors = $null
$ast = [Management.Automation.Language.Parser]::ParseFile($buildPath, [ref]$tokens, [ref]$parseErrors)
if ($parseErrors.Count -ne 0) {
  throw 'Runtime shared UI guard failed: build-hap.ps1 must parse cleanly.'
}
$requiredCalls = @(
  "& (Join-Path `$PSScriptRoot 'test-runtime-shared-ui-guard.ps1')",
  "& (Join-Path `$PSScriptRoot 'check-runtime-shared-ui.ps1')",
  "& (Join-Path `$PSScriptRoot 'test-runtime-ui-evidence-guard.ps1')"
)
foreach ($call in $requiredCalls) {
  $matches = @($ast.EndBlock.Statements | Where-Object {
      $_.Extent.Text.Replace("`r`n", "`n").Trim() -ceq $call
    })
  if ($matches.Count -ne 1) {
    throw "Runtime shared UI guard failed: build-hap must execute one top-level call: $call"
  }
}

Write-Output 'Runtime shared UI guard passed.'
