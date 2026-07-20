import { image } from '@kit.ImageKit';
import { resourceManager } from '@kit.LocalizationKit';
import { abilityDelegatorRegistry } from '@kit.TestKit';
import { describe, it, expect } from '@ohos/hypium';
import { mindSporeLite } from '@kit.MindSporeLiteKit';
import { imageClassificationModelRawfilePath } from '../../../main/ets/services/ai/ImageClassificationService';
import { normalizedRgbInputFromResizedRgba } from '../../../main/ets/services/ai/ImageClassificationPreprocess';
import { HarmonyRawfileContentReader, loadImageClassificationLabels } from '../../../main/ets/services/ai/ImageClassificationRuntimeFactory';
import {
  imageClassificationScoresFromOutputTensor,
  MindSporeLiteModelRunner,
  mindSporeLiteCpuContext,
  rawfileContentToArrayBuffer
} from '../../../main/ets/services/ai/MindSporeLiteModelRunner';

interface FixtureExpectation {
  readonly path: string;
  readonly expectedLabel: string;
}

const fixtures: Array<FixtureExpectation> = [
  { path: 'fixtures/classification/grace_hopper.jpg', expectedLabel: 'military_uniform' },
  { path: 'fixtures/classification/yellow_labrador.jpg', expectedLabel: 'Labrador_retriever' }
];

async function createInputBuffer(manager: resourceManager.ResourceManager, path: string): Promise<ArrayBuffer> {
  const encoded = await manager.getRawFileContent(path);
  const encodedBuffer = rawfileContentToArrayBuffer(encoded);
  const source = image.createImageSource(encodedBuffer);
  try {
    const pixelMap = await source.createPixelMap({
      desiredSize: { width: 256, height: 256 },
      desiredPixelFormat: image.PixelMapFormat.RGBA_8888
    });
    try {
      const rgbaBuffer = new ArrayBuffer(256 * 256 * 4);
      await pixelMap.readPixelsToBuffer(rgbaBuffer);
      return normalizedRgbInputFromResizedRgba(new Uint8Array(rgbaBuffer));
    } finally {
      await pixelMap.release();
    }
  } finally {
    await source.release();
  }
}

function topRawScores(scores: Float32Array, labels: Array<string>, count: number): Array<string> {
  const ranked: Array<number> = [];
  for (let index = 0; index < scores.length; index++) {
    ranked.push(index);
  }
  ranked.sort((left: number, right: number) => scores[right] - scores[left]);
  const names: Array<string> = [];
  for (let index = 0; index < count && index < ranked.length; index++) {
    const rawIndex = ranked[index];
    const directLabel = rawIndex < labels.length ? labels[rawIndex] : '<background-or-unmapped>';
    const shiftedLabel = rawIndex > 0 && rawIndex - 1 < labels.length ? labels[rawIndex - 1] : '<unmapped>';
    names.push(`${rawIndex}:${scores[rawIndex]}:direct=${directLabel}:minusOne=${shiftedLabel}`);
  }
  return names;
}

function expectedLabelRank(scores: Array<number>, labels: Array<string>, expectedLabel: string): number {
  const ranked: Array<number> = [];
  for (let index = 0; index < scores.length; index++) {
    ranked.push(index);
  }
  ranked.sort((left: number, right: number) => scores[right] - scores[left]);
  for (let rank = 0; rank < ranked.length; rank++) {
    if (labels[ranked[rank]] === expectedLabel) {
      return rank;
    }
  }
  return -1;
}

export default function imageClassificationNativeTest() {
  describe('ImageClassificationNativeTest', () => {
    it('reportsTopFiveForTwoLabeledRealFixturesThroughTheDeviceModel', 0, async () => {
      const applicationContext = abilityDelegatorRegistry.getAbilityDelegator()
        .getAppContext()
        .getApplicationContext();
      const mainManager = applicationContext.createModuleContext('entry').resourceManager;
      const testManager = applicationContext.createModuleContext('entry_test').resourceManager;
      const model = await mindSporeLite.loadModelFromBuffer(
        rawfileContentToArrayBuffer(await mainManager.getRawFileContent(imageClassificationModelRawfilePath)),
        mindSporeLiteCpuContext()
      );
      const productionRunner = new MindSporeLiteModelRunner({
        resourceManager: new HarmonyRawfileContentReader(mainManager),
        modelRawfilePath: imageClassificationModelRawfilePath,
        outputTensorDecoder: imageClassificationScoresFromOutputTensor
      });
      const labels = await loadImageClassificationLabels(new HarmonyRawfileContentReader(mainManager));
      const inputs = model.getInputs();
      expect(inputs.length).assertEqual(1);
      console.info(`image-classification-model-input=name=${inputs[0].name} shape=${inputs[0].shape.join(',')} dtype=${inputs[0].dtype} format=${inputs[0].format} elements=${inputs[0].elementNum} bytes=${inputs[0].dataSize}`);
      const expectedRanks: Array<number> = [];

      for (let index = 0; index < fixtures.length; index++) {
        const fixture = fixtures[index];
        const inputBuffer = await createInputBuffer(testManager, fixture.path);
        inputs[0].setData(inputBuffer);
        const outputs = await model.predict(inputs);
        expect(outputs.length > 0).assertTrue();
        const scores = new Float32Array(outputs[0].getData());
        expect(scores.length >= labels.length).assertTrue();
        const rawTopFive = topRawScores(scores, labels, 5);
        console.info(`image-classification-fixture=${fixture.path} expected=${fixture.expectedLabel} outputLength=${scores.length} rawTop5=${rawTopFive.join('|')}`);
        expect(rawTopFive.length).assertEqual(5);
        const decodedScores = await productionRunner.predictScoresFromInput(inputBuffer);
        expect(decodedScores.length).assertEqual(labels.length);
        const expectedRank = expectedLabelRank(decodedScores, labels, fixture.expectedLabel);
        console.info(`image-classification-decoded=${fixture.path} expected=${fixture.expectedLabel} rank=${expectedRank}`);
        expect(expectedRank >= 0 && expectedRank < 5).assertTrue();
        expectedRanks.push(expectedRank);
      }
      expect(expectedRanks[0] !== expectedRanks[1]).assertTrue();
    });
  });
}
