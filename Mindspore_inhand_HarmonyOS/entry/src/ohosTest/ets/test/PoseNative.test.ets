import { fileIo } from '@kit.CoreFileKit';
import { image } from '@kit.ImageKit';
import { abilityDelegatorRegistry } from '@kit.TestKit';
import { describe, it, expect } from '@ohos/hypium';
import { mindSporeLite } from '@kit.MindSporeLiteKit';
import { HarmonyRawfileContentReader } from '../../../main/ets/services/ai/ImageClassificationRuntimeFactory';
import { mindSporeLiteCpuContext, rawfileContentToArrayBuffer } from
  '../../../main/ets/services/ai/MindSporeLiteModelRunner';
import {
  HarmonyMoveNetInputPreprocessor,
  LocalMoveNetPoseRunner,
  moveNetInputByteCount,
  moveNetModelRawfilePath,
  moveNetPointCount,
  poseMinPointScore,
  PosePoint,
  PoseResult,
  poseSkeletonLines
} from '../../../main/ets/services/ai/PoseService';

interface PoseFixturePointLabel {
  readonly index: number;
  readonly name: string;
  readonly x: number;
  readonly y: number;
}

interface PoseFixtureLabel {
  readonly rawfilePath: string;
  readonly width: number;
  readonly height: number;
  readonly sha256: string;
  readonly keypoints: Array<PoseFixturePointLabel>;
}

interface PoseFixtureDocument {
  readonly format: string;
  readonly annotationMethod: string;
  readonly fixtures: Array<PoseFixtureLabel>;
}

interface PoseAccuracy {
  readonly accepted: number;
  readonly visible: number;
  readonly meanError: number;
  readonly maximumAcceptedError: number;
}

function asciiText(bytes: Uint8Array): string {
  let text: string = '';
  const chunkSize: number = 4096;
  for (let start: number = 0; start < bytes.length; start += chunkSize) {
    let chunk: string = '';
    const end: number = Math.min(bytes.length, start + chunkSize);
    for (let index: number = start; index < end; index++) {
      chunk += String.fromCharCode(bytes[index]);
    }
    text += chunk;
  }
  return text;
}

async function grayJpegBytes(): Promise<Uint8Array> {
  const width: number = 320;
  const height: number = 320;
  const rgba = new Uint8Array(width * height * 4);
  for (let offset: number = 0; offset < rgba.length; offset += 4) {
    rgba[offset] = 128;
    rgba[offset + 1] = 128;
    rgba[offset + 2] = 128;
    rgba[offset + 3] = 255;
  }
  const pixelMap = await image.createPixelMap(rgba.buffer as ArrayBuffer, {
    size: { width: width, height: height },
    srcPixelFormat: image.PixelMapFormat.RGBA_8888,
    pixelFormat: image.PixelMapFormat.RGBA_8888
  });
  const packer = image.createImagePacker();
  try {
    return new Uint8Array(await packer.packToData(pixelMap, { format: 'image/jpeg', quality: 100 }));
  } finally {
    await packer.release();
    await pixelMap.release();
  }
}

async function writeBytes(path: string, bytes: Uint8Array): Promise<void> {
  const file = await fileIo.open(path, fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
  try {
    const written = await fileIo.write(file.fd, bytes.buffer as ArrayBuffer, {
      offset: bytes.byteOffset,
      length: bytes.byteLength
    });
    expect(written).assertEqual(bytes.byteLength);
  } finally {
    await fileIo.close(file);
  }
}

function labelledAccuracy(result: PoseResult, fixture: PoseFixtureLabel): PoseAccuracy {
  let accepted: number = 0;
  let visible: number = 0;
  let errorSum: number = 0;
  let maximumAcceptedError: number = 0;
  for (let index: number = 0; index < fixture.keypoints.length; index++) {
    const label = fixture.keypoints[index];
    const point = result.points[label.index];
    if (point === undefined || point.score < poseMinPointScore) {
      continue;
    }
    visible++;
    const dx: number = (point.x - label.x) / fixture.width;
    const dy: number = (point.y - label.y) / fixture.height;
    const error: number = Math.sqrt(dx * dx + dy * dy);
    errorSum += error;
    if (error <= 0.08) {
      accepted++;
      maximumAcceptedError = Math.max(maximumAcceptedError, error);
    }
  }
  return {
    accepted: accepted,
    visible: visible,
    meanError: visible === 0 ? 1 : errorSum / visible,
    maximumAcceptedError: maximumAcceptedError
  };
}

function normalizedPoseDifference(left: PoseResult, right: PoseResult): number {
  const count: number = Math.min(left.points.length, right.points.length);
  const leftWidth: number = left.imageWidth ?? 1;
  const leftHeight: number = left.imageHeight ?? 1;
  const rightWidth: number = right.imageWidth ?? 1;
  const rightHeight: number = right.imageHeight ?? 1;
  let difference: number = 0;
  for (let index: number = 0; index < count; index++) {
    const leftPoint: PosePoint = left.points[index];
    const rightPoint: PosePoint = right.points[index];
    const dx: number = leftPoint.x / leftWidth - rightPoint.x / rightWidth;
    const dy: number = leftPoint.y / leftHeight - rightPoint.y / rightHeight;
    difference += Math.sqrt(dx * dx + dy * dy);
  }
  return count === 0 ? 0 : difference / count;
}

export default function poseNativeTest() {
  describe('PoseNativeTest', () => {
    it('runsPinnedMoveNetForTwoLicensedLabelledPeopleAndRecoversAfterFailuresOnApi24', 0, async () => {
      const applicationContext = abilityDelegatorRegistry.getAbilityDelegator()
        .getAppContext()
        .getApplicationContext();
      const mainManager = applicationContext.createModuleContext('entry').resourceManager;
      const testManager = applicationContext.createModuleContext('entry_test').resourceManager;
      const resources = new HarmonyRawfileContentReader(mainManager);
      const labels = JSON.parse(asciiText(await testManager.getRawFileContent(
        'fixtures/posenet/labels.json'
      ))) as PoseFixtureDocument;
      expect(labels.fixtures.length).assertEqual(2);
      expect(labels.annotationMethod.startsWith('Manually placed')).assertTrue();

      const modelBytes = await mainManager.getRawFileContent(moveNetModelRawfilePath);
      const model = await mindSporeLite.loadModelFromBuffer(
        rawfileContentToArrayBuffer(modelBytes),
        mindSporeLiteCpuContext()
      );
      const preprocessor = new HarmonyMoveNetInputPreprocessor(resources);
      const directInput = await preprocessor.createInput(`rawfile://${labels.fixtures[0].rawfilePath}`);
      const inputs = model.getInputs();
      expect(inputs.length).assertEqual(1);
      expect(inputs[0].name).assertEqual('serving_default_input:0');
      expect(inputs[0].shape.join(',')).assertEqual('1,192,192,3');
      expect(inputs[0].dtype).assertEqual(mindSporeLite.DataType.NUMBER_TYPE_UINT8);
      expect(inputs[0].elementNum).assertEqual(moveNetInputByteCount);
      expect(inputs[0].dataSize).assertEqual(moveNetInputByteCount);
      inputs[0].setData(directInput.inputBuffer);
      const outputs = await model.predict(inputs);
      expect(outputs.length).assertEqual(1);
      expect(outputs[0].name).assertEqual('StatefulPartitionedCall:0');
      expect(outputs[0].shape.join(',')).assertEqual('1,1,17,3');
      expect(outputs[0].dtype).assertEqual(mindSporeLite.DataType.NUMBER_TYPE_FLOAT32);
      expect(outputs[0].elementNum).assertEqual(moveNetPointCount * 3);
      expect(outputs[0].dataSize).assertEqual(moveNetPointCount * 3 * 4);
      console.info(`posenet-api24-model input=${inputs[0].name}:${inputs[0].shape.join(',')}:dtype=${inputs[0].dtype}:bytes=${inputs[0].dataSize} ` +
        `output=${outputs[0].name}:${outputs[0].shape.join(',')}:dtype=${outputs[0].dtype}:bytes=${outputs[0].dataSize}`);

      const runner = new LocalMoveNetPoseRunner({
        resourceManager: resources,
        modelRawfilePath: moveNetModelRawfilePath
      });
      let missingRejected: boolean = false;
      try {
        await runner.detectPose('rawfile://posenet/does-not-exist.jpg');
      } catch (_) {
        missingRejected = true;
      }
      expect(missingRejected).assertTrue();

      let timerTicks: number = 0;
      const timerId: number = setInterval((): void => {
        timerTicks++;
      }, 20);
      const first = await runner.detectPose(`rawfile://${labels.fixtures[0].rawfilePath}`);
      clearInterval(timerId);
      expect(timerTicks > 0).assertTrue();
      const second = await runner.detectPose(`rawfile://${labels.fixtures[1].rawfilePath}`);

      const results: Array<PoseResult> = [first, second];
      for (let index: number = 0; index < results.length; index++) {
        const result = results[index];
        const fixture = labels.fixtures[index];
        const accuracy = labelledAccuracy(result, fixture);
        const lines = poseSkeletonLines(result.points);
        console.info(`posenet-api24-fixture=${fixture.rawfilePath} ok=${result.ok} points=${result.pointCount} ` +
          `lines=${lines.length} accepted=${accuracy.accepted}/${fixture.keypoints.length} visible=${accuracy.visible} ` +
          `meanError=${accuracy.meanError} maxAcceptedError=${accuracy.maximumAcceptedError} executionMs=${result.executionMs}`);
        expect(result.ok).assertTrue();
        expect(result.skeletonCount).assertEqual(1);
        expect(result.pointCount).assertEqual(moveNetPointCount);
        expect(result.imageWidth).assertEqual(fixture.width);
        expect(result.imageHeight).assertEqual(fixture.height);
        expect(lines.length >= 8).assertTrue();
        expect(accuracy.accepted >= 12).assertTrue();
      }
      const poseDifference = normalizedPoseDifference(first, second);
      console.info(`posenet-api24-input-dependent-difference=${poseDifference} timerTicks=${timerTicks}`);
      expect(poseDifference > 0.015).assertTrue();

      const grayPath = `${applicationContext.cacheDir}/posenet-no-person.jpg`;
      await writeBytes(grayPath, await grayJpegBytes());
      const noPerson = await runner.detectPose(grayPath);
      console.info(`posenet-api24-no-person ok=${noPerson.ok} skeletons=${noPerson.skeletonCount} points=${noPerson.pointCount}`);
      expect(noPerson.ok).assertFalse();
      expect(noPerson.skeletonCount).assertEqual(0);
      const recovered = await runner.detectPose(`rawfile://${labels.fixtures[0].rawfilePath}`);
      expect(recovered.ok).assertTrue();
      expect(recovered.pointCount).assertEqual(moveNetPointCount);
    });
  });
}
