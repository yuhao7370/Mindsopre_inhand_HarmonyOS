import { common } from '@kit.AbilityKit';
import { uniformTypeDescriptor } from '@kit.ArkData';
import { systemShare } from '@kit.ShareKit';
import { meApkUrl } from '../../common/data/WebDestination';
import { AppStringKey } from '../../common/i18n/AppStrings';

export interface ShareTextPayload {
  readonly title: string;
  readonly text: string;
}

export interface ShareTextResult {
  readonly ok: boolean;
  readonly messageKey: AppStringKey;
  readonly sharedTextLength: number;
}

export interface TextShareWriter {
  shareText(payload: ShareTextPayload): Promise<void>;
}

export class HarmonySystemShareTextWriter implements TextShareWriter {
  private readonly context: common.UIAbilityContext;

  constructor(context: common.UIAbilityContext) {
    this.context = context;
  }

  async shareText(payload: ShareTextPayload): Promise<void> {
    const record: systemShare.SharedRecord = {
      utd: uniformTypeDescriptor.UniformDataType.PLAIN_TEXT,
      title: payload.title,
      content: payload.text,
      description: payload.text
    };
    const data = new systemShare.SharedData(record);
    await new systemShare.ShareController(data).show(this.context, {});
  }
}

export class ShareService {
  private readonly writer: TextShareWriter;

  constructor(writer: TextShareWriter) {
    this.writer = writer;
  }

  async shareText(payload: ShareTextPayload): Promise<ShareTextResult> {
    if (payload.text.length === 0) {
      return failedShareTextResult();
    }
    try {
      await this.writer.shareText(payload);
      return {
        ok: true,
        messageKey: 'me_share_done',
        sharedTextLength: payload.text.length
      };
    } catch (_) {
      return failedShareTextResult();
    }
  }
}

export function mindSporeInhandShareText(recommendation: string): string {
  const normalizedRecommendation = recommendation.trim();
  if (normalizedRecommendation.length === 0) {
    return meApkUrl;
  }
  return `${normalizedRecommendation} ${meApkUrl}`;
}

function failedShareTextResult(): ShareTextResult {
  return {
    ok: false,
    messageKey: 'me_share_failed',
    sharedTextLength: 0
  };
}
