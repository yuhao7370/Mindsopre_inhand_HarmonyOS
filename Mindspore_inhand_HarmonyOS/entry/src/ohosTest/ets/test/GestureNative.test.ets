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
  HmsGestureOutputs
} from '../../../main/ets/services/ai/HmsGestureYoloDecoder';

interface ExpectedGestureTensor {
  readonly name: string;
  readonly shape: Array<number>;
}

const expectedGestureTensors: Array<ExpectedGestureTensor> = [
  { name: 'layer89-conv-hand', shape: [1, 60, 7, 7] },
  { name: 'layer101-conv-hand', shape: [1, 60, 14, 14] },
  { name: 'layer113-conv-hand', shape: [1, 60, 28, 28] }
];

async function loadOpenPalmGestureInput(manager: resourceManager.ResourceManager): Promise<Float32Array> {
  let encoded: Uint8Array;
  try {
    encoded = await manager.getRawFileContent('fixtures/gesture/open_palm.png');
  } catch (_) {
    throw new Error('Unable to load open-palm gesture fixture.');
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
      return gestureInputFromRgba(new Uint8Array(rgbaBuffer), width, height);
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
    it('loadsRealModelAndProducesDeterministicFiniteOutputs', 0, async () => {
      const resourceManager = abilityDelegatorRegistry.getAbilityDelegator().getAppContext().resourceManager;
      const modelBytes = await resourceManager.getRawFileContent(hmsGestureModelRawfilePath);
      const session: HmsGestureNativeSession = await createHarmonyHmsGestureNativeSession();
      try {
        const modelInfo = session.loadModel(modelBytes);
        expect(modelInfo.inputName).assertEqual('data');
        expect(modelInfo.inputShape.join(',')).assertEqual('1,3,224,224');

        const input = await loadOpenPalmGestureInput(resourceManager);
        expect(input.length).assertEqual(1 * 3 * 224 * 224);
        const firstOutputs = await session.predict(input);
        const secondOutputs = await session.predict(input);
        assertExactFiniteOutputs(firstOutputs, secondOutputs);
      } finally {
        session.release();
      }
    });
  });
}
