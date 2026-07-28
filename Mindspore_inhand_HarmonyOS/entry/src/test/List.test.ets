import localUnitTest from './LocalUnit.test';
import gestureModelUnitTest from './GestureModelUnit.test';
import translationModelUnitTest from './TranslationModelUnit.test';
import translationRuntimeV2UnitTest from './TranslationRuntimeV2Unit.test';
import translationRuntimeV2SafetyUnitTest from './TranslationRuntimeV2SafetyUnit.test';
import poseMoveNetUnitTest from './PoseMoveNetUnit.test';
import experienceFontScaleUnitTest from './ExperienceFontScaleUnit.test';
import customModelPackageUnitTest from './CustomModelPackage.test';

export default function testsuite() {
  localUnitTest();
  gestureModelUnitTest();
  translationModelUnitTest();
  translationRuntimeV2UnitTest();
  translationRuntimeV2SafetyUnitTest();
  poseMoveNetUnitTest();
  experienceFontScaleUnitTest();
  customModelPackageUnitTest();
}
