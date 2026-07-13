import { describe, it, expect } from '@ohos/hypium';
import { gestureInputFromRgba } from '../main/ets/services/ai/HmsGesturePreprocessor';
import {
  HmsGestureOutputTensor,
  HmsGestureOutputs,
  decodeHmsGestureOutputs
} from '../main/ets/services/ai/HmsGestureYoloDecoder';
import { AndroidGestureModelDetection } from '../main/ets/services/ai/GestureService';

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

export default function gestureModelUnitTest(): void {
  describe('GestureModelUnit', () => {
    it('stretchesRgbaToBgrPlanar224WithNearestSampling', 0, () => {
      const rgba = new Uint8Array([
        10, 20, 30, 255, 40, 50, 60, 255,
        70, 80, 90, 255, 100, 110, 120, 255
      ]);

      const input = gestureInputFromRgba(rgba, 2, 2);
      const planeSize = 224 * 224;

      expect(input.length).assertEqual(150528);
      assertNear(input[0], 30 / 255);
      assertNear(input[111], 30 / 255);
      assertNear(input[112], 60 / 255);
      assertNear(input[111 * 224 + 111], 30 / 255);
      assertNear(input[112 * 224 + 112], 120 / 255);
      assertNear(input[planeSize], 20 / 255);
      assertNear(input[planeSize * 2], 10 / 255);
      assertNear(input[input.length - 1], 100 / 255);
      expect(totalFinite(input)).assertTrue();
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

    it('suppressesSameClassAtNmsBoundaryAndKeepsJustBelowBoundary', 0, () => {
      const atBoundary = blankOutputs();
      const atValues = mutableTensor(atBoundary, 'layer113-conv-hand');
      setPrediction(atValues, 28, 0, 5, 8, 4, 10, 10);
      setPrediction(atValues, 28, 0, 6, 8, 4, 9, 9, -0.40187445282936096);
      expect(decodeHmsGestureOutputs(atBoundary, 224, 224, 0.9).length).assertEqual(1);

      const belowBoundary = blankOutputs();
      const belowValues = mutableTensor(belowBoundary, 'layer113-conv-hand');
      setPrediction(belowValues, 28, 0, 5, 8, 4, 10, 10);
      setPrediction(belowValues, 28, 0, 6, 8, 4, 9, 9, -0.39246997237205505);
      expect(decodeHmsGestureOutputs(belowBoundary, 224, 224, 0.9).length).assertEqual(2);
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
