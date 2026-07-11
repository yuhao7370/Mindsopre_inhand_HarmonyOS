import { common } from '@kit.AbilityKit';
import router from '@ohos.router';
import { splashLogoHeightVp, splashLogoWidthVp } from '../common/data/SplashBranding';
import { userPrivacyRulesUrl, webPagePath } from '../common/data/WebDestination';
import { appString } from '../common/i18n/AppStrings';
import { AppColor, AppRadius, AppSpacing } from '../common/theme/AppTheme';
import { PermissionRequestSummary, PermissionService } from '../services/permissions/PermissionService';
import {
  canFinishSplashForStartupPermissionState,
  finishSplashActionForStartupPermissionState,
  splashOpenAppSettingsAction,
  splashRetryPermissionAction,
  SplashStartupPermissionState,
  SplashStartupTransition,
  SplashRetryPermissionAction,
  splashStartupTransitionForMissingContext,
  splashStartupTransitionForRequest,
  splashStartupTransitionForRequestAfterPrivacyAccept
} from '../services/splash/SplashStartupService';
import {
  HarmonyPrivacyConsentStore,
  PrivacyConsentService
} from '../services/storage/PrivacyConsentService';

@Component
export struct SplashPage {
  onFinished: () => void = () => {};
  private consentService: PrivacyConsentService | undefined = undefined;
  private countdownTimer: number = -1;
  @State countdownValue: number = 3;
  @State showPrivacyDialog: boolean = false;
  @State showPermissionDialog: boolean = false;
  @State startupPermissionState: SplashStartupPermissionState = 'blocked';

  aboutToAppear() {
    const service = this.privacyConsentService();
    if (service !== undefined && service.hasAcceptedPrivacy()) {
      this.requestStartupPermissionsThenEnter();
      return;
    }
    this.showPrivacyDialog = true;
  }

  aboutToDisappear() {
    this.stopCountdown();
  }

  private uiAbilityContext(): common.UIAbilityContext | undefined {
    const context = this.getUIContext().getHostContext();
    if (!context) {
      return undefined;
    }
    return context as common.UIAbilityContext;
  }

  private privacyConsentService(): PrivacyConsentService | undefined {
    if (this.consentService !== undefined) {
      return this.consentService;
    }
    try {
      const context = this.uiAbilityContext();
      if (context === undefined) {
        return undefined;
      }
      this.consentService = new PrivacyConsentService(new HarmonyPrivacyConsentStore(context));
      return this.consentService;
    } catch (_) {
      return undefined;
    }
  }

  private startCountdown(): void {
    this.stopCountdown();
    this.countdownValue = 3;
    this.countdownTimer = setInterval(() => {
      if (this.countdownValue <= 1) {
        this.finishSplash();
        return;
      }
      this.countdownValue -= 1;
    }, 1000);
  }

  private stopCountdown(): void {
    if (this.countdownTimer >= 0) {
      clearInterval(this.countdownTimer);
      this.countdownTimer = -1;
    }
  }

  private requestStartupPermissionsThenEnter(finishImmediatelyWhenReady: boolean = false): void {
    const context = this.uiAbilityContext();
    if (context === undefined) {
      this.applyStartupTransition(splashStartupTransitionForMissingContext());
      return;
    }
    new PermissionService().requestStartup(context).then((permission: PermissionRequestSummary) => {
      this.handleStartupPermissionRequest(permission, finishImmediatelyWhenReady);
    }).catch(() => {
      this.handleStartupPermissionRequest({ ok: false, requested: [] }, finishImmediatelyWhenReady);
    });
  }

  private handleStartupPermissionRequest(
    permission: PermissionRequestSummary,
    finishImmediatelyWhenReady: boolean = false
  ): void {
    this.applyStartupTransition(finishImmediatelyWhenReady ?
      splashStartupTransitionForRequestAfterPrivacyAccept(permission) :
      splashStartupTransitionForRequest(permission));
  }

  private applyStartupTransition(transition: SplashStartupTransition): void {
    this.startupPermissionState = transition.permissionState;
    this.showPermissionDialog = transition.showPermissionDialog;
    if (transition.finishImmediately) {
      this.stopCountdown();
      this.finishSplash();
      return;
    }
    if (transition.startCountdown) {
      this.startCountdown();
      return;
    }
    this.stopCountdown();
  }

  private finishSplash(): void {
    if (!finishSplashActionForStartupPermissionState(this.startupPermissionState).finishSplash) {
      return;
    }
    this.stopCountdown();
    this.onFinished();
  }

  private acceptPrivacy(): void {
    const service = this.privacyConsentService();
    if (service !== undefined) {
      service.acceptPrivacy();
    }
    this.showPrivacyDialog = false;
    this.showPermissionDialog = false;
    this.requestStartupPermissionsThenEnter(true);
  }

  private declinePrivacy(): void {
    const service = this.privacyConsentService();
    if (service !== undefined) {
      service.declinePrivacy();
    }
    const context = this.uiAbilityContext();
    if (context !== undefined) {
      context.terminateSelf();
    }
  }

  private retryStartupPermissions(): void {
    const action: SplashRetryPermissionAction = splashRetryPermissionAction();
    this.showPermissionDialog = action.showPermissionDialog;
    if (action.requestPermissions) {
      this.requestStartupPermissionsThenEnter(true);
    }
  }

  private openAppPermissionSettings(): void {
    const context = this.uiAbilityContext();
    if (context === undefined) {
      return;
    }
    try {
      const action = splashOpenAppSettingsAction(context.applicationInfo.name);
      context.startAbility(action.want).catch(() => {
      });
    } catch (_) {
    }
  }

  private exitAfterPermissionDenied(): void {
    const context = this.uiAbilityContext();
    if (context !== undefined) {
      context.terminateSelf();
    }
  }

  private openPrivacyPolicy(): void {
    router.pushUrl({
      url: webPagePath,
      params: {
        titleKey: 'me_user_agreements',
        url: userPrivacyRulesUrl
      }
    });
  }

  @Builder
  countdownButton() {
    Row() {
      Text(`${this.countdownValue}`)
        .fontSize(14)
        .fontColor(AppColor.accent)
        .fontWeight(FontWeight.Bold)
      Text(appString('splash_count_down'))
        .fontSize(14)
        .fontColor(AppColor.accent)
    }
    .height(34)
    .padding({ left: AppSpacing.md, right: AppSpacing.md })
    .border({ width: 1, color: AppColor.accent, radius: 17 })
    .enabled(canFinishSplashForStartupPermissionState(this.startupPermissionState))
    .opacity(canFinishSplashForStartupPermissionState(this.startupPermissionState) ? 1 : 0.45)
    .onClick(() => this.finishSplash())
  }

  @Builder
  privacyDialog() {
    Column() {
      Column() {
        Text(appString('me_user_agreements'))
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColor.textPrimary)
          .width('100%')
          .textAlign(TextAlign.Center)
        Scroll() {
          Text(appString('me_privacy'))
            .fontSize(13)
            .fontColor(AppColor.textSecondary)
            .lineHeight(20)
            .width('100%')
        }
        .height(180)
        .margin({ top: AppSpacing.md })
        Text(appString('me_user_agreement'))
          .fontSize(13)
          .fontColor(AppColor.accent)
          .textAlign(TextAlign.Center)
          .margin({ top: AppSpacing.sm })
          .onClick(() => this.openPrivacyPolicy())
        Row() {
          Button(appString('me_disagree_and_exit'))
            .height(38)
            .layoutWeight(1)
            .margin({ right: AppSpacing.sm })
            .onClick(() => this.declinePrivacy())
          Button(appString('me_agree'))
            .height(38)
            .layoutWeight(1)
            .onClick(() => this.acceptPrivacy())
        }
        .width('100%')
        .margin({ top: AppSpacing.lg })
      }
      .width('86%')
      .padding(AppSpacing.lg)
      .backgroundColor(AppColor.cardBackground)
      .borderRadius(AppRadius.sheet)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .backgroundColor('#66000000')
  }

  @Builder
  permissionDialog() {
    Column() {
      Column() {
        Text(appString('feature_runtime_permissions_title'))
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColor.textPrimary)
          .width('100%')
          .textAlign(TextAlign.Center)
        Text(appString('app_need_permission'))
          .fontSize(13)
          .fontColor(AppColor.textSecondary)
          .lineHeight(20)
          .width('100%')
          .margin({ top: AppSpacing.md })
        Button(appString('app_permission_by_hand'))
          .height(38)
          .width('100%')
          .margin({ top: AppSpacing.lg })
          .onClick(() => this.openAppPermissionSettings())
        Row() {
          Button(appString('splash_permission_exit'))
            .height(38)
            .layoutWeight(1)
            .margin({ right: AppSpacing.sm })
            .onClick(() => this.exitAfterPermissionDenied())
          Button(appString('splash_permission_retry'))
            .height(38)
            .layoutWeight(1)
            .onClick(() => this.retryStartupPermissions())
        }
        .width('100%')
        .margin({ top: AppSpacing.md })
      }
      .width('86%')
      .padding(AppSpacing.lg)
      .backgroundColor(AppColor.cardBackground)
      .borderRadius(AppRadius.sheet)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .backgroundColor('#66000000')
  }

  build() {
    Stack() {
      Column() {
        Row() {
          Blank()
          this.countdownButton()
        }
        .width('100%')
        .padding({ top: AppSpacing.lg, right: AppSpacing.lg })
        Image($r('app.media.logo_splash'))
          .width(splashLogoWidthVp)
          .height(splashLogoHeightVp)
          .objectFit(ImageFit.Contain)
          .margin({ top: 88 })
        Text(appString('EntryAbility_label'))
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColor.textPrimary)
          .margin({ top: AppSpacing.xl })
        Text(appString('title_splash_welcome'))
          .fontSize(15)
          .fontColor(AppColor.textSecondary)
          .textAlign(TextAlign.Center)
          .lineHeight(22)
          .width('78%')
          .margin({ top: AppSpacing.md })
        Blank()
      }
      .width('100%')
      .height('100%')
      .backgroundColor(AppColor.pageBackground)
      if (this.showPrivacyDialog) {
        this.privacyDialog()
      }
      if (this.showPermissionDialog) {
        this.permissionDialog()
      }
    }
    .width('100%')
    .height('100%')
  }
}
