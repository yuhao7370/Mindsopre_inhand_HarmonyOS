import { AppRoute } from '../../app/AppRoutes';

export type FeatureCategory = 'experience-vision' | 'experience-speech' | 'advanced-vision' | 'advanced-speech';

export interface FeatureItem {
  readonly id: string;
  readonly title: string;
  readonly badge?: string;
  readonly icon: string;
  readonly routeName: string;
  readonly visibleByDefault: boolean;
}

export interface FeatureSection {
  readonly id: FeatureCategory;
  readonly title: string;
  readonly items: FeatureItem[];
}

export const experienceSections: FeatureSection[] = [
  {
    id: 'experience-vision',
    title: 'Computer Vision',
    items: [
      { id: 'posenet', title: 'PoseNet', icon: 'people', routeName: AppRoute.POSENET.name, visibleByDefault: true },
      { id: 'segmentation', title: 'Portrait Segmentation', icon: 'image', routeName: AppRoute.SEGMENTATION_LIVE.name, visibleByDefault: true },
      { id: 'image', title: 'Image Classification', icon: 'grid', routeName: AppRoute.IMAGE_CAMERA.name, visibleByDefault: true },
      { id: 'gesture', title: 'Gesture Recognition', icon: 'hand', routeName: AppRoute.GESTURE_STILL.name, visibleByDefault: true },
      { id: 'dance', title: 'Dance Factory', badge: 'HOT', icon: 'dance', routeName: AppRoute.DANCE.name, visibleByDefault: false }
    ]
  },
  {
    id: 'experience-speech',
    title: 'Speech Semantic Technology',
    items: [
      { id: 'poetry', title: 'Intelligent poetry', badge: 'HOT', icon: 'poetry', routeName: AppRoute.POETRY.name, visibleByDefault: false },
      { id: 'text', title: 'Text Extraction', icon: 'text', routeName: AppRoute.TEXT_RECOGNITION.name, visibleByDefault: true },
      { id: 'translation', title: 'Text Translation', icon: 'translate', routeName: AppRoute.TEXT_TRANSLATION.name, visibleByDefault: true }
    ]
  },
  {
    id: 'advanced-vision',
    title: 'Computer Vision',
    items: [
      { id: 'objectPhoto', title: 'Object Detection(Photo)', icon: 'photo', routeName: AppRoute.OBJECT_PHOTO.name, visibleByDefault: true },
      { id: 'objectCamera', title: 'Object Detection(Real-time)', icon: 'camera', routeName: AppRoute.OBJECT_CAMERA.name, visibleByDefault: true },
      { id: 'style', title: 'Style Transfer', icon: 'style', routeName: AppRoute.STYLE_TRANSFER.name, visibleByDefault: true },
      { id: 'custom', title: 'Custom Model', icon: 'model', routeName: AppRoute.CUSTOM_MODEL.name, visibleByDefault: true }
    ]
  },
  {
    id: 'advanced-speech',
    title: 'Speech Semantic Technology',
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

export const visibleExperienceSections: FeatureSection[] = experienceSections
  .map((section: FeatureSection) => {
    return {
      id: section.id,
      title: section.title,
      items: section.items.filter((item: FeatureItem) => item.visibleByDefault)
    };
  })
  .filter((section: FeatureSection) => section.items.length > 0);

export function findFeatureByRoute(routeName: string): FeatureItem | undefined {
  return allExperienceFeatures.find((item: FeatureItem) => item.routeName === routeName);
}
