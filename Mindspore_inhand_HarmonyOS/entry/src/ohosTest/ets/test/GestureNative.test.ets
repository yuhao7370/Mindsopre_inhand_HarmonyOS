import { image } from '@kit.ImageKit';
import { resourceManager } from '@kit.LocalizationKit';
import { abilityDelegatorRegistry } from '@kit.TestKit';
import { describe, it, expect } from '@ohos/hypium';
import {
  hmsGestureModelRawfilePath
} from '../../../main/ets/services/ai/HmsGestureModelDetector';
import {
  createHarmonyHmsGestureNativeSession,
  HmsGestureNativeSession
} from '../../../main/ets/services/ai/HmsGestureNativeSession';
import { gestureInputFromRgba } from '../../../main/ets/services/ai/HmsGesturePreprocessor';
import {
  HmsGestureOutputTensor,
  HmsGestureOutputs,
  decodeHmsGestureOutputs
} from '../../../main/ets/services/ai/HmsGestureYoloDecoder';
import { AndroidGestureModelDetection } from '../../../main/ets/services/ai/GestureService';
import { AiRunResult } from '../../../main/ets/services/ai/AiService';
import { projectLiveGestureResult } from '../../../main/ets/features/runtime/LiveGestureResultProjector';

interface ExpectedGestureTensor {
  readonly name: string;
  readonly shape: Array<number>;
}

const expectedGestureTensors: Array<ExpectedGestureTensor> = [
  { name: 'layer89-conv-hand', shape: [1, 60, 7, 7] },
  { name: 'layer101-conv-hand', shape: [1, 60, 14, 14] },
  { name: 'layer113-conv-hand', shape: [1, 60, 28, 28] }
];

interface GestureFixtureInput {
  readonly input: Float32Array;
  readonly width: number;
  readonly height: number;
}

async function loadGestureInput(
  manager: resourceManager.ResourceManager,
  fixturePath: string
): Promise<GestureFixtureInput> {
  let encoded: Uint8Array;
  try {
    encoded = await manager.getRawFileContent(fixturePath);
  } catch (_) {
    throw new Error(`Unable to load gesture fixture ${fixturePath}.`);
  }
  const encodedBuffer = new ArrayBuffer(encoded.byteLength);
  new Uint8Array(encodedBuffer).set(encoded);
  const imageSource = image.createImageSource(encodedBuffer);
  try {
    const pixelMap = await imageSource.createPixelMap({
      desiredPixelFormat: image.PixelMapFormat.RGBA_8888
    });
    try {
      const imageInfo: image.ImageInfo = await pixelMap.getImageInfo();
      const width = imageInfo.size.width;
      const height = imageInfo.size.height;
      const rgbaBuffer = new ArrayBuffer(width * height * 4);
      await pixelMap.readPixelsToBuffer(rgbaBuffer);
      return {
        input: gestureInputFromRgba(new Uint8Array(rgbaBuffer), width, height),
        width: width,
        height: height
      };
    } finally {
      await pixelMap.release();
    }
  } finally {
    await imageSource.release();
  }
}

function assertExactFiniteOutputs(first: HmsGestureOutputs, second: HmsGestureOutputs): void {
  expect(first.tensors.length).assertEqual(expectedGestureTensors.length);
  expect(second.tensors.length).assertEqual(expectedGestureTensors.length);
  for (let tensorIndex = 0; tensorIndex < expectedGestureTensors.length; tensorIndex++) {
    const expected = expectedGestureTensors[tensorIndex];
    const firstTensor: HmsGestureOutputTensor = first.tensors[tensorIndex];
    const secondTensor: HmsGestureOutputTensor = second.tensors[tensorIndex];
    expect(firstTensor.name).assertEqual(expected.name);
    expect(firstTensor.shape.join(',')).assertEqual(expected.shape.join(','));
    expect(secondTensor.name).assertEqual(expected.name);
    expect(secondTensor.shape.join(',')).assertEqual(expected.shape.join(','));

    const firstValues = new Float32Array(firstTensor.data);
    const secondValues = new Float32Array(secondTensor.data);
    expect(firstValues.length).assertEqual(60 * expected.shape[2] * expected.shape[3]);
    expect(secondValues.length).assertEqual(firstValues.length);
    let exactAndFinite = true;
    for (let valueIndex = 0; valueIndex < firstValues.length; valueIndex++) {
      if (!Number.isFinite(firstValues[valueIndex]) || firstValues[valueIndex] !== secondValues[valueIndex]) {
        exactAndFinite = false;
        break;
      }
    }
    expect(exactAndFinite).assertTrue();
  }
}

export default function gestureNativeTest() {
  describe('GestureNativeTest', () => {
    it('detectsLicensedFourFixtureAndRejectsSolidGrayOnApi24', 0, async () => {
      const applicationContext = abilityDelegatorRegistry.getAbilityDelegator()
        .getAppContext()
        .getApplicationContext();
      const mainResourceManager = applicationContext.createModuleContext('entry').resourceManager;
      const testResourceManager = applicationContext.createModuleContext('entry_test').resourceManager;
      const modelBytes = await mainResourceManager.getRawFileContent(hmsGestureModelRawfilePath);
      const session: HmsGestureNativeSession = await createHarmonyHmsGestureNativeSession();
      try {
        const modelInfo = session.loadModel(modelBytes);
        expect(modelInfo.inputName).assertEqual('data');
        expect(modelInfo.inputShape.join(',')).assertEqual('1,3,224,224');

        const positive = await loadGestureInput(testResourceManager, 'fixtures/gesture/four.jpg');
        expect(positive.input.length).assertEqual(1 * 3 * 224 * 224);
        const backing = new Float32Array(positive.input.length + 2);
        backing.set(positive.input, 1);
        const positiveView = backing.subarray(1, positive.input.length + 1);
        const firstOutputs = await session.predict(positiveView);
        const secondOutputs = await session.predict(positiveView);
        assertExactFiniteOutputs(firstOutputs, secondOutputs);

        const detections = decodeHmsGestureOutputs(firstOutputs, positive.width, positive.height, 0.6);
        const four = detections.find((detection: AndroidGestureModelDetection) => detection.category === 3);
        expect(four !== undefined).assertTrue();
        const iou = rectangleIou(four!, 242.214, 182.637, 41.648, 59.506);
        console.info(`gesture-four-score=${four!.score} iou=${iou} rect=${JSON.stringify(four!.rect)}`);
        expect(four!.score >= 0.85).assertTrue();
        expect(iou >= 0.9).assertTrue();

        const negative = await loadGestureInput(testResourceManager, 'fixtures/gesture/solid_gray.png');
        const negativeOutputs = await session.predict(negative.input);
        const negativeDetections = decodeHmsGestureOutputs(
          negativeOutputs,
          negative.width,
          negative.height,
          0.6
        );
        console.info(`gesture-solid-gray-count=${negativeDetections.length}`);
        expect(negativeDetections.length).assertEqual(0);

        const generation = 42;
        const positiveResult: AiRunResult = {
          ok: true,
          code: 'GESTURE_DETECTION_DONE',
          aiMethod: 'detectGesture',
          messageKey: 'feature_runtime_gesture_done',
          detailText: 'fixture=four.jpg',
          data: {
            kind: 'gesture',
            imageUri: 'fixtures/gesture/four.jpg',
            result: {
              ok: true,
              gestures: [{ category: four!.category, label: 'Four', score: four!.score, rect: four!.rect }],
              imageWidth: positive.width,
              imageHeight: positive.height,
              executionMs: 1
            }
          }
        };
        const emptyResult: AiRunResult = {
          ok: false,
          code: 'GESTURE_DETECTION_FAILED',
          aiMethod: 'detectGesture',
          messageKey: 'feature_runtime_gesture_failed',
          detailText: 'fixture=solid_gray.png'
        };
        const positiveState = projectLiveGestureResult(positiveResult, generation, generation)!;
        expect(positiveState.detections.length).assertEqual(1);
        expect(positiveState.detections[0].category).assertEqual(3);
        expect(positiveState.detections[0].score >= 0.85).assertTrue();
        expect(projectLiveGestureResult(emptyResult, generation - 1, generation) === undefined).assertTrue();
        const emptyState = projectLiveGestureResult(emptyResult, generation, generation)!;
        expect(emptyState.generation).assertEqual(generation);
        expect(emptyState.imageUri).assertEqual('');
        expect(emptyState.detections.length).assertEqual(0);
        expect(emptyState.imageWidth).assertEqual(0);
        expect(emptyState.imageHeight).assertEqual(0);
        console.info('gesture-live-transition=four->empty stale-overlay=false stale-score=false');
      } finally {
        session.release();
      }
    });
  });
}

function rectangleIou(
  detection: AndroidGestureModelDetection,
  left: number,
  top: number,
  width: number,
  height: number
): number {
  const right = left + width;
  const bottom = top + height;
  const actual = detection.rect!;
  const actualRight = actual.left + actual.width;
  const actualBottom = actual.top + actual.height;
  const intersectionWidth = Math.max(0, Math.min(actualRight, right) - Math.max(actual.left, left));
  const intersectionHeight = Math.max(0, Math.min(actualBottom, bottom) - Math.max(actual.top, top));
  const intersection = intersectionWidth * intersectionHeight;
  const union = actual.width * actual.height + width * height - intersection;
  return union > 0 ? intersection / union : 0;
}
