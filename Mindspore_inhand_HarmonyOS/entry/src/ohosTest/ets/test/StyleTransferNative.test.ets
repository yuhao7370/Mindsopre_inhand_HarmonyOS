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

function requireByteRange(bytes: Uint8Array, offset: number, length: number): void {
  if (offset < 0 || length < 0 || offset > bytes.length - length) {
    throw new Error('Malformed MNN FlatBuffer fixture.');
  }
}

function uint16(bytes: Uint8Array, offset: number): number {
  requireByteRange(bytes, offset, 2);
  return bytes[offset] | (bytes[offset + 1] << 8);
}

function uint32(bytes: Uint8Array, offset: number): number {
  requireByteRange(bytes, offset, 4);
  return (bytes[offset] | (bytes[offset + 1] << 8) | (bytes[offset + 2] << 16) |
    (bytes[offset + 3] << 24)) >>> 0;
}

function int32(bytes: Uint8Array, offset: number): number {
  const unsigned = uint32(bytes, offset);
  return unsigned > 0x7FFFFFFF ? unsigned - 0x100000000 : unsigned;
}

function tableFieldOffset(bytes: Uint8Array, tableOffset: number, fieldIndex: number): number {
  requireByteRange(bytes, tableOffset, 4);
  const vtableDistance = int32(bytes, tableOffset);
  if (vtableDistance === 0) {
    throw new Error('Malformed MNN FlatBuffer table.');
  }
  const vtableOffset = tableOffset - vtableDistance;
  const vtableSize = uint16(bytes, vtableOffset);
  if (vtableSize < 4 || vtableSize % 2 !== 0) {
    throw new Error('Malformed MNN FlatBuffer vtable.');
  }
  requireByteRange(bytes, vtableOffset, vtableSize);
  const fieldEntry = vtableOffset + 4 + fieldIndex * 2;
  return fieldEntry + 1 < vtableOffset + vtableSize ? uint16(bytes, fieldEntry) : 0;
}

function mnnModelWithCaffeTensorLayout(model: Uint8Array): Uint8Array {
  const fixture = model.slice();
  const netOffset = uint32(fixture, 0);
  const opListFieldOffset = tableFieldOffset(fixture, netOffset, 3);
  if (opListFieldOffset === 0) {
    throw new Error('MNN fixture does not contain an op list.');
  }
  const opListField = netOffset + opListFieldOffset;
  const opListOffset = opListField + uint32(fixture, opListField);
  const opCount = uint32(fixture, opListOffset);
  requireByteRange(fixture, opListOffset + 4, opCount * 4);
  if (opCount === 0) {
    throw new Error('MNN fixture op list is empty.');
  }
  let mutatedInputCount: number = 0;
  for (let index: number = 0; index < opCount; index++) {
    const opEntry = opListOffset + 4 + index * 4;
    const opOffset = opEntry + uint32(fixture, opEntry);
    const mainTypeField = tableFieldOffset(fixture, opOffset, 1);
    if (mainTypeField === 0 || fixture[opOffset + mainTypeField] !== 21) {
      continue;
    }
    const mainField = tableFieldOffset(fixture, opOffset, 2);
    if (mainField === 0) {
      throw new Error('MNN Input op does not contain a parameter table.');
    }
    const mainFieldOffset = opOffset + mainField;
    const inputTableOffset = mainFieldOffset + uint32(fixture, mainFieldOffset);
    const formatField = tableFieldOffset(fixture, inputTableOffset, 2);
    if (formatField === 0) {
      throw new Error('MNN Input op omits dformat.');
    }
    requireByteRange(fixture, inputTableOffset + formatField, 1);
    if (fixture[inputTableOffset + formatField] !== 1) {
      throw new Error('MNN Input tensor is not NHWC before mutation.');
    }
    fixture[inputTableOffset + formatField] = 0;
    mutatedInputCount++;
  }
  if (mutatedInputCount === 0) {
    throw new Error('MNN fixture does not contain an Input op.');
  }
  let changedByteCount: number = 0;
  for (let index: number = 0; index < fixture.length; index++) {
    if (fixture[index] === model[index]) {
      continue;
    }
    if (model[index] !== 1 || fixture[index] !== 0) {
      throw new Error('MNN fixture mutation changed data outside NHWC dformat fields.');
    }
    changedByteCount++;
  }
  if (changedByteCount !== mutatedInputCount) {
    throw new Error('MNN fixture mutation count does not match Input op count.');
  }
  return fixture;
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
      expect(await styleTransferMnn.validateModelPair(predictBytes, transferBytes)).assertTrue();
      expect(await styleTransferMnn.validatePredictModel(mnnModelWithCaffeTensorLayout(predictBytes))).assertFalse();
      expect(await styleTransferMnn.validateTransferModel(mnnModelWithCaffeTensorLayout(transferBytes))).assertFalse();
      expect(await styleTransferMnn.validatePredictModel(new Uint8Array([1, 2, 3, 4]))).assertFalse();
      expect(await styleTransferMnn.validateTransferModel(new Uint8Array([1, 2, 3, 4]))).assertFalse();
      expect(await styleTransferMnn.validateModelPair(
        predictBytes,
        new Uint8Array([1, 2, 3, 4])
      )).assertFalse();

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

      expect(await styleTransferMnn.validateModelPair(
        predictBytes,
        new Uint8Array([1, 2, 3, 4])
      )).assertFalse();
      const pairValidationNative = await styleTransferMnn.run(
        new Float32Array(style0Input.styleInputBuffer),
        new Float32Array(style0Input.contentInputBuffer)
      );
      const pairValidationRecovered: StyleTransferNativeOutput = new TestStyleTransferNativeOutput(
        pairValidationNative.output,
        pairValidationNative.predictMs,
        pairValidationNative.transferMs
      );
      expect(pairValidationRecovered.output.length).assertEqual(first.output.length);
      expect(outputContractValid(pairValidationRecovered.output)).assertTrue();

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
