import { AppRoute } from '../../app/AppRoutes';
import { AppStringKey } from '../../common/i18n/AppStrings';

export type FeatureInputKind =
  'camera' |
  'photo' |
  'contentImage' |
  'styleImage' |
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
  'recognizedText' |
  'translationText';

export type FeaturePermissionKind = 'camera' | 'media' | 'internet';

export interface FeatureWorkflow {
  readonly routeName: string;
  readonly titleKey: AppStringKey;
  readonly summaryKey: AppStringKey;
  readonly aiMethod: AiMethodName;
  readonly inputKinds: Array<FeatureInputKind>;
  readonly requiredPermissions: Array<FeaturePermissionKind>;
  readonly resultKind: FeatureResultKind;
  readonly liveMode: boolean;
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
    liveMode: true
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
    liveMode: false
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
    inputKinds: ['photo'],
    requiredPermissions: ['media'],
    resultKind: 'segmentationMask',
    liveMode: false
  },
  {
    routeName: AppRoute.IMAGE_CAMERA.name,
    titleKey: 'title_image',
    summaryKey: 'workflow_summary_classification',
    aiMethod: 'classifyImage',
    inputKinds: ['camera'],
    requiredPermissions: ['camera'],
    resultKind: 'classification',
    liveMode: true
  },
  {
    routeName: AppRoute.GESTURE_STILL.name,
    titleKey: 'title_gesture_recognition',
    summaryKey: 'workflow_summary_gesture',
    aiMethod: 'detectGesture',
    inputKinds: ['photo', 'camera'],
    requiredPermissions: ['camera', 'media'],
    resultKind: 'gestureLabel',
    liveMode: false
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
    liveMode: false
  },
  {
    routeName: AppRoute.OBJECT_PHOTO.name,
    titleKey: 'title_object',
    summaryKey: 'workflow_summary_object_photo',
    aiMethod: 'detectObjects',
    inputKinds: ['photo', 'modelFile'],
    requiredPermissions: ['media'],
    resultKind: 'detections',
    liveMode: false
  },
  {
    routeName: AppRoute.OBJECT_CAMERA.name,
    titleKey: 'title_object_camera',
    summaryKey: 'workflow_summary_object_camera',
    aiMethod: 'detectObjects',
    inputKinds: ['camera', 'modelFile'],
    requiredPermissions: ['camera', 'media'],
    resultKind: 'detections',
    liveMode: true
  },
  {
    routeName: AppRoute.STYLE_TRANSFER.name,
    titleKey: 'title_style_transfer',
    summaryKey: 'workflow_summary_style_transfer',
    aiMethod: 'runStyleTransfer',
    inputKinds: ['camera', 'contentImage', 'styleImage', 'modelFile'],
    requiredPermissions: ['camera', 'media'],
    resultKind: 'styledImage',
    liveMode: false
  },
  {
    routeName: AppRoute.CUSTOM_MODEL.name,
    titleKey: 'title_custom_model',
    summaryKey: 'workflow_summary_custom_model',
    aiMethod: 'runCustomModel',
    inputKinds: ['camera', 'photo', 'modelFile'],
    requiredPermissions: ['camera', 'media'],
    resultKind: 'tensorSummary',
    liveMode: false
  },
  {
    routeName: AppRoute.DANCE.name,
    titleKey: 'title_dance',
    summaryKey: 'workflow_summary_pose',
    aiMethod: 'detectPose',
    inputKinds: ['camera'],
    requiredPermissions: ['camera'],
    resultKind: 'poseOverlay',
    liveMode: true
  },
  {
    routeName: AppRoute.POETRY.name,
    titleKey: 'title_intelligent_poetry',
    summaryKey: 'workflow_summary_text_translation',
    aiMethod: 'translateText',
    inputKinds: ['text'],
    requiredPermissions: ['internet'],
    resultKind: 'translationText',
    liveMode: false
  }
];

export function workflowForRoute(routeName: string): FeatureWorkflow | undefined {
  return featureWorkflows.find((workflow: FeatureWorkflow) => workflow.routeName === routeName);
}

export function inputLabelKey(inputKind: FeatureInputKind): AppStringKey {
  switch (inputKind) {
    case 'camera':
      return 'feature_input_camera';
    case 'photo':
      return 'feature_input_photo';
    case 'contentImage':
      return 'feature_input_content_image';
    case 'styleImage':
      return 'feature_input_style_image';
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
