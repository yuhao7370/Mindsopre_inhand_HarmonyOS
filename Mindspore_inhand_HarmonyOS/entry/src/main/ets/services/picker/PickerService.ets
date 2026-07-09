import { common } from '@kit.AbilityKit';
import { picker } from '@kit.CoreFileKit';
import { camera, cameraPicker } from '@kit.CameraKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { FeatureInputKind, FeatureWorkflow } from '../../features/runtime/FeatureWorkflowCatalog';

export type RuntimeInputAction =
  'captureImage' |
  'pickImage' |
  'pickModelFile' |
  'enterText';

export interface PickResult {
  readonly ok: boolean;
  readonly uri: string;
}

export const modelFileSuffixFilters: Array<string> = ['.ms'];

export function inputActionForKind(kind: FeatureInputKind): RuntimeInputAction {
  switch (kind) {
    case 'camera':
      return 'captureImage';
    case 'photo':
    case 'contentImage':
    case 'styleImage':
      return 'pickImage';
    case 'modelFile':
      return 'pickModelFile';
    case 'text':
      return 'enterText';
  }
}

export function runtimeInputActionsForWorkflow(workflow: FeatureWorkflow): Array<RuntimeInputAction> {
  const actions: Array<RuntimeInputAction> = [];
  workflow.inputKinds.forEach((kind: FeatureInputKind) => {
    const action = inputActionForKind(kind);
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
    const profile = new cameraPicker.PickerProfile();
    profile.cameraPosition = camera.CameraPosition.CAMERA_POSITION_BACK;
    try {
      const result = await cameraPicker.pick(this.context, [cameraPicker.PickerMediaType.PHOTO], profile);
      const uri = result.resultUri;
      return { ok: uri.length > 0, uri: uri };
    } catch (_) {
      return { ok: false, uri: '' };
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
    const option = new picker.DocumentSelectOptions();
    option.fileSuffixFilters = modelFileSuffixFilters;
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
