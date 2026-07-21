import { fileIo } from '@kit.CoreFileKit';
import { image } from '@kit.ImageKit';
import { abilityDelegatorRegistry } from '@kit.TestKit';
import { describe, it, expect } from '@ohos/hypium';
import styleTransferMnn from 'libstyle_transfer_mnn.so';
import { HarmonyStyleTransferInputPreprocessor } from
  '../../../main/ets/services/ai/HarmonyStyleTransferInputPreprocessor';
import { HarmonyRawfileContentReader } from '../../../main/ets/services/ai/ImageClassificationRuntimeFactory';
import {
  builtInStyleTransferStyles,
  builtInStyleTransferUri,
  LocalMnnStyleTransferTensorRunner,
  stylePredictModelRawfilePath,
  styleTransferModelRawfilePath,
  StyleTransferInput,
  StyleTransferNativeOutput,
  StyleTransferTensorOutput
} from '../../../main/ets/services/ai/StyleTransferService';

class TestStyleTransferNativeOutput implements StyleTransferNativeOutput {
  readonly output: Float32Array;
  readonly predictMs: number;
  readonly transferMs: number;

  constructor(output: Float32Array, predictMs: number, transferMs: number) {
    this.output = output;
    this.predictMs = predictMs;
    this.transferMs = transferMs;
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

async function geometricContentJpeg(): Promise<Uint8Array> {
  const width: number = 640;
  const height: number = 360;
  const rgba = new Uint8Array(width * height * 4);
  for (let y: number = 0; y < height; y++) {
    for (let x: number = 0; x < width; x++) {
      const offset = (y * width + x) * 4;
      const checker = (Math.trunc(x / 48) + Math.trunc(y / 48)) % 2 === 0;
      rgba[offset] = checker ? Math.trunc(x * 255 / (width - 1)) : 30;
      rgba[offset + 1] = checker ? 50 : Math.trunc(y * 255 / (height - 1));
      rgba[offset + 2] = checker ? 210 : 245;
      rgba[offset + 3] = 255;
    }
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

function outputContractValid(output: Float32Array): boolean {
  for (let index: number = 0; index < output.length; index++) {
    if (!Number.isFinite(output[index]) || output[index] < 0 || output[index] > 1) {
      return false;
    }
  }
  return true;
}

function meanAbsoluteDifference(left: Float32Array, right: Float32Array): number {
  expect(left.length).assertEqual(right.length);
  let difference: number = 0;
  for (let index: number = 0; index < left.length; index++) {
    difference += Math.abs(left[index] - right[index]);
  }
  return difference / left.length;
}

function changedPixelRatio(left: Float32Array, right: Float32Array): number {
  let changed: number = 0;
  const pixels = left.length / 3;
  for (let offset: number = 0; offset < left.length; offset += 3) {
    if (Math.abs(left[offset] - right[offset]) > 1 / 255 ||
      Math.abs(left[offset + 1] - right[offset + 1]) > 1 / 255 ||
      Math.abs(left[offset + 2] - right[offset + 2]) > 1 / 255) {
      changed++;
    }
  }
  return changed / pixels;
}

export default function styleTransferNativeTest() {
  describe('StyleTransferNativeTest', () => {
    it('runsTwoLicensedStylesAsynchronouslyAndRecoversFromRejectedPairLoadOnApi24', 0, async () => {
      const applicationContext = abilityDelegatorRegistry.getAbilityDelegator()
        .getAppContext()
        .getApplicationContext();
      const mainManager = applicationContext.createModuleContext('entry').resourceManager;
      const resources = new HarmonyRawfileContentReader(mainManager);
      const predictBytes = await mainManager.getRawFileContent(stylePredictModelRawfilePath);
      const transferBytes = await mainManager.getRawFileContent(styleTransferModelRawfilePath);

      expect(await styleTransferMnn.validatePredictModel(predictBytes)).assertTrue();
      expect(await styleTransferMnn.validateTransferModel(transferBytes)).assertTrue();
      expect(await styleTransferMnn.validatePredictModel(new Uint8Array([1, 2, 3, 4]))).assertFalse();
      expect(await styleTransferMnn.validateTransferModel(new Uint8Array([1, 2, 3, 4]))).assertFalse();

      const contentPath = `${applicationContext.cacheDir}/style-transfer-geometric.jpg`;
      await writeBytes(contentPath, await geometricContentJpeg());
      const preprocessor = new HarmonyStyleTransferInputPreprocessor({ resourceManager: resources });
      const style0Input: StyleTransferInput = await preprocessor.createInput(
        contentPath,
        builtInStyleTransferUri(builtInStyleTransferStyles[0])
      );
      const style1Input: StyleTransferInput = await preprocessor.createInput(
        contentPath,
        builtInStyleTransferUri(builtInStyleTransferStyles[1])
      );
      expect(style0Input.contentImageWidth).assertEqual(640);
      expect(style0Input.contentImageHeight).assertEqual(360);

      const runner = new LocalMnnStyleTransferTensorRunner({
        resourceManager: resources,
        predictModelRawfilePath: stylePredictModelRawfilePath,
        transferModelRawfilePath: styleTransferModelRawfilePath
      });
      let timerTicks: number = 0;
      const timerId: number = setInterval((): void => {
        timerTicks++;
      }, 50);
      const first: StyleTransferTensorOutput = await runner.runStyleTransfer(style0Input);
      clearInterval(timerId);
      expect(timerTicks > 0).assertTrue();
      const second: StyleTransferTensorOutput = await runner.runStyleTransfer(style1Input);

      expect(first.output.length).assertEqual(384 * 384 * 3);
      expect(second.output.length).assertEqual(first.output.length);
      expect(outputContractValid(first.output)).assertTrue();
      expect(outputContractValid(second.output)).assertTrue();
      const content = new Float32Array(style0Input.contentInputBuffer);
      const contentDifference0 = meanAbsoluteDifference(first.output, content);
      const contentDifference1 = meanAbsoluteDifference(second.output, content);
      const styleDifference = meanAbsoluteDifference(first.output, second.output);
      const styleChangedRatio = changedPixelRatio(first.output, second.output);
      console.info(`style-transfer-api24 ticks=${timerTicks} predict=${first.predictMs}ms transfer=${first.transferMs}ms ` +
        `content-mae=${contentDifference0},${contentDifference1} style-mae=${styleDifference} changed=${styleChangedRatio}`);
      expect(contentDifference0 > 0.05).assertTrue();
      expect(contentDifference1 > 0.05).assertTrue();
      expect(styleDifference > 0.02).assertTrue();
      expect(styleChangedRatio > 0.5).assertTrue();

      let rejected: boolean = false;
      try {
        await styleTransferMnn.loadModels(predictBytes, new Uint8Array([1, 2, 3, 4]));
      } catch (_) {
        rejected = true;
      }
      expect(rejected).assertTrue();
      const nativeRecovered = await styleTransferMnn.run(
        new Float32Array(style0Input.styleInputBuffer),
        new Float32Array(style0Input.contentInputBuffer)
      );
      const recovered: StyleTransferNativeOutput = new TestStyleTransferNativeOutput(
        nativeRecovered.output,
        nativeRecovered.predictMs,
        nativeRecovered.transferMs
      );
      expect(recovered.output.length).assertEqual(first.output.length);
      expect(outputContractValid(recovered.output)).assertTrue();
      styleTransferMnn.release();
    });
  });
}
