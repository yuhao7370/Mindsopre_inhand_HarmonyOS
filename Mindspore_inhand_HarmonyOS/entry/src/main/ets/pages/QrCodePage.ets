import { common } from '@kit.AbilityKit';
import router from '@ohos.router';
import { AppStringKey, appString } from '../common/i18n/AppStrings';
import { AppColor, AppSpacing } from '../common/theme/AppTheme';
import {
  QrCodeSaveSheetAction,
  qrCodeSaveSheetVisibleAfterAction,
  shouldStartQrCodeSave
} from '../features/qrcode/QrCodeActionSheetState';
import {
  HarmonyQrCodeAssetWriter,
  HarmonyQrCodeMediaReader,
  QrCodeSaveResult,
  QrCodeSaveService
} from '../services/media/QrCodeSaveService';

interface QrCodePageParams {
  titleKey?: AppStringKey;
}

@Entry
@Component
struct QrCodePage {
  @State titleKey: AppStringKey = 'me_my_qr_code';
  @State statusKey: AppStringKey = 'empty';
  @State showSaveSheet: boolean = false;
  @State saveInFlight: boolean = false;

  aboutToAppear() {
    const params = router.getParams() as QrCodePageParams;
    this.titleKey = params?.titleKey ?? 'me_my_qr_code';
  }

  onBackPress(): boolean {
    if (!this.showSaveSheet) {
      return false;
    }
    this.applySaveSheetAction('back');
    return true;
  }

  private uiAbilityContext(): common.UIAbilityContext | undefined {
    const context = this.getUIContext().getHostContext();
    if (!context) {
      return undefined;
    }
    return context as common.UIAbilityContext;
  }

  private saveQrCodeImage(): Promise<QrCodeSaveResult> {
    const context = this.uiAbilityContext();
    if (context === undefined) {
      const result: QrCodeSaveResult = { ok: false, uri: '', messageKey: 'image_save_failed' };
      return Promise.resolve(result);
    }

    return new QrCodeSaveService(
      new HarmonyQrCodeMediaReader(context.resourceManager, $r('app.media.my_qr_code')),
      new HarmonyQrCodeAssetWriter(context)
    ).save()
      .catch((): QrCodeSaveResult => ({ ok: false, uri: '', messageKey: 'image_save_failed' }));
  }

  private applySaveSheetAction(action: QrCodeSaveSheetAction): void {
    this.showSaveSheet = qrCodeSaveSheetVisibleAfterAction(this.showSaveSheet, action);
  }

  private saveFromSheet(): void {
    if (!shouldStartQrCodeSave(this.saveInFlight)) {
      return;
    }
    this.saveInFlight = true;
    this.saveQrCodeImage()
      .then((result: QrCodeSaveResult) => {
        const action: QrCodeSaveSheetAction = result.ok ? 'saveSuccess' : 'saveFailed';
        this.statusKey = result.messageKey;
        this.applySaveSheetAction(action);
      })
      .catch(() => {
        this.statusKey = 'image_save_failed';
        this.applySaveSheetAction('saveFailed');
      })
      .finally(() => {
        this.saveInFlight = false;
      });
  }

  @Builder
  saveActionSheet() {
    Column() {
      Blank()
        .layoutWeight(1)
        .onClick(() => this.applySaveSheetAction('backdrop'))
      Column() {
        Row() {
          SaveButton({
            icon: SaveIconStyle.FULL_FILLED,
            text: SaveDescription.SAVE_IMAGE,
            buttonType: ButtonType.Capsule
          })
            .height(40)
            .onClick((_event: ClickEvent, result: SaveButtonOnClickResult) => {
              if (result === SaveButtonOnClickResult.SUCCESS) {
                this.saveFromSheet();
                return;
              }
              this.statusKey = 'image_save_failed';
              this.applySaveSheetAction('saveFailed');
            })
        }
        .width('100%')
        .height(56)
        .justifyContent(FlexAlign.Center)

        Column()
          .width('100%')
          .height(1)
          .backgroundColor(AppColor.divider)

        Text(appString('app_cancel'))
          .width('100%')
          .height(56)
          .fontSize(15)
          .fontColor(AppColor.textPrimary)
          .textAlign(TextAlign.Center)
          .onClick(() => this.applySaveSheetAction('cancel'))
      }
      .width('100%')
      .backgroundColor(AppColor.cardBackground)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#66000000')
  }

  build() {
    Stack() {
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
          Text('...')
            .fontSize(20)
            .fontColor(AppColor.textPrimary)
            .fontWeight(FontWeight.Bold)
            .width(44)
            .height(40)
            .textAlign(TextAlign.Center)
            .onClick(() => this.applySaveSheetAction('open'))
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

          if (this.statusKey !== 'empty') {
            Text(appString(this.statusKey))
              .fontSize(14)
              .fontColor(AppColor.textSecondary)
              .textAlign(TextAlign.Center)
              .margin({ top: AppSpacing.md })
              .padding({ left: AppSpacing.lg, right: AppSpacing.lg })
          }
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      }
      .width('100%')
      .height('100%')

      if (this.showSaveSheet) {
        this.saveActionSheet()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppColor.pageBackground)
  }
}
