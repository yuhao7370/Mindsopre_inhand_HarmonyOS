import router from '@ohos.router';
import { allExperienceFeatures, FeatureItem } from '../common/data/FeatureCatalog';
import { AppStringKey, appString } from '../common/i18n/AppStrings';
import { AppColor, AppSpacing } from '../common/theme/AppTheme';

interface FeatureStubParams {
  title?: string;
  titleKey?: AppStringKey;
  routeName?: string;
  url?: string;
}

@Entry
@Component
struct FeatureStubPage {
  @State title: string = '';
  @State titleKey: AppStringKey = 'feature_stub_title';
  @State routeName: string = '';
  @State sourceUrl: string = '';

  aboutToAppear() {
    const params = router.getParams() as FeatureStubParams;
    this.routeName = params?.routeName ?? '';
    this.sourceUrl = params?.url ?? '';
    const feature = allExperienceFeatures.find((item: FeatureItem) => item.routeName === this.routeName);
    this.title = params?.title ?? feature?.title ?? '';
    this.titleKey = params?.titleKey ?? feature?.titleKey ?? this.titleKey;
  }

  build() {
    Column() {
      Text(this.titleKey === 'feature_stub_title' && this.title.length > 0 ? this.title : appString(this.titleKey))
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColor.textPrimary)
        .textAlign(TextAlign.Center)
      Text(appString('feature_stub_message'))
        .fontSize(15)
        .fontColor(AppColor.textSecondary)
        .textAlign(TextAlign.Center)
        .margin({ top: 16 })
      if (this.sourceUrl.length > 0) {
        Text(this.sourceUrl)
          .fontSize(12)
          .fontColor(AppColor.textMuted)
          .textAlign(TextAlign.Center)
          .margin({ top: 12 })
      }
      Button(appString('action_back'))
        .margin({ top: 28 })
        .onClick(() => router.back())
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .padding(AppSpacing.xl)
    .backgroundColor(AppColor.pageBackground)
  }
}
