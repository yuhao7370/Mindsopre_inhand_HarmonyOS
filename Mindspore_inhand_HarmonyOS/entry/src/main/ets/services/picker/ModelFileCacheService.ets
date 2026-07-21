import { fileIo } from '@kit.CoreFileKit';
import { mindSporeLite } from '@kit.MindSporeLiteKit';
import { AppRoute } from '../../app/AppRoutes';
import { AppStringKey } from '../../common/i18n/AppStrings';
import { FeatureInputKind } from '../../features/runtime/FeatureWorkflowCatalog';
import { FileUriContentReader } from '../ai/FileUriContentReader';
import { validateCustomModelContent } from '../ai/CustomModelService';
import { validateObjectDetectionModelContent } from '../ai/ObjectDetectionService';
import {
  stylePredictModelRawfilePath,
  styleTransferModelRawfilePath,
  validateStyleTransferModelPairContent,
  validateStyleTransferPredictModelContent,
  validateStyleTransferTransferModelContent
} from '../ai/StyleTransferService';
import {
  mindSporeLiteCpuContext,
  RawfileContentReader,
  rawfileContentToArrayBuffer
} from '../ai/MindSporeLiteModelRunner';

export interface ModelFileCacheResult {
  readonly ok: boolean;
  readonly uri: string;
  readonly messageKey: AppStringKey;
}

export interface CachedModelFileInputState {
  readonly modelInputUri: string;
  readonly stylePredictModelInputUri: string;
  readonly styleTransferModelInputUri: string;
}

export interface CachedModelFileExistenceChecker {
  modelFileExists(path: string): Promise<boolean>;
}

export interface ModelFileCacheWriter {
  writeModelFile(
    cacheDir: string,
    fileName: string,
    content: Uint8Array,
    requestToken: number,
    isCurrent: () => boolean
  ): Promise<string | undefined>;
}

export interface ModelFileCacheFileBackend {
  open(path: string, mode: number): Promise<fileIo.File>;
  write(file: fileIo.File, content: Uint8Array): Promise<number>;
  close(file: fileIo.File): Promise<void>;
  replace(sourcePath: string, targetPath: string): void;
  remove(path: string): void;
}

export interface ModelFileCompatibilityChecker {
  isCompatible(
    routeName: string,
    inputKind: FeatureInputKind,
    cachedUri: string,
    content: Uint8Array
  ): Promise<boolean>;
}

export interface ModelFileTensorMetadata {
  readonly shape: Array<number>;
  readonly dtype: mindSporeLite.DataType;
  readonly format: mindSporeLite.Format;
  readonly elementNum: number;
  readonly dataSize: number;
}

export interface ModelFileCompatibilityLoader {
  loadModel(content: Uint8Array): Promise<Array<ModelFileTensorMetadata>>;
}

export interface ObjectDetectionModelContentValidator {
  validate(content: Uint8Array): Promise<boolean>;
}

export interface CustomModelContentValidator {
  validate(content: Uint8Array): Promise<boolean>;
}

export class NativeCustomModelContentValidator implements CustomModelContentValidator {
  async validate(content: Uint8Array): Promise<boolean> {
    return await validateCustomModelContent(content);
  }
}

export interface StyleTransferModelContentValidator {
  validatePredict(content: Uint8Array): Promise<boolean>;
  validateTransfer(content: Uint8Array): Promise<boolean>;
  validatePair(predictContent: Uint8Array, transferContent: Uint8Array): Promise<boolean>;
}

export interface StyleTransferModelPairCompatibilityChecker {
  isCompatible(inputKind: FeatureInputKind, cacheDir: string, candidate: Uint8Array): Promise<boolean>;
}

export class NativeStyleTransferModelContentValidator implements StyleTransferModelContentValidator {
  async validatePredict(content: Uint8Array): Promise<boolean> {
    return await validateStyleTransferPredictModelContent(content);
  }

  async validateTransfer(content: Uint8Array): Promise<boolean> {
    return await validateStyleTransferTransferModelContent(content);
  }

  async validatePair(predictContent: Uint8Array, transferContent: Uint8Array): Promise<boolean> {
    return await validateStyleTransferModelPairContent(predictContent, transferContent);
  }
}

export class NativeStyleTransferModelPairCompatibilityChecker implements
  StyleTransferModelPairCompatibilityChecker {
  private readonly resourceManager: RawfileContentReader;
  private readonly fileReader: FileUriContentReader;
  private readonly existenceChecker: CachedModelFileExistenceChecker;
  private readonly validator: StyleTransferModelContentValidator;

  constructor(
    resourceManager: RawfileContentReader,
    fileReader: FileUriContentReader = new FileUriContentReader(),
    existenceChecker: CachedModelFileExistenceChecker = new HarmonyCachedModelFileExistenceChecker(),
    validator: StyleTransferModelContentValidator = new NativeStyleTransferModelContentValidator()
  ) {
    this.resourceManager = resourceManager;
    this.fileReader = fileReader;
    this.existenceChecker = existenceChecker;
    this.validator = validator;
  }

  async isCompatible(
    inputKind: FeatureInputKind,
    cacheDir: string,
    candidate: Uint8Array
  ): Promise<boolean> {
    try {
      if (inputKind === 'stylePredictModelFile') {
        const transfer = await this.otherStageContent(
          cacheDir,
          'custom_transfer.mnn',
          styleTransferModelRawfilePath
        );
        return await this.validator.validatePair(candidate, transfer);
      }
      if (inputKind === 'styleTransferModelFile') {
        const predict = await this.otherStageContent(
          cacheDir,
          'custom_predict.mnn',
          stylePredictModelRawfilePath
        );
        return await this.validator.validatePair(predict, candidate);
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  private async otherStageContent(cacheDir: string, fileName: string, rawfilePath: string): Promise<Uint8Array> {
    const stablePath = modelFileCachePath(cacheDir, fileName);
    if (await this.existenceChecker.modelFileExists(stablePath)) {
      return await this.fileReader.readFileContent(stablePath);
    }
    return await this.resourceManager.getRawFileContent(rawfilePath);
  }
}

export class NativeObjectDetectionModelContentValidator implements ObjectDetectionModelContentValidator {
  async validate(content: Uint8Array): Promise<boolean> {
    return await validateObjectDetectionModelContent(content);
  }
}

export class MindSporeLiteModelCompatibilityLoader implements ModelFileCompatibilityLoader {
  async loadModel(content: Uint8Array): Promise<Array<ModelFileTensorMetadata>> {
    if (!modelFileContentLooksUsable(content)) {
      throw new Error('Empty MindSpore model file.');
    }
    const model = await mindSporeLite.loadModelFromBuffer(
      rawfileContentToArrayBuffer(content),
      mindSporeLiteCpuContext()
    );
    return model.getInputs().map((input: mindSporeLite.MSTensor): ModelFileTensorMetadata => ({
      shape: input.shape.slice(),
      dtype: input.dtype,
      format: input.format,
      elementNum: input.elementNum,
      dataSize: input.dataSize
    }));
  }
}

export class BasicModelFileCompatibilityChecker implements ModelFileCompatibilityChecker {
  private readonly loader: ModelFileCompatibilityLoader;
  private readonly objectDetectionValidator: ObjectDetectionModelContentValidator;
  private readonly styleTransferValidator: StyleTransferModelContentValidator;
  private readonly customModelValidator: CustomModelContentValidator;

  constructor(
    loader: ModelFileCompatibilityLoader = new MindSporeLiteModelCompatibilityLoader(),
    objectDetectionValidator: ObjectDetectionModelContentValidator =
      new NativeObjectDetectionModelContentValidator(),
    styleTransferValidator: StyleTransferModelContentValidator =
      new NativeStyleTransferModelContentValidator(),
    customModelValidator: CustomModelContentValidator = new NativeCustomModelContentValidator()
  ) {
    this.loader = loader;
    this.objectDetectionValidator = objectDetectionValidator;
    this.styleTransferValidator = styleTransferValidator;
    this.customModelValidator = customModelValidator;
  }

  async isCompatible(
    routeName: string,
    inputKind: FeatureInputKind,
    _cachedUri: string,
    content: Uint8Array
  ): Promise<boolean> {
    try {
      if (inputKind === 'modelFile' &&
        (routeName === AppRoute.OBJECT_PHOTO.name || routeName === AppRoute.OBJECT_CAMERA.name)) {
        return await this.objectDetectionValidator.validate(content);
      }
      if (routeName === AppRoute.STYLE_TRANSFER.name && inputKind === 'stylePredictModelFile') {
        return await this.styleTransferValidator.validatePredict(content);
      }
      if (routeName === AppRoute.STYLE_TRANSFER.name && inputKind === 'styleTransferModelFile') {
        return await this.styleTransferValidator.validateTransfer(content);
      }
      if (routeName === AppRoute.CUSTOM_MODEL.name && inputKind === 'modelFile') {
        return await this.customModelValidator.validate(content);
      }
      const inputs = await this.loader.loadModel(content);
      return true;
    } catch (_) {
      return false;
    }
  }
}

export function customModelInputContractCompatible(inputs: Array<ModelFileTensorMetadata>): boolean {
  if (inputs.length !== 1) {
    return false;
  }
  const input = inputs[0];
  return input.shape.length === 4 &&
    input.shape[0] === 1 &&
    input.shape[1] === 224 &&
    input.shape[2] === 224 &&
    input.shape[3] === 3 &&
    input.dtype === mindSporeLite.DataType.NUMBER_TYPE_FLOAT32 &&
    input.format === mindSporeLite.Format.NHWC &&
    input.elementNum === 150528 &&
    input.dataSize === 602112;
}

export class RuntimeModelFileCacheService {
  private readonly reader: FileUriContentReader;
  private readonly writer: ModelFileCacheWriter;
  private readonly compatibilityChecker: ModelFileCompatibilityChecker;
  private readonly styleTransferPairChecker?: StyleTransferModelPairCompatibilityChecker;

  constructor(
    reader: FileUriContentReader = new FileUriContentReader(),
    writer: ModelFileCacheWriter = new HarmonyModelFileCacheWriter(),
    compatibilityChecker: ModelFileCompatibilityChecker = new BasicModelFileCompatibilityChecker(),
    styleTransferPairChecker?: StyleTransferModelPairCompatibilityChecker
  ) {
    this.reader = reader;
    this.writer = writer;
    this.compatibilityChecker = compatibilityChecker;
    this.styleTransferPairChecker = styleTransferPairChecker;
  }

  cachePickedModelFile(
    sourceUri: string,
    cacheDir: string,
    routeName: string,
    inputKind: FeatureInputKind
  ): Promise<ModelFileCacheResult>;
  cachePickedModelFile(
    sourceUri: string,
    cacheDir: string,
    routeName: string,
    inputKind: FeatureInputKind,
    requestToken: number,
    isCurrent: () => boolean
  ): Promise<ModelFileCacheResult | undefined>;
  async cachePickedModelFile(
    sourceUri: string,
    cacheDir: string,
    routeName: string,
    inputKind: FeatureInputKind,
    requestToken: number = 0,
    isCurrent: () => boolean = (): boolean => true
  ): Promise<ModelFileCacheResult | undefined> {
    if (sourceUri.length === 0 || cacheDir.length === 0) {
      return modelFileCacheFailedResult(routeName, inputKind);
    }

    try {
      const content = await this.reader.readFileContent(sourceUri);
      const fileName = cachedModelFileNameForInputKind(routeName, inputKind);
      if (fileName.length === 0) {
        return modelFileCacheFailedResult(routeName, inputKind);
      }
      const targetUri = modelFileCachePath(cacheDir, fileName);
      const compatible = await this.isCompatibleModelFile(routeName, inputKind, targetUri, content);
      if (!compatible) {
        return modelFileIncompatibleResult(routeName, inputKind);
      }
      if (routeName === AppRoute.STYLE_TRANSFER.name &&
        (inputKind === 'stylePredictModelFile' || inputKind === 'styleTransferModelFile')) {
        if (this.styleTransferPairChecker === undefined ||
          !await this.styleTransferPairChecker.isCompatible(inputKind, cacheDir, content)) {
          return modelFileIncompatibleResult(routeName, inputKind);
        }
      }
      const uri = await this.writer.writeModelFile(cacheDir, fileName, content, requestToken, isCurrent);
      if (uri === undefined) {
        return undefined;
      }
      if (uri.length === 0) {
        return modelFileCacheFailedResult(routeName, inputKind);
      }
      return {
        ok: true,
        uri: uri,
        messageKey: modelFileReadyMessageKey(routeName, inputKind)
      };
    } catch (_) {
      return modelFileCacheFailedResult(routeName, inputKind);
    }
  }

  private async isCompatibleModelFile(
    routeName: string,
    inputKind: FeatureInputKind,
    uri: string,
    content: Uint8Array
  ): Promise<boolean> {
    try {
      return await this.compatibilityChecker.isCompatible(routeName, inputKind, uri, content);
    } catch (_) {
      return false;
    }
  }
}

export function runtimeModelFileCacheService(rawfileReader: RawfileContentReader): RuntimeModelFileCacheService {
  return new RuntimeModelFileCacheService(
    new FileUriContentReader(),
    new HarmonyModelFileCacheWriter(),
    new BasicModelFileCompatibilityChecker(),
    new NativeStyleTransferModelPairCompatibilityChecker(rawfileReader)
  );
}

class HarmonyModelFileCacheFileBackend implements ModelFileCacheFileBackend {
  async open(path: string, mode: number): Promise<fileIo.File> {
    return await fileIo.open(path, mode);
  }

  async write(file: fileIo.File, content: Uint8Array): Promise<number> {
    return await fileIo.write(file.fd, content.buffer as ArrayBuffer, {
      offset: content.byteOffset,
      length: content.byteLength
    });
  }

  async close(file: fileIo.File): Promise<void> {
    await fileIo.close(file);
  }

  replace(sourcePath: string, targetPath: string): void {
    fileIo.moveFileSync(sourcePath, targetPath, 0);
  }

  remove(path: string): void {
    fileIo.unlinkSync(path);
  }
}

let modelFileCacheTempSequence: number = 0;

export class HarmonyModelFileCacheWriter implements ModelFileCacheWriter {
  private readonly backend: ModelFileCacheFileBackend;

  constructor(backend: ModelFileCacheFileBackend = new HarmonyModelFileCacheFileBackend()) {
    this.backend = backend;
  }

  async writeModelFile(
    cacheDir: string,
    fileName: string,
    content: Uint8Array,
    requestToken: number,
    isCurrent: () => boolean
  ): Promise<string | undefined> {
    const stablePath = modelFileCachePath(cacheDir, fileName);
    const tempPath = `${stablePath}.tmp-${Date.now()}-${++modelFileCacheTempSequence}-${requestToken}`;
    try {
      const file = await this.backend.open(
        tempPath,
        fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC
      );
      try {
        const writtenBytes = await this.backend.write(file, content);
        if (!modelFileCacheWriteSucceeded(writtenBytes, content)) {
          throw new Error('Incomplete model file cache write.');
        }
      } finally {
        await this.backend.close(file);
      }
      if (!isCurrent()) {
        this.removeTempFile(tempPath);
        return undefined;
      }
      this.backend.replace(tempPath, stablePath);
      return stablePath;
    } catch (_) {
      this.removeTempFile(tempPath);
      throw new Error('Model file cache publication failed.');
    }
  }

  private removeTempFile(path: string): void {
    try {
      this.backend.remove(path);
    } catch (_) {
    }
  }
}

export class HarmonyCachedModelFileExistenceChecker implements CachedModelFileExistenceChecker {
  async modelFileExists(path: string): Promise<boolean> {
    try {
      const stat = await fileIo.stat(path);
      return stat.size > 0;
    } catch (_) {
      return false;
    }
  }
}

export async function cachedModelFileInputStateForRoute(
  routeName: string,
  cacheDir: string,
  existenceChecker: CachedModelFileExistenceChecker = new HarmonyCachedModelFileExistenceChecker()
): Promise<CachedModelFileInputState> {
  return {
    modelInputUri: await cachedModelFileUriForInputKind(routeName, 'modelFile', cacheDir, existenceChecker),
    stylePredictModelInputUri: await cachedModelFileUriForInputKind(
      routeName,
      'stylePredictModelFile',
      cacheDir,
      existenceChecker
    ),
    styleTransferModelInputUri: await cachedModelFileUriForInputKind(
      routeName,
      'styleTransferModelFile',
      cacheDir,
      existenceChecker
    )
  };
}

export function cachedModelFileNameForInputKind(routeName: string, inputKind: FeatureInputKind): string {
  if (inputKind === 'stylePredictModelFile') {
    return 'custom_predict.mnn';
  }
  if (inputKind === 'styleTransferModelFile') {
    return 'custom_transfer.mnn';
  }
  if (routeName === AppRoute.CUSTOM_MODEL.name && inputKind === 'modelFile') {
    return 'custom_model.ms';
  }
  if ((routeName === AppRoute.OBJECT_PHOTO.name || routeName === AppRoute.OBJECT_CAMERA.name) &&
    inputKind === 'modelFile') {
    return 'object_detection_model.mnn';
  }
  return '';
}

export function shouldCachePickedModelFileForRoute(routeName: string, inputKind: FeatureInputKind): boolean {
  return cachedModelFileNameForInputKind(routeName, inputKind).length > 0;
}

export function modelFileCacheWriteSucceeded(writtenBytes: number, content: Uint8Array): boolean {
  return writtenBytes === content.byteLength;
}

export function modelFileCachePath(cacheDir: string, fileName: string): string {
  const normalizedCacheDir = cacheDir.endsWith('/') || cacheDir.endsWith('\\') ?
    cacheDir.substring(0, cacheDir.length - 1) :
    cacheDir;
  return `${normalizedCacheDir}/${fileName}`;
}

export function modelFileContentLooksUsable(content: Uint8Array): boolean {
  return content.byteLength > 0;
}

async function cachedModelFileUriForInputKind(
  routeName: string,
  inputKind: FeatureInputKind,
  cacheDir: string,
  existenceChecker: CachedModelFileExistenceChecker
): Promise<string> {
  const fileName = cachedModelFileNameForInputKind(routeName, inputKind);
  if (cacheDir.length === 0 || fileName.length === 0) {
    return '';
  }
  const uri = modelFileCachePath(cacheDir, fileName);
  return await existenceChecker.modelFileExists(uri) ? uri : '';
}

function modelFileReadyMessageKey(routeName: string, inputKind: FeatureInputKind): AppStringKey {
  if (routeName === AppRoute.STYLE_TRANSFER.name && inputKind === 'stylePredictModelFile') {
    return 'feature_runtime_style_predict_model_loaded';
  }
  if (routeName === AppRoute.STYLE_TRANSFER.name && inputKind === 'styleTransferModelFile') {
    return 'feature_runtime_style_transfer_model_loaded';
  }
  return 'feature_runtime_model_ready';
}

function modelFileFailureMessageKey(routeName: string, inputKind: FeatureInputKind): AppStringKey {
  if (routeName === AppRoute.STYLE_TRANSFER.name && inputKind === 'stylePredictModelFile') {
    return 'feature_runtime_style_predict_model_load_failed';
  }
  if (routeName === AppRoute.STYLE_TRANSFER.name && inputKind === 'styleTransferModelFile') {
    return 'feature_runtime_style_transfer_model_load_failed';
  }
  return 'feature_runtime_model_cache_failed';
}

function modelFileCacheFailedResult(routeName: string, inputKind: FeatureInputKind): ModelFileCacheResult {
  return {
    ok: false,
    uri: '',
    messageKey: modelFileFailureMessageKey(routeName, inputKind)
  };
}

function modelFileIncompatibleResult(routeName: string, inputKind: FeatureInputKind): ModelFileCacheResult {
  const styleModelFailureKey = modelFileFailureMessageKey(routeName, inputKind);
  return {
    ok: false,
    uri: '',
    messageKey: styleModelFailureKey === 'feature_runtime_model_cache_failed' ?
      'feature_runtime_model_incompatible' :
      styleModelFailureKey
  };
}
