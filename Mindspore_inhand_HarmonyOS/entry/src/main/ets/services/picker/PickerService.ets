import { common } from '@kit.AbilityKit';
import { picker } from '@kit.CoreFileKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { FeatureInputKind, FeatureWorkflow } from '../../features/runtime/FeatureWorkflowCatalog';

export type RuntimeInputAction =
  'captureOrPickImage' |
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
    case 'photo':
    case 'contentImage':
    case 'styleImage':
      return 'captureOrPickImage';
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
