import router from '@ohos.router';
import { AppRoute } from '../app/AppRoutes';

@Entry
@Component
struct RuntimeHarnessPage {
  private openPortrait(): void {
    router.pushUrl({
      url: AppRoute.PORTRAIT_SEGMENTATION.page,
      params: {
        routeName: AppRoute.PORTRAIT_SEGMENTATION.name,
        titleKey: 'title_segmentation',
        runtimeEvidenceRunId: AppStorage.get<string>('runtimeEvidenceRunId') ?? '',
        runtimeEvidenceMode: AppStorage.get<string>('runtimeEvidenceMode') ?? ''
      }
    });
  }

  build() {
    Column() {
      Button('Open portrait')
        .width('80%')
        .constraintSize({ minHeight: 48 })
        .onClick(() => this.openPortrait())
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }
}
