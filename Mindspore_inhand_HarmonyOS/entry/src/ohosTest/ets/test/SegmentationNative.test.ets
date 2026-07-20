import { fileIo } from '@kit.CoreFileKit';
import { image } from '@kit.ImageKit';
import { resourceManager } from '@kit.LocalizationKit';
import { abilityDelegatorRegistry } from '@kit.TestKit';
import { describe, it, expect } from '@ohos/hypium';
import { AppRoute } from '../../../main/ets/app/AppRoutes';
import { workflowForRoute } from '../../../main/ets/features/runtime/FeatureWorkflowCatalog';
import {
  createHarmonySegmentationService,
  HarmonyRawfileContentReader
} from '../../../main/ets/services/ai/ImageClassificationRuntimeFactory';
import { SegmentationResult } from '../../../main/ets/services/ai/SegmentationService';

const personFixturePath: string = 'posenet/skeleton_image.JPG';
const noPersonFixturePath: string = 'portrait/portrait1.jpg';
const foregroundChannelThreshold: number = 245;
const foregroundAlphaThreshold: number = 127;
const minimumForegroundIou: number = 0.72;

async function cacheFixture(
  manager: resourceManager.ResourceManager,
  cacheDir: string,
  rawfilePath: string,
  fileName: string
): Promise<string> {
  const bytes = await manager.getRawFileContent(rawfilePath);
  const path = `${cacheDir}/${fileName}`;
  const file = await fileIo.open(
    path,
    fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC
  );
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

async function decodedRgba(
  manager: resourceManager.ResourceManager,
  rawfilePath: string,
  width: number,
  height: number
): Promise<Uint8Array> {
  const encoded = await manager.getRawFileContent(rawfilePath);
  const encodedBuffer = new ArrayBuffer(encoded.byteLength);
  new Uint8Array(encodedBuffer).set(encoded);
  const source = image.createImageSource(encodedBuffer);
  try {
    const pixelMap = await source.createPixelMap({
      desiredSize: { width: width, height: height },
      desiredPixelFormat: image.PixelMapFormat.RGBA_8888
    });
    try {
      const rgba = new ArrayBuffer(width * height * 4);
      await pixelMap.readPixelsToBuffer(rgba);
      return new Uint8Array(rgba);
    } finally {
      await pixelMap.release();
    }
  } finally {
    await source.release();
  }
}

function foregroundIou(expectedRgba: Uint8Array, actualForegroundRgba: Uint8Array): number {
  let intersection: number = 0;
  let union: number = 0;
  for (let offset = 0; offset + 3 < expectedRgba.length; offset += 4) {
    const expectedForeground = expectedRgba[offset] < foregroundChannelThreshold ||
      expectedRgba[offset + 1] < foregroundChannelThreshold ||
      expectedRgba[offset + 2] < foregroundChannelThreshold;
    const actualForeground = actualForegroundRgba[offset + 3] > foregroundAlphaThreshold;
    if (expectedForeground && actualForeground) {
      intersection++;
    }
    if (expectedForeground || actualForeground) {
      union++;
    }
  }
  return union === 0 ? 0 : intersection / union;
}

export default function segmentationNativeTest() {
  describe('SegmentationNativeTest', () => {
    it('producesARealForegroundAtDocumentedIouForTheLabeledPortrait', 0, async () => {
      const applicationContext = abilityDelegatorRegistry.getAbilityDelegator()
        .getAppContext()
        .getApplicationContext();
      const mainManager = applicationContext.createModuleContext('entry').resourceManager;
      const workflow = workflowForRoute(AppRoute.SEGMENTATION_STILL.name)!;
      const fixturePath = await cacheFixture(
        mainManager,
        applicationContext.cacheDir,
        personFixturePath,
        'segmentation-person.JPG'
      );
      const resources = new HarmonyRawfileContentReader(mainManager);
      const service = createHarmonySegmentationService({ resourceManager: resources }, workflow);

      const result: SegmentationResult = await service.segmentPerson(fixturePath);
      expect(result.ok).assertTrue();
      expect(result.foregroundAvailable).assertTrue();
      const width = result.foregroundImageWidth ?? 0;
      const height = result.foregroundImageHeight ?? 0;
      const foreground = new Uint8Array(result.foregroundImageRgba ?? new ArrayBuffer(0));
      expect(width > 0 && height > 0).assertTrue();
      expect(foreground.length).assertEqual(width * height * 4);
      const expected = await decodedRgba(mainManager, personFixturePath, width, height);
      const iou = foregroundIou(expected, foreground);
      console.info(`segmentation-person-iou=${iou} threshold=${minimumForegroundIou} size=${width}x${height}`);
      expect(iou >= minimumForegroundIou).assertTrue();
    });

    it('rejectsTheMateriallyDifferentNoPersonFixture', 0, async () => {
      const applicationContext = abilityDelegatorRegistry.getAbilityDelegator()
        .getAppContext()
        .getApplicationContext();
      const mainManager = applicationContext.createModuleContext('entry').resourceManager;
      const workflow = workflowForRoute(AppRoute.PORTRAIT_SEGMENTATION.name)!;
      const fixturePath = await cacheFixture(
        mainManager,
        applicationContext.cacheDir,
        noPersonFixturePath,
        'segmentation-no-person.jpg'
      );
      const resources = new HarmonyRawfileContentReader(mainManager);
      const service = createHarmonySegmentationService({ resourceManager: resources }, workflow);

      const result: SegmentationResult = await service.segmentPerson(fixturePath);
      console.info(`segmentation-no-person=ok=${result.ok} subjects=${result.subjectCount} foreground=${result.foregroundAvailable}`);
      expect(result.ok).assertFalse();
      expect(result.subjectCount).assertEqual(0);
      expect(result.foregroundAvailable).assertFalse();
    });
  });
}
