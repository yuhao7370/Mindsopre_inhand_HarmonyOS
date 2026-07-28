import { fileIo, hash } from '@kit.CoreFileKit';
import { mindSporeLite } from '@kit.MindSporeLiteKit';
import util from '@ohos.util';
import zlib from '@ohos.zlib';
import { AppStringKey } from '../../common/i18n/AppStrings';
import { FileUriContentReader } from './FileUriContentReader';
import { mindSporeLiteCpuContext, rawfileContentToArrayBuffer } from './MindSporeLiteModelRunner';
import {
  CustomModelDataType,
  CustomModelInputKind,
  CustomModelPackageManifest,
  CustomModelTensorFormat,
  CustomModelTensorMetadata,
  customModelDeclaredFiles,
  customModelPackageMaxExtractedBytes,
  customModelPackageMaxZipBytes,
  parseCustomModelPackageManifest,
  validateCustomModelTensorContract
} from './CustomModelPackage';

export interface CustomModelArchiveEntry {
  readonly name: string;
  readonly size: number;
  readonly isFile: boolean;
  readonly isSymbolicLink: boolean;
}

export interface CustomModelPackageDescriptor {
  readonly rootDir: string;
  readonly modelPath: string;
  readonly manifest: CustomModelPackageManifest;
  readonly inputKind: CustomModelInputKind;
  readonly inputSummary: string;
  readonly outputSummary: string;
}

export interface CustomModelPackageImportResult {
  readonly ok: boolean;
  readonly descriptor?: CustomModelPackageDescriptor;
  readonly messageKey: AppStringKey;
}

interface CustomModelPackagePointer {
  readonly rootDir: string;
}

let customModelPackageRequestSequence: number = 0;

export function validateCustomModelPackageArchive(
  zipBytes: number,
  originalBytes: number,
  entries: Array<CustomModelArchiveEntry>
): boolean {
  if (!Number.isInteger(zipBytes) || zipBytes <= 0 || zipBytes > customModelPackageMaxZipBytes ||
    !Number.isInteger(originalBytes) || originalBytes <= 0 ||
    originalBytes > customModelPackageMaxExtractedBytes || entries.length === 0) {
    return false;
  }
  let actualBytes = 0;
  for (let index = 0; index < entries.length; index++) {
    const entry = entries[index];
    if (!entry.isFile || entry.isSymbolicLink || !rootArchiveName(entry.name) ||
      !Number.isInteger(entry.size) || entry.size < 0 ||
      actualBytes > customModelPackageMaxExtractedBytes - entry.size) {
      return false;
    }
    actualBytes += entry.size;
  }
  return actualBytes > 0 && actualBytes <= customModelPackageMaxExtractedBytes;
}

export function customModelPackageFilesMatchManifest(
  manifest: CustomModelPackageManifest,
  entries: Array<CustomModelArchiveEntry>
): boolean {
  const declared = customModelDeclaredFiles(manifest).slice().sort();
  const actual = entries.map((entry: CustomModelArchiveEntry): string => entry.name).sort();
  if (declared.length !== actual.length) {
    return false;
  }
  for (let index = 0; index < declared.length; index++) {
    if (declared[index] !== actual[index]) {
      return false;
    }
  }
  return true;
}

export class CustomModelPackageService {
  async importPackage(sourceUri: string, cacheDir: string): Promise<CustomModelPackageImportResult> {
    if (sourceUri.length === 0 || cacheDir.length === 0) {
      return failedImport('feature_runtime_model_cache_failed');
    }
    const baseDir = joinPath(cacheDir, 'custom-model-package');
    const requestDir = joinPath(
      baseDir,
      `request-${Date.now()}-${++customModelPackageRequestSequence}`
    );
    const extractedDir = joinPath(requestDir, 'files');
    const zipPath = joinPath(requestDir, 'package.zip');
    try {
      if (!fileIo.accessSync(baseDir)) {
        await fileIo.mkdir(baseDir, true);
      }
      await fileIo.mkdir(extractedDir, true);
      await fileIo.copyFile(sourceUri, zipPath);
      const zipStat = await fileIo.stat(zipPath);
      const originalBytes = await zlib.getOriginalSize(zipPath);
      if (zipStat.size <= 0 || zipStat.size > customModelPackageMaxZipBytes ||
        originalBytes <= 0 || originalBytes > customModelPackageMaxExtractedBytes) {
        throw new Error('Model package exceeds its size limit.');
      }
      await zlib.decompressFile(zipPath, extractedDir);
      const entries = await archiveEntries(extractedDir);
      if (!validateCustomModelPackageArchive(zipStat.size, originalBytes, entries)) {
        throw new Error('Model package archive layout is not supported.');
      }
      const manifest = parseCustomModelPackageManifest(
        await fileIo.readText(joinPath(extractedDir, 'manifest.json'))
      );
      if (!customModelPackageFilesMatchManifest(manifest, entries)) {
        throw new Error('Model package files do not match manifest.');
      }
      await verifyDeclaredAssets(extractedDir, manifest);
      const descriptor = await descriptorForRoot(extractedDir, manifest);
      await publishPointer(baseDir, extractedDir);
      return {
        ok: true,
        descriptor: descriptor,
        messageKey: 'feature_runtime_model_ready'
      };
    } catch (error) {
      console.error(`Custom model package import failed: ${String(error)}`);
      await removeTree(requestDir);
      return failedImport('feature_runtime_model_incompatible');
    }
  }

  async loadCurrentPackage(cacheDir: string): Promise<CustomModelPackageDescriptor | undefined> {
    if (cacheDir.length === 0) {
      return undefined;
    }
    try {
      const pointerContent = await fileIo.readText(
        joinPath(joinPath(cacheDir, 'custom-model-package'), 'current.json')
      );
      const pointer = JSON.parse(pointerContent) as CustomModelPackagePointer;
      if (typeof pointer.rootDir !== 'string' || pointer.rootDir.length === 0) {
        return undefined;
      }
      const manifest = parseCustomModelPackageManifest(
        await fileIo.readText(joinPath(pointer.rootDir, 'manifest.json'))
      );
      const entries = await archiveEntries(pointer.rootDir);
      if (!customModelPackageFilesMatchManifest(manifest, entries)) {
        return undefined;
      }
      await verifyDeclaredAssets(pointer.rootDir, manifest);
      return await descriptorForRoot(pointer.rootDir, manifest);
    } catch (_) {
      return undefined;
    }
  }
}

async function descriptorForRoot(
  rootDir: string,
  manifest: CustomModelPackageManifest
): Promise<CustomModelPackageDescriptor> {
  const modelPath = joinPath(rootDir, manifest.model.file);
  const modelContent = await new FileUriContentReader().readFileContent(modelPath);
  const model = await mindSporeLite.loadModelFromBuffer(
    rawfileContentToArrayBuffer(modelContent),
    mindSporeLiteCpuContext()
  );
  const nativeInputs = model.getInputs();
  const inputs = nativeInputs.map((tensor: mindSporeLite.MSTensor): CustomModelTensorMetadata =>
    tensorMetadata(tensor));
  for (let index = 0; index < nativeInputs.length; index++) {
    nativeInputs[index].setData(new ArrayBuffer(nativeInputs[index].dataSize));
  }
  const nativeOutputs = await model.predict(nativeInputs);
  const outputs = nativeOutputs.map((tensor: mindSporeLite.MSTensor): CustomModelTensorMetadata =>
    tensorMetadata(tensor));
  validateCustomModelTensorContract(manifest, inputs, outputs);
  return {
    rootDir: rootDir,
    modelPath: modelPath,
    manifest: manifest,
    inputKind: manifest.input.kind,
    inputSummary: manifest.input.tensors
      .map((tensor): string => `${tensor.name} ${tensor.dtype} [${tensor.shape.join(', ')}]`)
      .join('\n'),
    outputSummary:
      `${manifest.output.kind}: ${manifest.output.tensor.name} ` +
      `${manifest.output.tensor.dtype} [${manifest.output.tensor.shape.join(', ')}]`
  };
}

function tensorMetadata(tensor: mindSporeLite.MSTensor): CustomModelTensorMetadata {
  return {
    name: tensor.name,
    dtype: customModelDataType(tensor.dtype),
    shape: tensor.shape.slice(),
    format: customModelTensorFormat(tensor.format),
    elementNum: tensor.elementNum,
    dataSize: tensor.dataSize
  };
}

function customModelDataType(dtype: mindSporeLite.DataType): CustomModelDataType {
  if (dtype === mindSporeLite.DataType.NUMBER_TYPE_FLOAT32) {
    return 'FLOAT32';
  }
  if (dtype === mindSporeLite.DataType.NUMBER_TYPE_UINT8) {
    return 'UINT8';
  }
  if (dtype === mindSporeLite.DataType.NUMBER_TYPE_INT32) {
    return 'INT32';
  }
  throw new Error('Model tensor dtype is not supported.');
}

function customModelTensorFormat(format: mindSporeLite.Format): CustomModelTensorFormat {
  if (format === mindSporeLite.Format.NHWC) {
    return 'NHWC';
  }
  if (format === mindSporeLite.Format.NCHW) {
    return 'NCHW';
  }
  return '';
}

async function archiveEntries(rootDir: string): Promise<Array<CustomModelArchiveEntry>> {
  const names = await fileIo.listFile(rootDir, { recursion: true });
  const entries: Array<CustomModelArchiveEntry> = [];
  for (let index = 0; index < names.length; index++) {
    const name = stripLeadingSeparator(names[index]);
    const stat = await fileIo.lstat(joinPath(rootDir, name));
    entries.push({
      name: name,
      size: stat.size,
      isFile: stat.isFile(),
      isSymbolicLink: stat.isSymbolicLink()
    });
  }
  return entries;
}

async function verifyDeclaredAssets(rootDir: string, manifest: CustomModelPackageManifest): Promise<void> {
  const assets = [
    manifest.model,
    manifest.input.text?.tokenizer,
    manifest.output.labels,
    manifest.output.tokenizer
  ];
  for (let index = 0; index < assets.length; index++) {
    const asset = assets[index];
    if (asset !== undefined) {
      const actual = (await hash.hash(joinPath(rootDir, asset.file), 'sha256')).toLowerCase();
      if (actual !== asset.sha256) {
        throw new Error(`SHA-256 mismatch for ${asset.file}.`);
      }
    }
  }
}

async function publishPointer(baseDir: string, rootDir: string): Promise<void> {
  const pointerPath = joinPath(baseDir, 'current.json');
  const content = new util.TextEncoder().encodeInto(JSON.stringify({ rootDir: rootDir }));
  const createMode = fileIo.accessSync(pointerPath) ? 0 : fileIo.OpenMode.CREATE;
  const file = await fileIo.open(
    pointerPath,
    fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.TRUNC | createMode
  );
  try {
    const written = await fileIo.write(file.fd, content.buffer as ArrayBuffer, {
      offset: content.byteOffset,
      length: content.byteLength
    });
    if (written !== content.byteLength) {
      throw new Error('Incomplete model package pointer write.');
    }
  } finally {
    await fileIo.close(file);
  }
}

async function removeTree(rootDir: string): Promise<void> {
  try {
    const names = await fileIo.listFile(rootDir, { recursion: true });
    names.sort((left: string, right: string): number => right.length - left.length);
    for (let index = 0; index < names.length; index++) {
      const path = joinPath(rootDir, stripLeadingSeparator(names[index]));
      try {
        const stat = await fileIo.lstat(path);
        if (stat.isDirectory() && !stat.isSymbolicLink()) {
          await fileIo.rmdir(path);
        } else {
          await fileIo.unlink(path);
        }
      } catch (_) {
      }
    }
    await fileIo.rmdir(rootDir);
  } catch (_) {
  }
}

function rootArchiveName(name: string): boolean {
  return name.length > 0 && !name.startsWith('.') && !name.includes('/') &&
    !name.includes('\\') && !name.includes('..') && !/^[A-Za-z]:/.test(name);
}

function stripLeadingSeparator(value: string): string {
  let result = value;
  while (result.startsWith('/') || result.startsWith('\\')) {
    result = result.substring(1);
  }
  return result;
}

function joinPath(parent: string, child: string): string {
  const base = parent.endsWith('/') || parent.endsWith('\\') ?
    parent.substring(0, parent.length - 1) :
    parent;
  return `${base}/${child}`;
}

function failedImport(messageKey: AppStringKey): CustomModelPackageImportResult {
  return {
    ok: false,
    messageKey: messageKey
  };
}
