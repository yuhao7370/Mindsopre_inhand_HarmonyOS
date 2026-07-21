import gestureNativeTest from './GestureNative.test';
import imageClassificationNativeTest from './ImageClassificationNative.test';
import segmentationNativeTest from './SegmentationNative.test';
import translationNativeTest from './TranslationNative.test';
import ocrNativeTest from './OcrNative.test';

export default function testsuite() {
  gestureNativeTest();
  imageClassificationNativeTest();
  segmentationNativeTest();
  translationNativeTest();
  ocrNativeTest();
}
