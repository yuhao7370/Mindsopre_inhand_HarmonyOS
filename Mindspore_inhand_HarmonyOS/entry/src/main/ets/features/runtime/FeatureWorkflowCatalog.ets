import { AppRoute } from '../../app/AppRoutes';
import { AppStringKey } from '../../common/i18n/AppStrings';
import { LiveCameraPosition } from '../../services/camera/LiveCameraService';
import { PoseDetectionMode } from '../../services/ai/PoseService';
import {
  customModelMoreUrl,
  helpImageClassificationUrl,
  helpImageSegmentationUrl,
  helpObjectDetectionUrl,
  helpPoseNetUrl,
  helpSceneDetectionUrl,
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
  readonly runtimeTitleKey?: AppStringKey;
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
    inputKinds: ['photo', 'camera'],
    requiredPermissions: ['camera', 'media'],
    resultKind: 'poseOverlay',
    liveMode: false,
    sampleImageRawfilePath: 'posenet/skeleton_image.JPG',
    linkedLiveRouteName: AppRoute.LIVE_SKELETON.name,
    helpUrl: helpPoseNetUrl,
    helpContentKey: 'feature_runtime_help_pose_net'
  },
  {
    routeName: AppRoute.LIVE_SKELETON.name,
    titleKey: 'title_pose_net',
    summaryKey: 'workflow_summary_pose',
    aiMethod: 'detectPose',
    inputKinds: ['camera'],
    requiredPermissions: ['camera'],
    resultKind: 'poseOverlay',
    liveMode: true,
    helpUrl: helpPoseNetUrl,
    helpContentKey: 'feature_runtime_help_pose_net'
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
    linkedLiveRouteName: AppRoute.SEGMENTATION_LIVE.name,
    helpUrl: helpImageSegmentationUrl,
    helpContentKey: 'feature_runtime_help_image_segmentation'
  },
  {
    routeName: AppRoute.SEGMENTATION_LIVE.name,
    titleKey: 'title_segmentation',
    summaryKey: 'workflow_summary_segmentation',
    aiMethod: 'segmentPerson',
    inputKinds: ['camera'],
    requiredPermissions: ['camera'],
    resultKind: 'segmentationMask',
    liveMode: true,
    helpUrl: helpImageSegmentationUrl,
    helpContentKey: 'feature_runtime_help_image_segmentation'
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
    liveMode: true,
    helpUrl: helpImageSegmentationUrl,
    helpContentKey: 'feature_runtime_help_image_segmentation'
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
    summaryKey: 'workflow_summary_gesture_still_android_prompt',
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
    summaryKey: 'workflow_summary_scene_still_android_prompt',
    aiMethod: 'detectScene',
    inputKinds: ['photo', 'camera'],
    requiredPermissions: ['camera', 'media'],
    resultKind: 'sceneLabels',
    liveMode: false,
    linkedLiveRouteName: AppRoute.SCENE_LIVE.name,
    helpUrl: helpSceneDetectionUrl,
    helpContentKey: 'feature_runtime_help_scene_detection'
  },
  {
    routeName: AppRoute.SCENE_LIVE.name,
    titleKey: 'title_scene_detection',
    summaryKey: 'workflow_summary_scene',
    aiMethod: 'detectScene',
    inputKinds: ['camera'],
    requiredPermissions: ['camera'],
    resultKind: 'sceneLabels',
    liveMode: true,
    helpUrl: helpSceneDetectionUrl,
    helpContentKey: 'feature_runtime_help_scene_detection'
  },
  {
    routeName: AppRoute.TEXT_RECOGNITION.name,
    titleKey: 'title_text_extraction',
    summaryKey: 'workflow_summary_text_recognition_android_prompt',
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
    requiredPermissions: ['camera', 'media'],
    resultKind: 'translationText',
    liveMode: false,
    runActionKey: 'feature_runtime_run_translation'
  },
  {
    routeName: AppRoute.OBJECT_PHOTO.name,
    titleKey: 'title_object',
    runtimeTitleKey: 'title_object_photo_detection',
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
    runtimeTitleKey: 'title_object_camera_detection',
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
    inputKinds: ['contentImage', 'camera', 'styleImage'],
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
    inputKinds: ['modelFile', 'photo', 'camera'],
    requiredPermissions: ['camera', 'media'],
    resultKind: 'tensorSummary',
    liveMode: false,
    helpUrl: customModelMoreUrl,
    helpContentKey: 'feature_runtime_custom_model_help'
  }
];

export function workflowForRoute(routeName: string): FeatureWorkflow | undefined {
  return featureWorkflows.find((workflow: FeatureWorkflow) => workflow.routeName === routeName);
}

export type SpecializedAndroidLiveLayout = 'imageClassification' | 'objectDetection';

export function specializedAndroidLiveLayoutForWorkflow(
  workflow: FeatureWorkflow | undefined
): SpecializedAndroidLiveLayout | undefined {
  if (workflow?.routeName === AppRoute.IMAGE_CAMERA.name) {
    return 'imageClassification';
  }
  if (workflow?.routeName === AppRoute.OBJECT_CAMERA.name) {
    return 'objectDetection';
  }
  return undefined;
}

export function usesSimpleAndroidLiveLayout(workflow: FeatureWorkflow | undefined): boolean {
  const routeName = workflow?.routeName ?? '';
  return routeName === AppRoute.SEGMENTATION_LIVE.name ||
    routeName === AppRoute.GESTURE_LIVE.name ||
    routeName === AppRoute.SCENE_LIVE.name ||
    routeName === AppRoute.LIVE_SKELETON.name;
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

export function visibleInputKindsForWorkflow(workflow: FeatureWorkflow): Array<FeatureInputKind> {
  const implicitInputKind = autoStartInputKindForWorkflow(workflow) ?? initialInputKindForWorkflow(workflow);
  return runtimeInputKindsForWorkflow(workflow).filter((inputKind: FeatureInputKind) => {
    return inputKind !== implicitInputKind &&
      (workflow.routeName !== AppRoute.PORTRAIT_SEGMENTATION.name || inputKind !== 'backgroundImage') &&
      (workflow.routeName !== AppRoute.STYLE_TRANSFER.name || inputKind !== 'styleImage');
  });
}

export function shouldShowPrimaryImageInputPreview(
  workflow: FeatureWorkflow | undefined,
  overlayReady: boolean
): boolean {
  const routeName = workflow?.routeName ?? '';
  const replacesPrimaryPreview = routeName === AppRoute.OBJECT_PHOTO.name ||
    routeName === AppRoute.POSENET.name ||
    routeName === AppRoute.GESTURE_STILL.name;
  return !overlayReady || !replacesPrimaryPreview;
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

export function fixedLiveCameraPositionForWorkflow(
  workflow: FeatureWorkflow | undefined
): LiveCameraPosition | undefined {
  if (workflow === undefined) {
    return undefined;
  }
  if (workflow.routeName === AppRoute.IMAGE_CAMERA.name ||
    workflow.routeName === AppRoute.OBJECT_CAMERA.name) {
    return 'back';
  }
  return undefined;
}

const rememberedLiveCameraPositions: Map<string, LiveCameraPosition> = new Map<string, LiveCameraPosition>();

export function rememberedLiveCameraPositionForWorkflow(
  workflow: FeatureWorkflow | undefined
): LiveCameraPosition {
  const fixedPosition = fixedLiveCameraPositionForWorkflow(workflow);
  if (fixedPosition !== undefined) {
    return fixedPosition;
  }
  const routeName = workflow?.routeName ?? '';
  const rememberedPosition = routeName.length > 0 ? rememberedLiveCameraPositions.get(routeName) : undefined;
  return rememberedPosition ?? initialLiveCameraPositionForWorkflow(workflow);
}

export function rememberLiveCameraPositionForRoute(routeName: string, position: LiveCameraPosition): void {
  if (routeName.length === 0) {
    return;
  }
  if (fixedLiveCameraPositionForWorkflow(workflowForRoute(routeName)) !== undefined) {
    return;
  }
  rememberedLiveCameraPositions.set(routeName, position);
}

export function resetRememberedLiveCameraPositionsForTests(): void {
  rememberedLiveCameraPositions.clear();
}

export function poseModeForWorkflow(workflow: FeatureWorkflow): PoseDetectionMode {
  if (workflow.routeName === AppRoute.LIVE_SKELETON.name) {
    return 'yoga';
  }
  return 'normal';
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

export function workflowRuntimeTitleKey(
  workflow: FeatureWorkflow | undefined,
  fallbackTitleKey?: AppStringKey
): AppStringKey {
  return workflow?.runtimeTitleKey ?? fallbackTitleKey ?? workflow?.titleKey ?? 'feature_runtime_unknown_route';
}

export function shouldShowPrimaryRunAction(workflow: FeatureWorkflow | undefined): boolean {
  return workflow?.routeName === AppRoute.POSENET.name ||
    workflow?.routeName === AppRoute.TEXT_TRANSLATION.name ||
    workflow?.routeName === AppRoute.CUSTOM_MODEL.name;
}

export function workflowInitialStatusKey(workflow: FeatureWorkflow | undefined): AppStringKey {
  if (workflow?.routeName === AppRoute.CUSTOM_MODEL.name) {
    return 'feature_runtime_custom_model_output_placeholder';
  }
  if (workflow?.routeName === AppRoute.STYLE_TRANSFER.name) {
    return 'feature_runtime_style_choose_image';
  }
  return 'feature_runtime_status_idle';
}

export function workflowResultTitleKey(workflow: FeatureWorkflow | undefined): AppStringKey {
  return workflow?.routeName === AppRoute.CUSTOM_MODEL.name ?
    'feature_runtime_custom_model_output_title' :
    'feature_runtime_result_title';
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
  if (aiMethod === 'detectScene') {
    return labelKey === 'feature_runtime_result_scenes';
  }
  if (aiMethod === 'runCustomModel') {
    return labelKey === 'feature_runtime_result_output';
  }
  return false;
}

export function shouldShowCopyTextAction(aiMethod: string): boolean {
  return aiMethod === 'recognizeText' || aiMethod === 'translateText';
}

export function shouldShowResultSaveAction(
  workflow: FeatureWorkflow | undefined,
  _resultImageReady: boolean
): boolean {
  return workflow?.routeName === AppRoute.STYLE_TRANSFER.name ||
    workflow?.routeName === AppRoute.SEGMENTATION_STILL.name;
}

export function shouldShowStandaloneSegmentationForegroundPreview(
  workflow: FeatureWorkflow | undefined
): boolean {
  return workflow?.routeName === AppRoute.SEGMENTATION_STILL.name;
}

export function shouldShowStandaloneSegmentationOverlayPreview(
  workflow: FeatureWorkflow | undefined
): boolean {
  return workflow?.routeName === AppRoute.SEGMENTATION_STILL.name;
}

export function shouldShowCompositeSegmentationSaveAction(
  workflow: FeatureWorkflow | undefined
): boolean {
  return workflow?.routeName === AppRoute.PORTRAIT_SEGMENTATION.name;
}

export function shouldShowLiveGestureCameraOverlay(workflow: FeatureWorkflow | undefined): boolean {
  return workflow?.aiMethod === 'detectGesture' && workflow.liveMode;
}

export function shouldMirrorLiveGestureCameraOverlay(
  workflow: FeatureWorkflow | undefined,
  liveCameraPosition: LiveCameraPosition
): boolean {
  return shouldShowLiveGestureCameraOverlay(workflow) && liveCameraPosition === 'front';
}

export function shouldShowLiveObjectDetectionCameraOverlay(workflow: FeatureWorkflow | undefined): boolean {
  return workflow?.aiMethod === 'detectObjects' && workflow.liveMode;
}

export function shouldShowLivePoseCameraOverlay(workflow: FeatureWorkflow | undefined): boolean {
  return workflow?.aiMethod === 'detectPose' && workflow.liveMode;
}

export function shouldShowLivePoseTemplateOverlay(workflow: FeatureWorkflow | undefined): boolean {
  return workflow?.routeName === AppRoute.LIVE_SKELETON.name;
}

export function shouldShowLiveSegmentationCameraOverlay(workflow: FeatureWorkflow | undefined): boolean {
  return workflow?.aiMethod === 'segmentPerson' && workflow.liveMode;
}

export function shouldShowLiveClassificationCameraOverlay(workflow: FeatureWorkflow | undefined): boolean {
  return workflow?.aiMethod === 'classifyImage' && workflow.liveMode;
}

export function liveClassificationEmptyPromptKey(workflow: FeatureWorkflow | undefined): AppStringKey | undefined {
  return shouldShowLiveClassificationCameraOverlay(workflow) ? 'feature_runtime_live_classification_keep' : undefined;
}

export function shouldClearRuntimeResultAtWorkflowStart(workflow: FeatureWorkflow | undefined): boolean {
  return !shouldShowLiveClassificationCameraOverlay(workflow) &&
    workflow?.routeName !== AppRoute.PORTRAIT_SEGMENTATION.name;
}

export function shouldKeepScreenOnForWorkflow(workflow: FeatureWorkflow | undefined): boolean {
  return workflow?.routeName === AppRoute.OBJECT_PHOTO.name;
}

export function shouldMirrorSegmentationForeground(
  workflow: FeatureWorkflow | undefined,
  liveCameraPosition: LiveCameraPosition
): boolean {
  return workflow?.routeName === AppRoute.PORTRAIT_SEGMENTATION.name &&
    liveCameraPosition === 'front';
}

export function inputKindReplacesPrimaryInput(inputKind: FeatureInputKind): boolean {
  return inputKind !== 'modelFile' &&
    inputKind !== 'backgroundImage' &&
    inputKind !== 'stylePredictModelFile' &&
    inputKind !== 'styleTransferModelFile';
}

export function liveRuntimeModeForWorkflow(
  workflow: FeatureWorkflow | undefined
): boolean {
  return workflow?.liveMode === true;
}

export function shouldRenderLiveCameraPreview(
  workflow: FeatureWorkflow | undefined,
  liveCameraActive: boolean
): boolean {
  return workflow?.liveMode === true || liveCameraActive;
}

export function isInputPreparationRequestCurrent(requestId: number, currentRequestId: number): boolean {
  return requestId === currentRequestId;
}

export function shouldDeferRuntimeResultClearUntilPickResult(
  workflow: FeatureWorkflow,
  inputKind: FeatureInputKind
): boolean {
  if (inputKind === 'text' || inputKind === 'sampleImage') {
    return false;
  }
  return inputKind !== 'camera' || !workflow.liveMode;
}

export function shouldPreserveRuntimeResultAfterInputReady(
  workflow: FeatureWorkflow | undefined,
  inputKind: FeatureInputKind
): boolean {
  return workflow?.routeName === AppRoute.PORTRAIT_SEGMENTATION.name &&
    inputKind === 'backgroundImage';
}

export function shouldPreserveRuntimeVisualResultOnAiResult(
  workflow: FeatureWorkflow | undefined,
  resultOk: boolean,
  dataKind: string
): boolean {
  return workflow?.routeName === AppRoute.PORTRAIT_SEGMENTATION.name &&
    resultOk &&
    dataKind === 'segmentation';
}

export function runtimeSegmentationBackgroundImageUri(
  workflow: FeatureWorkflow | undefined,
  currentBackgroundImageUri: string,
  resultBackgroundImageUri: string
): string {
  if (workflow?.routeName === AppRoute.PORTRAIT_SEGMENTATION.name && currentBackgroundImageUri.length > 0) {
    return currentBackgroundImageUri;
  }
  return resultBackgroundImageUri;
}

export function shouldLeaveRuntimeAfterCancelledInitialPick(
  workflow: FeatureWorkflow,
  inputKind: FeatureInputKind,
  initialPick: boolean
): boolean {
  return initialPick &&
    workflow.routeName === AppRoute.OBJECT_PHOTO.name &&
    inputKind === 'photo';
}

export function cancelledPickStatusKeyForWorkflow(
  workflow: FeatureWorkflow | undefined,
  inputKind: FeatureInputKind,
  initialPick: boolean
): AppStringKey {
  if (workflow !== undefined &&
    shouldLeaveRuntimeAfterCancelledInitialPick(workflow, inputKind, initialPick)) {
    return 'feature_runtime_image_invalid';
  }
  return 'feature_runtime_pick_cancelled';
}

export function cancelledPickToastStatusKeyForWorkflow(
  workflow: FeatureWorkflow | undefined,
  inputKind: FeatureInputKind,
  initialPick: boolean
): AppStringKey | undefined {
  if (workflow !== undefined &&
    shouldLeaveRuntimeAfterCancelledInitialPick(workflow, inputKind, initialPick)) {
    return cancelledPickStatusKeyForWorkflow(workflow, inputKind, initialPick);
  }
  return undefined;
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
    (inputKind === 'photo' || inputKind === 'camera')) {
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

export function styleTransferStyleReadyStatusKey(
  workflow: FeatureWorkflow,
  inputKind: FeatureInputKind,
  contentInputReady: boolean,
  readyKey: AppStringKey
): AppStringKey {
  if (workflow.routeName === AppRoute.STYLE_TRANSFER.name &&
    inputKind === 'styleImage' &&
    !contentInputReady) {
    return 'feature_runtime_style_original_required';
  }
  return readyKey;
}

export function shouldClearTextInputAfterInputReady(workflow: FeatureWorkflow, inputKind: FeatureInputKind): boolean {
  return workflow.routeName === AppRoute.TEXT_TRANSLATION.name &&
    (inputKind === 'photo' || inputKind === 'camera');
}

export function shouldHideTextInputWhenPreparingInput(workflow: FeatureWorkflow, inputKind: FeatureInputKind): boolean {
  return workflow.routeName === AppRoute.TEXT_TRANSLATION.name &&
    (inputKind === 'photo' || inputKind === 'camera');
}

export function textInputVisibleAfterCancelledPick(
  workflow: FeatureWorkflow | undefined,
  inputKind: FeatureInputKind,
  currentTextInputVisible: boolean,
  previousTextInputVisible: boolean | undefined
): boolean {
  if (workflow !== undefined &&
    shouldHideTextInputWhenPreparingInput(workflow, inputKind) &&
    previousTextInputVisible !== undefined) {
    return previousTextInputVisible;
  }
  return currentTextInputVisible;
}

export function shouldShowStyleRecoveryControl(aiMethod: string, styledImageReady: boolean): boolean {
  return aiMethod === 'runStyleTransfer';
}

export function shouldShowStyleTransferStyledPreview(
  styledImageReady: boolean,
  originalPreviewRecovered: boolean
): boolean {
  return styledImageReady && !originalPreviewRecovered;
}

export function styleTransferRecoveryStatusKey(contentInputReady: boolean): AppStringKey {
  return contentInputReady ? 'feature_runtime_style_recovered' : 'feature_runtime_style_original_required';
}

export function shouldStartWorkflowRun(workflow: FeatureWorkflow, workflowRunning: boolean,
  liveRuntimeLoopReady: boolean): boolean {
  return (workflow.liveMode && liveRuntimeLoopReady) || !workflowRunning;
}

export function shouldAllowRuntimeInputChange(
  workflow: FeatureWorkflow | undefined,
  _inputKind: FeatureInputKind,
  workflowRunning: boolean
): boolean {
  return !workflowRunning || workflow?.routeName !== AppRoute.STYLE_TRANSFER.name;
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

export function workflowInputLabelKey(
  workflow: FeatureWorkflow | undefined,
  inputKind: FeatureInputKind
): AppStringKey {
  if ((workflow?.routeName === AppRoute.OBJECT_PHOTO.name || workflow?.routeName === AppRoute.OBJECT_CAMERA.name) &&
    inputKind === 'modelFile') {
    return 'feature_runtime_object_select_model';
  }
  if (workflow?.routeName === AppRoute.CUSTOM_MODEL.name) {
    if (inputKind === 'modelFile') {
      return 'feature_runtime_custom_model_select_model';
    }
    if (inputKind === 'photo') {
      return 'feature_runtime_custom_model_select_photo';
    }
    if (inputKind === 'camera') {
      return 'feature_runtime_custom_model_take_photo';
    }
  }
  if (workflow?.routeName === AppRoute.STYLE_TRANSFER.name) {
    if (inputKind === 'contentImage') {
      return 'feature_runtime_style_album';
    }
    if (inputKind === 'camera') {
      return 'feature_runtime_style_take_photo';
    }
    if (inputKind === 'stylePredictModelFile') {
      return 'feature_runtime_style_select_predict_model';
    }
    if (inputKind === 'styleTransferModelFile') {
      return 'feature_runtime_style_select_transfer_model';
    }
  }
  if (inputKind === 'photo' && workflowUsesAndroidHmsStillButton(workflow)) {
    return 'feature_input_photo_android';
  }
  if (inputKind === 'camera' && workflowUsesAndroidHmsStillButton(workflow)) {
    return 'feature_input_camera_android';
  }
  return inputLabelKey(inputKind);
}

export function workflowGoLiveLabelKey(workflow: FeatureWorkflow | undefined): AppStringKey {
  return workflowUsesAndroidHmsRealTimeButton(workflow) ? 'feature_runtime_go_live_android_hms' : 'feature_runtime_go_live';
}

function workflowUsesAndroidHmsStillButton(workflow: FeatureWorkflow | undefined): boolean {
  const routeName = workflow?.routeName ?? '';
  return routeName === AppRoute.POSENET.name ||
    routeName === AppRoute.SEGMENTATION_STILL.name ||
    routeName === AppRoute.GESTURE_STILL.name ||
    routeName === AppRoute.SCENE_STILL.name ||
    routeName === AppRoute.TEXT_RECOGNITION.name ||
    routeName === AppRoute.TEXT_TRANSLATION.name;
}

function workflowUsesAndroidHmsRealTimeButton(workflow: FeatureWorkflow | undefined): boolean {
  const routeName = workflow?.routeName ?? '';
  return routeName === AppRoute.POSENET.name ||
    routeName === AppRoute.SEGMENTATION_STILL.name ||
    routeName === AppRoute.GESTURE_STILL.name ||
    routeName === AppRoute.SCENE_STILL.name;
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
