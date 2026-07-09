import { AppStringKey, appString } from '../i18n/AppStrings';
import { AppColor } from '../theme/AppTheme';

@Component
export struct GradientTitleBar {
  title: string = '';
  titleKey: AppStringKey = 'empty';
  subtitle: string = '';
  subtitleKey: AppStringKey = 'empty';

  build() {
    Column() {
      Text(this.titleKey === 'empty' ? this.title : appString(this.titleKey))
        .fontSize(28)
        .fontWeight(FontWeight.Bold)
        .fontColor(Color.White)
        .textAlign(TextAlign.Center)
      if (this.subtitle.length > 0 || this.subtitleKey !== 'empty') {
        Text(this.subtitleKey === 'empty' ? this.subtitle : appString(this.subtitleKey))
          .fontSize(16)
          .fontColor(Color.White)
          .textAlign(TextAlign.Center)
          .margin({ top: 16 })
      }
    }
    .width('100%')
    .height(210)
    .justifyContent(FlexAlign.Center)
    .linearGradient({
      angle: 120,
      colors: [[AppColor.primaryStart, 0], [AppColor.primaryEnd, 1]]
    })
  }
}
