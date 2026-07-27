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

  private openTextTranslation(): void {
    router.pushUrl({
      url: AppRoute.TEXT_TRANSLATION.page,
      params: {
        routeName: AppRoute.TEXT_TRANSLATION.name,
        titleKey: 'title_texttranslation',
        runtimeEvidenceRunId: AppStorage.get<string>('runtimeEvidenceRunId') ?? '',
        runtimeEvidenceMode: AppStorage.get<string>('runtimeEvidenceMode') ?? ''
      }
    });
  }

  private openStyleTransfer(): void {
    router.pushUrl({
      url: AppRoute.STYLE_TRANSFER.page,
      params: {
        routeName: AppRoute.STYLE_TRANSFER.name,
        titleKey: 'title_style_transfer',
        runtimeEvidenceRunId: AppStorage.get<string>('runtimeEvidenceRunId') ?? '',
        runtimeEvidenceMode: AppStorage.get<string>('runtimeEvidenceMode') ?? ''
      }
    });
  }

  private openCustomModel(): void {
    router.pushUrl({
      url: AppRoute.CUSTOM_MODEL.page,
      params: {
        routeName: AppRoute.CUSTOM_MODEL.name,
        titleKey: 'title_custom_model',
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
      Button('Open text translation')
        .width('80%')
        .constraintSize({ minHeight: 48 })
        .onClick(() => this.openTextTranslation())
      Button('Open style transfer')
        .width('80%')
        .constraintSize({ minHeight: 48 })
        .onClick(() => this.openStyleTransfer())
      Button('Open custom model')
        .width('80%')
        .constraintSize({ minHeight: 48 })
        .onClick(() => this.openCustomModel())
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }
}
