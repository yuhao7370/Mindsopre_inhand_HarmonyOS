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
      .accessibilityText(appString('action_back'))
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
        .accessibilityText(appString('action_more'))
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
    Web({ src: this.webUrl, controller: this.webController })
      .onErrorReceive((event: OnErrorReceiveEvent) => {
        this.handleWebError(event);
      })
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

Write-Host 'Native page UI guard mutation tests passed'
