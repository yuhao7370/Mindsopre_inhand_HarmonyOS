import localUnitTest from './LocalUnit.test';
import gestureModelUnitTest from './GestureModelUnit.test';

export default function testsuite() {
  localUnitTest();
  gestureModelUnitTest();
}
