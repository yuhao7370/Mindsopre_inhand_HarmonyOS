import { webPagePath } from '../common/data/WebDestination';

export interface AppRouteInfo {
  readonly name: string;
  readonly page: string;
}

export interface AppRouteCatalog {
  readonly MAIN: AppRouteInfo;
  readonly OBJECT_PHOTO: AppRouteInfo;
  readonly OBJECT_CAMERA: AppRouteInfo;
  readonly IMAGE_CAMERA: AppRouteInfo;
  readonly STYLE_TRANSFER: AppRouteInfo;
  readonly CUSTOM_MODEL: AppRouteInfo;
  readonly POSENET: AppRouteInfo;
  readonly LIVE_SKELETON: AppRouteInfo;
  readonly SEGMENTATION_STILL: AppRouteInfo;
  readonly SEGMENTATION_LIVE: AppRouteInfo;
  readonly PORTRAIT_SEGMENTATION: AppRouteInfo;
  readonly GESTURE_STILL: AppRouteInfo;
  readonly GESTURE_LIVE: AppRouteInfo;
  readonly TEXT_RECOGNITION: AppRouteInfo;
  readonly TEXT_TRANSLATION: AppRouteInfo;
  readonly DANCE: AppRouteInfo;
  readonly POETRY: AppRouteInfo;
  readonly MY_QR_CODE: AppRouteInfo;
  readonly WEB: AppRouteInfo;
  readonly PRIVACY: AppRouteInfo;
}

export const AppRoute: AppRouteCatalog = {
  MAIN: { name: '/app/MainActivity', page: 'pages/Index' } as AppRouteInfo,
  OBJECT_PHOTO: { name: '/imageobject/ObjectPhotoActivity', page: 'pages/FeatureRuntimePage' } as AppRouteInfo,
  OBJECT_CAMERA: { name: '/imageobject/ObjectCameraActivity', page: 'pages/FeatureRuntimePage' } as AppRouteInfo,
  IMAGE_CAMERA: { name: '/imageobject/ImageCameraActivity', page: 'pages/FeatureRuntimePage' } as AppRouteInfo,
  STYLE_TRANSFER: { name: '/styletransfer/StyleMainActivity', page: 'pages/FeatureRuntimePage' } as AppRouteInfo,
  CUSTOM_MODEL: { name: '/custommodel/CustomModelMainActivity', page: 'pages/FeatureRuntimePage' } as AppRouteInfo,
  POSENET: { name: '/hms/PosenetMainActivitys', page: 'pages/FeatureRuntimePage' } as AppRouteInfo,
  LIVE_SKELETON: { name: '/posenet/LiveSkeletonAnalyseActivity', page: 'pages/FeatureRuntimePage' } as AppRouteInfo,
  SEGMENTATION_STILL: { name: '/hms/ImageSegmentationActivity', page: 'pages/FeatureRuntimePage' } as AppRouteInfo,
  SEGMENTATION_LIVE: { name: '/hms/ImageSegmentationLiveAnalyseActivity', page: 'pages/FeatureRuntimePage' } as AppRouteInfo,
  PORTRAIT_SEGMENTATION: { name: '/hms/PortraitSegmentationActivity', page: 'pages/FeatureRuntimePage' } as AppRouteInfo,
  GESTURE_STILL: { name: '/hms/StillHandGestureAnalyseActivity', page: 'pages/FeatureRuntimePage' } as AppRouteInfo,
  GESTURE_LIVE: { name: '/hms/LiveHandGestureAnalyseActivity', page: 'pages/FeatureRuntimePage' } as AppRouteInfo,
  TEXT_RECOGNITION: { name: '/hms/TextRecognitionActivity', page: 'pages/FeatureRuntimePage' } as AppRouteInfo,
  TEXT_TRANSLATION: { name: '/hms/TextTranslationActivity', page: 'pages/FeatureRuntimePage' } as AppRouteInfo,
  DANCE: { name: '/dance/DanceMainActivity', page: 'pages/FeatureRuntimePage' } as AppRouteInfo,
  POETRY: { name: '/app/IntelligentPoetryWritingActivity', page: 'pages/FeatureRuntimePage' } as AppRouteInfo,
  MY_QR_CODE: { name: '/app/MyQRCodeActivity', page: 'pages/QrCodePage' } as AppRouteInfo,
  WEB: { name: '/app/WebViewUtilsActivity', page: webPagePath } as AppRouteInfo,
  PRIVACY: { name: '/app/PrivacyPolicyActivity', page: webPagePath } as AppRouteInfo
};

export const appRoutes: AppRouteInfo[] = [
  AppRoute.MAIN,
  AppRoute.OBJECT_PHOTO,
  AppRoute.OBJECT_CAMERA,
  AppRoute.IMAGE_CAMERA,
  AppRoute.STYLE_TRANSFER,
  AppRoute.CUSTOM_MODEL,
  AppRoute.POSENET,
  AppRoute.LIVE_SKELETON,
  AppRoute.SEGMENTATION_STILL,
  AppRoute.SEGMENTATION_LIVE,
  AppRoute.PORTRAIT_SEGMENTATION,
  AppRoute.GESTURE_STILL,
  AppRoute.GESTURE_LIVE,
  AppRoute.TEXT_RECOGNITION,
  AppRoute.TEXT_TRANSLATION,
  AppRoute.DANCE,
  AppRoute.POETRY,
  AppRoute.MY_QR_CODE,
  AppRoute.WEB,
  AppRoute.PRIVACY
];

export function findRouteByName(name: string): AppRouteInfo | undefined {
  return appRoutes.find((route: AppRouteInfo) => route.name === name);
}
