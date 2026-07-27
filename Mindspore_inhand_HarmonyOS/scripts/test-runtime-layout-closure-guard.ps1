$ErrorActionPreference = 'Stop'

$guardPath = Join-Path $PSScriptRoot 'check-runtime-layout-closure.ps1'
$tempParent = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd(
  [IO.Path]::DirectorySeparatorChar,
  [IO.Path]::AltDirectorySeparatorChar
)
$tempRoot = [IO.Path]::GetFullPath((Join-Path $tempParent ("mindspore-runtime-layout-closure-" + [guid]::NewGuid().ToString('N'))))
$tempPrefix = $tempParent + [IO.Path]::DirectorySeparatorChar
$utf8 = [Text.UTF8Encoding]::new($false)
if (-not $tempRoot.StartsWith($tempPrefix, [StringComparison]::OrdinalIgnoreCase)) {
  throw 'Runtime layout closure fixture refused an unsafe temporary path.'
}

function Normalize-Newlines([string]$Text) {
  return $Text.Replace("`r`n", "`n").Replace("`r", "`n")
}

function Write-FixtureFile([string]$Root, [string]$RelativePath, [string]$Text) {
  $path = Join-Path $Root $RelativePath
  [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($path)) | Out-Null
  [IO.File]::WriteAllText($path, (Normalize-Newlines $Text).Replace("`n", "`r`n"), $utf8)
}

function New-ValidFixture([string]$Root) {
  Write-FixtureFile $Root 'entry\src\main\ets\pages\FeatureRuntimePage.ets' @'
@Component
struct FeatureRuntimePage {
  private selectorDecoy: string = 'if (usesAndroidTextTranslationLayout(workflowForRoute(this.routeName))) {';
  private builderDecoy: string = "this.textTranslationAndroidLayout()";
  private templateDecoy: string = `
  build() {
    this.notTheRuntimeLayoutChain()
  }`;

  // build() { this.textRecognitionAndroidLayout() }
  @Builder
  runtimeLayoutContent() {
    if (usesAndroidTextTranslationLayout(workflowForRoute(this.routeName))) {
      this.textTranslationAndroidLayout()
    } else if (usesAndroidTextRecognitionLayout(workflowForRoute(this.routeName))) {
      this.textRecognitionAndroidLayout()
    } else if (usesAndroidPoseNetStillLayout(workflowForRoute(this.routeName))) {
      this.poseNetStillAndroidLayout()
    } else if (usesAndroidGestureStillLayout(workflowForRoute(this.routeName))) {
      this.gestureStillAndroidLayout()
    } else if (usesAndroidObjectPhotoLayout(workflowForRoute(this.routeName))) {
      this.objectPhotoAndroidLayout()
    } else if (usesAndroidStyleTransferLayout(workflowForRoute(this.routeName))) {
      this.styleTransferAndroidLayout()
    } else if (usesAndroidCustomModelLayout(workflowForRoute(this.routeName))) {
      this.customModelAndroidLayout()
    } else if (usesAndroidStillSegmentationLayout(workflowForRoute(this.routeName))) {
      this.stillSegmentationAndroidLayout()
    } else if (usesAndroidStillSceneLayout(workflowForRoute(this.routeName))) {
      this.stillSceneAndroidLayout()
    } else if (usesAndroidPortraitSegmentationLayout(workflowForRoute(this.routeName))) {
      this.portraitSegmentationAndroidLayout()
    } else if (specializedAndroidLiveLayoutForWorkflow(workflowForRoute(this.routeName)) === 'segmentation') {
      this.segmentationAndroidLiveLayout()
    } else if (specializedAndroidLiveLayoutForWorkflow(workflowForRoute(this.routeName)) === 'gesture') {
      this.gestureAndroidLiveLayout()
    } else if (specializedAndroidLiveLayoutForWorkflow(workflowForRoute(this.routeName)) === 'scene') {
      this.sceneAndroidLiveLayout()
    } else if (specializedAndroidLiveLayoutForWorkflow(workflowForRoute(this.routeName)) === 'skeleton') {
      this.skeletonAndroidLiveLayout()
    } else if (specializedAndroidLiveLayoutForWorkflow(workflowForRoute(this.routeName)) === 'imageClassification') {
      this.imageClassificationAndroidLiveLayout()
    } else if (specializedAndroidLiveLayoutForWorkflow(workflowForRoute(this.routeName)) === 'objectDetection') {
      this.objectDetectionAndroidLiveLayout()
    } else if (usesSimpleAndroidLiveLayout(workflowForRoute(this.routeName))) {
      this.simpleAndroidLiveLayout()
    } else {
      Scroll() {
        Column() {
        }
      }
    }
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      this.runtimeLayoutContent()
      this.runtimePermissionRecoveryOverlay()
    }
    .width('100%')
    .height('100%')
    .key(this.routeName)
  }
}
'@

  Write-FixtureFile $Root 'scripts\build-hap.ps1' @'
$ErrorActionPreference = 'Stop'
& (Join-Path $PSScriptRoot 'test-runtime-layout-closure-guard.ps1')
& (Join-Path $PSScriptRoot 'check-runtime-layout-closure.ps1')
$hvigor = 'hvigorw.bat'
'@
}

function Copy-Fixture([string]$Source, [string]$Destination) {
  [IO.Directory]::CreateDirectory($Destination) | Out-Null
  [IO.Directory]::GetFiles($Source, '*', [IO.SearchOption]::AllDirectories) | ForEach-Object {
    $relative = $_.Substring($Source.Length).TrimStart('\', '/')
    $target = Join-Path $Destination $relative
    [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($target)) | Out-Null
    [IO.File]::Copy($_, $target, $true)
  }
}

function Replace-Once([string]$Path, [string]$Before, [string]$After) {
  $text = Normalize-Newlines ([IO.File]::ReadAllText($Path))
  $Before = Normalize-Newlines $Before
  $After = Normalize-Newlines $After
  $first = $text.IndexOf($Before, [StringComparison]::Ordinal)
  if ($first -lt 0 -or $text.IndexOf($Before, $first + $Before.Length, [StringComparison]::Ordinal) -ge 0) {
    throw "Runtime layout closure fixture expected one mutation target: $Before"
  }
  [IO.File]::WriteAllText(
    $Path,
    $text.Substring(0, $first) + $After + $text.Substring($first + $Before.Length),
    $utf8
  )
}

function Assert-GuardRejectsMutation(
  [string]$ValidRoot,
  [string]$Name,
  [scriptblock]$Mutate
) {
  $root = Join-Path $tempRoot $Name
  Copy-Fixture $ValidRoot $root
  & $Mutate $root
  $failed = $false
  try { & $guardPath -SourceRoot $root | Out-Null } catch { $failed = $true }
  if (-not $failed) { throw "Runtime layout closure guard accepted mutation: $Name" }
  Write-Output "Rejected runtime layout mutation: $Name"
}

try {
  $validRoot = Join-Path $tempRoot 'valid'
  New-ValidFixture $validRoot
  & $guardPath -SourceRoot $validRoot | Out-Null
  Write-Output 'Accepted runtime layout fixture: valid'

  $pagePath = 'entry\src\main\ets\pages\FeatureRuntimePage.ets'
  $buildPath = 'scripts\build-hap.ps1'

  Assert-GuardRejectsMutation $validRoot 'missing-branch' {
    param($root)
    Replace-Once (Join-Path $root $pagePath) @'
    } else if (usesAndroidPoseNetStillLayout(workflowForRoute(this.routeName))) {
      this.poseNetStillAndroidLayout()
'@ ''
  }

  Assert-GuardRejectsMutation $validRoot 'swapped-builders' {
    param($root)
    $path = Join-Path $root $pagePath
    Replace-Once $path '      this.textTranslationAndroidLayout()' '      this.__runtimeLayoutSwap__()'
    Replace-Once $path '      this.textRecognitionAndroidLayout()' '      this.textTranslationAndroidLayout()'
    Replace-Once $path '      this.__runtimeLayoutSwap__()' '      this.textRecognitionAndroidLayout()'
  }

  Assert-GuardRejectsMutation $validRoot 'changed-selector' {
    param($root)
    Replace-Once (Join-Path $root $pagePath) `
      'usesAndroidStillSceneLayout(workflowForRoute(this.routeName))' `
      'usesAndroidStillSegmentationLayout(workflowForRoute(this.routeName))'
  }

  Assert-GuardRejectsMutation $validRoot 'reordered-branches' {
    param($root)
    $path = Join-Path $root $pagePath
    $before = @'
    } else if (usesAndroidObjectPhotoLayout(workflowForRoute(this.routeName))) {
      this.objectPhotoAndroidLayout()
    } else if (usesAndroidStyleTransferLayout(workflowForRoute(this.routeName))) {
      this.styleTransferAndroidLayout()
'@
    $after = @'
    } else if (usesAndroidStyleTransferLayout(workflowForRoute(this.routeName))) {
      this.styleTransferAndroidLayout()
    } else if (usesAndroidObjectPhotoLayout(workflowForRoute(this.routeName))) {
      this.objectPhotoAndroidLayout()
'@
    Replace-Once $path $before $after
  }

  Assert-GuardRejectsMutation $validRoot 'early-fallback' {
    param($root)
    Replace-Once (Join-Path $root $pagePath) `
      "    } else if (specializedAndroidLiveLayoutForWorkflow(workflowForRoute(this.routeName)) === 'objectDetection') {" `
      '    } else {'
  }

  Assert-GuardRejectsMutation $validRoot 'missing-skeleton-branch' {
    param($root)
    Replace-Once (Join-Path $root $pagePath) @'
    } else if (specializedAndroidLiveLayoutForWorkflow(workflowForRoute(this.routeName)) === 'skeleton') {
      this.skeletonAndroidLiveLayout()
'@ ''
  }

  Assert-GuardRejectsMutation $validRoot 'skeleton-branch-comment-decoy' {
    param($root)
    Replace-Once (Join-Path $root $pagePath) `
      "    } else if (specializedAndroidLiveLayoutForWorkflow(workflowForRoute(this.routeName)) === 'skeleton') {" `
      "    // } else if (specializedAndroidLiveLayoutForWorkflow(workflowForRoute(this.routeName)) === 'skeleton') {"
  }

  Assert-GuardRejectsMutation $validRoot 'skeleton-builder-string-decoy' {
    param($root)
    Replace-Once (Join-Path $root $pagePath) `
      '      this.skeletonAndroidLiveLayout()' `
      "      const skeletonBuilderDecoy = 'this.skeletonAndroidLiveLayout()'"
  }

  Assert-GuardRejectsMutation $validRoot 'skeleton-builder-template-decoy' {
    param($root)
    Replace-Once (Join-Path $root $pagePath) `
      '      this.skeletonAndroidLiveLayout()' `
      '      const skeletonBuilderDecoy = `this.skeletonAndroidLiveLayout()`'
  }

  Assert-GuardRejectsMutation $validRoot 'skeleton-unused-sibling-decoy' {
    param($root)
    $path = Join-Path $root $pagePath
    Replace-Once $path '      this.skeletonAndroidLiveLayout()' '      this.sceneAndroidLiveLayout()'
    Replace-Once $path @'
  build() {
    Stack({ alignContent: Alignment.TopStart }) {
'@ @'
  private unusedSkeletonLayoutDecoy() {
    this.skeletonAndroidLiveLayout()
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
'@
  }

  Assert-GuardRejectsMutation $validRoot 'quoted-builder-decoy' {
    param($root)
    Replace-Once (Join-Path $root $pagePath) `
      '      this.gestureStillAndroidLayout()' `
      "      const builderDecoy = 'this.gestureStillAndroidLayout()'"
  }

  Assert-GuardRejectsMutation $validRoot 'comment-selector-decoy' {
    param($root)
    Replace-Once (Join-Path $root $pagePath) `
      '    } else if (usesAndroidCustomModelLayout(workflowForRoute(this.routeName))) {' `
      '    // } else if (usesAndroidCustomModelLayout(workflowForRoute(this.routeName))) {'
  }

  Assert-GuardRejectsMutation $validRoot 'fake-build-template-decoy' {
    param($root)
    Replace-Once (Join-Path $root $pagePath) `
      "  build() {`n    Stack({ alignContent: Alignment.TopStart }) {" `
      "  private buildDecoy2: string = ```n  build() {`n  }```;`n  render() {`n    Stack({ alignContent: Alignment.TopStart }) {"
  }

  Assert-GuardRejectsMutation $validRoot 'sibling-component-real-build' {
    param($root)
    $path = Join-Path $root $pagePath
    Replace-Once $path 'struct FeatureRuntimePage {' 'struct SiblingDecoyPage {'
    [IO.File]::AppendAllText($path, @'

@Component
struct FeatureRuntimePage {
    build() {
      Column() {
      }
    }
}
'@, $utf8)
  }

  Assert-GuardRejectsMutation $validRoot 'missing-guard-wiring' {
    param($root)
    Replace-Once (Join-Path $root $buildPath) `
      "& (Join-Path `$PSScriptRoot 'check-runtime-layout-closure.ps1')" `
      "# & (Join-Path `$PSScriptRoot 'check-runtime-layout-closure.ps1')"
  }

  Assert-GuardRejectsMutation $validRoot 'nested-suite-wiring' {
    param($root)
    Replace-Once (Join-Path $root $buildPath) `
      "& (Join-Path `$PSScriptRoot 'test-runtime-layout-closure-guard.ps1')" `
      "function Invoke-RuntimeLayoutSuite {`n  & (Join-Path `$PSScriptRoot 'test-runtime-layout-closure-guard.ps1')`n}"
  }

  Assert-GuardRejectsMutation $validRoot 'quoted-wiring-decoy' {
    param($root)
    Replace-Once (Join-Path $root $buildPath) `
      "& (Join-Path `$PSScriptRoot 'check-runtime-layout-closure.ps1')" `
      '$guardDecoy = "& (Join-Path $PSScriptRoot ''check-runtime-layout-closure.ps1'')"'
  }

  Write-Output 'Runtime layout closure guard mutation fixtures passed.'
} finally {
  if ([IO.Directory]::Exists($tempRoot)) {
    $resolved = [IO.Path]::GetFullPath($tempRoot)
    if (-not $resolved.StartsWith($tempPrefix, [StringComparison]::OrdinalIgnoreCase)) {
      throw 'Runtime layout closure fixture refused unsafe cleanup.'
    }
    [IO.Directory]::Delete($resolved, $true)
  }
}
