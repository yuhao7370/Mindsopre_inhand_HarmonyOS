import { fileIo } from '@kit.CoreFileKit';
import { mindSporeLite } from '@kit.MindSporeLiteKit';
import { TranslationGraphManifest, TranslationModelManifest } from './TranslationModelManifest';
import {
  createMindSporeLiteTranslationTensorSessionForTests,
  runTranslationModelRequest,
  TranslationMindSporeModel,
  TranslationModelBundle,
  TranslationRequestQueue,
  TranslationTensorSession
} from './MindSporeLiteTranslationRunner';
import { configureTranslationTokenizer } from './TinyTranslationTokenizer';
import { TextTranslationResult } from './TextRecognitionService';

export interface TranslationWorkerInitialization {
  readonly directory: string;
  readonly manifest: TranslationModelManifest;
  readonly tokenizerRuntime: string;
}

export class TranslationWorkerRuntime {
  private bundle?: TranslationModelBundle;
  // MindSpore Lite keeps views into the source ArrayBuffer in a worker. Keep the
  // buffers alive for as long as their models can serve requests.
  private modelBuffers: Array<ArrayBuffer> = [];

  async initialize(request: TranslationWorkerInitialization): Promise<void> {
    configureTranslationTokenizer(request.tokenizerRuntime);
    this.modelBuffers = [];
    const encoder = await this.loadModel(request.directory, request.manifest.graphs[0]);
    this.modelBuffers.push(encoder.buffer);
    const prefill = await this.loadModel(request.directory, request.manifest.graphs[1]);
    this.modelBuffers.push(prefill.buffer);
    const step = await this.loadModel(request.directory, request.manifest.graphs[2]);
    this.modelBuffers.push(step.buffer);
    const session: TranslationTensorSession = createMindSporeLiteTranslationTensorSessionForTests(
      request.manifest,
      new WorkerMindSporeModelAdapter(encoder.model),
      new WorkerMindSporeModelAdapter(prefill.model),
      new WorkerMindSporeModelAdapter(step.model)
    );
    this.bundle = {
      manifest: request.manifest,
      session: session,
      requestQueue: new TranslationRequestQueue()
    };
  }

  async translate(text: string, targetLanguage: string): Promise<TextTranslationResult> {
    if (this.bundle === undefined) {
      throw new Error('Translation worker is not initialized.');
    }
    return await runTranslationModelRequest(this.bundle, text, targetLanguage);
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
