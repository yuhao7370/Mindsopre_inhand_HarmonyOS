import { AppColor } from '../theme/AppTheme';

@Component
export struct GradientTitleBar {
  title: string = '';
  subtitle: string = '';

  build() {
    Column() {
      Text(this.title)
        .fontSize(28)
        .fontWeight(FontWeight.Bold)
        .fontColor(Color.White)
      if (this.subtitle.length > 0) {
        Text(this.subtitle)
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
