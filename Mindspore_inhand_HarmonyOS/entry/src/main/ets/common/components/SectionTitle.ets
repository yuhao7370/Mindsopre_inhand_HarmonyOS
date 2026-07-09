import { AppStringKey, appString } from '../i18n/AppStrings';
import { AppColor } from '../theme/AppTheme';

@Component
export struct SectionTitle {
  title: string = '';
  titleKey: AppStringKey = 'empty';

  build() {
    Row() {
      Column()
        .width(4)
        .height(18)
        .backgroundColor(AppColor.accent)
      Text(this.titleKey === 'empty' ? this.title : appString(this.titleKey))
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColor.textPrimary)
        .margin({ left: 10 })
    }
    .height(30)
    .alignItems(VerticalAlign.Center)
  }
}
