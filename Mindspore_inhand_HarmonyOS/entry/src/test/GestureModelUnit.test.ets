import { describe, it, expect } from '@ohos/hypium';
import { image } from '@kit.ImageKit';
import { AppRoute } from '../main/ets/app/AppRoutes';
import { workflowForRoute } from '../main/ets/features/runtime/FeatureWorkflowCatalog';
import { gestureInputFromRgba } from '../main/ets/services/ai/HmsGesturePreprocessor';
import {
  HmsGestureOutputTensor,
  HmsGestureOutputs,
  decodeHmsGestureOutputs,
  hmsGestureBoxesExceedNmsThreshold
} from '../main/ets/services/ai/HmsGestureYoloDecoder';
import {
  AndroidGestureModelDetection,
  AndroidGestureModelRunner,
  GestureRectangle
} from '../main/ets/services/ai/GestureService';
import {
  HmsGestureImageLoader,
  HmsGestureModelDetector,
  HmsGestureOpenedImage,
  HmsGesturePixelMap,
  hmsGestureModelRawfilePath
} from '../main/ets/services/ai/HmsGestureModelDetector';
import {
  HmsGestureModelInfo,
  HmsGestureNativeSession
} from '../main/ets/services/ai/HmsGestureNativeSession';
import { createRuntimeAiServiceForWorkflow } from '../main/ets/services/ai/ImageClassificationRuntimeFactory';
import { RawfileContentReader } from '../main/ets/services/ai/MindSporeLiteModelRunner';

interface GestureScaleFixture {
  readonly name: string;
  readonly gridSize: number;
  readonly stride: number;
}

const gestureScaleFixtures: Array<GestureScaleFixture> = [
  { name: 'layer89-conv-hand', gridSize: 7, stride: 32 },
  { name: 'layer101-conv-hand', gridSize: 14, stride: 16 },
  { name: 'layer113-conv-hand', gridSize: 28, stride: 8 }
];

function assertNear(actual: number, expected: number, tolerance: number = 0.0001): void {
  expect(Math.abs(actual - expected) <= tolerance).assertTrue();
}

function assertThrows(action: () => void): void {
  let threw = false;
  try {
    action();
  } catch (_) {
    threw = true;
  }
  expect(threw).assertTrue();
}

function tensorValues(gridSize: number): Float32Array {
  const values = new Float32Array(60 * gridSize * gridSize);
  values.fill(-100);
  return values;
}

function arrayBufferFromValues(values: Float32Array): ArrayBuffer {
  const data = new ArrayBuffer(values.byteLength);
  new Float32Array(data).set(values);
  return data;
}

function outputTensor(fixture: GestureScaleFixture, values?: Float32Array): HmsGestureOutputTensor {
  const tensorData = values ?? tensorValues(fixture.gridSize);
  return {
    name: fixture.name,
    shape: [1, 60, fixture.gridSize, fixture.gridSize],
    data: arrayBufferFromValues(tensorData)
  };
}

function blankOutputs(): HmsGestureOutputs {
  return {
    tensors: [
      outputTensor(gestureScaleFixtures[0]),
      outputTensor(gestureScaleFixtures[1]),
      outputTensor(gestureScaleFixtures[2])
    ]
  };
}

function mutableTensor(outputs: HmsGestureOutputs, name: string): Float32Array {
  for (let index = 0; index < outputs.tensors.length; index++) {
    const tensor = outputs.tensors[index];
    if (tensor.name === name) {
      return new Float32Array(tensor.data);
    }
  }
  throw new Error(`Missing fixture tensor ${name}`);
}

function setPrediction(
  values: Float32Array,
  gridSize: number,
  anchorIndex: number,
  cellX: number,
  cellY: number,
  category: number,
  objectness: number = 10,
  classLogit: number = 10,
  tx: number = 0,
  ty: number = 0,
  tw: number = 0,
  th: number = 0
): void {
  const planeSize = gridSize * gridSize;
  const cellIndex = cellY * gridSize + cellX;
  const channelBase = anchorIndex * 20;
  values[(channelBase + 0) * planeSize + cellIndex] = tx;
  values[(channelBase + 1) * planeSize + cellIndex] = ty;
  values[(channelBase + 2) * planeSize + cellIndex] = tw;
  values[(channelBase + 3) * planeSize + cellIndex] = th;
  values[(channelBase + 4) * planeSize + cellIndex] = objectness;
  values[(channelBase + 5 + category) * planeSize + cellIndex] = classLogit;
}

function totalFinite(values: Float32Array): boolean {
  for (let index = 0; index < values.length; index++) {
    if (!Number.isFinite(values[index])) {
      return false;
    }
  }
  return true;
}

class RecordingGestureRawfileReader implements RawfileContentReader {
  readonly seenPaths: Array<string> = [];

  async getRawFileContent(path: string): Promise<Uint8Array> {
    this.seenPaths.push(path);
    return new Uint8Array([1, 2, 3]);
  }
}

class FakeGestureImageLoader implements HmsGestureImageLoader {
  readonly seenUris: Array<string> = [];
  readCount: number = 0;
  pixelMapReleaseCount: number = 0;
  closeCount: number = 0;
  readonly width: number;
  readonly height: number;

  constructor(width: number = 2, height: number = 2) {
    this.width = width;
    this.height = height;
  }

  async open(imageUri: string): Promise<HmsGestureOpenedImage> {
    this.seenUris.push(imageUri);
    return new FakeGestureOpenedImage(this);
  }
}

class FakeGestureOpenedImage implements HmsGestureOpenedImage {
  readonly pixelMap: HmsGesturePixelMap;
  private readonly owner: FakeGestureImageLoader;

  constructor(owner: FakeGestureImageLoader) {
    this.owner = owner;
    this.pixelMap = new FakeGesturePixelMap(owner);
  }

  async close(): Promise<void> {
    this.owner.closeCount++;
  }
}

class FakeGesturePixelMap implements HmsGesturePixelMap {
  private readonly owner: FakeGestureImageLoader;

  constructor(owner: FakeGestureImageLoader) {
    this.owner = owner;
  }

  async getImageInfo(): Promise<image.ImageInfo> {
    return {
      size: {
        width: this.owner.width,
        height: this.owner.height
      }
    } as image.ImageInfo;
  }

  async readPixelsToBuffer(buffer: ArrayBuffer): Promise<void> {
    this.owner.readCount++;
    const rgba = new Uint8Array(buffer);
    for (let index = 0; index < rgba.length; index += 4) {
      rgba[index] = 10;
      rgba[index + 1] = 20;
      rgba[index + 2] = 30;
      rgba[index + 3] = 255;
    }
  }

  async release(): Promise<void> {
    this.owner.pixelMapReleaseCount++;
  }
}

class FakeGestureNativeSession implements HmsGestureNativeSession {
  loadCount: number = 0;
  predictCount: number = 0;
  releaseCount: number = 0;
  maxConcurrentPredictions: number = 0;
  private activePredictions: number = 0;
  readonly outputs: HmsGestureOutputs;
  readonly modelInfo: HmsGestureModelInfo;
  readonly rejectPrediction: boolean;

  constructor(
    outputs: HmsGestureOutputs,
    modelInfo: HmsGestureModelInfo = { inputName: 'data', inputShape: [1, 3, 224, 224] },
    rejectPrediction: boolean = false
  ) {
    this.outputs = outputs;
    this.modelInfo = modelInfo;
    this.rejectPrediction = rejectPrediction;
  }

  loadModel(_modelBytes: Uint8Array): HmsGestureModelInfo {
    this.loadCount++;
    return this.modelInfo;
  }

  async predict(_input: Float32Array): Promise<HmsGestureOutputs> {
    this.predictCount++;
    this.activePredictions++;
    this.maxConcurrentPredictions = Math.max(this.maxConcurrentPredictions, this.activePredictions);
    await Promise.resolve();
    this.activePredictions--;
    if (this.rejectPrediction) {
      throw new Error('native prediction failed');
    }
    return this.outputs;
  }

  release(): void {
    this.releaseCount++;
  }
}

export default function gestureModelUnitTest(): void {
  describe('GestureModelUnit', () => {
    it('hmsGestureDetectorLoadsOnceSerializesPredictionsAndStopsIdempotently', 0, async () => {
      const outputs = blankOutputs();
      setPrediction(mutableTensor(outputs, 'layer113-conv-hand'), 28, 0, 10, 10, 11);
      const nativeSession = new FakeGestureNativeSession(outputs);
      const reader = new RecordingGestureRawfileReader();
      const imageLoader = new FakeGestureImageLoader(320, 240);
      const detector = new HmsGestureModelDetector({
        resourceManager: reader,
        nativeSessionFactory: async (): Promise<HmsGestureNativeSession> => nativeSession,
        imageLoader: imageLoader
      });

      const firstPromise = detector.detectAndroidGestures('file://selected/first.jpg');
      const secondPromise = detector.detectAndroidGestures('file://selected/second.jpg');
      const first = await firstPromise;
      const second = await secondPromise;

      expect(reader.seenPaths.length).assertEqual(1);
      expect(reader.seenPaths[0]).assertEqual(hmsGestureModelRawfilePath);
      expect(nativeSession.loadCount).assertEqual(1);
      expect(nativeSession.predictCount).assertEqual(2);
      expect(nativeSession.maxConcurrentPredictions).assertEqual(1);
      expect(imageLoader.readCount).assertEqual(2);
      expect(imageLoader.pixelMapReleaseCount).assertEqual(2);
      expect(imageLoader.closeCount).assertEqual(2);
      expect(first.imageWidth).assertEqual(320);
      expect(first.imageHeight).assertEqual(240);
      expect(first.gestures[0].category).assertEqual(11);
      expect(second.gestures[0].category).assertEqual(11);

      await detector.stop();
      await detector.stop();
      expect(nativeSession.releaseCount).assertEqual(1);
      const stopped = await new AndroidGestureModelRunner(detector).detectGesture('file://selected/stopped.jpg');
      expect(stopped.ok).assertFalse();
      expect(nativeSession.predictCount).assertEqual(2);
    });

    it('hmsGestureDetectorReportsModelNativeAndDecodeFailuresHonestly', 0, async () => {
      const invalidModelSession = new FakeGestureNativeSession(blankOutputs(), {
        inputName: 'wrong',
        inputShape: [1, 3, 224, 224]
      });
      const invalidModelDetector = new HmsGestureModelDetector({
        resourceManager: new RecordingGestureRawfileReader(),
        nativeSessionFactory: async (): Promise<HmsGestureNativeSession> => invalidModelSession,
        imageLoader: new FakeGestureImageLoader()
      });
      const invalidModel = await new AndroidGestureModelRunner(invalidModelDetector)
        .detectGesture('file://selected/model.jpg');

      const nativeImageLoader = new FakeGestureImageLoader();
      const nativeSession = new FakeGestureNativeSession(
        blankOutputs(),
        { inputName: 'data', inputShape: [1, 3, 224, 224] },
        true
      );
      const nativeDetector = new HmsGestureModelDetector({
        resourceManager: new RecordingGestureRawfileReader(),
        nativeSessionFactory: async (): Promise<HmsGestureNativeSession> => nativeSession,
        imageLoader: nativeImageLoader
      });
      const nativeFailure = await new AndroidGestureModelRunner(nativeDetector)
        .detectGesture('file://selected/native.jpg');

      const malformedOutputs = blankOutputs();
      malformedOutputs.tensors[0].name = 'wrong-output';
      const decodeImageLoader = new FakeGestureImageLoader();
      const decodeDetector = new HmsGestureModelDetector({
        resourceManager: new RecordingGestureRawfileReader(),
        nativeSessionFactory: async (): Promise<HmsGestureNativeSession> =>
          new FakeGestureNativeSession(malformedOutputs),
        imageLoader: decodeImageLoader
      });
      const decodeFailure = await new AndroidGestureModelRunner(decodeDetector)
        .detectGesture('file://selected/decode.jpg');

      expect(invalidModel.ok).assertFalse();
      expect(invalidModelSession.releaseCount).assertEqual(1);
      expect(nativeFailure.ok).assertFalse();
      expect(nativeImageLoader.pixelMapReleaseCount).assertEqual(1);
      expect(decodeFailure.ok).assertFalse();
      expect(decodeImageLoader.pixelMapReleaseCount).assertEqual(1);
    });

    it('runtimeFactoryUsesStillGestureThresholdPointSix', 0, async () => {
      const workflow = workflowForRoute(AppRoute.GESTURE_STILL.name)!;
      const outputs = blankOutputs();
      setPrediction(mutableTensor(outputs, 'layer89-conv-hand'), 7, 0, 2, 3, 10, 0, 0);
      const service = await createRuntimeAiServiceForWorkflow(workflow, {
        resourceManager: new RecordingGestureRawfileReader(),
        hmsGestureNativeSessionFactory: async (): Promise<HmsGestureNativeSession> =>
          new FakeGestureNativeSession(outputs),
        hmsGestureImageLoader: new FakeGestureImageLoader()
      });

      const result = await service.run(workflow, { imageUri: 'file://selected/still.jpg' });

      expect(result.code).assertEqual('GESTURE_DETECTION_FAILED');
    });

    it('runtimeFactoryUsesLiveGestureThresholdPointOne', 0, async () => {
      const workflow = workflowForRoute(AppRoute.GESTURE_LIVE.name)!;
      const outputs = blankOutputs();
      setPrediction(mutableTensor(outputs, 'layer89-conv-hand'), 7, 0, 2, 3, 10, 0, 0);
      const service = await createRuntimeAiServiceForWorkflow(workflow, {
        resourceManager: new RecordingGestureRawfileReader(),
        hmsGestureNativeSessionFactory: async (): Promise<HmsGestureNativeSession> =>
          new FakeGestureNativeSession(outputs),
        hmsGestureImageLoader: new FakeGestureImageLoader()
      });

      const result = await service.run(workflow, { imageUri: 'file://selected/live.jpg' });

      expect(result.code).assertEqual('GESTURE_DETECTION_DONE');
    });

    it('stretchesRgbaToBgrPlanar224WithMnnRoundedNearestSampling', 0, () => {
      const rgba = new Uint8Array([
        10, 20, 30, 255, 40, 50, 60, 255,
        70, 80, 90, 255, 100, 110, 120, 255
      ]);

      const input = gestureInputFromRgba(rgba, 2, 2);
      const planeSize = 224 * 224;

      expect(input.length).assertEqual(150528);
      assertNear(input[0], 30 / 255);
      // Pinned MNN nearest uses clamp(round(target * sourceLength / 224)); 2x2 changes at 56, not 112.
      assertNear(input[55], 30 / 255);
      assertNear(input[56], 60 / 255);
      assertNear(input[55 * 224], 30 / 255);
      assertNear(input[56 * 224], 90 / 255);
      assertNear(input[56 * 224 + 56], 120 / 255);
      assertNear(input[planeSize], 20 / 255);
      assertNear(input[planeSize * 2], 10 / 255);
      assertNear(input[input.length - 1], 100 / 255);
      expect(totalFinite(input)).assertTrue();
    });

    it('roundsAndClampsNearestCoordinatesForNonSquareDownscale', 0, () => {
      const width = 335;
      const height = 225;
      const rgba = new Uint8Array(width * height * 4);
      for (let sourceY = 0; sourceY < height; sourceY++) {
        for (let sourceX = 0; sourceX < width; sourceX++) {
          const offset = (sourceY * width + sourceX) * 4;
          rgba[offset] = sourceX % 256;
          rgba[offset + 1] = sourceY % 256;
          rgba[offset + 2] = (sourceX + sourceY) % 256;
          rgba[offset + 3] = 255;
        }
      }

      const input = gestureInputFromRgba(rgba, width, height);
      const planeSize = 224 * 224;
      const targetOffset = 112 * 224 + 2;

      // round(2*335/224)=3 and round(112*225/224)=113; floor would select (2,112).
      assertNear(input[targetOffset], 116 / 255);
      assertNear(input[planeSize + targetOffset], 113 / 255);
      assertNear(input[planeSize * 2 + targetOffset], 3 / 255);
      // The last target coordinate rounds to the last valid source coordinate and remains clamped.
      assertNear(input[planeSize - 1], 46 / 255);
      assertNear(input[planeSize * 2 - 1], 224 / 255);
      assertNear(input[input.length - 1], 78 / 255);
    });

    it('rejectsInvalidPreprocessDimensionsAndLengths', 0, () => {
      assertThrows((): void => { gestureInputFromRgba(new Uint8Array(4), 0, 1); });
      assertThrows((): void => { gestureInputFromRgba(new Uint8Array(4), 1, -1); });
      assertThrows((): void => { gestureInputFromRgba(new Uint8Array(7), 1, 2); });
      assertThrows((): void => { gestureInputFromRgba(new Uint8Array(8), 1.5, 1); });
    });

    it('decodesExactSyntheticCellAnchorAndThresholdBoundary', 0, () => {
      const outputs = blankOutputs();
      setPrediction(mutableTensor(outputs, 'layer89-conv-hand'), 7, 0, 2, 3, 14, 0, 0);

      // HMS 2.1.0.300 arm64 resolveBox 0x3243c-0x32458 rejects only score < threshold.
      const detections = decodeHmsGestureOutputs(outputs, 448, 112, 0.25);

      expect(detections.length).assertEqual(1);
      expect(detections[0].category).assertEqual(14);
      assertNear(detections[0].score, 0.25);
      assertNear(detections[0].rect?.left ?? -1, 55);
      assertNear(detections[0].rect?.top ?? -1, 30.75);
      assertNear(detections[0].rect?.width ?? -1, 210);
      assertNear(detections[0].rect?.height ?? -1, 50.5);
      expect(decodeHmsGestureOutputs(outputs, 448, 112, 0.250001).length).assertEqual(0);
    });

    it('decodesAllThreeOutputScales', 0, () => {
      const outputs = blankOutputs();
      for (let index = 0; index < gestureScaleFixtures.length; index++) {
        const fixture = gestureScaleFixtures[index];
        setPrediction(mutableTensor(outputs, fixture.name), fixture.gridSize, 0, index + 1, index + 1, index);
      }

      const detections = decodeHmsGestureOutputs(outputs, 224, 224, 0.9);

      expect(detections.length).assertEqual(3);
      expect(detections[0].category).assertEqual(0);
      expect(detections[1].category).assertEqual(1);
      expect(detections[2].category).assertEqual(2);
    });

    it('restoresSourceCoordinatesAndClipsModelEdges', 0, () => {
      const outputs = blankOutputs();
      setPrediction(mutableTensor(outputs, 'layer89-conv-hand'), 7, 0, 0, 0, 3);

      const detection = decodeHmsGestureOutputs(outputs, 448, 112, 0.9)[0];

      assertNear(detection.rect?.left ?? -1, 0);
      assertNear(detection.rect?.top ?? -1, 0);
      assertNear(detection.rect?.width ?? -1, 137);
      assertNear(detection.rect?.height ?? -1, 33.25);
    });

    it('suppressesNmsOnlyAboveExactIouBoundary', 0, () => {
      const reference: GestureRectangle = { left: 0, top: 0, width: 20, height: 10 };
      const exact: GestureRectangle = { left: 0, top: 0, width: 9, height: 10 };
      const above: GestureRectangle = { left: 0, top: 0, width: 9.000000000000002, height: 10 };
      const below: GestureRectangle = { left: 0, top: 0, width: 8.999999999999998, height: 10 };

      // Containment makes IoU width/20: exact is 9/20 == 0.45; adjacent doubles bracket it.
      expect(hmsGestureBoxesExceedNmsThreshold(reference, exact)).assertFalse();
      expect(hmsGestureBoxesExceedNmsThreshold(reference, above)).assertTrue();
      expect(hmsGestureBoxesExceedNmsThreshold(reference, below)).assertFalse();
    });

    it('retainsOverlappingCrossClassDetections', 0, () => {
      const outputs = blankOutputs();
      const values = mutableTensor(outputs, 'layer113-conv-hand');
      setPrediction(values, 28, 0, 10, 10, 6);
      setPrediction(values, 28, 1, 10, 10, 7, 9, 9, 0, 0, Math.log(19 / 25), Math.log(19 / 27));

      const detections = decodeHmsGestureOutputs(outputs, 224, 224, 0.9);

      expect(detections.length).assertEqual(2);
      expect(detections[0].category).assertEqual(6);
      expect(detections[1].category).assertEqual(7);
    });

    it('sortsDeterministicallyAndDoesNotCapResults', 0, () => {
      const outputs = blankOutputs();
      const values = mutableTensor(outputs, 'layer113-conv-hand');
      setPrediction(values, 28, 0, 20, 20, 3, 8, 8);
      setPrediction(values, 28, 0, 15, 15, 2, 8, 8);
      setPrediction(values, 28, 0, 10, 10, 1, 8, 8);
      setPrediction(values, 28, 0, 5, 5, 0, 8, 8);

      const detections = decodeHmsGestureOutputs(outputs, 224, 224, 0.9);

      expect(detections.length).assertEqual(4);
      for (let index = 0; index < detections.length; index++) {
        expect(detections[index].category).assertEqual(index);
      }
    });

    it('rejectsMalformedOutputNamesShapesAndLengths', 0, () => {
      const missing = blankOutputs();
      missing.tensors[0].name = 'wrong-name';
      assertThrows((): void => { decodeHmsGestureOutputs(missing, 224, 224, 0.6); });

      const wrongShape = blankOutputs();
      wrongShape.tensors[1].shape = [1, 60, 7, 7];
      assertThrows((): void => { decodeHmsGestureOutputs(wrongShape, 224, 224, 0.6); });

      const wrongLength = blankOutputs();
      wrongLength.tensors[2].data = new ArrayBuffer(5 * Float32Array.BYTES_PER_ELEMENT);
      assertThrows((): void => { decodeHmsGestureOutputs(wrongLength, 224, 224, 0.6); });

      const duplicate = blankOutputs();
      duplicate.tensors[2].name = duplicate.tensors[1].name;
      assertThrows((): void => { decodeHmsGestureOutputs(duplicate, 224, 224, 0.6); });
      assertThrows((): void => { decodeHmsGestureOutputs(blankOutputs(), 0, 224, 0.6); });
      assertThrows((): void => { decodeHmsGestureOutputs(blankOutputs(), 224, 224, Number.NaN); });
    });

    it('skipsNonFiniteCandidatesAndNeverEmitsNonFiniteGeometry', 0, () => {
      const outputs = blankOutputs();
      const values = mutableTensor(outputs, 'layer89-conv-hand');
      setPrediction(values, 7, 0, 1, 1, 5, Number.NaN, 10);
      setPrediction(values, 7, 1, 2, 2, 6, 10, 10, 0, 0, Number.POSITIVE_INFINITY, 0);
      setPrediction(values, 7, 2, 3, 3, 7, 10, 10, 0, 0, 1000, 1000);

      const detections = decodeHmsGestureOutputs(outputs, 224, 224, 0.9);

      expect(detections.length).assertEqual(1);
      const detection: AndroidGestureModelDetection = detections[0];
      expect(Number.isFinite(detection.score)).assertTrue();
      expect(Number.isFinite(detection.rect?.left ?? Number.NaN)).assertTrue();
      expect(Number.isFinite(detection.rect?.top ?? Number.NaN)).assertTrue();
      expect(Number.isFinite(detection.rect?.width ?? Number.NaN)).assertTrue();
      expect(Number.isFinite(detection.rect?.height ?? Number.NaN)).assertTrue();
    });
  });
}
