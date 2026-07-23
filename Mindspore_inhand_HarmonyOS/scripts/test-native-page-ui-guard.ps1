$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'check-native-page-title-bar.ps1')

$fixture = @'
import { appString } from '../i18n/AppStrings';
import { AppColor } from '../theme/AppTheme';

@Component
export struct NativePageTitleBar {
  title: string = '';
  showMore: boolean = false;
  onBack: () => void = () => {};
  onMore: () => void = () => {};

  build() {
    Row() {
      Row() {
        SymbolGlyph($r('sys.symbol.chevron_backward'))
          .fontSize(24)
          .fontColor([AppColor.textPrimary])
      }
      .width(48)
      .height(48)
        .accessibilityText($r('app.string.action_back'))
      .onClick(() => this.onBack())

      Text(this.title).maxLines(2)

      if (this.showMore) {
        Row() {
          SymbolGlyph($r('sys.symbol.more'))
            .fontSize(24)
            .fontColor([AppColor.textPrimary])
        }
        .width(48)
        .height(48)
        .accessibilityText($r('app.string.action_more'))
        .onClick(() => this.onMore())
      }
    }
  }
}
'@

function Assert-Rejected([string]$Name, [string]$Source) {
  try {
    Assert-NativePageTitleBarContract $Source
  } catch {
    Write-Host "Rejected mutation: $Name"
    return
  }
  throw "Expected mutation to be rejected: $Name"
}

Assert-NativePageTitleBarContract $fixture
Assert-Rejected 'back target changed to 40vp' ([regex]::Replace($fixture, '\.width\(48\)', '.width(40)', 1))
Assert-Rejected 'back callback removed' ($fixture -replace '\.onClick\(\(\) => this\.onBack\(\)\)', '')
Assert-Rejected 'more callback removed' ($fixture -replace '\.onClick\(\(\) => this\.onMore\(\)\)', '')
Assert-Rejected 'commented valid code' ($fixture -replace 'SymbolGlyph\(\$r\(''sys\.symbol\.chevron_backward''\)\)', '// SymbolGlyph($r(''sys.symbol.chevron_backward''))')
Assert-Rejected 'string literal valid code' ($fixture -replace 'SymbolGlyph\(\$r\(''sys\.symbol\.chevron_backward''\)\)', "'SymbolGlyph(`$r('sys.symbol.chevron_backward'))'")

$webFixture = @'
@Component
struct WebPage {
  @State progress: number = 0;
  @State loadFailed: boolean = false;
  private readonly webController = new webview.WebviewController();

  private retryWebPage(): void {
    this.loadFailed = false;
    this.progress = 0;
    this.webController.refresh();
  }

  private handleWebError(event: OnErrorReceiveEvent): void {
    this.loadFailed = webPageFailedAfterRequest(this.loadFailed, event.request.isMainFrame());
  }

  @Builder
  webContent() {
    if (this.localRawfile.length > 0) {
      Web({ src: $rawfile('privacy.html'), controller: this.webController })
        .onPageBegin(() => {
          this.loadFailed = false;
        })
        .onErrorReceive((event: OnErrorReceiveEvent) => {
          this.handleWebError(event);
        })
    } else if (shouldInstallPoetryJavascriptBridge(this.routeName, this.webUrl)) {
      Web({ src: this.webUrl, controller: this.webController })
        .javaScriptProxy({ object: this.poetryBridge })
        .onPageBegin(() => {
          this.loadFailed = false;
        })
        .onErrorReceive((event: OnErrorReceiveEvent) => {
          this.handleWebError(event);
        })
    } else {
      Web({ src: this.webUrl, controller: this.webController })
        .onPageBegin(() => {
          this.loadFailed = false;
        })
        .onErrorReceive((event: OnErrorReceiveEvent) => {
          this.handleWebError(event);
        })
    }
  }

  build() {
    Column() {
      NativePageTitleBar({ title: appString(this.titleKey), onBack: () => router.back() })
      Progress({ value: this.progress, total: 100, type: ProgressType.Linear })
        .opacity(this.progress > 0 && this.progress < 100 && !this.loadFailed ? 1 : 0)
      this.webContent()
    }
  }
}
'@

function Assert-WebRejected([string]$Name, [string]$Source) {
  try {
    Assert-WebPageNativeShellContract $Source
  } catch {
    Write-Host "Rejected WebPage mutation: $Name"
    return
  }
  throw "Expected WebPage mutation to be rejected: $Name"
}

Assert-WebPageNativeShellContract $webFixture
Assert-WebRejected 'real title bar removed' ($webFixture -replace 'NativePageTitleBar\([^\n]+\)', '')
$conditionalProgress = [regex]::Replace(
  $webFixture,
  '(?s)      Progress\(\{ value:.*?\.opacity\([^\r\n]+\)\r?\n',
  "      if (this.progress > 0 && this.progress < 100) {`n        Progress({ value: this.progress, total: 100, type: ProgressType.Linear })`n          .opacity(this.progress > 0 && this.progress < 100 && !this.loadFailed ? 1 : 0)`n      }`n"
)
Assert-WebRejected 'progress conditionally rendered' $conditionalProgress
Assert-WebRejected 'main-frame check removed' ($webFixture -replace 'event\.request\.isMainFrame\(\)', 'false')
Assert-WebRejected 'retry refresh removed' ($webFixture -replace 'this\.webController\.refresh\(\);', '')
Assert-WebRejected 'commented title bar' ($webFixture -replace 'NativePageTitleBar\([^\n]+\)', '// NativePageTitleBar({ title: appString(this.titleKey), onBack: () => router.back() })')
$privacyPageBeginMissing = [regex]::Replace(
  $webFixture,
  '(?s)(if \(this\.localRawfile\.length > 0\) \{.*?)(\.onPageBegin\(\(\) => \{\s*this\.loadFailed = false;\s*\}\))',
  '$1',
  1
)
Assert-WebRejected 'privacy branch page begin removed' $privacyPageBeginMissing
$privacyErrorMissing = [regex]::Replace(
  $webFixture,
  '(?s)(if \(this\.localRawfile\.length > 0\) \{.*?)(\.onErrorReceive\(\(event: OnErrorReceiveEvent\) => \{\s*this\.handleWebError\(event\);\s*\}\))',
  '$1',
  1
)
Assert-WebRejected 'privacy branch error callback removed' $privacyErrorMissing
$poetryPageBeginMissing = [regex]::Replace(
  $webFixture,
  '(?s)(else if \(shouldInstallPoetryJavascriptBridge\(this\.routeName, this\.webUrl\)\) \{.*?)(\.onPageBegin\(\(\) => \{\s*this\.loadFailed = false;\s*\}\))',
  '$1',
  1
)
Assert-WebRejected 'poetry branch page begin removed' $poetryPageBeginMissing
$poetryErrorMissing = [regex]::Replace(
  $webFixture,
  '(?s)(else if \(shouldInstallPoetryJavascriptBridge\(this\.routeName, this\.webUrl\)\) \{.*?)(\.onErrorReceive\(\(event: OnErrorReceiveEvent\) => \{\s*this\.handleWebError\(event\);\s*\}\))',
  '$1',
  1
)
Assert-WebRejected 'poetry branch error callback removed' $poetryErrorMissing

$qrFixture = @'
@Component
struct QrCodePage {
  @State showSaveSheet: boolean = false;
  @State saveInFlight: boolean = false;
  @State statusKey: AppStringKey = 'empty';

  private applySaveSheetAction(_action: QrCodeSaveSheetAction): void {}

  @Builder
  saveActionSheet() {
    Column() {
      SaveButton({ icon: SaveIconStyle.FULL_FILLED })
        .enabled(!this.saveInFlight)
      if (this.statusKey === 'image_save_failed') {
        Text(appString('image_save_failed'))
      }
    }
  }

  build() {
    Column() {
      NativePageTitleBar({
        title: appString(this.titleKey),
        showMore: true,
        onBack: () => router.back(),
        onMore: () => this.applySaveSheetAction('open')
      })
      Image($r('app.media.my_qr_code'))
        .accessibilityText(appString(this.titleKey) as Resource)
      Column() {}
        .constraintSize({ maxWidth: 300 })
    }
    .bindSheet(this.showSaveSheet, this.saveActionSheet(), {
      height: SheetSize.FIT_CONTENT,
      onWillDismiss: (action: DismissSheetAction) => {
        this.applySaveSheetAction(
          qrCodeSheetActionForNativeDismiss(action.reason === DismissReason.PRESS_BACK)
        );
      }
    })
  }
}
'@

function Assert-QrCodeRejected([string]$Name, [string]$Source) {
  try {
    Assert-QrCodePageNativeShellContract $Source
  } catch {
    Write-Host "Rejected QrCodePage mutation: $Name"
    return
  }
  throw "Expected QR mutation to be rejected: $Name"
}

Assert-QrCodePageNativeShellContract $qrFixture
Assert-QrCodeRejected 'real title bar removed' ($qrFixture -replace 'NativePageTitleBar', 'LegacyTitleBar')
Assert-QrCodeRejected 'more callback removed' ($qrFixture -replace 'onMore:\s*\(\) => this\.applySaveSheetAction\(''open''\)', '')
Assert-QrCodeRejected 'save enabled binding changed to a constant' ($qrFixture -replace '\.enabled\(!this\.saveInFlight\)', '.enabled(true)')
Assert-QrCodeRejected 'dismiss reason mapping removed' ($qrFixture -replace 'qrCodeSheetActionForNativeDismiss\(action\.reason === DismissReason\.PRESS_BACK\)', 'false')
Assert-QrCodeRejected 'QR accessible name resource cast removed' ($qrFixture -replace 'appString\(this\.titleKey\) as Resource', 'appString(this.titleKey)')

function Assert-PoetryPosterRejected([string]$Name, [string]$Source) {
  try {
    Assert-PoetryPosterNativeShellContract $Source
  } catch {
    Write-Host "Rejected poetry poster mutation: $Name"
    return
  }
  throw "Expected poetry poster mutation to be rejected: $Name"
}

$root = Split-Path -Parent $PSScriptRoot
$poetryPosterSourcePath = Join-Path $root 'entry/src/main/ets/pages/PoetryPosterPage.ets'
$poetryPosterSource = Get-Content -Raw -Encoding UTF8 -LiteralPath $poetryPosterSourcePath
Assert-PoetryPosterNativeShellContract $poetryPosterSource
Assert-PoetryPosterRejected 'frame cover changed to fill' ($poetryPosterSource -replace 'backgroundImageSize\(ImageSize\.Cover\)', 'backgroundImageSize(ImageSize.FILL)')
Assert-PoetryPosterRejected 'snapshot id moved into action area' ($poetryPosterSource -replace '\.id\(poetryPosterComponentId\)', '')
Assert-PoetryPosterRejected 'save button moved into poster card' ($poetryPosterSource.Replace('posterCard() {', "posterCard() {`n    SaveButton({})"))
Assert-PoetryPosterRejected 'snapshot wait removed' ($poetryPosterSource -replace 'waitUntilRenderFinished:\s*true', 'waitUntilRenderFinished: false')
Assert-PoetryPosterRejected 'save finally removed' ([regex]::Replace($poetryPosterSource, '(?s)(private savePoster\(\): void \{.*?\.finally\(\(\) => \{)\s*this\.actionInFlight = false;\s*(\}\))', '$1$2', 1))
Assert-PoetryPosterRejected 'share finally removed' ([regex]::Replace($poetryPosterSource, '(?s)(private sharePoster\(\): void \{.*?\.finally\(\(\) => \{)\s*this\.actionInFlight = false;\s*(\}\))', '$1$2', 1))

Write-Host 'Native page UI guard mutation tests passed'
