import gestureNativeTest from './GestureNative.test';
import imageClassificationNativeTest from './ImageClassificationNative.test';
import translationNativeTest from './TranslationNative.test';

export default function testsuite() {
  gestureNativeTest();
  imageClassificationNativeTest();
  translationNativeTest();
}
