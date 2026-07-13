import { abilityDelegatorRegistry } from '@kit.TestKit';
import { describe, it, expect } from '@ohos/hypium';
import {
  hmsGestureModelRawfilePath
} from '../../../main/ets/services/ai/HmsGestureModelDetector';
import {
  createHarmonyHmsGestureNativeSession,
  HmsGestureNativeSession
} from '../../../main/ets/services/ai/HmsGestureNativeSession';
import {
  decodeHmsGestureOutputs,
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

        const input = new Float32Array(1 * 3 * 224 * 224);
        const firstOutputs = await session.predict(input);
        const secondOutputs = await session.predict(input);
        assertExactFiniteOutputs(firstOutputs, secondOutputs);

        const firstDecoded = decodeHmsGestureOutputs(firstOutputs, 224, 224, 0);
        const secondDecoded = decodeHmsGestureOutputs(secondOutputs, 224, 224, 0);
        expect(firstDecoded.length > 0).assertTrue();
        expect(JSON.stringify(firstDecoded)).assertEqual(JSON.stringify(secondDecoded));
      } finally {
        session.release();
      }
    });
  });
}
