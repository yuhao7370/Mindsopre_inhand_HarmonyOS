import router from '@ohos.router';
import { webview } from '@kit.ArkWeb';
import { AppRoute } from '../app/AppRoutes';
import { NativePageTitleBar } from '../common/components/NativePageTitleBar';
import { AppStringKey, appString } from '../common/i18n/AppStrings';
import { AppColor } from '../common/theme/AppTheme';
import {
  mindSporeBaseUrl,
  userPrivacyRulesUrl,
  webDestinationForUrl,
  webUrlForRouteName,
  WebDestination
} from '../common/data/WebDestination';
import {
  poetryJavascriptBridgeName,
  poetryJavascriptGenerateMethod,
  poetryPosterTextFromParam,
  shouldInstallPoetryJavascriptBridge
} from '../services/poetry/PoetryPosterService';
import { webPageFailedAfterRequest } from '../features/web/WebPageLoadState';

interface WebPageParams {
  titleKey?: AppStringKey;
  url?: string;
  routeName?: string;
}

class PoetryJavascriptBridge {
  private readonly onPoetryGenerated: (text: string) => void;

  constructor(onPoetryGenerated: (text: string) => void) {
    this.onPoetryGenerated = onPoetryGenerated;
  }

  getGeneratePoetry(text: string): void {
    this.onPoetryGenerated(text);
  }
}

@Entry
@Component
struct WebPage {
  @State titleKey: AppStringKey = 'me_official_title';
  @State progress: number = 0;
  @State loadFailed: boolean = false;

  private readonly webController: webview.WebviewController = new webview.WebviewController();
  private readonly poetryBridge: PoetryJavascriptBridge =
    new PoetryJavascriptBridge((text: string) => this.openPoetryPoster(text));
  private routeName: string = '';
  private webUrl: string = '';
  private localRawfile: string = '';

  aboutToAppear() {
    const params = router.getParams() as WebPageParams;
    const fallbackTitleKey: AppStringKey = params?.titleKey ?? 'me_official_title';
    this.routeName = params?.routeName ?? '';
    const sourceUrl = params?.url ?? webUrlForRouteName(params?.routeName ?? '') ?? mindSporeBaseUrl;
    const destination: WebDestination = webDestinationForUrl(sourceUrl, fallbackTitleKey);
    this.titleKey = destination.titleKey;
    this.webUrl = destination.url;
    this.localRawfile = destination.localRawfile ?? '';
  }

  private openPoetryPoster(text: string): void {
    router.pushUrl({
      url: AppRoute.POETRY_POSTER.page,
      params: {
        poem: poetryPosterTextFromParam(text)
      }
    });
  }

  private handleWebError(event: OnErrorReceiveEvent): void {
    this.loadFailed = webPageFailedAfterRequest(this.loadFailed, event.request.isMainFrame());
  }

  private retryWebPage(): void {
    this.loadFailed = false;
    this.progress = 0;
    this.webController.refresh();
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
        .onPageBegin(() => {
          this.loadFailed = false;
        })
        .onErrorReceive((event: OnErrorReceiveEvent) => {
          this.handleWebError(event);
        })
        .height('100%')
        .width('100%')
    } else if (shouldInstallPoetryJavascriptBridge(this.routeName, this.webUrl)) {
      Web({ src: this.webUrl, controller: this.webController })
        .javaScriptAccess(true)
        .domStorageAccess(true)
        .mixedMode(MixedMode.All)
        .javaScriptProxy({
          object: this.poetryBridge,
          name: poetryJavascriptBridgeName,
          methodList: [poetryJavascriptGenerateMethod],
          controller: this.webController
        })
        .onProgressChange((event: OnProgressChangeEvent) => {
          this.progress = event.newProgress;
        })
        .onPageBegin(() => {
          this.loadFailed = false;
        })
        .onErrorReceive((event: OnErrorReceiveEvent) => {
          this.handleWebError(event);
        })
        .height('100%')
        .width('100%')
    } else {
      Web({ src: this.webUrl, controller: this.webController })
        .javaScriptAccess(true)
        .domStorageAccess(true)
        .mixedMode(MixedMode.All)
        .onProgressChange((event: OnProgressChangeEvent) => {
          this.progress = event.newProgress;
        })
        .onPageBegin(() => {
          this.loadFailed = false;
        })
        .onErrorReceive((event: OnErrorReceiveEvent) => {
          this.handleWebError(event);
        })
        .height('100%')
        .width('100%')
    }
  }

  build() {
    Column() {
      NativePageTitleBar({
        title: appString(this.titleKey),
        onBack: () => router.back()
      })

      Progress({ value: this.progress, total: 100, type: ProgressType.Linear })
        .width('100%')
        .height(2)
        .color(AppColor.accent)
        .backgroundColor(Color.Transparent)
        .opacity(this.progress > 0 && this.progress < 100 && !this.loadFailed ? 1 : 0)

      Stack() {
        this.webContent()
        if (this.loadFailed) {
          Column() {
            Text(appString('web_load_failed'))
            Button(appString('web_retry'))
              .height(48)
              .onClick(() => this.retryWebPage())
          }
          .width('100%')
          .height('100%')
          .justifyContent(FlexAlign.Center)
          .backgroundColor(AppColor.pageBackground)
        }
      }
      .layoutWeight(1)
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppColor.pageBackground)
  }
}
