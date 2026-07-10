import { AppStringKey } from '../../common/i18n/AppStrings';

export const portraitSegmentationRawfileUriPrefix: string = 'rawfile://';
export const portraitSegmentationCustomBackgroundId: string = 'custom';

export interface PortraitSegmentationBackgroundPreset {
  readonly id: string;
  readonly titleKey: AppStringKey;
  readonly mediaName: string;
  readonly rawfilePath: string;
}

export const portraitSegmentationBackgroundPresets: Array<PortraitSegmentationBackgroundPreset> = [
  {
    id: 'portrait1',
    titleKey: 'feature_runtime_portrait_background_1',
    mediaName: 'portrait1',
    rawfilePath: 'portrait/portrait1.jpg'
  },
  {
    id: 'portrait2',
    titleKey: 'feature_runtime_portrait_background_2',
    mediaName: 'portrait2',
    rawfilePath: 'portrait/portrait2.jpg'
  },
  {
    id: 'portrait3',
    titleKey: 'feature_runtime_portrait_background_3',
    mediaName: 'portrait3',
    rawfilePath: 'portrait/portrait3.jpg'
  },
  {
    id: 'portrait4',
    titleKey: 'feature_runtime_portrait_background_4',
    mediaName: 'portrait4',
    rawfilePath: 'portrait/portrait4.jpg'
  },
  {
    id: 'portrait5',
    titleKey: 'feature_runtime_portrait_background_5',
    mediaName: 'portrait5',
    rawfilePath: 'portrait/portrait5.jpg'
  }
];

export function portraitSegmentationBackgroundUri(preset: PortraitSegmentationBackgroundPreset): string {
  return `${portraitSegmentationRawfileUriPrefix}${preset.rawfilePath}`;
}

export function rawfilePathFromPortraitSegmentationBackgroundUri(uri: string): string {
  if (!uri.startsWith(portraitSegmentationRawfileUriPrefix)) {
    return uri;
  }
  return uri.substring(portraitSegmentationRawfileUriPrefix.length);
}
