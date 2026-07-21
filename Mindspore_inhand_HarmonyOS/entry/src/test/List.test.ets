import localUnitTest from './LocalUnit.test';
import gestureModelUnitTest from './GestureModelUnit.test';
import translationModelUnitTest from './TranslationModelUnit.test';
import poseMoveNetUnitTest from './PoseMoveNetUnit.test';

export default function testsuite() {
  localUnitTest();
  gestureModelUnitTest();
  translationModelUnitTest();
  poseMoveNetUnitTest();
}
