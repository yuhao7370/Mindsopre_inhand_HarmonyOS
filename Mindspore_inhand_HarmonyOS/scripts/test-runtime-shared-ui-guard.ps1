$ErrorActionPreference = 'Stop'

$guardPath = Join-Path $PSScriptRoot 'check-runtime-shared-ui.ps1'
$backGuardPath = Join-Path $PSScriptRoot 'check-toolbar-back-icon.ps1'
$headerGuardPath = Join-Path $PSScriptRoot 'check-runtime-header-actions.ps1'
$switchGuardPath = Join-Path $PSScriptRoot 'check-live-camera-switch-icon.ps1'
$tempParent = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\', '/')
$tempRoot = [IO.Path]::GetFullPath((Join-Path $tempParent ("mindspore-runtime-shared-ui-" + [guid]::NewGuid().ToString('N'))))
$tempPrefix = $tempParent + [IO.Path]::DirectorySeparatorChar
$utf8 = [Text.UTF8Encoding]::new($false)
if (-not $tempRoot.StartsWith($tempPrefix, [StringComparison]::OrdinalIgnoreCase)) {
  throw 'Runtime shared UI fixture refused an unsafe temporary path.'
}

function Write-Fixture([string]$Root, [string]$RelativePath, [string]$Content) {
  $path = Join-Path $Root $RelativePath
  [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($path)) | Out-Null
  [IO.File]::WriteAllText($path, $Content.Replace("`r`n", "`n").Replace("`r", "`n"), $utf8)
}

function New-ValidFixture([string]$Root) {
  Write-Fixture $Root 'entry\src\main\ets\pages\FeatureRuntimePage.ets' @'
  @Builder
  runtimeActionToolbar(showActions: boolean) {
    Row() {
      Row() {
        Image($r('app.media.icon_back'))
          .width(11)
          .height(22)
          .objectFit(ImageFit.Contain)
      }
      .width(48)
      .height(48)
      .accessibilityText($r('app.string.action_back'))
      .accessibilityRole(AccessibilityRoleType.BACK_BUTTON)
      .onClick(() => router.back())
      Text(appString(this.titleKey))
        .layoutWeight(1)
        .maxLines(2)
      if (showActions && this.helpContentKey !== undefined) {
        Row() {
          Image($r('app.media.icon_help'))
            .width(24)
            .height(24)
            .objectFit(ImageFit.Contain)
        }
        .width(48)
        .height(48)
        .accessibilityText(appString('feature_runtime_help') as Resource)
        .accessibilityRole(AccessibilityRoleType.BUTTON)
        .onClick(() => this.showLocalHelpDialog())
      }
      if (showActions && this.helpUrl.length > 0) {
        Row() {
          Image($r('app.media.icon_more'))
            .width(24)
            .height(24)
            .objectFit(ImageFit.Contain)
        }
        .width(48)
        .height(48)
        .accessibilityText($r('app.string.action_more'))
        .accessibilityRole(AccessibilityRoleType.BUTTON)
        .onClick(() => this.openHelpPage())
      }
    }
    .constraintSize({ minHeight: 56 })
  }

  @Builder
  runtimeStatusBar() {
    Text(appString(this.statusKey))
      .constraintSize({ minHeight: 44 })
      .backgroundColor('#B31F2937')
  }

  @Builder
  runtimeCameraSwitchAction() {
    Row() {
      Image($r('app.media.front_back_switch'))
        .width(24)
        .height(24)
        .objectFit(ImageFit.Contain)
    }
    .width(48)
    .height(48)
    .accessibilityText(appString('feature_runtime_switch_camera') as Resource)
    .accessibilityRole(AccessibilityRoleType.BUTTON)
    .onClick(() => this.switchLiveCamera())
  }

  @Builder
  runtimePermissionRecoveryOverlay() {
    if (this.shouldShowRuntimePermissionRetry()) {
      Stack() {
        Scroll() {
          Column() {
            Button(appString('splash_permission_retry'))
              .constraintSize({ minHeight: 48 })
              .onClick(() => this.retryRuntimePermission())
            Button(appString('app_permission_by_hand'), { type: ButtonType.Normal })
              .constraintSize({ minHeight: 48 })
              .onClick(() => this.openRuntimePermissionSettings())
          }
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#66000000')
      .hitTestBehavior(HitTestMode.Default)
    }
  }

  @Builder
  portraitSegmentationToolbar() {
    Row() {
      Row() {
        Image($r('app.media.icon_back'))
      }
      .width(48)
      .height(48)
      .accessibilityText($r('app.string.action_back'))
      .onClick(() => router.back())
      Text(appString(this.titleKey))
        .maxLines(2)
      if (this.liveCameraSwitchAvailable) {
        Row() {
        }
        .width(48)
        .height(48)
        .accessibilityText(appString('feature_runtime_switch_camera') as Resource)
        .onClick(() => this.switchLiveCamera())
      }
      SaveButton({
        icon: SaveIconStyle.FULL_FILLED
      })
        .width(48)
        .height(48)
        .enabled(compositeSegmentationSaveReady(this.workflowRunning,
          this.segmentationForegroundPixelMap !== undefined, this.resultImageSaveInFlight))
        .onClick(() => this.saveResultComponentImage(segmentationBackgroundReplacementComponentId))
    }
    .constraintSize({ minHeight: 56 })
  }

  @Builder
  portraitSegmentationComposite() {
  }

  @Builder
  simpleAndroidLiveLayout() {
    Column() {
      this.runtimeActionToolbar(false)
      Stack() {
        this.liveCameraSurfaceContent()
        Column() {
          this.runtimeStatusBar()
          if (this.liveCameraSwitchAvailable) {
            this.runtimeCameraSwitchAction()
          }
        }
        .padding({ left: AppSpacing.page, right: AppSpacing.page, top: AppSpacing.sm, bottom: AppSpacing.md })
      }
    }
  }

  @Builder
  imageClassificationAndroidLiveLayout() {
  }

  @Builder
  runtimeLayoutContent() {
    this.simpleAndroidLiveLayout()
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

  // Decoys must never satisfy a missing real contract:
  // .height(56) .width(48) .backgroundColor('#66000000')
'@

  Write-Fixture $Root 'scripts\build-hap.ps1' @'
& (Join-Path $PSScriptRoot 'test-runtime-shared-ui-guard.ps1')
& (Join-Path $PSScriptRoot 'check-runtime-shared-ui.ps1')
& (Join-Path $PSScriptRoot 'test-runtime-ui-evidence-guard.ps1')
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
  $text = [IO.File]::ReadAllText($Path).Replace("`r`n", "`n").Replace("`r", "`n")
  $before = $Before.Replace("`r`n", "`n").Replace("`r", "`n")
  $after = $After.Replace("`r`n", "`n").Replace("`r", "`n")
  $first = $text.IndexOf($before, [StringComparison]::Ordinal)
  if ($first -lt 0 -or $text.IndexOf($before, $first + $before.Length, [StringComparison]::Ordinal) -ge 0) {
    throw "Runtime shared UI fixture expected exactly one mutation target: $Before"
  }
  [IO.File]::WriteAllText(
    $Path,
    $text.Substring(0, $first) + $after + $text.Substring($first + $before.Length),
    $utf8
  )
}

function Assert-Rejected([string]$ValidRoot, [string]$Name, [string]$Before, [string]$After) {
  $root = Join-Path $tempRoot $Name
  Copy-Fixture $ValidRoot $root
  Replace-Once (Join-Path $root 'entry\src\main\ets\pages\FeatureRuntimePage.ets') $Before $After
  $rejected = $false
  try {
    & $guardPath -SourceRoot $root | Out-Null
    & $backGuardPath -SourceRoot $root | Out-Null
    & $headerGuardPath -SourceRoot $root | Out-Null
    & $switchGuardPath -SourceRoot $root | Out-Null
  } catch {
    $rejected = $true
  }
  if (-not $rejected) { throw "Runtime shared UI guard accepted mutation: $Name" }
}

try {
  $valid = Join-Path $tempRoot 'valid'
  New-ValidFixture $valid
  & $guardPath -SourceRoot $valid | Out-Null
  & $backGuardPath -SourceRoot $valid | Out-Null
  & $headerGuardPath -SourceRoot $valid | Out-Null
  & $switchGuardPath -SourceRoot $valid | Out-Null

  Assert-Rejected $valid 'fixed-title-height' `
    "        .onClick(() => this.openHelpPage())`n      }`n    }`n    .constraintSize({ minHeight: 56 })" `
    "        .onClick(() => this.openHelpPage())`n      }`n    }`n    .height(56)"
  Assert-Rejected $valid 'fixed-title-height-comment-decoy' `
    "        .onClick(() => this.openHelpPage())`n      }`n    }`n    .constraintSize({ minHeight: 56 })" `
    "        .onClick(() => this.openHelpPage())`n      }`n    }`n    // .constraintSize({ minHeight: 56 })`n    .height(56)"
  Assert-Rejected $valid 'small-switch-target' `
    "    .width(48)`n    .height(48)`n    .accessibilityText(appString('feature_runtime_switch_camera') as Resource)" `
    "    .width(40)`n    .height(40)`n    .accessibilityText(appString('feature_runtime_switch_camera') as Resource)"
  Assert-Rejected $valid 'small-back-parent-child-decoy' `
    "        Image(`$r('app.media.icon_back'))`n          .width(11)`n          .height(22)`n          .objectFit(ImageFit.Contain)`n      }`n      .width(48)`n      .height(48)" `
    "        Image(`$r('app.media.icon_back'))`n          .width(48)`n          .height(48)`n          .objectFit(ImageFit.Contain)`n      }`n      .width(40)`n      .height(40)"
  Assert-Rejected $valid 'small-back-parent-sibling-decoy' `
    "      .width(48)`n      .height(48)`n      .accessibilityText(`$r('app.string.action_back'))`n      .accessibilityRole(AccessibilityRoleType.BACK_BUTTON)`n      .onClick(() => router.back())`n      Text(appString(this.titleKey))" `
    "      .width(40)`n      .height(40)`n      .accessibilityText(`$r('app.string.action_back'))`n      .accessibilityRole(AccessibilityRoleType.BACK_BUTTON)`n      .onClick(() => router.back())`n      Row() {`n        Image(`$r('app.media.icon_back'))`n      }`n      .width(48)`n      .height(48)`n      .accessibilityText(`$r('app.string.action_back'))`n      .accessibilityRole(AccessibilityRoleType.BACK_BUTTON)`n      .onClick(() => router.back())`n      Text(appString(this.titleKey))"
  Assert-Rejected $valid 'small-help-parent-child-decoy' `
    "          Image(`$r('app.media.icon_help'))`n            .width(24)`n            .height(24)`n            .objectFit(ImageFit.Contain)`n        }`n        .width(48)`n        .height(48)" `
    "          Image(`$r('app.media.icon_help'))`n            .width(48)`n            .height(48)`n            .objectFit(ImageFit.Contain)`n        }`n        .width(40)`n        .height(40)"
  Assert-Rejected $valid 'small-more-parent-child-decoy' `
    "          Image(`$r('app.media.icon_more'))`n            .width(24)`n            .height(24)`n            .objectFit(ImageFit.Contain)`n        }`n        .width(48)`n        .height(48)" `
    "          Image(`$r('app.media.icon_more'))`n            .width(48)`n            .height(48)`n            .objectFit(ImageFit.Contain)`n        }`n        .width(40)`n        .height(40)"
  Assert-Rejected $valid 'small-switch-parent-child-decoy' `
    "      Image(`$r('app.media.front_back_switch'))`n        .width(24)`n        .height(24)`n        .objectFit(ImageFit.Contain)`n    }`n    .width(48)`n    .height(48)" `
    "      Image(`$r('app.media.front_back_switch'))`n        .width(48)`n        .height(48)`n        .objectFit(ImageFit.Contain)`n    }`n    .width(40)`n    .height(40)"
  Assert-Rejected $valid 'missing-help-role' `
    "        .accessibilityText(appString('feature_runtime_help') as Resource)`n        .accessibilityRole(AccessibilityRoleType.BUTTON)" `
    "        .accessibilityText(appString('feature_runtime_help') as Resource)`n        .accessibilityRole(AccessibilityRoleType.NONE)"
  Assert-Rejected $valid 'back-semantic-comment-string-decoy' `
    "      .accessibilityText(`$r('app.string.action_back'))`n      .accessibilityRole(AccessibilityRoleType.BACK_BUTTON)`n      .onClick(() => router.back())`n      Text(appString(this.titleKey))`n        .layoutWeight(1)" `
    "      // .accessibilityText(`$r('app.string.action_back'))`n      .accessibilityDescription(`".accessibilityText(`$r('app.string.action_back'))`")`n      .accessibilityRole(AccessibilityRoleType.BACK_BUTTON)`n      .onClick(() => router.back())`n      Text(appString(this.titleKey))`n        .layoutWeight(1)"
  Assert-Rejected $valid 'back-image-template-string-decoy' `
    "  runtimeActionToolbar(showActions: boolean) {`n    Row() {`n      Row() {`n        Image(`$r('app.media.icon_back'))" `
    "  runtimeActionToolbar(showActions: boolean) {`n    const imageDecoy = ```n        Image(`$r('app.media.icon_back'))`n    ```n    Row() {`n      Row() {`n        Image(`$r('app.media.icon_default'))"
  Assert-Rejected $valid 'missing-full-scrim' `
    "      .backgroundColor('#66000000')" `
    "      .backgroundColor(Color.Transparent)"
  Assert-Rejected $valid 'scrim-string-decoy' `
    "      .backgroundColor('#66000000')" `
    "      .backgroundColor(Color.Transparent)`n      .accessibilityDescription(`".backgroundColor('#66000000')`")"
  Assert-Rejected $valid 'recovery-blocks-child-actions' `
    '      .hitTestBehavior(HitTestMode.Default)' `
    '      .hitTestBehavior(HitTestMode.Block)'
  Assert-Rejected $valid 'swap-recovery-handlers' `
    'this.retryRuntimePermission()' `
    'this.openRuntimePermissionSettings()'
  Assert-Rejected $valid 'fixed-route-switch-exposed' `
    "          if (this.liveCameraSwitchAvailable) {`n            this.runtimeCameraSwitchAction()`n          }" `
    '          this.runtimeCameraSwitchAction()'
  Assert-Rejected $valid 'content-scoped-overlay' `
    "  @Builder`n  runtimeLayoutContent() {`n    this.simpleAndroidLiveLayout()`n  }`n`n  build() {`n    Stack({ alignContent: Alignment.TopStart }) {`n      this.runtimeLayoutContent()`n      this.runtimePermissionRecoveryOverlay()`n    }`n    .width('100%')`n    .height('100%')`n    .key(this.routeName)`n  }" `
    "  @Builder`n  runtimeLayoutContent() {`n    Column() {`n      this.runtimeActionToolbar(false)`n      Stack() {`n        this.simpleAndroidLiveLayout()`n        this.runtimePermissionRecoveryOverlay()`n      }`n    }`n  }`n`n  build() {`n    this.runtimeLayoutContent()`n  }"

  Write-Output 'Runtime shared UI guard mutation fixtures passed.'
} finally {
  if ([IO.Directory]::Exists($tempRoot)) {
    $resolved = [IO.Path]::GetFullPath($tempRoot)
    if (-not $resolved.StartsWith($tempPrefix, [StringComparison]::OrdinalIgnoreCase)) {
      throw 'Runtime shared UI fixture refused unsafe cleanup.'
    }
    [IO.Directory]::Delete($resolved, $true)
  }
}
