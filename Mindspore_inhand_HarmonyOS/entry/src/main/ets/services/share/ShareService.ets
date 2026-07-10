import { common } from '@kit.AbilityKit';
import { uniformTypeDescriptor } from '@kit.ArkData';
import { systemShare } from '@kit.ShareKit';
import { mindSporeBaseUrl } from '../../common/data/WebDestination';
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

export interface ImageSharePayload {
  readonly title: string;
  readonly uri: string;
  readonly description: string;
}

export interface ShareImageResult {
  readonly ok: boolean;
  readonly messageKey: AppStringKey;
  readonly sharedUri: string;
}

export interface TextShareWriter {
  shareText(payload: ShareTextPayload): Promise<void>;
}

export interface ImageShareWriter {
  shareImage(payload: ImageSharePayload): Promise<void>;
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

export class HarmonySystemShareImageWriter implements ImageShareWriter {
  private readonly context: common.UIAbilityContext;

  constructor(context: common.UIAbilityContext) {
    this.context = context;
  }

  async shareImage(payload: ImageSharePayload): Promise<void> {
    const record: systemShare.SharedRecord = {
      utd: uniformTypeDescriptor.UniformDataType.JPEG,
      title: payload.title,
      uri: payload.uri,
      description: payload.description
    };
    const data = new systemShare.SharedData(record);
    await new systemShare.ShareController(data).show(this.context, {});
  }
}

export class ShareService {
  private readonly writer: TextShareWriter;
  private readonly imageWriter?: ImageShareWriter;

  constructor(writer: TextShareWriter, imageWriter?: ImageShareWriter) {
    this.writer = writer;
    this.imageWriter = imageWriter;
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

  async shareImage(payload: ImageSharePayload): Promise<ShareImageResult> {
    if (payload.uri.length === 0 || this.imageWriter === undefined) {
      return failedShareImageResult();
    }
    try {
      await this.imageWriter.shareImage(payload);
      return {
        ok: true,
        messageKey: 'poem_share_done',
        sharedUri: payload.uri
      };
    } catch (_) {
      return failedShareImageResult();
    }
  }
}

export function mindSporeInhandShareText(recommendation: string): string {
  const normalizedRecommendation = recommendation.trim();
  if (normalizedRecommendation.length === 0) {
    return mindSporeBaseUrl;
  }
  return `${normalizedRecommendation} ${mindSporeBaseUrl}`;
}

function failedShareTextResult(): ShareTextResult {
  return {
    ok: false,
    messageKey: 'me_share_failed',
    sharedTextLength: 0
  };
}

function failedShareImageResult(): ShareImageResult {
  return {
    ok: false,
    messageKey: 'poem_share_failed',
    sharedUri: ''
  };
}
