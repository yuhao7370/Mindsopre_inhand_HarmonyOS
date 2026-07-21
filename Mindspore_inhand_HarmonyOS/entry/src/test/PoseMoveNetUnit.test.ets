import { describe, it, expect } from '@ohos/hypium';
import {
  CoreVisionFallbackPoseRunner,
  LocalMoveNetPoseRunner,
  LocalMoveNetPoseRunnerOptions,
  MoveNetLetterbox,
  MoveNetInput,
  MoveNetInputPreprocessor,
  MoveNetRuntime,
  PoseResult,
  PoseRunner,
  moveNetInputByteCount,
  moveNetLetterboxForImage,
  moveNetPoseResultFromOutput,
  moveNetRgbInputFromResizedRgba,
  moveNetTensorContractMatches,
  poseSkeletonLines
} from '../main/ets/services/ai/PoseService';
import { RawfileContentReader } from '../main/ets/services/ai/MindSporeLiteModelRunner';

class FixedPoseRunner implements PoseRunner {
  readonly result: PoseResult;
  calls: number = 0;

  constructor(result: PoseResult) {
    this.result = result;
  }

  async detectPose(_imageUri: string): Promise<PoseResult> {
    this.calls++;
    return this.result;
  }
}

class ThrowingPoseRunner implements PoseRunner {
  calls: number = 0;

  async detectPose(_imageUri: string): Promise<PoseResult> {
    this.calls++;
    throw new Error('CoreVision unavailable');
  }
}

class FixedMoveNetRawfileReader implements RawfileContentReader {
  async getRawFileContent(_path: string): Promise<Uint8Array> {
    return new Uint8Array([9]);
  }
}

class FixedMoveNetInputPreprocessor implements MoveNetInputPreprocessor {
  private readonly input: MoveNetInput;

  constructor(input: MoveNetInput) {
    this.input = input;
  }

  async createInput(_imageUri: string): Promise<MoveNetInput> {
    return this.input;
  }
}

class RecordingMoveNetRuntime implements MoveNetRuntime {
  readonly events: Array<string> = [];
  private blockFirstPredict: boolean;
  private firstPredictStartedResolver: (() => void) | undefined = undefined;
  private firstPredictStarted: Promise<void>;
  private firstPredictRelease: (() => void) | undefined = undefined;
  rejectFirstPredict: boolean = false;

  constructor(blockFirstPredict: boolean = false) {
    this.blockFirstPredict = blockFirstPredict;
    this.firstPredictStarted = new Promise<void>((resolve: () => void) => {
      this.firstPredictStartedResolver = resolve;
    });
  }

  async loadModel(content: Uint8Array): Promise<void> {
    this.events.push(`load:${content[0]}`);
  }

  async predict(_input: Uint8Array): Promise<Float32Array> {
    this.events.push('predict-start');
    if (this.blockFirstPredict) {
      this.blockFirstPredict = false;
      if (this.firstPredictStartedResolver !== undefined) {
        this.firstPredictStartedResolver();
        this.firstPredictStartedResolver = undefined;
      }
      await new Promise<void>((resolve: () => void) => {
        this.firstPredictRelease = resolve;
      });
    }
    if (this.rejectFirstPredict) {
      this.rejectFirstPredict = false;
      this.events.push('predict-error');
      throw new Error('predict failed');
    }
    this.events.push('predict-end');
    return visibleMoveNetOutput();
  }

  async waitForFirstPredict(): Promise<void> {
    await this.firstPredictStarted;
  }

  releaseFirstPredict(): void {
    if (this.firstPredictRelease !== undefined) {
      this.firstPredictRelease();
      this.firstPredictRelease = undefined;
    }
  }
}

function poseResult(ok: boolean, x: number = 10): PoseResult {
  return {
    ok: ok,
    skeletonCount: ok ? 1 : 0,
    pointCount: ok ? 1 : 0,
    imageWidth: 100,
    imageHeight: 100,
    points: ok ? [{ type: 0, score: 0.9, x: x, y: 20 }] : [],
    executionMs: 1
  };
}

function visibleMoveNetOutput(): Float32Array {
  const output = new Float32Array(17 * 3);
  for (let index = 0; index < 17; index++) {
    output[index * 3] = 0.5;
    output[index * 3 + 1] = 0.5;
    output[index * 3 + 2] = 0.9;
  }
  return output;
}

export default function poseMoveNetUnitTest() {
  describe('PoseMoveNetUnitTest', () => {
    it('computesAspectPreservingMoveNetLetterboxGeometry', 0, () => {
      const landscape: MoveNetLetterbox = moveNetLetterboxForImage(640, 480);
      expect(landscape.originalWidth).assertEqual(640);
      expect(landscape.originalHeight).assertEqual(480);
      expect(landscape.resizedWidth).assertEqual(192);
      expect(landscape.resizedHeight).assertEqual(144);
      expect(landscape.padX).assertEqual(0);
      expect(landscape.padY).assertEqual(24);

      const portrait: MoveNetLetterbox = moveNetLetterboxForImage(1024, 1365);
      expect(portrait.resizedWidth).assertEqual(144);
      expect(portrait.resizedHeight).assertEqual(192);
      expect(portrait.padX).assertEqual(24);
      expect(portrait.padY).assertEqual(0);
    });

    it('padsResizedRgbaWithBlackAndCopiesRgbBytes', 0, () => {
      const transform: MoveNetLetterbox = moveNetLetterboxForImage(2, 1);
      const rgba: Uint8Array = new Uint8Array(transform.resizedWidth * transform.resizedHeight * 4);
      for (let index = 0; index < rgba.length; index += 4) {
        rgba[index] = 11;
        rgba[index + 1] = 22;
        rgba[index + 2] = 33;
        rgba[index + 3] = 255;
      }

      const input: Uint8Array = new Uint8Array(moveNetRgbInputFromResizedRgba(rgba, transform));
      const firstContentPixel: number = (transform.padY * 192 + transform.padX) * 3;
      expect(input.length).assertEqual(moveNetInputByteCount);
      expect(input[0]).assertEqual(0);
      expect(input[firstContentPixel]).assertEqual(11);
      expect(input[firstContentPixel + 1]).assertEqual(22);
      expect(input[firstContentPixel + 2]).assertEqual(33);
    });

    it('decodesCoco17AndReversesLetterboxToOriginalPixels', 0, () => {
      const transform: MoveNetLetterbox = moveNetLetterboxForImage(640, 480);
      const result: PoseResult = moveNetPoseResultFromOutput(visibleMoveNetOutput(), transform, 7);

      expect(result.ok).assertTrue();
      expect(result.skeletonCount).assertEqual(1);
      expect(result.pointCount).assertEqual(17);
      expect(result.points.length).assertEqual(17);
      expect(result.imageWidth).assertEqual(640);
      expect(result.imageHeight).assertEqual(480);
      expect(result.points[0].type).assertEqual(0);
      expect(result.points[0].x).assertEqual(320);
      expect(result.points[0].y).assertEqual(240);
      expect(poseSkeletonLines(result.points).length).assertEqual(12);
    });

    it('keepsAUsefulPartialPoseButRejectsMalformedOutputs', 0, () => {
      const transform: MoveNetLetterbox = moveNetLetterboxForImage(640, 480);
      const partial: Float32Array = visibleMoveNetOutput();
      partial[1 * 3 + 2] = 0.1;
      partial[2 * 3 + 2] = 0.1;
      partial[3 * 3 + 2] = 0.1;
      partial[4 * 3 + 2] = 0.1;
      const partialResult: PoseResult = moveNetPoseResultFromOutput(partial, transform, 2);
      expect(partialResult.ok).assertTrue();
      expect(partialResult.points.length).assertEqual(17);
      expect(poseSkeletonLines(partialResult.points).length >= 4).assertTrue();

      const nonFinite: Float32Array = visibleMoveNetOutput();
      nonFinite[0] = Number.NaN;
      const nonFiniteResult: PoseResult = moveNetPoseResultFromOutput(nonFinite, transform, 2);
      expect(nonFiniteResult.ok).assertFalse();
      expect(nonFiniteResult.points.length).assertEqual(0);

      const outOfRange: Float32Array = visibleMoveNetOutput();
      outOfRange[1] = 1.01;
      const outOfRangeResult: PoseResult = moveNetPoseResultFromOutput(outOfRange, transform, 2);
      expect(outOfRangeResult.ok).assertFalse();
      expect(outOfRangeResult.points.length).assertEqual(0);

      const shortResult: PoseResult = moveNetPoseResultFromOutput(new Float32Array(50), transform, 2);
      expect(shortResult.ok).assertFalse();
      expect(shortResult.points.length).assertEqual(0);
    });

    it('validatesExactMoveNetInputAndOutputTensorMetadata', 0, () => {
      expect(moveNetTensorContractMatches(
        1, 'serving_default_input:0', [1, 192, 192, 3], 37, 110592,
        1, 'StatefulPartitionedCall:0', [1, 1, 17, 3], 43, 204
      )).assertTrue();
      expect(moveNetTensorContractMatches(
        1, 'serving_default_input:0', [1, 192, 192, 3], 43, 442368,
        1, 'StatefulPartitionedCall:0', [1, 1, 17, 3], 43, 204
      )).assertFalse();
      expect(moveNetTensorContractMatches(
        1, 'serving_default_input:0', [1, 192, 192, 3], 37, 110592,
        1, 'StatefulPartitionedCall:0', [1, 17, 3], 43, 204
      )).assertFalse();
    });

    it('keepsValidCoreVisionSuccessAuthoritative', 0, async () => {
      const coreVision = new FixedPoseRunner(poseResult(true, 11));
      const local = new FixedPoseRunner(poseResult(true, 77));
      const result: PoseResult = await new CoreVisionFallbackPoseRunner(coreVision, local).detectPose('fixture');

      expect(result.points[0].x).assertEqual(11);
      expect(coreVision.calls).assertEqual(1);
      expect(local.calls).assertEqual(0);
    });

    it('fallsBackWhenCoreVisionThrowsOrReturnsNoPose', 0, async () => {
      const localAfterError = new FixedPoseRunner(poseResult(true, 71));
      const errorResult: PoseResult = await new CoreVisionFallbackPoseRunner(
        new ThrowingPoseRunner(),
        localAfterError
      ).detectPose('fixture');
      expect(errorResult.points[0].x).assertEqual(71);
      expect(localAfterError.calls).assertEqual(1);

      const emptyCoreVision = new FixedPoseRunner(poseResult(false));
      const localAfterEmpty = new FixedPoseRunner(poseResult(true, 72));
      const emptyResult: PoseResult = await new CoreVisionFallbackPoseRunner(
        emptyCoreVision,
        localAfterEmpty
      ).detectPose('fixture');
      expect(emptyResult.points[0].x).assertEqual(72);
      expect(emptyCoreVision.calls).assertEqual(1);
      expect(localAfterEmpty.calls).assertEqual(1);
    });

    it('serializesSharedMoveNetRuntimeAndLoadsBuiltinModelOnce', 0, async () => {
      const runtime = new RecordingMoveNetRuntime(true);
      const input: MoveNetInput = {
        inputBuffer: new ArrayBuffer(moveNetInputByteCount),
        letterbox: moveNetLetterboxForImage(640, 480)
      };
      const options: LocalMoveNetPoseRunnerOptions = {
        resourceManager: new FixedMoveNetRawfileReader(),
        modelRawfilePath: 'model/movenet.ms',
        preprocessor: new FixedMoveNetInputPreprocessor(input),
        runtime: runtime
      };
      const runnerA = new LocalMoveNetPoseRunner(options);
      const runnerB = new LocalMoveNetPoseRunner(options);

      const first: Promise<PoseResult> = runnerA.detectPose('first');
      await runtime.waitForFirstPredict();
      const second: Promise<PoseResult> = runnerB.detectPose('second');
      for (let tick = 0; tick < 10; tick++) {
        await Promise.resolve();
      }
      expect(runtime.events.join(',')).assertEqual('load:9,predict-start');
      runtime.releaseFirstPredict();
      const firstResult: PoseResult = await first;
      const secondResult: PoseResult = await second;

      expect(firstResult.ok).assertTrue();
      expect(secondResult.ok).assertTrue();
      expect(runtime.events.join(','))
        .assertEqual('load:9,predict-start,predict-end,predict-start,predict-end');
    });

    it('recoversTheSharedMoveNetQueueAfterPredictionFailure', 0, async () => {
      const runtime = new RecordingMoveNetRuntime();
      runtime.rejectFirstPredict = true;
      const input: MoveNetInput = {
        inputBuffer: new ArrayBuffer(moveNetInputByteCount),
        letterbox: moveNetLetterboxForImage(640, 480)
      };
      const runner = new LocalMoveNetPoseRunner({
        resourceManager: new FixedMoveNetRawfileReader(),
        modelRawfilePath: 'model/movenet.ms',
        preprocessor: new FixedMoveNetInputPreprocessor(input),
        runtime: runtime
      });
      let failed: boolean = false;
      try {
        await runner.detectPose('first');
      } catch (_) {
        failed = true;
      }
      const recovered: PoseResult = await runner.detectPose('second');

      expect(failed).assertTrue();
      expect(recovered.ok).assertTrue();
      expect(runtime.events.join(','))
        .assertEqual('load:9,predict-start,predict-error,predict-start,predict-end');
    });
  });
}
