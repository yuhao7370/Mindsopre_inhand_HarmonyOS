import router from '@ohos.router';
import { webview } from '@kit.ArkWeb';
import { AppStringKey, appString } from '../common/i18n/AppStrings';
import { AppColor, AppSpacing } from '../common/theme/AppTheme';
import {
  mindSporeBaseUrl,
  userPrivacyRulesUrl,
  webDestinationForUrl,
  WebDestination
} from '../common/data/WebDestination';

interface WebPageParams {
  titleKey?: AppStringKey;
  url?: string;
  routeName?: string;
}

@Entry
@Component
struct WebPage {
  @State titleKey: AppStringKey = 'me_official_title';
  @State progress: number = 0;

  private readonly webController: webview.WebviewController = new webview.WebviewController();
  private webUrl: string = '';
  private localRawfile: string = '';

  aboutToAppear() {
    const params = router.getParams() as WebPageParams;
    const fallbackTitleKey: AppStringKey = params?.titleKey ?? 'me_official_title';
    const sourceUrl = params?.url ?? (params?.routeName === '/app/PrivacyPolicyActivity' ? userPrivacyRulesUrl : mindSporeBaseUrl);
    const destination: WebDestination = webDestinationForUrl(sourceUrl, fallbackTitleKey);
    this.titleKey = destination.titleKey;
    this.webUrl = destination.url;
    this.localRawfile = destination.localRawfile ?? '';
  }

  @Builder
  webContent() {
    if (this.localRawfile.length > 0) {
      Web({ src: $rawfile('privacy.html'), controller: this.webController })
        .javaScriptAccess(true)
        .domStorageAccess(true)
        .mixedMode(MixedMode.All)
        .onProgressChange((event: OnProgressChangeEvent) => {
          this.progress = event.newProgress;
        })
        .layoutWeight(1)
        .width('100%')
    } else {
      Web({ src: this.webUrl, controller: this.webController })
        .javaScriptAccess(true)
        .domStorageAccess(true)
        .mixedMode(MixedMode.All)
        .onProgressChange((event: OnProgressChangeEvent) => {
          this.progress = event.newProgress;
        })
        .layoutWeight(1)
        .width('100%')
    }
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

      if (this.progress > 0 && this.progress < 100) {
        Progress({ value: this.progress, total: 100, type: ProgressType.Linear })
          .width('100%')
          .height(2)
          .color(AppColor.accent)
          .backgroundColor(AppColor.divider)
      }

      this.webContent()
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppColor.pageBackground)
  }
}
