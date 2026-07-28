import { fileIo, hash } from '@kit.CoreFileKit';
import { image } from '@kit.ImageKit';
import { abilityDelegatorRegistry } from '@kit.TestKit';
import { describe, it, expect } from '@ohos/hypium';
import {
  CustomModelSelectedFileRunner,
  CustomModelService,
  customModelInputFloatCount,
  validateCustomModelContent
} from '../../../main/ets/services/ai/CustomModelService';
import { HarmonyCustomModelInputPreprocessor } from
  '../../../main/ets/services/ai/HarmonyCustomModelInputPreprocessor';
import { RuntimeModelFileCacheService } from '../../../main/ets/services/picker/ModelFileCacheService';
import { AppRoute } from '../../../main/ets/app/AppRoutes';
import { FileUriContentReader } from '../../../main/ets/services/ai/FileUriContentReader';
import { CustomModelPackageService } from '../../../main/ets/services/ai/CustomModelPackageService';
import { CustomModelPackageRunner } from '../../../main/ets/services/ai/CustomModelPackageRunner';

const primaryModelPath: string = 'model/custom_channel_mean.ms';
const invertedModelPath: string = 'model/custom_channel_mean_inverted.ms';
const nonFiniteModelPath: string = 'model/custom_channel_mean_non_finite.ms';

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

async function solidPngBytes(red: number, green: number, blue: number): Promise<Uint8Array> {
  const width: number = 224;
  const height: number = 224;
  const rgba = new Uint8Array(width * height * 4);
  for (let offset: number = 0; offset < rgba.length; offset += 4) {
    rgba[offset] = red;
    rgba[offset + 1] = green;
    rgba[offset + 2] = blue;
    rgba[offset + 3] = 255;
  }
  const pixelMap = await image.createPixelMap(rgba.buffer as ArrayBuffer, {
    size: { width: width, height: height },
    srcPixelFormat: image.PixelMapFormat.RGBA_8888,
    pixelFormat: image.PixelMapFormat.RGBA_8888
  });
  const packer = image.createImagePacker();
  try {
    return new Uint8Array(await packer.packToData(pixelMap, { format: 'image/png', quality: 100 }));
  } finally {
    await packer.release();
    await pixelMap.release();
  }
}

function meanAbsoluteDifference(left: Array<number>, right: Array<number>): number {
  let sum = 0;
  for (let index = 0; index < left.length; index++) {
    sum += Math.abs(left[index] - right[index]);
  }
  return left.length > 0 ? sum / left.length : 0;
}

function maxAbsoluteDifference(left: Array<number>, right: Array<number>): number {
  let maximum = 0;
  for (let index = 0; index < left.length; index++) {
    maximum = Math.max(maximum, Math.abs(left[index] - right[index]));
  }
  return maximum;
}

function outputIsFiniteUnitRgb(output: Array<number>): boolean {
  if (output.length !== 3) {
    return false;
  }
  for (let index = 0; index < output.length; index++) {
    if (!Number.isFinite(output[index]) || output[index] < 0 || output[index] > 1) {
      return false;
    }
  }
  return true;
}

export default function customModelNativeTest() {
  describe('CustomModelNativeTest', () => {
    it('readsLargeCoreFileKitContentExactlyAcrossTheOneMiBBoundary', 0, async () => {
      const applicationContext = abilityDelegatorRegistry.getAbilityDelegator()
        .getAppContext()
        .getApplicationContext();
      const byteCount = 1024 * 1024 + 37;
      const expected = new Uint8Array(byteCount);
      for (let index = 0; index < expected.length; index++) {
        expected[index] = (index * 31 + 7) % 256;
      }
      const sourcePath = await cacheBytes(applicationContext.cacheDir, 'custom-model-exact-read-source.bin', expected);

      const actual = await new FileUriContentReader().readFileContent(sourcePath);

      let mismatches = 0;
      for (let index = 0; index < expected.length; index++) {
        if (actual[index] !== expected[index]) {
          mismatches++;
        }
      }
      const copyPath = await cacheBytes(applicationContext.cacheDir, 'custom-model-exact-read-copy.bin', actual);
      const sourceSha = await hash.hash(sourcePath, 'sha256');
      const copySha = await hash.hash(copyPath, 'sha256');
      const expectedSha = 'ded6bc08234e6a4aece8ff14ffc2ac1f662602eaed4472146a5a9ac1a738a4a8';
      expect(actual.length).assertEqual(expected.length);
      expect(mismatches).assertEqual(0);
      expect(sourceSha.toLowerCase()).assertEqual(expectedSha);
      expect(copySha.toLowerCase()).assertEqual(expectedSha);
      console.info(`custom-model-core-file exactReadBytes=${actual.length} sourceSha=${sourceSha} copySha=${copySha}`);
    });

    it('validatesCachesReloadsAndRunsInputDependentCustomModels', 0, async () => {
      const applicationContext = abilityDelegatorRegistry.getAbilityDelegator()
        .getAppContext()
        .getApplicationContext();
      const mainManager = applicationContext.createModuleContext('entry').resourceManager;
      const cacheDir = applicationContext.cacheDir;
      const primary = await mainManager.getRawFileContent(primaryModelPath);
      const inverted = await mainManager.getRawFileContent(invertedModelPath);
      const nonFinite = await mainManager.getRawFileContent(nonFiniteModelPath);
      expect(primary.byteLength).assertEqual(600);
      expect(inverted.byteLength).assertEqual(800);
      expect(nonFinite.byteLength).assertEqual(800);
      expect(await validateCustomModelContent(primary)).assertTrue();
      expect(await validateCustomModelContent(inverted)).assertTrue();
      expect(await validateCustomModelContent(nonFinite)).assertFalse();

      const pickedPrimary = await cacheBytes(cacheDir, 'picked-channel-mean.ms', primary);
      const pickedInverted = await cacheBytes(cacheDir, 'picked-channel-mean-inverted.ms', inverted);
      const pickedNonFinite = await cacheBytes(cacheDir, 'picked-channel-mean-non-finite.ms', nonFinite);
      const redImage = await cacheBytes(cacheDir, 'custom-model-red.png', await solidPngBytes(255, 0, 0));
      const blueImage = await cacheBytes(cacheDir, 'custom-model-blue.png', await solidPngBytes(0, 0, 255));
      const cacheService = new RuntimeModelFileCacheService();
      const primaryCache = await cacheService.cachePickedModelFile(
        pickedPrimary,
        cacheDir,
        AppRoute.CUSTOM_MODEL.name,
        'modelFile'
      );
      expect(primaryCache.ok).assertTrue();

      const service = new CustomModelService({
        preprocessor: new HarmonyCustomModelInputPreprocessor(),
        tensorRunner: new CustomModelSelectedFileRunner()
      });
      let ticks = 0;
      const timer = setInterval(() => ticks++, 1);
      const redResult = await service.run(primaryCache.uri, redImage);
      const blueResult = await service.run(primaryCache.uri, blueImage);
      clearInterval(timer);
      expect(redResult.ok).assertTrue();
      expect(blueResult.ok).assertTrue();
      expect(outputIsFiniteUnitRgb(redResult.output)).assertTrue();
      expect(outputIsFiniteUnitRgb(blueResult.output)).assertTrue();
      const mae = meanAbsoluteDifference(redResult.output, blueResult.output);
      const maxAbs = maxAbsoluteDifference(redResult.output, blueResult.output);
      expect(mae > 0.5).assertTrue();
      expect(maxAbs > 0.9).assertTrue();
      expect(ticks > 0).assertTrue();

      const rejectedCache = await cacheService.cachePickedModelFile(
        pickedNonFinite,
        cacheDir,
        AppRoute.CUSTOM_MODEL.name,
        'modelFile'
      );
      expect(rejectedCache.ok).assertFalse();
      const afterRejectedReplacement = await service.run(primaryCache.uri, redImage);
      expect(afterRejectedReplacement.ok).assertTrue();
      expect(maxAbsoluteDifference(afterRejectedReplacement.output, redResult.output) < 0.001).assertTrue();

      const invertedCache = await cacheService.cachePickedModelFile(
        pickedInverted,
        cacheDir,
        AppRoute.CUSTOM_MODEL.name,
        'modelFile'
      );
      expect(invertedCache.ok).assertTrue();
      expect(invertedCache.uri).assertEqual(primaryCache.uri);
      const invertedRed = await service.run(invertedCache.uri, redImage);
      expect(invertedRed.ok).assertTrue();
      expect(invertedRed.output.length).assertEqual(3);
      for (let index = 0; index < invertedRed.output.length; index++) {
        expect(Math.abs(redResult.output[index] + invertedRed.output[index] - 1) < 0.001).assertTrue();
      }

      const recoveredCache = await cacheService.cachePickedModelFile(
        pickedPrimary,
        cacheDir,
        AppRoute.CUSTOM_MODEL.name,
        'modelFile'
      );
      expect(recoveredCache.ok).assertTrue();
      const recoveredBlue = await service.run(recoveredCache.uri, blueImage);
      expect(recoveredBlue.ok).assertTrue();
      expect(maxAbsoluteDifference(recoveredBlue.output, blueResult.output) < 0.001).assertTrue();
      console.info(
        `custom-model-device inputFloats=${customModelInputFloatCount} red=${redResult.output.join(',')} ` +
        `blue=${blueResult.output.join(',')} mae=${mae} maxAbs=${maxAbs} ticks=${ticks} ` +
        `sameUriComplement=${invertedRed.output.join(',')} rejectedNonFinite=${!rejectedCache.ok}`
      );
    });

    it('importsAndRunsImageAndTextModelPackagesWithoutRandomOutput', 0, async () => {
      const applicationContext = abilityDelegatorRegistry.getAbilityDelegator()
        .getAppContext()
        .getApplicationContext();
      const mainManager = applicationContext.createModuleContext('entry').resourceManager;
      const cacheDir = `${applicationContext.cacheDir}/package-native-test-${Date.now()}`;
      await fileIo.mkdir(cacheDir, true);
      const imageZip = await mainManager.getRawFileContent('model/custom_image_package.zip');
      const textZip = await mainManager.getRawFileContent('model/custom_text_package.zip');
      const imageZipPath = await cacheBytes(cacheDir, 'image.zip', imageZip);
      const textZipPath = await cacheBytes(cacheDir, 'text.zip', textZip);
      const redImage = await cacheBytes(cacheDir, 'package-red.png', await solidPngBytes(255, 0, 0));
      const blueImage = await cacheBytes(cacheDir, 'package-blue.png', await solidPngBytes(0, 0, 255));
      const packageService = new CustomModelPackageService();
      const runner = new CustomModelPackageRunner(new HarmonyCustomModelInputPreprocessor());

      const imageImport = await packageService.importPackage(imageZipPath, cacheDir);
      expect(imageImport.ok).assertTrue();
      expect(imageImport.descriptor?.inputKind).assertEqual('image');
      const red = await runner.run(imageImport.descriptor!.modelPath, redImage, '');
      const blue = await runner.run(imageImport.descriptor!.modelPath, blueImage, '');
      expect(red.ok).assertTrue();
      expect(blue.ok).assertTrue();
      expect(maxAbsoluteDifference(red.output, blue.output) > 0.9).assertTrue();
      expect(red.displayText === blue.displayText).assertFalse();

      const textImport = await packageService.importPackage(textZipPath, cacheDir);
      expect(textImport.ok).assertTrue();
      expect(textImport.descriptor?.inputKind).assertEqual('text');
      const firstText = await runner.run(textImport.descriptor!.modelPath, '', 'hi');
      const secondText = await runner.run(textImport.descriptor!.modelPath, '', 'bye');
      expect(firstText.ok).assertTrue();
      expect(secondText.ok).assertTrue();
      expect(firstText.displayText === secondText.displayText).assertFalse();

      const corrupt = imageZip.slice();
      corrupt[0] = 0;
      const corruptPath = await cacheBytes(cacheDir, 'corrupt.zip', corrupt);
      expect((await packageService.importPackage(corruptPath, cacheDir)).ok).assertFalse();
      expect((await packageService.loadCurrentPackage(cacheDir))?.manifest.name)
        .assertEqual(textImport.descriptor!.manifest.name);
    });
  });
}
