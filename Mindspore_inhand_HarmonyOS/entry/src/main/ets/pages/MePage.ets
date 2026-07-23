import { common } from '@kit.AbilityKit';
import router from '@ohos.router';
import { MeItem, isMeItemPageNavigable, isMeItemUrlNavigable, visibleMeItems } from '../common/data/MeCatalog';
import {
  meInfoCardMinHeightVp,
  meInfoCardRadiusVp,
  meLogoSizeVp,
  mePageInsetVp,
  meTitleMinHeightVp
} from '../common/data/MeLayoutSpec';
import { webPagePath } from '../common/data/WebDestination';
import { AppStringKey, appString } from '../common/i18n/AppStrings';
import { AppColor, AppSpacing } from '../common/theme/AppTheme';
import { AppVersionService } from '../services/app/AppVersionService';
import {
  HarmonySystemShareTextWriter,
  ShareService,
  mindSporeInhandShareText
} from '../services/share/ShareService';

@Component
export struct MePage {
  @State versionLabel: string = 'V1.0.0';
  @State statusKey: AppStringKey = 'empty';

  aboutToAppear() {
    this.versionLabel = new AppVersionService().currentVersionLabel();
  }

  private openItem(item: MeItem): void {
    if (item.id === 'share') {
      this.shareApp();
      return;
    }
    if (isMeItemPageNavigable(item)) {
      router.pushUrl({
        url: item.page ?? '',
        params: {
          titleKey: item.titleKey
        }
      });
      return;
    }
    if (!isMeItemUrlNavigable(item)) {
      return;
    }
    router.pushUrl({
      url: webPagePath,
      params: {
        titleKey: item.titleKey,
        url: item.url ?? ''
      }
    });
  }

  private uiAbilityContext(): common.UIAbilityContext | undefined {
    const context = this.getUIContext().getHostContext();
    if (!context) {
      return undefined;
    }
    return context as common.UIAbilityContext;
  }

  private shareApp(): void {
    const context = this.uiAbilityContext();
    if (context === undefined) {
      this.statusKey = 'me_share_failed';
      return;
    }

    this.shareAppWithContext(context).catch(() => {
      this.statusKey = 'me_share_failed';
    });
  }

  private async shareAppWithContext(context: common.UIAbilityContext): Promise<void> {
    const title = await context.resourceManager.getStringValue($r('app.string.title_share').id);
    const recommendation = await context.resourceManager.getStringValue($r('app.string.title_share_commend').id);
    const result = await new ShareService(new HarmonySystemShareTextWriter(context)).shareText({
      title: title,
      text: mindSporeInhandShareText(recommendation)
    });
    this.statusKey = result.messageKey;
  }

  @Builder
  private versionCard(item: MeItem) {
    Row() {
      Image($r('app.media.me_version_v2'))
        .width(meLogoSizeVp)
        .height(meLogoSizeVp)
        .objectFit(ImageFit.Contain)
      Column() {
        Text(appString('EntryAbility_label'))
          .width('100%')
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColor.textPrimary)
          .maxLines(2)
        Text(appString(item.titleKey))
          .width('100%')
          .fontSize(14)
          .fontColor(AppColor.textSecondary)
          .margin({ top: 6 })
        Text(this.versionLabel)
          .width('100%')
          .fontSize(13)
          .fontColor(AppColor.textMuted)
          .margin({ top: 2 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      .margin({ left: 12 })
    }
    .width('100%')
    .constraintSize({ minHeight: meInfoCardMinHeightVp })
    .padding(14)
    .alignItems(VerticalAlign.Top)
    .backgroundColor(Color.White)
    .border({ width: 1, color: '#E8EDF5', radius: meInfoCardRadiusVp })
  }

  build() {
    Scroll() {
      Column() {
        Text(appString('me_head_title'))
          .width('100%')
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColor.textPrimary)
          .constraintSize({ minHeight: meTitleMinHeightVp })
          .padding({ top: 16, bottom: 16 })
        ForEach(visibleMeItems, (item: MeItem) => {
          if (item.id === 'version') {
            this.versionCard(item)
          }
        }, (item: MeItem) => item.id)
        if (this.statusKey !== 'empty') {
          Text(appString(this.statusKey))
            .width('100%')
            .fontSize(13)
            .fontColor(AppColor.textSecondary)
            .textAlign(TextAlign.Center)
            .margin({ top: AppSpacing.md })
        }
      }
      .width('100%')
      .padding({
        left: mePageInsetVp,
        right: mePageInsetVp,
        bottom: 28
      })
    }
    .width('100%')
    .height('100%')
    .align(Alignment.TopStart)
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.None)
    .backgroundColor(Color.White)
  }
}
