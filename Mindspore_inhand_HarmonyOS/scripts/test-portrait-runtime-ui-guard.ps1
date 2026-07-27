param(
  [switch]$ExpectRed
)

$ErrorActionPreference = 'Stop'

function Fail([string]$Message) {
  throw "Portrait runtime UI guard mutation failed: $Message"
}

function Normalize-Newlines([string]$Text) {
  return $Text.Replace("`r`n", "`n").Replace("`r", "`n")
}

$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$guard = Join-Path $PSScriptRoot 'check-portrait-runtime-ui.ps1'
if (-not [IO.File]::Exists($guard)) { Fail 'missing portrait runtime UI guard.' }

if ($ExpectRed) {
  $rejected = $false
  try { & $guard -SourceRoot $root *> $null } catch { $rejected = $true }
  if (-not $rejected) { Fail 'Portrait RED runner expected the baseline guard to reject missing behavior.' }
  throw 'Portrait RED confirmed: baseline lacks the required portrait runtime UI contract.'
}

$tempBase = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd([IO.Path]::DirectorySeparatorChar)
$tempRoot = Join-Path $tempBase ('mih-portrait-runtime-ui-guard-' + [Guid]::NewGuid().ToString('N'))

function Assert-SafeTempPath([string]$Path) {
  if (-not $Path.StartsWith($tempBase + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
    Fail "unsafe fixture path: $Path"
  }
}

function New-Fixture() {
  $fixture = Join-Path $tempRoot ([Guid]::NewGuid().ToString('N'))
  Assert-SafeTempPath $fixture
  foreach ($relativePath in @(
    'entry\src\main\ets\pages\FeatureRuntimePage.ets',
    'entry\src\main\ets\features\runtime\FeatureWorkflowCatalog.ets',
    'entry\src\main\ets\features\runtime\FeatureRuntimeInputState.ets',
    'entry\src\main\ets\features\runtime\PortraitSegmentationBackgroundCatalog.ets',
    'entry\src\main\ets\services\ai\AiService.ets',
    'entry\src\main\ets\services\ai\SegmentationService.ets',
    'scripts\build-hap.ps1'
  )) {
    $source = Join-Path $root $relativePath
    if (-not [IO.File]::Exists($source)) { Fail "missing fixture source: $relativePath" }
    $target = Join-Path $fixture $relativePath
    [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($target)) | Out-Null
    [IO.File]::Copy($source, $target, $true)
  }
  return $fixture
}

function Replace-Once([string]$Text, [string]$Before, [string]$After, [string]$Name) {
  $normalized = Normalize-Newlines $Text
  $from = Normalize-Newlines $Before
  $to = Normalize-Newlines $After
  $count = ([regex]::Matches($normalized, [regex]::Escape($from))).Count
  if ($count -ne 1) { Fail "fixture '$Name' expected one marker, found $count." }
  $index = $normalized.IndexOf($from, [StringComparison]::Ordinal)
  return $normalized.Substring(0, $index) + $to + $normalized.Substring($index + $from.Length)
}

function Invoke-Mutation(
  [string]$Name,
  [string]$RelativePath,
  [string]$Before,
  [string]$After,
  [bool]$ShouldReject = $true
) {
  $fixture = New-Fixture
  $path = Join-Path $fixture $RelativePath
  $original = [IO.File]::ReadAllText($path)
  [IO.File]::WriteAllText($path, (Replace-Once $original $Before $After $Name), [Text.UTF8Encoding]::new($false))
  $rejected = $false
  try { & $guard -SourceRoot $fixture *> $null } catch { $rejected = $true }
  if ($ShouldReject -and -not $rejected) { Fail "mutation '$Name' was incorrectly accepted." }
  if (-not $ShouldReject -and $rejected) { Fail "decoy '$Name' was incorrectly rejected." }
}

function Invoke-SectionMutation(
  [string]$Name,
  [string]$RelativePath,
  [string]$Start,
  [string]$End,
  [string]$Before,
  [string]$After
) {
  $fixture = New-Fixture
  $path = Join-Path $fixture $RelativePath
  $text = Normalize-Newlines ([IO.File]::ReadAllText($path))
  $startIndex = $text.IndexOf($Start, [StringComparison]::Ordinal)
  $endIndex = if ($startIndex -ge 0) { $text.IndexOf($End, $startIndex + $Start.Length, [StringComparison]::Ordinal) } else { -1 }
  if ($startIndex -lt 0 -or $endIndex -le $startIndex) { Fail "fixture '$Name' could not isolate its section." }
  $section = $text.Substring($startIndex, $endIndex - $startIndex)
  $mutated = Replace-Once $section $Before $After $Name
  [IO.File]::WriteAllText($path, $text.Substring(0, $startIndex) + $mutated + $text.Substring($endIndex),
    [Text.UTF8Encoding]::new($false))
  $rejected = $false
  try { & $guard -SourceRoot $fixture *> $null } catch { $rejected = $true }
  if (-not $rejected) { Fail "section mutation '$Name' was incorrectly accepted." }
}

try {
  Assert-SafeTempPath $tempRoot
  [IO.Directory]::CreateDirectory($tempRoot) | Out-Null
  & $guard -SourceRoot $root
  if ($LASTEXITCODE -ne 0) { Fail 'baseline portrait guard failed.' }

  $page = 'entry\src\main\ets\pages\FeatureRuntimePage.ets'
  $catalog = 'entry\src\main\ets\features\runtime\FeatureWorkflowCatalog.ets'
  $inputState = 'entry\src\main\ets\features\runtime\FeatureRuntimeInputState.ets'
  $aiService = 'entry\src\main\ets\services\ai\AiService.ets'
  $segmentationService = 'entry\src\main\ets\services\ai\SegmentationService.ets'
  $build = 'scripts\build-hap.ps1'

  Invoke-SectionMutation 'distorted-composite-fit' $page `
    '  portraitSegmentationComposite() {' '  portraitSegmentationStatus() {' `
    "Image(this.backgroundImageUri)`n        .orientation(this.segmentationBackgroundImageOrientation)`n        .width('100%')`n        .height('100%')`n        .objectFit(ImageFit.Contain)" `
    "Image(this.backgroundImageUri)`n        .orientation(this.segmentationBackgroundImageOrientation)`n        .width('100%')`n        .height('100%')`n        .objectFit(ImageFit.Fill)"
  Invoke-SectionMutation 'color-only-preset-selection' $page `
    '  portraitSegmentationBackgroundStrip() {' '      }, (preset: PortraitSegmentationBackgroundPreset) => preset.id)' `
    "SymbolGlyph(`$r('sys.symbol.checkmark'))" "Text('')"
  Invoke-SectionMutation 'lost-custom-picker' $page `
    '  portraitSegmentationBackgroundStrip() {' '  stillScenePreviewContent() {' `
    "this.prepareInput('backgroundImage')" "this.prepareInput('styleImage')"
  Invoke-SectionMutation 'lost-preset-selection' $page `
    '  portraitSegmentationBackgroundStrip() {' '  stillScenePreviewContent() {' `
    'this.selectPortraitBackgroundPreset(preset)' 'this.selectBuiltInStyle(preset)'
  Invoke-SectionMutation 'clipped-3.2-background-labels' $page `
    '  portraitSegmentationBackgroundStrip() {' '  stillScenePreviewContent() {' `
    '.height(184)' '.height(144)'
  Invoke-Mutation 'lost-cancel-preservation' $inputState 'backgroundImageUri: backgroundState.backgroundImageUri' "backgroundImageUri: ''"
  Invoke-Mutation 'rear-camera-default' $catalog "return 'front';" "return 'back';"
  Invoke-Mutation 'lost-camera-memory' $catalog 'rememberedLiveCameraPositions.set(routeName, position);' 'return;'
  Invoke-SectionMutation 'startup-media-request' $catalog `
    '    routeName: AppRoute.PORTRAIT_SEGMENTATION.name,' '    routeName: AppRoute.IMAGE_CAMERA.name,' `
    "requiredPermissions: ['camera']" "requiredPermissions: ['camera', 'media']"
  Invoke-SectionMutation 'destructive-portrait-failure' $catalog `
    'export function shouldPreserveRuntimeVisualResultOnAiResult(' 'export function shouldPreserveRuntimeVisualResultOnLiveFrameFailure(' `
    "if (usesAndroidPortraitSegmentationLayout(workflow)) {`n    return !resultOk || dataKind === 'segmentation';`n  }" `
    "if (usesAndroidPortraitSegmentationLayout(workflow)) {`n    return resultOk && dataKind === 'segmentation';`n  }"
  Invoke-SectionMutation 'no-subject-generic-status' $aiService `
    '  private segmentationFailureMessageKey(' '  private textRecognitionSummary(' `
    "'feature_runtime_segmentation_no_subject' : 'feature_runtime_segmentation_failed'" `
    "'feature_runtime_segmentation_failed' : 'feature_runtime_segmentation_failed'"
  Invoke-SectionMutation 'no-subject-retry-disabled' $catalog `
    'export function liveSegmentationRetryActionForStatus(' 'export function liveGestureRetryActionForStatus(' `
    "    statusKey === 'feature_runtime_segmentation_no_subject') {" `
    "    false) {"
  Invoke-SectionMutation 'local-no-subject-becomes-generic' $segmentationService `
    'export function localSegmentationResultFromMask(' 'async function openSegmentationImageFile(' `
    "failureReason: 'noSubject'" "failureReason: 'runtimeException'"
  Invoke-SectionMutation 'corevision-no-subject-becomes-generic' $segmentationService `
    'export async function segmentationResultFromCoreVision(' 'export function segmentationRectanglePercent(' `
    "failureReason: 'noSubject'" "failureReason: 'runtimeException'"
  Invoke-SectionMutation 'save-before-ready' $page `
    '  portraitSegmentationToolbar() {' '  portraitSegmentationComposite() {' `
    'this.segmentationForegroundPixelMap !== undefined, this.resultImageSaveInFlight))' 'true, false))'
  Invoke-SectionMutation 'duplicate-save-ownership' $page `
    '  private async saveResultComponentImageAsync(componentId: string): Promise<void> {' '  private async saveResultPixelMapAsync(' `
    'this.resultImageSaveInFlight = true;' 'this.resultImageSaveInFlight = false;'
  Invoke-SectionMutation 'missing-save-feedback' $page `
    '  private saveResultComponentImage(componentId: string): void {' '  private saveResultPixelMap(' `
    'this.showRuntimeToast(this.statusKey);' 'this.statusKey = this.statusKey;'
  Invoke-Mutation 'duplicate-view-id' $page '.id(segmentationBackgroundReplacementComponentId)' ".id(segmentationBackgroundReplacementComponentId)`n    .id(segmentationBackgroundReplacementComponentId)"
  Invoke-Mutation 'comment-decoy' $page 'portraitSegmentationAndroidLayout() {' "portraitSegmentationAndroidLayout() {`n    // SymbolGlyph(`$r('sys.symbol.checkmark')) this.portraitSegmentationStatus()" $false
  Invoke-Mutation 'string-decoy' $page 'portraitSegmentationAndroidLayout() {' "portraitSegmentationAndroidLayout() {`n    const ignored = `"SymbolGlyph(`$r('sys.symbol.checkmark')) this.portraitSegmentationStatus()`";" $false
  Invoke-Mutation 'template-literal-decoy' $page 'portraitSegmentationAndroidLayout() {' "portraitSegmentationAndroidLayout() {`n    const ignored = ``SymbolGlyph(`$r('sys.symbol.checkmark')) this.portraitSegmentationStatus()``;" $false
  Invoke-SectionMutation 'removed-real-layout-only-template-decoy' $page `
    '  portraitSegmentationAndroidLayout() {' '  simpleAndroidLiveLayout() {' `
    'this.portraitSegmentationComposite()' '`${this.portraitSegmentationComposite()}`'
  Invoke-Mutation 'unused-sibling-decoy' $page 'portraitSegmentationStatus() {' "unusedPortraitSegmentationStatus() {`n    Text(appString(this.statusKey))`n  }`n`n  portraitSegmentationStatus() {" $false
  Invoke-Mutation 'comment-build-wire' $build "& (Join-Path `$PSScriptRoot 'check-portrait-runtime-ui.ps1')" "# & (Join-Path `$PSScriptRoot 'check-portrait-runtime-ui.ps1')"

  Write-Output 'Portrait runtime UI guard negative fixtures passed.'
} finally {
  if ($tempRoot.StartsWith($tempBase + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase) -and
    [IO.Directory]::Exists($tempRoot)) {
    [IO.Directory]::Delete($tempRoot, $true)
  }
}
