import { common } from '@kit.AbilityKit';
import { deviceInfo } from '@kit.BasicServicesKit';
import { picker } from '@kit.CoreFileKit';
import { camera, cameraPicker } from '@kit.CameraKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { AppRoute } from '../../app/AppRoutes';
import { FeatureInputKind, FeatureWorkflow } from '../../features/runtime/FeatureWorkflowCatalog';

export type RuntimeInputAction =
  'startLiveCamera' |
  'useSampleImage' |
  'captureImage' |
  'pickImage' |
  'pickModelFile' |
  'enterText';

export interface PickResult {
  readonly ok: boolean;
  readonly uri: string;
  readonly failure?: 'cameraUnavailable';
}

export const modelFileSuffixFilters: Array<string> = ['.ms'];
export const modelPackageSuffixFilters: Array<string> = ['.zip'];

export function isApi24EmulatorCameraPickerUnsupported(hardwareModel: string): boolean {
  const normalized = hardwareModel.toUpperCase();
  return normalized.indexOf('PHEMU') >= 0 || normalized === 'EMULATOR';
}

export function shouldUseInlineCameraFallback(
  workflow: FeatureWorkflow | undefined,
  inputKind: FeatureInputKind,
  result: PickResult
): boolean {
  return workflow?.routeName === AppRoute.SCENE_STILL.name &&
    inputKind === 'camera' &&
    !result.ok &&
    result.failure === 'cameraUnavailable';
}

export function inputActionForKind(kind: FeatureInputKind): RuntimeInputAction {
  switch (kind) {
    case 'camera':
      return 'captureImage';
    case 'sampleImage':
      return 'useSampleImage';
    case 'photo':
    case 'contentImage':
    case 'styleImage':
    case 'backgroundImage':
      return 'pickImage';
    case 'stylePredictModelFile':
    case 'styleTransferModelFile':
    case 'modelFile':
      return 'pickModelFile';
    case 'text':
      return 'enterText';
  }
}

export function runtimeInputActionForWorkflowInput(
  workflow: FeatureWorkflow,
  kind: FeatureInputKind
): RuntimeInputAction {
  if (kind === 'camera' && workflow.liveMode) {
    return 'startLiveCamera';
  }
  return inputActionForKind(kind);
}

export function runtimeInputActionsForWorkflow(workflow: FeatureWorkflow): Array<RuntimeInputAction> {
  const actions: Array<RuntimeInputAction> = [];
  workflow.inputKinds.forEach((kind: FeatureInputKind) => {
    const action = runtimeInputActionForWorkflowInput(workflow, kind);
    if (actions.indexOf(action) < 0) {
      actions.push(action);
    }
  });
  return actions;
}

export class PickerService {
  private readonly context: common.UIAbilityContext;

  constructor(context: common.UIAbilityContext) {
    this.context = context;
  }

  async captureImage(): Promise<PickResult> {
    // API24's PHEMU image has no functional cameraPicker activity: invoking it blocks the
    // ArkTS event loop before a Promise can be raced. Keep physical devices on the native picker.
    if (isApi24EmulatorCameraPickerUnsupported(deviceInfo.hardwareModel)) {
      return { ok: false, uri: '', failure: 'cameraUnavailable' };
    }
    const profile = new cameraPicker.PickerProfile();
    profile.cameraPosition = camera.CameraPosition.CAMERA_POSITION_BACK;
    try {
      const result = await cameraPicker.pick(this.context, [cameraPicker.PickerMediaType.PHOTO], profile);
      const uri = result.resultUri;
      return { ok: uri.length > 0, uri: uri };
    } catch (_) {
      return { ok: false, uri: '', failure: 'cameraUnavailable' };
    }
  }

  async pickImage(): Promise<PickResult> {
    const option = new photoAccessHelper.PhotoSelectOptions();
    option.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
    option.maxSelectNumber = 1;
    try {
      const result: photoAccessHelper.PhotoSelectResult = await new photoAccessHelper.PhotoViewPicker().select(option);
      const uri = result.photoUris.length > 0 ? result.photoUris[0] : '';
      return { ok: uri.length > 0, uri: uri };
    } catch (_) {
      return { ok: false, uri: '' };
    }
  }

  async pickModelFile(): Promise<PickResult> {
    return await this.pickDocument(modelFileSuffixFilters);
  }

  async pickModelPackage(): Promise<PickResult> {
    return await this.pickDocument(modelPackageSuffixFilters);
  }

  private async pickDocument(suffixFilters: Array<string>): Promise<PickResult> {
    const option = new picker.DocumentSelectOptions();
    option.fileSuffixFilters = suffixFilters;
    option.maxSelectNumber = 1;
    try {
      const result = await new picker.DocumentViewPicker(this.context).select(option);
      const uri = result.length > 0 ? result[0] : '';
      return { ok: uri.length > 0, uri: uri };
    } catch (_) {
      return { ok: false, uri: '' };
    }
  }
}
