import router from '@ohos.router';
import { AppStringKey, appString } from '../common/i18n/AppStrings';
import { AppColor, AppSpacing } from '../common/theme/AppTheme';

interface QrCodePageParams {
  titleKey?: AppStringKey;
}

@Entry
@Component
struct QrCodePage {
  @State titleKey: AppStringKey = 'me_my_qr_code';

  aboutToAppear() {
    const params = router.getParams() as QrCodePageParams;
    this.titleKey = params?.titleKey ?? 'me_my_qr_code';
  }

  build() {
    Column() {
      Row() {
        Text('<')
          .fontSize(24)
          .fontColor(AppColor.textPrimary)
          .fontWeight(FontWeight.Bold)
          .width(40)
          .height(40)
          .textAlign(TextAlign.Center)
          .onClick(() => router.back())
        Text(appString(this.titleKey))
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColor.textPrimary)
          .layoutWeight(1)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%')
      .height(56)
      .padding({ left: AppSpacing.md, right: AppSpacing.md })
      .backgroundColor(AppColor.cardBackground)

      Column() {
        Image($r('app.media.my_qr_code'))
          .width('78%')
          .aspectRatio(1)
          .objectFit(ImageFit.Contain)
      }
      .width('100%')
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppColor.pageBackground)
  }
}
