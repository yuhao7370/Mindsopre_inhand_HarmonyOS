import { FeatureInputKind } from './FeatureWorkflowCatalog';
import {
  portraitSegmentationBackgroundStateAfterCancelledPick
} from './PortraitSegmentationBackgroundCatalog';

export interface FeatureRuntimePickedInputState {
  readonly selectedInputSummary: string;
  readonly imageInputUri: string;
  readonly contentImageUri: string;
  readonly styleImageUri: string;
  readonly backgroundImageUri: string;
  readonly selectedPortraitBackgroundPresetId: string;
  readonly modelInputUri: string;
  readonly stylePredictModelInputUri: string;
  readonly styleTransferModelInputUri: string;
}

export function runtimePickedInputStateAfterCancelledPick(
  routeName: string,
  inputKind: FeatureInputKind,
  state: FeatureRuntimePickedInputState
): FeatureRuntimePickedInputState {
  if (inputKind !== 'backgroundImage') {
    return state;
  }
  const backgroundState = portraitSegmentationBackgroundStateAfterCancelledPick(
    routeName,
    state.backgroundImageUri,
    state.selectedPortraitBackgroundPresetId
  );
  return {
    selectedInputSummary: state.selectedInputSummary,
    imageInputUri: state.imageInputUri,
    contentImageUri: state.contentImageUri,
    styleImageUri: state.styleImageUri,
    backgroundImageUri: backgroundState.backgroundImageUri,
    selectedPortraitBackgroundPresetId: backgroundState.selectedPresetId,
    modelInputUri: state.modelInputUri,
    stylePredictModelInputUri: state.stylePredictModelInputUri,
    styleTransferModelInputUri: state.styleTransferModelInputUri
  };
}

export function runtimePickedInputStateAfterModelCacheFailure(
  inputKind: FeatureInputKind,
  state: FeatureRuntimePickedInputState
): FeatureRuntimePickedInputState {
  if (inputKind !== 'modelFile' &&
    inputKind !== 'stylePredictModelFile' &&
    inputKind !== 'styleTransferModelFile') {
    return state;
  }
  return {
    selectedInputSummary: '',
    imageInputUri: state.imageInputUri,
    contentImageUri: state.contentImageUri,
    styleImageUri: state.styleImageUri,
    backgroundImageUri: state.backgroundImageUri,
    selectedPortraitBackgroundPresetId: state.selectedPortraitBackgroundPresetId,
    modelInputUri: state.modelInputUri,
    stylePredictModelInputUri: state.stylePredictModelInputUri,
    styleTransferModelInputUri: state.styleTransferModelInputUri
  };
}
