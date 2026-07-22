import { fileIo } from '@kit.CoreFileKit';
import { mindSporeLite } from '@kit.MindSporeLiteKit';
import {
  TranslationDirectionManifest,
  TranslationGraphManifest,
  TranslationModelManifest,
  translationDirectionForTarget
} from './TranslationModelManifest';
import {
  asciiContentToText,
  createMindSporeLiteTranslationTensorSessionForTests,
  runTranslationModelRequest,
  translationResultWithoutModel,
  TranslationMindSporeModel,
  TranslationModelBundle,
  TranslationRequestQueue,
  TranslationTensorSession
} from './MindSporeLiteTranslationRunner';
import { configureTranslationTokenizers, TranslationTokenizerContract } from './TinyTranslationTokenizer';
import { TextTranslationResult } from './TextRecognitionService';

export interface TranslationWorkerInitialization {
  readonly directory: string;
  readonly manifest: TranslationModelManifest;
}

export class TranslationWorkerRuntime {
  private directory: string = '';
  private manifest?: TranslationModelManifest;
  private bundle?: TranslationModelBundle;
  // MindSpore Lite keeps views into the source ArrayBuffer in a worker. Keep the
  // buffers alive for as long as their models can serve requests.
  private modelBuffers: Array<ArrayBuffer> = [];

  async initialize(request: TranslationWorkerInitialization): Promise<void> {
    this.directory = request.directory;
    this.manifest = request.manifest;
    this.modelBuffers = [];
    this.bundle = undefined;
  }

  async translate(text: string, targetLanguage: string): Promise<TextTranslationResult> {
    const start = Date.now();
    const withoutModel = translationResultWithoutModel(text, targetLanguage);
    if (withoutModel !== undefined) {
      console.info(`TranslationWorker target=${targetLanguage} modelLoad=false totalMs=${Date.now() - start}`);
      return withoutModel;
    }
    if (this.manifest === undefined) throw new Error('Translation worker is not initialized.');
    const direction = translationDirectionForTarget(this.manifest, targetLanguage);
    const loadStart = Date.now();
    if (this.bundle === undefined) await this.loadDirection(direction);
    const loadMs = Date.now() - loadStart;
    if (this.bundle === undefined || this.bundle.direction.targetLanguage !== targetLanguage) {
      throw new Error('Translation worker direction differs from request.');
    }
    const result = await runTranslationModelRequest(this.bundle, text, targetLanguage);
    console.info(`TranslationWorker target=${targetLanguage} modelLoad=${loadMs > 0} loadMs=${loadMs} totalMs=${Date.now() - start}`);
    return result;
  }

  private async loadDirection(direction: TranslationDirectionManifest): Promise<void> {
    const source = await this.loadText(this.directory, direction.tokenizers.source.file, direction.tokenizers.source.size);
    const target = direction.tokenizers.target.file === direction.tokenizers.source.file ? source :
      await this.loadText(this.directory, direction.tokenizers.target.file, direction.tokenizers.target.size);
    configureTranslationTokenizers(source, target, tokenizerContract(direction, true), tokenizerContract(direction, false));
    const encoder = await this.loadModel(this.directory, direction.graphs.encoder);
    this.modelBuffers.push(encoder.buffer);
    const decoder = await this.loadModel(this.directory, direction.graphs.decoderFull);
    this.modelBuffers.push(decoder.buffer);
    const session: TranslationTensorSession = createMindSporeLiteTranslationTensorSessionForTests(
      direction,
      new WorkerMindSporeModelAdapter(encoder.model),
      new WorkerMindSporeModelAdapter(decoder.model)
    );
    this.bundle = {
      direction: direction,
      session: session,
      requestQueue: new TranslationRequestQueue()
    };
  }

  private async loadText(directory: string, fileName: string, size: number): Promise<string> {
    const separator = directory.endsWith('/') ? '' : '/';
    const file = await fileIo.open(`${directory}${separator}${fileName}`, fileIo.OpenMode.READ_ONLY);
    try {
      const stat = await fileIo.stat(file.fd);
      if (!Number.isInteger(stat.size) || stat.size !== size) throw new Error(`${fileName} size differs from manifest.`);
      return asciiContentToText(new Uint8Array(await readTranslationModelFully(file.fd, stat.size, fileName)));
    } finally { await fileIo.close(file); }
  }

  private async loadModel(directory: string, graph: TranslationGraphManifest): Promise<LoadedTranslationModel> {
    const separator = directory.endsWith('/') ? '' : '/';
    const file = await fileIo.open(`${directory}${separator}${graph.file}`, fileIo.OpenMode.READ_ONLY);
    try {
      const stat = await fileIo.stat(file.fd);
      if (!Number.isInteger(stat.size) || stat.size !== graph.size) {
        throw new Error(`${graph.file} size differs from the verified translation manifest.`);
      }
      const buffer = await readTranslationModelFully(file.fd, stat.size, graph.file);
      const model = await mindSporeLite.loadModelFromBuffer(
        buffer,
        { target: ['cpu'], cpu: { threadNum: 2 } }
      );
      return { model: model, buffer: buffer };
    } finally {
      await fileIo.close(file);
    }
  }
}

function tokenizerContract(direction: TranslationDirectionManifest, source: boolean): TranslationTokenizerContract {
  const tokenizer = source ? direction.tokenizers.source : direction.tokenizers.target;
  return { modelSha256: tokenizer.modelSha256, vocabularySha256: tokenizer.vocabularySha256,
    vocabularySize: direction.vocabulary.size, pieceCount: tokenizer.pieceCount,
    decodeVocabularySize: tokenizer.decodeVocabularySize, unknownId: direction.vocabulary.unk };
}

interface LoadedTranslationModel {
  readonly model: mindSporeLite.Model;
  readonly buffer: ArrayBuffer;
}

async function readTranslationModelFully(fd: number, size: number, fileName: string): Promise<ArrayBuffer> {
  const buffer = new ArrayBuffer(size);
  let copied = 0;
  while (copied < size) {
    const chunk = new ArrayBuffer(Math.min(1024 * 1024, size - copied));
    const bytesRead = await fileIo.read(fd, chunk, { offset: copied, length: chunk.byteLength });
    if (!Number.isInteger(bytesRead) || bytesRead <= 0 || bytesRead > chunk.byteLength) {
      throw new Error(`${fileName} could not be read completely.`);
    }
    new Uint8Array(buffer, copied, bytesRead).set(new Uint8Array(chunk, 0, bytesRead));
    copied += bytesRead;
  }
  return buffer;
}

class WorkerMindSporeModelAdapter implements TranslationMindSporeModel {
  private readonly model: mindSporeLite.Model;

  constructor(model: mindSporeLite.Model) {
    this.model = model;
  }

  getInputs() {
    return this.model.getInputs();
  }

  async predict(inputs: Array<mindSporeLite.MSTensor>) {
    return await this.model.predict(inputs);
  }
}
