import { AppColor } from '../theme/AppTheme';

@Component
export struct NativePageTitleBar {
  title: ResourceStr = '';
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
      .justifyContent(FlexAlign.Center)
      .accessibilityText($r('app.string.action_back'))
      .accessibilityRole(AccessibilityRoleType.BACK_BUTTON)
      .onClick(() => this.onBack())

      Text(this.title)
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColor.textPrimary)
        .layoutWeight(1)
        .maxLines(2)

      if (this.showMore) {
        Row() {
          SymbolGlyph($r('sys.symbol.more'))
            .fontSize(24)
            .fontColor([AppColor.textPrimary])
        }
        .width(48)
        .height(48)
        .justifyContent(FlexAlign.Center)
        .accessibilityText($r('app.string.action_more'))
        .accessibilityRole(AccessibilityRoleType.BUTTON)
        .onClick(() => this.onMore())
      } else {
        Blank().width(48)
      }
    }
    .width('100%')
    .constraintSize({ minHeight: 56 })
    .padding({ left: 16, right: 16, top: 4, bottom: 4 })
    .backgroundColor(AppColor.cardBackground)
  }
}
