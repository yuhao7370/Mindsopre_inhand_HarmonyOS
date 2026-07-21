import gestureNativeTest from './GestureNative.test';
import imageClassificationNativeTest from './ImageClassificationNative.test';
import segmentationNativeTest from './SegmentationNative.test';
import translationNativeTest from './TranslationNative.test';
import translationWorkerClientTest from './TranslationWorkerClient.test';
import ocrNativeTest from './OcrNative.test';
import objectDetectionNativeTest from './ObjectDetectionNative.test';
import styleTransferNativeTest from './StyleTransferNative.test';
import customModelNativeTest from './CustomModelNative.test';

export default function testsuite() {
  gestureNativeTest();
  imageClassificationNativeTest();
  segmentationNativeTest();
  translationNativeTest();
  translationWorkerClientTest();
  ocrNativeTest();
  objectDetectionNativeTest();
  styleTransferNativeTest();
  customModelNativeTest();
}
