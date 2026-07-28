import { AppRoute } from '../../app/AppRoutes';
import { AppStringKey } from '../i18n/AppStrings';

export type FeatureCategory = 'experience-vision' | 'experience-speech' | 'advanced-vision' | 'advanced-speech' | 'custom-models';

export interface FeatureItem {
  readonly id: string;
  readonly title: string;
  readonly titleKey: AppStringKey;
  readonly badge?: string;
  readonly badgeKey?: AppStringKey;
  readonly icon: string;
  readonly routeName: string;
  readonly visibleByDefault: boolean;
}

export interface FeatureSection {
  readonly id: FeatureCategory;
  readonly title: string;
  readonly titleKey: AppStringKey;
  readonly groupTitleKey?: AppStringKey;
  readonly items: FeatureItem[];
}

export const experienceSections: FeatureSection[] = [
  {
    id: 'experience-vision',
    title: 'Computer Vision',
    titleKey: 'tab_experience_one',
    groupTitleKey: 'experience_group_experience',
    items: [
      { id: 'posenet', title: 'PoseNet', titleKey: 'title_pose_net', icon: 'people', routeName: AppRoute.POSENET.name, visibleByDefault: true },
      { id: 'segmentation', title: 'Portrait Segmentation', titleKey: 'title_segmentation', icon: 'image', routeName: AppRoute.PORTRAIT_SEGMENTATION.name, visibleByDefault: true },
      { id: 'image', title: 'Image Classification', titleKey: 'title_image', icon: 'grid', routeName: AppRoute.IMAGE_CAMERA.name, visibleByDefault: true },
      { id: 'digit', title: 'Handwritten Digit Recognition', titleKey: 'title_handwritten_digit', icon: 'digit', routeName: AppRoute.DIGIT_STILL.name, visibleByDefault: true },
      { id: 'gesture', title: 'Gesture Recognition', titleKey: 'title_gesture_recognition', icon: 'hand', routeName: AppRoute.GESTURE_STILL.name, visibleByDefault: true },
      { id: 'dance', title: 'Dance Factory', titleKey: 'title_dance', badge: 'HOT', badgeKey: 'title_button_text_angle', icon: 'dance', routeName: AppRoute.DANCE.name, visibleByDefault: false }
    ]
  },
  {
    id: 'experience-speech',
    title: 'Speech Semantic Technology',
    titleKey: 'tab_speech_two',
    items: [
      { id: 'poetry', title: 'Intelligent poetry', titleKey: 'title_intelligent_poetry', badge: 'HOT', badgeKey: 'title_button_text_angle', icon: 'poetry', routeName: AppRoute.POETRY.name, visibleByDefault: false },
      { id: 'text', title: 'Text Extraction', titleKey: 'title_text_extraction', icon: 'text', routeName: AppRoute.TEXT_RECOGNITION.name, visibleByDefault: true },
      { id: 'translation', title: 'Text Translation', titleKey: 'title_texttranslation', icon: 'translate', routeName: AppRoute.TEXT_TRANSLATION.name, visibleByDefault: true }
    ]
  },
  {
    id: 'advanced-vision',
    title: 'Computer Vision',
    titleKey: 'tab_experience_one',
    groupTitleKey: 'experience_group_advanced',
    items: [
      { id: 'scene', title: 'Scene Detection', titleKey: 'title_scene_detection', icon: 'scene', routeName: AppRoute.SCENE_STILL.name, visibleByDefault: true },
      { id: 'objectPhoto', title: 'Object Detection(Photo)', titleKey: 'title_object', icon: 'photo', routeName: AppRoute.OBJECT_PHOTO.name, visibleByDefault: true },
      { id: 'objectCamera', title: 'Object Detection(Real-time)', titleKey: 'title_object_camera', icon: 'camera', routeName: AppRoute.OBJECT_CAMERA.name, visibleByDefault: true },
      { id: 'style', title: 'Style Transfer', titleKey: 'title_style_transfer', icon: 'style', routeName: AppRoute.STYLE_TRANSFER.name, visibleByDefault: true }
    ]
  },
  {
    id: 'custom-models',
    title: 'Model Tools',
    titleKey: 'experience_category_model_tools',
    groupTitleKey: 'experience_group_custom',
    items: [
      { id: 'custom', title: 'Custom Model', titleKey: 'title_custom_model', icon: 'model', routeName: AppRoute.CUSTOM_MODEL.name, visibleByDefault: true }
    ]
  },
  {
    id: 'advanced-speech',
    title: 'Speech Semantic Technology',
    titleKey: 'tab_speech_two',
    items: []
  }
];

export const allExperienceFeatures: FeatureItem[] = experienceSections.reduce(
  (items: FeatureItem[], section: FeatureSection) => {
    section.items.forEach((item: FeatureItem) => items.push(item));
    return items;
  },
  [] as FeatureItem[]
);

function createVisibleSection(section: FeatureSection): FeatureSection {
  return {
    id: section.id,
    title: section.title,
    titleKey: section.titleKey,
    groupTitleKey: section.groupTitleKey,
    items: section.items.filter((item: FeatureItem) => item.visibleByDefault)
  };
}

export const visibleExperienceSections: FeatureSection[] = experienceSections
  .map((section: FeatureSection) => createVisibleSection(section))
  .filter((section: FeatureSection) => section.items.length > 0);

export function findFeatureByRoute(routeName: string): FeatureItem | undefined {
  return allExperienceFeatures.find((item: FeatureItem) => item.routeName === routeName);
}
