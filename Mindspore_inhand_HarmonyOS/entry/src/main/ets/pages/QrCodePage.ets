import { common } from '@kit.AbilityKit';
import router from '@ohos.router';
import { NativePageTitleBar } from '../common/components/NativePageTitleBar';
import { AppStringKey, appString } from '../common/i18n/AppStrings';
import { AppColor, AppRadius, AppSpacing } from '../common/theme/AppTheme';
import {
  QrCodeSaveSheetAction,
  qrCodeSheetActionForNativeDismiss,
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
      SaveButton({
        icon: SaveIconStyle.FULL_FILLED,
        text: SaveDescription.SAVE_IMAGE,
        buttonType: ButtonType.Capsule
      })
        .width('100%')
        .height(48)
        .enabled(!this.saveInFlight)
        .onClick((_event: ClickEvent, result: SaveButtonOnClickResult) => {
          if (result === SaveButtonOnClickResult.SUCCESS) {
            this.saveFromSheet();
            return;
          }
          this.statusKey = 'image_save_failed';
          this.applySaveSheetAction('saveFailed');
        })

      if (this.saveInFlight) {
        Text(appString('qr_save_in_progress'))
          .fontSize(14)
          .fontColor(AppColor.textSecondary)
          .textAlign(TextAlign.Center)
      } else if (this.statusKey === 'image_save_failed') {
        Text(appString('image_save_failed'))
          .fontSize(14)
          .fontColor(AppColor.textSecondary)
          .textAlign(TextAlign.Center)
      }

      Button(appString('app_cancel'))
        .width('100%')
        .height(48)
        .backgroundColor(Color.Transparent)
        .fontColor(AppColor.accent)
        .border({ width: 1, color: AppColor.accent, radius: AppRadius.button })
        .onClick(() => this.applySaveSheetAction('cancel'))
    }
    .width('100%')
    .padding({ left: AppSpacing.md, right: AppSpacing.md, top: AppSpacing.md, bottom: AppSpacing.xl })
  }

  build() {
    Column() {
      NativePageTitleBar({
        title: appString(this.titleKey),
        showMore: true,
        onBack: () => router.back(),
        onMore: () => this.applySaveSheetAction('open')
      })

      Column() {
        Column() {
          Image($r('app.media.my_qr_code'))
            .width('100%')
            .aspectRatio(1)
            .objectFit(ImageFit.Contain)
            .accessibilityText(appString(this.titleKey) as Resource)
        }
        .width('78%')
        .constraintSize({ maxWidth: 300 })
        .padding(16)
        .backgroundColor(AppColor.cardBackground)
        .border({ width: 1, color: '#E8EDF5', radius: 12 })
      }
      .width('100%')
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppColor.pageBackground)
    .bindSheet(this.showSaveSheet, this.saveActionSheet(), {
      height: SheetSize.FIT_CONTENT,
      showClose: false,
      onWillDismiss: (action: DismissSheetAction) => {
        this.applySaveSheetAction(
          qrCodeSheetActionForNativeDismiss(action.reason === DismissReason.PRESS_BACK)
        );
        action.dismiss();
      },
      onDisappear: () => {
        this.showSaveSheet = false;
      }
    })
  }
}
