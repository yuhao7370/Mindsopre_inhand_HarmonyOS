import { common } from '@kit.AbilityKit';
import router from '@ohos.router';
import { MeItem, isMeItemPageNavigable, isMeItemUrlNavigable, visibleMeItems } from '../common/data/MeCatalog';
import {
  meDividerHeightVp,
  meRowIconGapVp,
  meRowIconSizeVp,
  meRowSideInsetVp,
  meRowVerticalPaddingVp,
  meTitleHeightVp
} from '../common/data/MeLayoutSpec';
import { webPagePath } from '../common/data/WebDestination';
import { iconLabel, iconMediaResource } from '../common/icons/IconSymbols';
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

  private valueForItem(item: MeItem): string {
    if (item.id === 'version') {
      return this.versionLabel;
    }
    return '';
  }

  @Builder
  private meIcon(item: MeItem) {
    if (iconMediaResource(item.icon) !== undefined) {
      Image(iconMediaResource(item.icon) as Resource)
        .width(meRowIconSizeVp)
        .height(meRowIconSizeVp)
        .objectFit(ImageFit.Contain)
        .margin({ right: meRowIconGapVp })
    } else {
      Text(iconLabel(item.icon))
        .fontSize(8)
        .fontWeight(FontWeight.Bold)
        .fontColor(Color.White)
        .width(meRowIconSizeVp)
        .height(meRowIconSizeVp)
        .backgroundColor(AppColor.accent)
        .borderRadius(meRowIconSizeVp / 2)
        .textAlign(TextAlign.Center)
        .maxLines(1)
        .margin({ right: meRowIconGapVp })
    }
  }

  @Builder
  private meChevron() {
    if (iconMediaResource('go') !== undefined) {
      Image(iconMediaResource('go') as Resource)
        .width(7)
        .height(12)
        .objectFit(ImageFit.Contain)
        .margin({ left: AppSpacing.sm })
    } else {
      Text('>')
        .fontSize(14)
        .fontColor(AppColor.textMuted)
        .margin({ left: AppSpacing.sm })
    }
  }

  @Builder
  meRow(item: MeItem) {
    Row() {
      this.meIcon(item)
      Text(appString(item.titleKey))
        .fontSize(16)
        .fontWeight(FontWeight.Normal)
        .fontColor('#333333')
        .layoutWeight(1)
        .maxLines(1)
      Text(this.valueForItem(item))
        .fontSize(13)
        .fontColor('#666666')
      if (isMeItemUrlNavigable(item) || isMeItemPageNavigable(item)) {
        this.meChevron()
      }
    }
    .width('100%')
    .padding({
      left: meRowSideInsetVp,
      right: meRowSideInsetVp,
      top: meRowVerticalPaddingVp,
      bottom: meRowVerticalPaddingVp
    })
    .onClick(() => this.openItem(item))
  }

  build() {
    Column() {
      Row() {
        Text(appString('me_head_title'))
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
          .textAlign(TextAlign.Center)
      }
      .width('100%')
      .height(meTitleHeightVp)
      .justifyContent(FlexAlign.Center)
      .linearGradient({
        angle: 90,
        colors: [['#59BBE3', 0], ['#6189FF', 1]]
      })
      Row() {
      }
      .width('100%')
      .height(meDividerHeightVp)
      .backgroundColor('#DBDBDB')
      Scroll() {
        Column() {
          ForEach(visibleMeItems, (item: MeItem) => {
            this.meRow(item)
          }, (item: MeItem) => item.id)
          if (this.statusKey !== 'empty') {
            Text(appString(this.statusKey))
              .fontSize(13)
              .fontColor(AppColor.textSecondary)
              .textAlign(TextAlign.Center)
              .margin({ top: AppSpacing.md })
          }
        }
        .width('100%')
      }
      .width('100%')
      .layoutWeight(1)
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.White)
  }
}
