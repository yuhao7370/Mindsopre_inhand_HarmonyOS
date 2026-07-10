import { AppRoute } from '../../app/AppRoutes';
import { AppStringKey } from '../../common/i18n/AppStrings';
import {
  helpImageClassificationUrl,
  helpObjectDetectionUrl,
  helpStyleTransferUrl
} from '../../common/data/WebDestination';

export type FeatureInputKind =
  'camera' |
  'photo' |
  'sampleImage' |
  'contentImage' |
  'styleImage' |
  'backgroundImage' |
  'stylePredictModelFile' |
  'styleTransferModelFile' |
  'modelFile' |
  'text';

export type AiMethodName =
  'classifyImage' |
  'detectObjects' |
  'runStyleTransfer' |
  'runCustomModel' |
  'segmentPerson' |
  'detectPose' |
  'detectGesture' |
  'detectScene' |
  'recognizeText' |
  'translateText';

export type FeatureResultKind =
  'classification' |
  'detections' |
  'styledImage' |
  'tensorSummary' |
  'segmentationMask' |
  'poseOverlay' |
  'gestureLabel' |
  'sceneLabels' |
  'recognizedText' |
  'translationText';

export type FeaturePermissionKind = 'camera' | 'media' | 'internet';

export interface FeatureWorkflow {
  readonly routeName: string;
  readonly titleKey: AppStringKey;
  readonly summaryKey: AppStringKey;
  readonly aiMethod: AiMethodName;
  readonly inputKinds: Array<FeatureInputKind>;
  readonly optionalInputKinds?: Array<FeatureInputKind>;
  readonly requiredPermissions: Array<FeaturePermissionKind>;
  readonly resultKind: FeatureResultKind;
  readonly liveMode: boolean;
  readonly runActionKey?: AppStringKey;
  readonly helpUrl?: string;
  readonly helpContentKey?: AppStringKey;
  readonly sampleImageRawfilePath?: string;
  readonly linkedLiveRouteName?: string;
}

export interface WorkflowInputReadyAction {
  readonly userText: string;
  readonly shouldRunWorkflow: boolean;
  readonly textInputVisible: boolean;
}

export interface WorkflowInitialPreviewAction {
  readonly inputKind: FeatureInputKind;
  readonly uri: string;
  readonly readyKey: AppStringKey;
  readonly shouldRunWorkflow: boolean;
}

export const featureWorkflows: Array<FeatureWorkflow> = [
  {
    routeName: AppRoute.POSENET.name,
    titleKey: 'title_pose_net',
    summaryKey: 'workflow_summary_pose',
    aiMethod: 'detectPose',
    inputKinds: ['sampleImage', 'photo', 'camera'],
    requiredPermissions: ['camera', 'media'],
    resultKind: 'poseOverlay',
    liveMode: false,
    sampleImageRawfilePath: 'posenet/skeleton_image.JPG',
    linkedLiveRouteName: AppRoute.LIVE_SKELETON.name
  },
  {
    routeName: AppRoute.LIVE_SKELETON.name,
    titleKey: 'title_pose_net',
    summaryKey: 'workflow_summary_pose',
    aiMethod: 'detectPose',
    inputKinds: ['camera'],
    requiredPermissions: ['camera'],
    resultKind: 'poseOverlay',
    liveMode: true
  },
  {
    routeName: AppRoute.SEGMENTATION_STILL.name,
    titleKey: 'title_segmentation',
    summaryKey: 'workflow_summary_segmentation',
    aiMethod: 'segmentPerson',
    inputKinds: ['photo', 'camera'],
    requiredPermissions: ['camera', 'media'],
    resultKind: 'segmentationMask',
    liveMode: false,
    linkedLiveRouteName: AppRoute.SEGMENTATION_LIVE.name
  },
  {
    routeName: AppRoute.SEGMENTATION_LIVE.name,
    titleKey: 'title_segmentation',
    summaryKey: 'workflow_summary_segmentation',
    aiMethod: 'segmentPerson',
    inputKinds: ['camera'],
    requiredPermissions: ['camera'],
    resultKind: 'segmentationMask',
    liveMode: true
  },
  {
    routeName: AppRoute.PORTRAIT_SEGMENTATION.name,
    titleKey: 'title_segmentation',
    summaryKey: 'workflow_summary_segmentation',
    aiMethod: 'segmentPerson',
    inputKinds: ['camera'],
    optionalInputKinds: ['backgroundImage'],
    requiredPermissions: ['camera', 'media'],
    resultKind: 'segmentationMask',
    liveMode: true
  },
  {
    routeName: AppRoute.IMAGE_CAMERA.name,
    titleKey: 'title_image',
    summaryKey: 'workflow_summary_classification',
    aiMethod: 'classifyImage',
    inputKinds: ['camera'],
    requiredPermissions: ['camera'],
    resultKind: 'classification',
    liveMode: true,
    helpUrl: helpImageClassificationUrl,
    helpContentKey: 'feature_runtime_help_image_classification'
  },
  {
    routeName: AppRoute.GESTURE_STILL.name,
    titleKey: 'title_gesture_recognition',
    summaryKey: 'workflow_summary_gesture',
    aiMethod: 'detectGesture',
    inputKinds: ['photo', 'camera'],
    requiredPermissions: ['camera', 'media'],
    resultKind: 'gestureLabel',
    liveMode: false,
    linkedLiveRouteName: AppRoute.GESTURE_LIVE.name
  },
  {
    routeName: AppRoute.GESTURE_LIVE.name,
    titleKey: 'title_gesture_recognition',
    summaryKey: 'workflow_summary_gesture',
    aiMethod: 'detectGesture',
    inputKinds: ['camera'],
    requiredPermissions: ['camera'],
    resultKind: 'gestureLabel',
    liveMode: true
  },
  {
    routeName: AppRoute.SCENE_STILL.name,
    titleKey: 'title_scene_detection',
    summaryKey: 'workflow_summary_scene',
    aiMethod: 'detectScene',
    inputKinds: ['photo', 'camera'],
    requiredPermissions: ['camera', 'media'],
    resultKind: 'sceneLabels',
    liveMode: false,
    linkedLiveRouteName: AppRoute.SCENE_LIVE.name
  },
  {
    routeName: AppRoute.SCENE_LIVE.name,
    titleKey: 'title_scene_detection',
    summaryKey: 'workflow_summary_scene',
    aiMethod: 'detectScene',
    inputKinds: ['camera'],
    requiredPermissions: ['camera'],
    resultKind: 'sceneLabels',
    liveMode: true
  },
  {
    routeName: AppRoute.TEXT_RECOGNITION.name,
    titleKey: 'title_text_extraction',
    summaryKey: 'workflow_summary_text_recognition',
    aiMethod: 'recognizeText',
    inputKinds: ['photo', 'camera'],
    requiredPermissions: ['camera', 'media'],
    resultKind: 'recognizedText',
    liveMode: false
  },
  {
    routeName: AppRoute.TEXT_TRANSLATION.name,
    titleKey: 'title_texttranslation',
    summaryKey: 'workflow_summary_text_translation',
    aiMethod: 'translateText',
    inputKinds: ['text', 'camera', 'photo'],
    requiredPermissions: ['camera', 'media', 'internet'],
    resultKind: 'translationText',
    liveMode: false,
    runActionKey: 'feature_runtime_run_translation'
  },
  {
    routeName: AppRoute.OBJECT_PHOTO.name,
    titleKey: 'title_object',
    summaryKey: 'workflow_summary_object_photo',
    aiMethod: 'detectObjects',
    inputKinds: ['photo'],
    optionalInputKinds: ['modelFile'],
    requiredPermissions: ['media'],
    resultKind: 'detections',
    liveMode: false,
    helpUrl: helpObjectDetectionUrl,
    helpContentKey: 'feature_runtime_help_object_photo'
  },
  {
    routeName: AppRoute.OBJECT_CAMERA.name,
    titleKey: 'title_object_camera',
    summaryKey: 'workflow_summary_object_camera',
    aiMethod: 'detectObjects',
    inputKinds: ['camera'],
    optionalInputKinds: ['modelFile'],
    requiredPermissions: ['camera'],
    resultKind: 'detections',
    liveMode: true,
    helpUrl: helpObjectDetectionUrl,
    helpContentKey: 'feature_runtime_help_object_camera'
  },
  {
    routeName: AppRoute.STYLE_TRANSFER.name,
    titleKey: 'title_style_transfer',
    summaryKey: 'workflow_summary_style_transfer',
    aiMethod: 'runStyleTransfer',
    inputKinds: ['camera', 'contentImage', 'styleImage'],
    optionalInputKinds: ['stylePredictModelFile', 'styleTransferModelFile'],
    requiredPermissions: ['camera', 'media'],
    resultKind: 'styledImage',
    liveMode: false,
    helpUrl: helpStyleTransferUrl,
    helpContentKey: 'feature_runtime_help_style_transfer'
  },
  {
    routeName: AppRoute.CUSTOM_MODEL.name,
    titleKey: 'title_custom_model',
    summaryKey: 'workflow_summary_custom_model',
    aiMethod: 'runCustomModel',
    inputKinds: ['camera', 'photo'],
    optionalInputKinds: ['modelFile'],
    requiredPermissions: ['camera', 'media'],
    resultKind: 'tensorSummary',
    liveMode: false,
    helpContentKey: 'feature_runtime_custom_model_help'
  }
];

export function workflowForRoute(routeName: string): FeatureWorkflow | undefined {
  return featureWorkflows.find((workflow: FeatureWorkflow) => workflow.routeName === routeName);
}

export function runtimeInputKindsForWorkflow(workflow: FeatureWorkflow): Array<FeatureInputKind> {
  const kinds: Array<FeatureInputKind> = [];
  workflow.inputKinds.forEach((kind: FeatureInputKind) => appendUniqueInputKind(kinds, kind));
  workflow.optionalInputKinds?.forEach((kind: FeatureInputKind) => appendUniqueInputKind(kinds, kind));
  return kinds;
}

export function autoStartInputKindForWorkflow(workflow: FeatureWorkflow): FeatureInputKind | undefined {
  if (!workflow.liveMode || workflow.inputKinds.length !== 1 || workflow.inputKinds[0] !== 'camera') {
    return undefined;
  }
  return 'camera';
}

export function initialInputKindForWorkflow(workflow: FeatureWorkflow): FeatureInputKind | undefined {
  if (workflow.routeName === AppRoute.OBJECT_PHOTO.name) {
    return 'photo';
  }
  return undefined;
}

export function initialPreviewActionForWorkflow(workflow: FeatureWorkflow): WorkflowInitialPreviewAction | undefined {
  if (workflow.routeName !== AppRoute.POSENET.name) {
    return undefined;
  }
  const uri = sampleImageUriForWorkflow(workflow);
  if (uri.length === 0) {
    return undefined;
  }
  return {
    inputKind: 'sampleImage',
    uri: uri,
    readyKey: 'feature_runtime_image_ready',
    shouldRunWorkflow: false
  };
}

export function initialLiveCameraPositionForWorkflow(
  workflow: FeatureWorkflow | undefined
): 'back' | 'front' {
  if (workflow === undefined) {
    return 'back';
  }
  if (workflow.routeName === AppRoute.SEGMENTATION_LIVE.name ||
    workflow.routeName === AppRoute.PORTRAIT_SEGMENTATION.name ||
    workflow.routeName === AppRoute.SCENE_LIVE.name) {
    return 'front';
  }
  return 'back';
}

export function sampleImageUriForWorkflow(workflow: FeatureWorkflow): string {
  const path = workflow.sampleImageRawfilePath ?? '';
  if (path.length === 0) {
    return '';
  }
  return `rawfile://${path}`;
}

export function workflowRunActionKey(workflow: FeatureWorkflow | undefined): AppStringKey {
  return workflow?.runActionKey ?? 'feature_runtime_run';
}

export function shouldUseLongTextInput(workflow: FeatureWorkflow | undefined): boolean {
  return workflow?.routeName === AppRoute.TEXT_TRANSLATION.name;
}

export function textInputPlaceholderKeyForWorkflow(workflow: FeatureWorkflow | undefined): AppStringKey {
  if (workflow?.routeName === AppRoute.TEXT_TRANSLATION.name) {
    return 'feature_runtime_text_translation_placeholder';
  }
  return 'feature_runtime_text_placeholder';
}

export function shouldUseLongTextResultRow(aiMethod: string, labelKey: AppStringKey): boolean {
  if (aiMethod === 'recognizeText') {
    return labelKey === 'feature_runtime_result_text';
  }
  if (aiMethod === 'translateText') {
    return labelKey === 'feature_runtime_result_text' ||
      labelKey === 'feature_runtime_result_translated_text';
  }
  return false;
}

export function inputKindReplacesPrimaryInput(inputKind: FeatureInputKind): boolean {
  return inputKind !== 'modelFile' &&
    inputKind !== 'backgroundImage' &&
    inputKind !== 'stylePredictModelFile' &&
    inputKind !== 'styleTransferModelFile';
}

export function shouldAutoRunWorkflowAfterInputReady(workflow: FeatureWorkflow, inputKind: FeatureInputKind): boolean {
  if (workflow.routeName === AppRoute.OBJECT_PHOTO.name && inputKind === 'photo') {
    return true;
  }
  if ((workflow.routeName === AppRoute.SEGMENTATION_STILL.name ||
    workflow.routeName === AppRoute.GESTURE_STILL.name ||
    workflow.routeName === AppRoute.SCENE_STILL.name) &&
    (inputKind === 'photo' || inputKind === 'camera')) {
    return true;
  }
  if (workflow.routeName === AppRoute.POSENET.name &&
    (inputKind === 'sampleImage' || inputKind === 'photo' || inputKind === 'camera')) {
    return true;
  }
  return (workflow.routeName === AppRoute.TEXT_RECOGNITION.name ||
    workflow.routeName === AppRoute.TEXT_TRANSLATION.name) &&
    (inputKind === 'photo' || inputKind === 'camera');
}

export function shouldAutoRunStyleTransferAfterStyleReady(
  workflow: FeatureWorkflow,
  inputKind: FeatureInputKind,
  contentInputReady: boolean
): boolean {
  return workflow.routeName === AppRoute.STYLE_TRANSFER.name &&
    inputKind === 'styleImage' &&
    contentInputReady;
}

export function shouldClearTextInputAfterInputReady(workflow: FeatureWorkflow, inputKind: FeatureInputKind): boolean {
  return workflow.routeName === AppRoute.TEXT_TRANSLATION.name &&
    (inputKind === 'photo' || inputKind === 'camera');
}

export function shouldShowStyleRecoveryControl(aiMethod: string, styledImageReady: boolean): boolean {
  return aiMethod === 'runStyleTransfer' && styledImageReady;
}

export function shouldStartWorkflowRun(workflow: FeatureWorkflow, workflowRunning: boolean): boolean {
  return workflow.liveMode || !workflowRunning;
}

export function workflowInputReadyAction(workflow: FeatureWorkflow, inputKind: FeatureInputKind,
  currentUserText: string): WorkflowInputReadyAction {
  const shouldClearTextInput = shouldClearTextInputAfterInputReady(workflow, inputKind);
  return {
    userText: shouldClearTextInput ? '' : currentUserText,
    shouldRunWorkflow: shouldAutoRunWorkflowAfterInputReady(workflow, inputKind),
    textInputVisible: !shouldClearTextInput
  };
}

function appendUniqueInputKind(kinds: Array<FeatureInputKind>, kind: FeatureInputKind): void {
  if (kinds.indexOf(kind) < 0) {
    kinds.push(kind);
  }
}

export function inputLabelKey(inputKind: FeatureInputKind): AppStringKey {
  switch (inputKind) {
    case 'camera':
      return 'feature_input_camera';
    case 'photo':
      return 'feature_input_photo';
    case 'sampleImage':
      return 'feature_input_sample_image';
    case 'contentImage':
      return 'feature_input_content_image';
    case 'styleImage':
      return 'feature_input_style_image';
    case 'backgroundImage':
      return 'feature_input_background_image';
    case 'stylePredictModelFile':
      return 'feature_input_style_predict_model_file';
    case 'styleTransferModelFile':
      return 'feature_input_style_transfer_model_file';
    case 'modelFile':
      return 'feature_input_model_file';
    case 'text':
      return 'feature_input_text';
  }
}

export function permissionLabelKey(permissionKind: FeaturePermissionKind): AppStringKey {
  switch (permissionKind) {
    case 'camera':
      return 'feature_permission_camera';
    case 'media':
      return 'feature_permission_media';
    case 'internet':
      return 'feature_permission_internet';
  }
}
