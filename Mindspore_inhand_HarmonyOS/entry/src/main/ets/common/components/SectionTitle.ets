import { AppColor } from '../theme/AppTheme';

@Component
export struct SectionTitle {
  title: string = '';

  build() {
    Row() {
      Column()
        .width(4)
        .height(18)
        .backgroundColor(AppColor.accent)
      Text(this.title)
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColor.textPrimary)
        .margin({ left: 10 })
    }
    .height(30)
    .alignItems(VerticalAlign.Center)
  }
}
