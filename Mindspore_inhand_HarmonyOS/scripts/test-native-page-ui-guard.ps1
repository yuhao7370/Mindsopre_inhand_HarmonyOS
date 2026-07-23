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

Write-Host 'Native page UI guard mutation tests passed'
