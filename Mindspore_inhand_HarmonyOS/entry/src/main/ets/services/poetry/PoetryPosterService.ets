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
  readonly logoMediaName: string;
  readonly outerPaddingVp: number;
  readonly poemTopMarginVp: number;
  readonly poemTextPaddingVp: number;
  readonly posterMinHeightVp: number;
  readonly posterMaxWidthVp: number;
  readonly poemTextFontSizeFp: number;
  readonly poemTextMaxFontScale: number;
  readonly logoWidthVp: number;
  readonly logoHeightVp: number;
  readonly qrCodeSizeVp: number;
}

export const poetryPosterVisualSpec: PoetryPosterVisualSpec = {
  backgroundMediaName: 'poem_bg',
  frameMediaName: 'poem_frame',
  logoMediaName: 'poem_logo2',
  outerPaddingVp: 20,
  poemTopMarginVp: 20,
  poemTextPaddingVp: 20,
  posterMinHeightVp: 520,
  posterMaxWidthVp: 420,
  poemTextFontSizeFp: 15,
  poemTextMaxFontScale: 1.6,
  logoWidthVp: 76,
  logoHeightVp: 57,
  qrCodeSizeVp: 80
};

export function shouldInstallPoetryJavascriptBridge(routeName: string, url: string): boolean {
  return routeName === AppRoute.POETRY.name || url === intelligentPoetryUrl;
}

export function poetryPosterTextFromParam(text: string | undefined): string {
  return text ?? '';
}

export function shouldStartPoetryPosterAction(actionInFlight: boolean): boolean {
  return !actionInFlight;
}

export function poetryPosterImageSharePayload(uri: string, title: string, description: string): ImageSharePayload {
  return {
    title: title,
    uri: uri,
    description: description
  };
}
