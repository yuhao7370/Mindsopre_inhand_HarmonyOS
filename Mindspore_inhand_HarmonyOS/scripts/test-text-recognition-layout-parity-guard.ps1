$ErrorActionPreference = 'Stop'

$sourceRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$guard = Join-Path $PSScriptRoot 'check-text-recognition-layout-parity.ps1'
$tempPrefix = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$tempRoot = Join-Path $tempPrefix ('mih-ocr-guard-' + [Guid]::NewGuid().ToString('N'))

function Read-Normalized([string]$Path) {
  return [IO.File]::ReadAllText($Path).Replace("`r`n", "`n").Replace("`r", "`n")
}

function Copy-Fixture() {
  $fixture = Join-Path $tempRoot ([Guid]::NewGuid().ToString('N'))
  [IO.Directory]::CreateDirectory((Join-Path $fixture 'entry\src\main\ets\pages')) | Out-Null
  [IO.Directory]::CreateDirectory((Join-Path $fixture 'entry\src\main\ets\features\runtime')) | Out-Null
  [IO.Directory]::CreateDirectory((Join-Path $fixture 'scripts')) | Out-Null
  [IO.File]::Copy(
    (Join-Path $sourceRoot 'entry\src\main\ets\pages\FeatureRuntimePage.ets'),
    (Join-Path $fixture 'entry\src\main\ets\pages\FeatureRuntimePage.ets')
  )
  [IO.File]::Copy(
    (Join-Path $sourceRoot 'entry\src\main\ets\features\runtime\FeatureWorkflowCatalog.ets'),
    (Join-Path $fixture 'entry\src\main\ets\features\runtime\FeatureWorkflowCatalog.ets')
  )
  [IO.File]::Copy(
    (Join-Path $sourceRoot 'scripts\build-hap.ps1'),
    (Join-Path $fixture 'scripts\build-hap.ps1')
  )
  $pagePath = Join-Path $fixture 'entry\src\main\ets\pages\FeatureRuntimePage.ets'
  [IO.File]::WriteAllText($pagePath, ([IO.File]::ReadAllText($pagePath).Replace("`r`n", "`n").Replace("`r", "`n").Replace("`n", "`r`n")))
  return $fixture
}

function Mutate-And-Reject([string]$Name, [string]$RelativePath, [string]$From, [string]$To) {
  $fixture = Copy-Fixture
  $path = Join-Path $fixture $RelativePath
  $text = Read-Normalized $path
  if ($text.IndexOf($From, [StringComparison]::Ordinal) -lt 0) {
    throw "Text recognition mutation fixture '$Name' could not find source marker."
  }
  [IO.File]::WriteAllText($path, $text.Replace($From, $To))
  $rejected = $false
  try {
    & $guard -SourceRoot $fixture *> $null
  } catch {
    $rejected = $true
  }
  if (-not $rejected) {
    throw "Text recognition mutation fixture '$Name' was incorrectly accepted."
  }
}

function Mutate-And-Accept([string]$Name, [string]$RelativePath, [string]$From, [string]$To) {
  $fixture = Copy-Fixture
  $path = Join-Path $fixture $RelativePath
  $text = Read-Normalized $path
  if ($text.IndexOf($From, [StringComparison]::Ordinal) -lt 0) {
    throw "Text recognition decoy fixture '$Name' could not find source marker."
  }
  [IO.File]::WriteAllText($path, $text.Replace($From, $To))
  try {
    & $guard -SourceRoot $fixture *> $null
  } catch {
    throw "Text recognition decoy fixture '$Name' was incorrectly rejected."
  }
}

function Mutate-Two-And-Reject(
  [string]$Name,
  [string]$RelativePath,
  [string]$FromOne,
  [string]$ToOne,
  [string]$FromTwo,
  [string]$ToTwo
) {
  $fixture = Copy-Fixture
  $path = Join-Path $fixture $RelativePath
  $text = Read-Normalized $path
  foreach ($marker in @($FromOne, $FromTwo)) {
    if ($text.IndexOf($marker, [StringComparison]::Ordinal) -lt 0) {
      throw "Text recognition mutation fixture '$Name' could not find source marker."
    }
  }
  [IO.File]::WriteAllText($path, $text.Replace($FromOne, $ToOne).Replace($FromTwo, $ToTwo))
  $rejected = $false
  try {
    & $guard -SourceRoot $fixture *> $null
  } catch {
    $rejected = $true
  }
  if (-not $rejected) {
    throw "Text recognition mutation fixture '$Name' was incorrectly accepted."
  }
}

try {
  [IO.Directory]::CreateDirectory($tempRoot) | Out-Null
  & $guard -SourceRoot $sourceRoot
  if ($LASTEXITCODE -ne 0) { throw 'Baseline text recognition guard failed.' }

  $page = 'entry\src\main\ets\pages\FeatureRuntimePage.ets'
  $catalog = 'entry\src\main\ets\features\runtime\FeatureWorkflowCatalog.ets'
  $build = 'scripts\build-hap.ps1'
  Mutate-And-Reject 'remove-scroll' $page '      Scroll() {' '      Column() {'
  Mutate-And-Reject 'duplicate-scroll' $page '      Scroll() {' "      Scroll() {`n        Scroll() {"
  Mutate-And-Reject 'stretch-preview' $page '.objectFit(ImageFit.Contain)' '.objectFit(ImageFit.Fill)'
  Mutate-And-Reject 'remove-orientation' $page '.orientation(this.textRecognitionImageOrientation)' '.orientation(ImageRotateOrientation.UP)'
  Mutate-And-Reject 'undersize-photo' $page `
    ".enabled(textRecognitionActionEnabled(this.workflowRunning))`n              .onClick(() => this.prepareInput('photo'))" `
    ".height(37)`n              .onClick(() => this.prepareInput('photo'))"
  Mutate-And-Reject 'enable-copy-during-run' $page `
    ".enabled(textRecognitionActionEnabled(this.workflowRunning))`n              .onClick(() => this.copyRecognizedText())" `
    ".enabled(true)`n              .onClick(() => this.copyRecognizedText())"
  Mutate-And-Reject 'retry-wrong-callback' $page `
    "Button(appString('web_retry'), { type: ButtonType.Normal })`n                .constraintSize({ minWidth: 72, minHeight: 48 })`n                .maxFontScale(1.6)`n                .fontColor(AppColor.accent)`n                .backgroundColor(Color.Transparent)`n                .onClick(() => this.runPrimaryAction())" `
    "Button(appString('web_retry'), { type: ButtonType.Normal })`n                .constraintSize({ minWidth: 72, minHeight: 48 })`n                .maxFontScale(1.6)`n                .fontColor(AppColor.accent)`n                .backgroundColor(Color.Transparent)`n                .onClick(() => this.copyRecognizedText())"
  Mutate-And-Reject 'retry-comment-decoy' $page `
    ".backgroundColor(Color.Transparent)`n                .onClick(() => this.runPrimaryAction())" `
    ".backgroundColor(Color.Transparent)`n                // .onClick(() => this.runPrimaryAction())`n                .onClick(() => this.copyRecognizedText())"
  Mutate-And-Reject 'retry-string-decoy' $page `
    ".backgroundColor(Color.Transparent)`n                .onClick(() => this.runPrimaryAction())" `
    ".backgroundColor(Color.Transparent)`n                .accessibilityDescription('.onClick(() => this.runPrimaryAction())')`n                .onClick(() => this.copyRecognizedText())"
  Mutate-And-Reject 'clip-long-result' $page `
    ".constraintSize({ minHeight: 112 })`n          .padding(AppSpacing.md)" `
    ".constraintSize({ minHeight: 112 })`n          .height(112)`n          .clip(true)`n          .padding(AppSpacing.md)"
  Mutate-Two-And-Reject 'photo-enabled-with-executable-decoy' $page `
    ".enabled(textRecognitionActionEnabled(this.workflowRunning))`n              .onClick(() => this.prepareInput('photo'))" `
    ".enabled(true)`n              .onClick(() => this.prepareInput('photo'))" `
    ".backgroundColor(Color.Transparent)`n                .onClick(() => this.runPrimaryAction())" `
    ".backgroundColor(Color.Transparent)`n                .enabled(textRecognitionActionEnabled(this.workflowRunning))`n                .onClick(() => this.runPrimaryAction())"
  Mutate-And-Reject 'remove-copy-feedback-publication' $page `
    "this.statusKey = result.ok ? 'feature_runtime_copy_done' : 'feature_runtime_copy_failed';" `
    "const ignoredCopyResult = result.ok;"
  Mutate-And-Reject 'copy-feedback-comment-decoy' $page `
    "this.statusKey = result.ok ? 'feature_runtime_copy_done' : 'feature_runtime_copy_failed';`n      this.showRuntimeToast(this.statusKey);" `
    "// this.statusKey = result.ok ? 'feature_runtime_copy_done' : 'feature_runtime_copy_failed';`n      // this.showRuntimeToast(this.statusKey);"
  Mutate-And-Reject 'copy-feedback-string-decoy' $page `
    "this.statusKey = result.ok ? 'feature_runtime_copy_done' : 'feature_runtime_copy_failed';`n      this.showRuntimeToast(this.statusKey);" `
    "this.showRuntimeToast('this.showRuntimeToast(this.statusKey);' as AppStringKey);"
  Mutate-And-Reject 'remove-orientation-update' $page `
    'this.updateTextRecognitionImageOrientation(result.uri);' `
    "const orientationDecoy = 'this.updateTextRecognitionImageOrientation(result.uri);';"
  Mutate-And-Reject 'allow-stale-orientation' $page `
    'if (this.imageInputUri === uri) {' 'if (true) {'
  Mutate-And-Reject 'enable-running-actions' $catalog `
    'return !workflowRunning;' 'return true;'
  Mutate-And-Reject 'remove-production-wire' $build `
    "& (Join-Path `$PSScriptRoot 'check-text-recognition-layout-parity.ps1')" `
    "`$guardDecoy = `"check-text-recognition-layout-parity.ps1`""
  Mutate-And-Reject 'remove-mutation-wire' $build `
    "& (Join-Path `$PSScriptRoot 'test-text-recognition-layout-parity-guard.ps1')" `
    "`$mutationDecoy = `"test-text-recognition-layout-parity-guard.ps1`""
  Mutate-And-Accept 'comment-decoy' $page `
    'this.runtimeActionToolbar(false)' `
    "// Scroll() {`n        this.runtimeActionToolbar(false)"
  Mutate-And-Accept 'string-decoy' $page `
    'this.runtimeActionToolbar(false)' `
    "const scrollDecoy = 'Scroll() {';`n        this.runtimeActionToolbar(false)"

  Write-Output 'Text recognition layout parity guard negative fixtures passed.'
} finally {
  if ($tempRoot.StartsWith($tempPrefix, [StringComparison]::OrdinalIgnoreCase) -and
    [IO.Directory]::Exists($tempRoot)) {
    [IO.Directory]::Delete($tempRoot, $true)
  }
}
