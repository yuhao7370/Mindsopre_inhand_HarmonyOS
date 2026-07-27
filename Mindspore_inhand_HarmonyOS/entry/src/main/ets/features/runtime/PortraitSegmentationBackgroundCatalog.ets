import { AppStringKey } from '../../common/i18n/AppStrings';
import { AppRoute } from '../../app/AppRoutes';

export const portraitSegmentationRawfileUriPrefix: string = 'rawfile://';
export const portraitSegmentationCustomBackgroundId: string = 'custom';
export const portraitSegmentationOriginalBackgroundId: string = 'original';

export interface PortraitSegmentationBackgroundPreset {
  readonly id: string;
  readonly titleKey: AppStringKey;
  readonly mediaName: string;
  readonly rawfilePath: string;
}

export interface PortraitSegmentationBackgroundState {
  readonly backgroundImageUri: string;
  readonly selectedPresetId: string;
}

export const portraitSegmentationBackgroundPresets: Array<PortraitSegmentationBackgroundPreset> = [
  {
    id: portraitSegmentationOriginalBackgroundId,
    titleKey: 'feature_runtime_portrait_background_1',
    mediaName: portraitSegmentationOriginalBackgroundId,
    rawfilePath: ''
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

export const defaultPortraitSegmentationBackgroundPreset: PortraitSegmentationBackgroundPreset =
  portraitSegmentationBackgroundPresets[0];

export function portraitSegmentationBackgroundUri(preset: PortraitSegmentationBackgroundPreset): string {
  if (preset.id === portraitSegmentationOriginalBackgroundId) {
    return '';
  }
  return `${portraitSegmentationRawfileUriPrefix}${preset.rawfilePath}`;
}

export function defaultPortraitSegmentationBackgroundUri(): string {
  return portraitSegmentationBackgroundUri(defaultPortraitSegmentationBackgroundPreset);
}

export function initialPortraitSegmentationBackgroundState(routeName: string, backgroundImageUri: string,
  selectedPresetId: string): PortraitSegmentationBackgroundState {
  if (routeName !== AppRoute.PORTRAIT_SEGMENTATION.name || backgroundImageUri.length > 0 ||
    selectedPresetId.length > 0) {
    return {
      backgroundImageUri: backgroundImageUri,
      selectedPresetId: selectedPresetId
    };
  }
  return {
    backgroundImageUri: defaultPortraitSegmentationBackgroundUri(),
    selectedPresetId: defaultPortraitSegmentationBackgroundPreset.id
  };
}

export function portraitSegmentationBackgroundStateAfterCancelledPick(routeName: string, backgroundImageUri: string,
  selectedPresetId: string): PortraitSegmentationBackgroundState {
  if (routeName !== AppRoute.PORTRAIT_SEGMENTATION.name) {
    return {
      backgroundImageUri: '',
      selectedPresetId: ''
    };
  }
  return {
    backgroundImageUri: backgroundImageUri,
    selectedPresetId: selectedPresetId
  };
}

export function rawfilePathFromPortraitSegmentationBackgroundUri(uri: string): string {
  if (!uri.startsWith(portraitSegmentationRawfileUriPrefix)) {
    return uri;
  }
  return uri.substring(portraitSegmentationRawfileUriPrefix.length);
}
