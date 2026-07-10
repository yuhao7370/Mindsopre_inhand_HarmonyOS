import { fileIo } from '@kit.CoreFileKit';
import { mindSporeLite } from '@kit.MindSporeLiteKit';
import { AppRoute } from '../../app/AppRoutes';
import { AppStringKey } from '../../common/i18n/AppStrings';
import { FeatureInputKind } from '../../features/runtime/FeatureWorkflowCatalog';
import { FileUriContentReader } from '../ai/FileUriContentReader';
import { mindSporeLiteCpuContext, rawfileContentToArrayBuffer } from '../ai/MindSporeLiteModelRunner';

export interface ModelFileCacheResult {
  readonly ok: boolean;
  readonly uri: string;
  readonly messageKey: AppStringKey;
}

export interface ModelFileCacheWriter {
  writeModelFile(cacheDir: string, fileName: string, content: Uint8Array): Promise<string>;
}

export interface ModelFileCompatibilityChecker {
  isCompatible(
    routeName: string,
    inputKind: FeatureInputKind,
    cachedUri: string,
    content: Uint8Array
  ): Promise<boolean>;
}

export interface ModelFileCompatibilityLoader {
  loadModel(content: Uint8Array): Promise<void>;
}

export class MindSporeLiteModelCompatibilityLoader implements ModelFileCompatibilityLoader {
  async loadModel(content: Uint8Array): Promise<void> {
    if (!modelFileContentLooksUsable(content)) {
      throw new Error('Empty MindSpore model file.');
    }
    await mindSporeLite.loadModelFromBuffer(rawfileContentToArrayBuffer(content), mindSporeLiteCpuContext());
  }
}

export class BasicModelFileCompatibilityChecker implements ModelFileCompatibilityChecker {
  private readonly loader: ModelFileCompatibilityLoader;

  constructor(loader: ModelFileCompatibilityLoader = new MindSporeLiteModelCompatibilityLoader()) {
    this.loader = loader;
  }

  async isCompatible(
    _routeName: string,
    _inputKind: FeatureInputKind,
    _cachedUri: string,
    content: Uint8Array
  ): Promise<boolean> {
    try {
      await this.loader.loadModel(content);
      return true;
    } catch (_) {
      return false;
    }
  }
}

export class RuntimeModelFileCacheService {
  private readonly reader: FileUriContentReader;
  private readonly writer: ModelFileCacheWriter;
  private readonly compatibilityChecker: ModelFileCompatibilityChecker;

  constructor(
    reader: FileUriContentReader = new FileUriContentReader(),
    writer: ModelFileCacheWriter = new HarmonyModelFileCacheWriter(),
    compatibilityChecker: ModelFileCompatibilityChecker = new BasicModelFileCompatibilityChecker()
  ) {
    this.reader = reader;
    this.writer = writer;
    this.compatibilityChecker = compatibilityChecker;
  }

  async cachePickedModelFile(
    sourceUri: string,
    cacheDir: string,
    routeName: string,
    inputKind: FeatureInputKind
  ): Promise<ModelFileCacheResult> {
    if (sourceUri.length === 0 || cacheDir.length === 0) {
      return modelFileCacheFailedResult();
    }

    try {
      const content = await this.reader.readFileContent(sourceUri);
      const fileName = cachedModelFileNameForInputKind(routeName, inputKind);
      if (fileName.length === 0) {
        return modelFileCacheFailedResult();
      }
      const targetUri = modelFileCachePath(cacheDir, fileName);
      const compatible = await this.isCompatibleModelFile(routeName, inputKind, targetUri, content);
      if (!compatible) {
        return modelFileIncompatibleResult();
      }
      const uri = await this.writer.writeModelFile(cacheDir, fileName, content);
      if (uri.length === 0) {
        return modelFileCacheFailedResult();
      }
      return {
        ok: true,
        uri: uri,
        messageKey: 'feature_runtime_model_ready'
      };
    } catch (_) {
      return modelFileCacheFailedResult();
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

export class HarmonyModelFileCacheWriter implements ModelFileCacheWriter {
  async writeModelFile(cacheDir: string, fileName: string, content: Uint8Array): Promise<string> {
    const path = modelFileCachePath(cacheDir, fileName);
    const file = await fileIo.open(path, fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
    try {
      const writtenBytes = await fileIo.write(file.fd, content.buffer as ArrayBuffer, {
        offset: content.byteOffset,
        length: content.byteLength
      });
      if (!modelFileCacheWriteSucceeded(writtenBytes, content)) {
        throw new Error('Incomplete model file cache write.');
      }
      return path;
    } finally {
      await fileIo.close(file);
    }
  }
}

export function cachedModelFileNameForInputKind(routeName: string, inputKind: FeatureInputKind): string {
  if (inputKind === 'stylePredictModelFile') {
    return 'custom_predict.ms';
  }
  if (inputKind === 'styleTransferModelFile') {
    return 'custom_transfer.ms';
  }
  if (routeName === AppRoute.CUSTOM_MODEL.name && inputKind === 'modelFile') {
    return 'custom_model.ms';
  }
  if ((routeName === AppRoute.OBJECT_PHOTO.name || routeName === AppRoute.OBJECT_CAMERA.name) &&
    inputKind === 'modelFile') {
    return 'object_detection_model.ms';
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

function modelFileCacheFailedResult(): ModelFileCacheResult {
  return {
    ok: false,
    uri: '',
    messageKey: 'feature_runtime_model_cache_failed'
  };
}

function modelFileIncompatibleResult(): ModelFileCacheResult {
  return {
    ok: false,
    uri: '',
    messageKey: 'feature_runtime_model_incompatible'
  };
}
