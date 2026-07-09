import { describe, it, expect } from '@ohos/hypium';
import { AppRoute, findRouteByName } from '../main/ets/app/AppRoutes';
import { MainTab, mainTabs } from '../main/ets/app/AppState';
import { hasAppStringKey } from '../main/ets/common/i18n/AppStrings';
import { iconLabel } from '../main/ets/common/icons/IconSymbols';
import { DefaultAiService } from '../main/ets/services/ai/AiService';
import { FeatureWorkflow, workflowForRoute } from '../main/ets/features/runtime/FeatureWorkflowCatalog';
import {
  declaredPermissionNames,
  runtimePermissionNamesForWorkflow
} from '../main/ets/services/permissions/PermissionService';
import {
  inputActionForKind,
  modelFileSuffixFilters,
  runtimeInputActionsForWorkflow
} from '../main/ets/services/picker/PickerService';
import {
  allExperienceFeatures,
  FeatureItem,
  FeatureSection,
  findFeatureByRoute,
  experienceSections,
  visibleExperienceSections
} from '../main/ets/common/data/FeatureCatalog';
import { collegeItems, isCollegeItemUrlNavigable } from '../main/ets/common/data/CollegeCatalog';
import { meItems, visibleMeItems } from '../main/ets/common/data/MeCatalog';

export default function localUnitTest() {
  describe('mindsporePortFoundation', () => {
    it('preservesAndroidRouteNames', 0, () => {
      expect(AppRoute.OBJECT_PHOTO.name).assertEqual('/imageobject/ObjectPhotoActivity');
      expect(AppRoute.STYLE_TRANSFER.name).assertEqual('/styletransfer/StyleMainActivity');
      expect(AppRoute.TEXT_TRANSLATION.name).assertEqual('/hms/TextTranslationActivity');
    });

    it('keepsHiddenAndroidFeaturesRouteReady', 0, () => {
      const dance = findFeatureByRoute('/dance/DanceMainActivity');
      const poetry = findFeatureByRoute('/app/IntelligentPoetryWritingActivity');
      expect(dance?.visibleByDefault).assertFalse();
      expect(poetry?.visibleByDefault).assertFalse();
    });

    it('showsExpectedVisibleExperienceFeatures', 0, () => {
      const visibleCount = visibleExperienceSections
        .map((section) => section.items.length)
        .reduce((sum, count) => sum + count, 0);
      expect(visibleCount).assertEqual(10);
      expect(allExperienceFeatures.length).assertEqual(12);
    });

    it('definesCollegeAndMeRows', 0, () => {
      expect(collegeItems.length).assertEqual(6);
      expect(visibleMeItems.length).assertEqual(1);
      expect(visibleMeItems[0].title).assertEqual('Version');
    });

    it('definesThreeMainTabsInAndroidOrder', 0, () => {
      expect(mainTabs.length).assertEqual(3);
      expect(mainTabs[0].id).assertEqual(MainTab.EXPERIENCE);
      expect(mainTabs[1].title).assertEqual('College');
      expect(mainTabs[2].title).assertEqual('Me');
    });

    it('mapsSemanticIconTokensToCompactLabels', 0, () => {
      expect(iconLabel('people')).assertEqual('P');
      expect(iconLabel('rocket')).assertEqual('E');
      expect(iconLabel('translate')).assertEqual('Tr');
      expect(iconLabel('image').length <= 2).assertTrue();
    });

    it('assignsI18nKeysToVisibleShellData', 0, () => {
      expect(hasAppStringKey(mainTabs[0].titleKey)).assertTrue();
      expect(hasAppStringKey(experienceSections[0].titleKey)).assertTrue();
      expect(hasAppStringKey(allExperienceFeatures[0].titleKey)).assertTrue();
      expect(hasAppStringKey(collegeItems[0].titleKey)).assertTrue();
      expect(hasAppStringKey(meItems[0].titleKey)).assertTrue();
    });

    it('doesNotNavigateQuickStartParentWithEmptyUrl', 0, () => {
      expect(isCollegeItemUrlNavigable(collegeItems[1])).assertTrue();
      expect(isCollegeItemUrlNavigable(collegeItems[2])).assertFalse();
    });

    it('definesRuntimeWorkflowForEveryVisibleExperienceFeature', 0, () => {
      visibleExperienceSections.forEach((section: FeatureSection) => {
        section.items.forEach((item: FeatureItem) => {
          const workflow = workflowForRoute(item.routeName);
          expect(workflow !== undefined).assertTrue();
          expect(workflow!.titleKey).assertEqual(item.titleKey);
        });
      });
    });

    it('mapsCoreFeatureRoutesToExpectedRuntimeCapabilities', 0, () => {
      const classification: FeatureWorkflow = workflowForRoute(AppRoute.IMAGE_CAMERA.name)!;
      expect(classification.aiMethod).assertEqual('classifyImage');
      expect(classification.inputKinds.indexOf('camera') >= 0).assertTrue();

      const styleTransfer: FeatureWorkflow = workflowForRoute(AppRoute.STYLE_TRANSFER.name)!;
      expect(styleTransfer.aiMethod).assertEqual('runStyleTransfer');
      expect(styleTransfer.inputKinds.indexOf('contentImage') >= 0).assertTrue();
      expect(styleTransfer.inputKinds.indexOf('styleImage') >= 0).assertTrue();

      const translation: FeatureWorkflow = workflowForRoute(AppRoute.TEXT_TRANSLATION.name)!;
      expect(translation.aiMethod).assertEqual('translateText');
      expect(translation.inputKinds.indexOf('text') >= 0).assertTrue();
      expect(translation.inputKinds.indexOf('camera') >= 0).assertTrue();
      expect(translation.inputKinds.indexOf('photo') >= 0).assertTrue();
      expect(translation.requiredPermissions.indexOf('internet') >= 0).assertTrue();
    });

    it('recordsPlatformNeedsFromOriginalAndroidFlows', 0, () => {
      const posenet: FeatureWorkflow = workflowForRoute(AppRoute.POSENET.name)!;
      expect(posenet.inputKinds.indexOf('camera') >= 0).assertTrue();
      expect(posenet.inputKinds.indexOf('photo') >= 0).assertTrue();

      const objectPhoto: FeatureWorkflow = workflowForRoute(AppRoute.OBJECT_PHOTO.name)!;
      expect(objectPhoto.inputKinds.indexOf('modelFile') >= 0).assertTrue();
      expect(objectPhoto.requiredPermissions.indexOf('media') >= 0).assertTrue();

      const objectCamera: FeatureWorkflow = workflowForRoute(AppRoute.OBJECT_CAMERA.name)!;
      expect(objectCamera.inputKinds.indexOf('modelFile') >= 0).assertTrue();
      expect(objectCamera.requiredPermissions.indexOf('media') >= 0).assertTrue();

      const customModel: FeatureWorkflow = workflowForRoute(AppRoute.CUSTOM_MODEL.name)!;
      expect(customModel.inputKinds.indexOf('camera') >= 0).assertTrue();
      expect(customModel.inputKinds.indexOf('photo') >= 0).assertTrue();
      expect(customModel.inputKinds.indexOf('modelFile') >= 0).assertTrue();
    });

    it('definesRuntimeWorkflowForEveryRuntimeRoute', 0, () => {
      expect(workflowForRoute(AppRoute.LIVE_SKELETON.name) !== undefined).assertTrue();
      expect(workflowForRoute(AppRoute.SEGMENTATION_STILL.name) !== undefined).assertTrue();
    });

    it('routesVisibleFeaturesToRuntimePage', 0, () => {
      visibleExperienceSections.forEach((section: FeatureSection) => {
        section.items.forEach((item: FeatureItem) => {
          expect(findRouteByName(item.routeName)?.page).assertEqual('pages/FeatureRuntimePage');
        });
      });
    });

    it('aiServiceReturnsExplicitPendingAdapterFailure', 0, async () => {
      const workflow = workflowForRoute(AppRoute.OBJECT_PHOTO.name);
      expect(workflow !== undefined).assertTrue();
      const result = await new DefaultAiService().run(workflow!);
      expect(result.ok).assertFalse();
      expect(result.code).assertEqual('NATIVE_ADAPTER_PENDING');
      expect(result.aiMethod).assertEqual('detectObjects');
    });

    it('mapsWorkflowPermissionsToHarmonyPermissionNames', 0, () => {
      const translation: FeatureWorkflow = workflowForRoute(AppRoute.TEXT_TRANSLATION.name)!;
      const permissionNames = runtimePermissionNamesForWorkflow(translation);
      expect(permissionNames.indexOf('ohos.permission.CAMERA') >= 0).assertTrue();
      expect(permissionNames.indexOf('ohos.permission.READ_IMAGEVIDEO') >= 0).assertTrue();
      expect(permissionNames.indexOf('ohos.permission.INTERNET')).assertEqual(-1);
      expect(declaredPermissionNames.indexOf('ohos.permission.INTERNET') >= 0).assertTrue();
    });

    it('mapsWorkflowInputsToPickerActions', 0, () => {
      const styleTransfer: FeatureWorkflow = workflowForRoute(AppRoute.STYLE_TRANSFER.name)!;
      const actions = runtimeInputActionsForWorkflow(styleTransfer);
      expect(actions.indexOf('captureOrPickImage') >= 0).assertTrue();
      expect(actions.indexOf('pickModelFile') >= 0).assertTrue();
      expect(inputActionForKind('text')).assertEqual('enterText');
    });

    it('usesMindSporeModelFileSuffixForModelPicker', 0, () => {
      expect(modelFileSuffixFilters.length).assertEqual(1);
      expect(modelFileSuffixFilters[0]).assertEqual('.ms');
    });
  });
}
