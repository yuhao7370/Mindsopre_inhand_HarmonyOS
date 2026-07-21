import { fileIo } from '@kit.CoreFileKit';
import { image } from '@kit.ImageKit';
import { resourceManager } from '@kit.LocalizationKit';
import { abilityDelegatorRegistry } from '@kit.TestKit';
import { describe, it, expect } from '@ohos/hypium';
import objectDetectionMnn from 'libobject_detection_mnn.so';
import {
  objectDetectionInputFloatCount,
  objectDetectionModelRawfilePath,
  objectDetectionOutputFloatCount,
  decodeNanoDetObjectDetections,
  ObjectDetection
} from '../../../main/ets/services/ai/ObjectDetectionService';
import { HarmonyObjectDetectionInputPreprocessor } from
  '../../../main/ets/services/ai/HarmonyObjectDetectionInputPreprocessor';

const dogFixturePath: string = 'fixtures/classification/yellow_labrador.jpg';

async function cacheBytes(cacheDir: string, fileName: string, bytes: Uint8Array): Promise<string> {
  const path = `${cacheDir}/${fileName}`;
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
  return path;
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

function detectionIou(detection: ObjectDetection, left: number, top: number, right: number, bottom: number): number {
  const intersectionWidth = Math.max(0, Math.min(detection.right, right) - Math.max(detection.left, left));
  const intersectionHeight = Math.max(0, Math.min(detection.bottom, bottom) - Math.max(detection.top, top));
  const intersection = intersectionWidth * intersectionHeight;
  const detectionArea = Math.max(0, detection.right - detection.left) * Math.max(0, detection.bottom - detection.top);
  const expectedArea = Math.max(0, right - left) * Math.max(0, bottom - top);
  const union = detectionArea + expectedArea - intersection;
  return union > 0 ? intersection / union : 0;
}

function topDetectionSummary(detections: Array<ObjectDetection>): string {
  const count = Math.min(5, detections.length);
  const values: Array<string> = [];
  for (let index: number = 0; index < count; index++) {
    const value = detections[index];
    values.push(`${value.labelId}:${value.score.toFixed(4)}:[${value.left.toFixed(1)},${value.top.toFixed(1)},${value.right.toFixed(1)},${value.bottom.toFixed(1)}]`);
  }
  return values.join('|');
}

export default function objectDetectionNativeTest() {
  describe('ObjectDetectionNativeTest', () => {
    it('loadsAndRunsTheProductionNanoDetContractOnApi24', 0, async () => {
      const applicationContext = abilityDelegatorRegistry.getAbilityDelegator()
        .getAppContext()
        .getApplicationContext();
      const mainManager = applicationContext.createModuleContext('entry').resourceManager;
      const modelBytes = await mainManager.getRawFileContent(objectDetectionModelRawfilePath);
      let timerTicks: number = 0;
      const timerId: number = setInterval((): void => {
        timerTicks++;
      }, 100);
      const validationStartedAt: number = Date.now();
      expect(await objectDetectionMnn.validateModel(modelBytes)).assertTrue();
      console.info(`object-detection-validation-ms=${Date.now() - validationStartedAt} timer-ticks=${timerTicks}`);
      clearInterval(timerId);
      expect(timerTicks > 0).assertTrue();
      expect(await objectDetectionMnn.validateModel(new Uint8Array([1, 2, 3, 4]))).assertFalse();

      const modelInfo = await objectDetectionMnn.loadModel(modelBytes);
      expect(modelInfo.inputName).assertEqual('data');
      expect(modelInfo.inputShape.join(',')).assertEqual('1,3,320,320');
      expect(modelInfo.outputName).assertEqual('output');
      expect(modelInfo.outputShape.join(',')).assertEqual('1,2125,112');
      try {
        const input = new Float32Array(objectDetectionInputFloatCount);
        const output = await objectDetectionMnn.predict(input);
        expect(output.byteLength).assertEqual(objectDetectionOutputFloatCount * 4);
        let finiteAndNonZero: boolean = false;
        let allFinite: boolean = true;
        for (let index: number = 0; index < output.length; index++) {
          if (!Number.isFinite(output[index])) {
            allFinite = false;
            break;
          }
          if (Math.abs(output[index]) > 1.0e-12) {
            finiteAndNonZero = true;
          }
        }
        expect(allFinite).assertTrue();
        expect(finiteAndNonZero).assertTrue();

        let invalidLoadRejected: boolean = false;
        try {
          await objectDetectionMnn.loadModel(new Uint8Array([1, 2, 3, 4]));
        } catch (_) {
          invalidLoadRejected = true;
        }
        expect(invalidLoadRejected).assertTrue();
        const outputAfterRejectedLoad = await objectDetectionMnn.predict(input);
        expect(outputAfterRejectedLoad.byteLength).assertEqual(objectDetectionOutputFloatCount * 4);
      } finally {
        objectDetectionMnn.release();
      }
    });

    it('detectsTheLicensedDogFixtureThroughTheProductionPreprocessorAndDecoder', 0, async () => {
      const applicationContext = abilityDelegatorRegistry.getAbilityDelegator()
        .getAppContext()
        .getApplicationContext();
      const mainManager = applicationContext.createModuleContext('entry').resourceManager;
      const testManager: resourceManager.ResourceManager =
        applicationContext.createModuleContext('entry_test').resourceManager;
      const fixtureBytes = await testManager.getRawFileContent(dogFixturePath);
      expect(fixtureBytes.byteLength).assertEqual(83281);
      const fixturePath = await cacheBytes(applicationContext.cacheDir, 'object-detection-dog.jpg', fixtureBytes);
      const preprocessor = new HarmonyObjectDetectionInputPreprocessor();
      const input = await preprocessor.createInput(fixturePath);
      expect(input.imageWidth).assertEqual(700);
      expect(input.imageHeight).assertEqual(577);

      const modelBytes = await mainManager.getRawFileContent(objectDetectionModelRawfilePath);
      await objectDetectionMnn.loadModel(modelBytes);
      try {
        let baselineSignature: string = '';
        for (let runIndex: number = 0; runIndex < 3; runIndex++) {
          const output = await objectDetectionMnn.predict(new Float32Array(input.inputBuffer));
          const detections = decodeNanoDetObjectDetections(output, input.imageWidth, input.imageHeight);
          console.info(`object-detection-dog-run=${runIndex} top=${topDetectionSummary(detections)}`);
          let bestDog: ObjectDetection | undefined = undefined;
          for (let index: number = 0; index < detections.length; index++) {
            if (detections[index].labelId === 17 &&
              (bestDog === undefined || detections[index].score > bestDog.score)) {
              bestDog = detections[index];
            }
          }
          expect(bestDog !== undefined).assertTrue();
          const dog = bestDog!;
          const iou = detectionIou(dog, 58, 37, 650, 552);
          const signature = `${dog.score.toFixed(6)}:${dog.left.toFixed(4)}:${dog.top.toFixed(4)}:` +
            `${dog.right.toFixed(4)}:${dog.bottom.toFixed(4)}`;
          console.info(`object-detection-dog-run=${runIndex} score=${dog.score} iou=${iou} box=${dog.left},${dog.top},${dog.right},${dog.bottom}`);
          if (runIndex === 0) {
            baselineSignature = signature;
          } else {
            expect(signature).assertEqual(baselineSignature);
          }
          expect(dog.score >= 0.65).assertTrue();
          expect(iou >= 0.85).assertTrue();
        }
      } finally {
        objectDetectionMnn.release();
      }
    });

    it('returnsNoDetectionForAProgrammaticSolidGrayImageThroughTheProductionPreprocessor', 0, async () => {
      const applicationContext = abilityDelegatorRegistry.getAbilityDelegator()
        .getAppContext()
        .getApplicationContext();
      const mainManager = applicationContext.createModuleContext('entry').resourceManager;
      const grayPath = await cacheBytes(applicationContext.cacheDir, 'object-detection-gray.jpg', await grayJpegBytes());
      const input = await new HarmonyObjectDetectionInputPreprocessor().createInput(grayPath);
      await objectDetectionMnn.loadModel(await mainManager.getRawFileContent(objectDetectionModelRawfilePath));
      try {
        const output = await objectDetectionMnn.predict(new Float32Array(input.inputBuffer));
        const detections = decodeNanoDetObjectDetections(output, input.imageWidth, input.imageHeight);
        console.info(`object-detection-gray-count=${detections.length} top=${topDetectionSummary(detections)}`);
        expect(detections.length).assertEqual(0);
      } finally {
        objectDetectionMnn.release();
      }
    });
  });
}
