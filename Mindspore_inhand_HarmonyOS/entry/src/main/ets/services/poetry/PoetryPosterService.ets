import { AppRoute } from '../../app/AppRoutes';
import { intelligentPoetryUrl } from '../../common/data/WebDestination';
import { ImageSharePayload } from '../share/ShareService';

export const poetryPosterPagePath: string = 'pages/PoetryPosterPage';
export const poetryPosterComponentId: string = 'poetryPosterContent';
export const poetryJavascriptBridgeName: string = 'android';
export const poetryJavascriptGenerateMethod: string = 'getGeneratePoetry';

export interface PoetryPosterVisualSpec {
  readonly backgroundMediaName: string;
  readonly frameMediaName: string;
  readonly outerPaddingVp: number;
  readonly poemTopMarginVp: number;
  readonly poemTextPaddingVp: number;
  readonly poemTextFontSizeFp: number;
  readonly qrCodeSizeVp: number;
}

export const poetryPosterVisualSpec: PoetryPosterVisualSpec = {
  backgroundMediaName: 'poem_bg',
  frameMediaName: 'poem_frame',
  outerPaddingVp: 20,
  poemTopMarginVp: 20,
  poemTextPaddingVp: 60,
  poemTextFontSizeFp: 15,
  qrCodeSizeVp: 80
};

export function shouldInstallPoetryJavascriptBridge(routeName: string, url: string): boolean {
  return routeName === AppRoute.POETRY.name || url === intelligentPoetryUrl;
}

export function poetryPosterTextFromParam(text: string | undefined): string {
  return text ?? '';
}

export function poetryPosterImageSharePayload(uri: string, title: string, description: string): ImageSharePayload {
  return {
    title: title,
    uri: uri,
    description: description
  };
}
