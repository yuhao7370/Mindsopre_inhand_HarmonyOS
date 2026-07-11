import { webPagePath } from '../../common/data/WebDestination';
import { AppStringKey } from '../../common/i18n/AppStrings';

export interface ExternalHelpLinkOpenOptions {
  readonly hideFailureTipDialog?: boolean;
}

export interface ExternalHelpLinkContext {
  openLink(link: string, options?: ExternalHelpLinkOpenOptions): Promise<void>;
}

export interface RuntimeHelpRouteParams {
  readonly titleKey: AppStringKey;
  readonly url: string;
}

export interface RuntimeHelpRouteOptions {
  readonly url: string;
  readonly params: RuntimeHelpRouteParams;
}

export interface ExternalHelpNavigator {
  pushUrl(options: RuntimeHelpRouteOptions): void;
}

export type RuntimeHelpOpenResult = 'external' | 'fallback' | 'ignored';

export async function openRuntimeHelpSource(
  context: ExternalHelpLinkContext | undefined,
  helpUrl: string,
  titleKey: AppStringKey,
  navigator: ExternalHelpNavigator
): Promise<RuntimeHelpOpenResult> {
  if (helpUrl.length === 0) {
    return 'ignored';
  }

  if (context !== undefined) {
    try {
      await context.openLink(helpUrl, { hideFailureTipDialog: true });
      return 'external';
    } catch (_) {
    }
  }

  try {
    navigator.pushUrl({
      url: webPagePath,
      params: {
        titleKey: titleKey,
        url: helpUrl
      }
    });
  } catch (_) {
  }
  return 'fallback';
}
