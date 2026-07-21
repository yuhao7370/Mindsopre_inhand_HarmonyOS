import { worker } from '@kit.ArkTS';
import {
  asciiContentToText,
  prepareProductionTranslationModelFiles,
  TranslationProductionBundleOptions
} from './MindSporeLiteTranslationRunner';
import { translationTokenizerRuntimeRawfilePath } from './TranslationModelManifest';
import { TextTranslationResult, TextTranslationRunner } from './TextRecognitionService';

interface TranslationWorkerMessage {
  readonly kind: string;
  readonly id: number;
  readonly ok: boolean;
  readonly result?: TextTranslationResult;
  readonly error?: string;
}

interface PendingTranslation {
  readonly resolveResult?: (result: TextTranslationResult) => void;
  readonly resolveReady?: () => void;
  readonly reject: (error: Error) => void;
}

interface TranslationWorkerInitializeMessage {
  readonly kind: string;
  readonly id: number;
  readonly directory: string;
  readonly manifest: Object;
  readonly tokenizerRuntime: string;
}

interface TranslationWorkerTranslateMessage {
  readonly kind: string;
  readonly id: number;
  readonly text: string;
  readonly targetLanguage: string;
}

export class TranslationWorkerClient implements TextTranslationRunner {
  private readonly options: TranslationProductionBundleOptions;
  private worker?: worker.ThreadWorker;
  private initialization?: Promise<void>;
  private nextId: number = 1;
  private readonly pending: Map<number, PendingTranslation> = new Map();

  constructor(options: TranslationProductionBundleOptions) {
    this.options = options;
  }

  async translate(text: string, targetLanguage: string): Promise<TextTranslationResult> {
    try {
      await this.ensureInitialized();
      return await this.request(text, targetLanguage);
    } catch (_) {
      return {
        ok: false,
        sourceText: text,
        translatedText: '',
        targetLanguage: targetLanguage,
        runtimeSource: 'localModel',
        errorCode: 'MODEL_EXECUTION_FAILED'
      };
    }
  }

  terminate(): void {
    const instance = this.worker;
    this.worker = undefined;
    this.initialization = undefined;
    if (instance !== undefined) {
      instance.terminate();
    }
    this.settleAll(new Error('Translation worker was terminated.'));
  }

  private async ensureInitialized(): Promise<void> {
    if (this.initialization === undefined) {
      this.initialization = this.startWorker();
      this.initialization.catch((): void => {
        this.terminate();
      });
    }
    await this.initialization;
  }

  private async startWorker(): Promise<void> {
    const prepared = await prepareProductionTranslationModelFiles(this.options);
    const tokenizerContent = await this.options.resourceManager.getRawFileContent(translationTokenizerRuntimeRawfilePath);
    const instance = new worker.ThreadWorker('entry/ets/workers/TranslationWorker.ets');
    this.worker = instance;
    instance.onmessage = (event): void => this.onMessage(event.data as TranslationWorkerMessage);
    instance.onerror = (event): void => this.settleAll(new Error(`Translation worker error: ${event.message}`));
    instance.onAllErrors = (event): void => this.settleAll(new Error(`Translation worker global error: ${event.message}`));
    instance.onexit = (code): void => this.settleAll(new Error(`Translation worker exited with code ${code}.`));
    const id = this.nextRequestId();
    const ready = new Promise<void>((resolve, reject): void => {
      this.pending.set(id, {
        resolveReady: resolve,
        reject: reject
      });
    });
    const message: TranslationWorkerInitializeMessage = {
      kind: 'initialize',
      id: id,
      directory: prepared.directory,
      manifest: prepared.manifest,
      tokenizerRuntime: asciiContentToText(tokenizerContent)
    };
    instance.postMessage(message);
    await ready;
  }

  private async request(text: string, targetLanguage: string): Promise<TextTranslationResult> {
    const instance = this.worker;
    if (instance === undefined) {
      throw new Error('Translation worker is unavailable.');
    }
    const id = this.nextRequestId();
    const result = new Promise<TextTranslationResult>((resolve, reject): void => {
      this.pending.set(id, { resolveResult: resolve, reject: reject });
    });
    const message: TranslationWorkerTranslateMessage = {
      kind: 'translate', id: id, text: text, targetLanguage: targetLanguage
    };
    instance.postMessage(message);
    return await result;
  }

  private onMessage(message: TranslationWorkerMessage): void {
    const pending = this.pending.get(message.id);
    if (pending === undefined) {
      return;
    }
    this.pending.delete(message.id);
    if (!message.ok) {
      pending.reject(new Error(message.error ?? 'Translation worker failed.'));
      return;
    }
    if (message.kind === 'ready') {
      if (pending.resolveReady === undefined) {
        pending.reject(new Error('Translation worker ready message did not match initialization.'));
        return;
      }
      pending.resolveReady();
      return;
    }
    if (message.result === undefined) {
      pending.reject(new Error('Translation worker returned no result.'));
      return;
    }
    if (pending.resolveResult === undefined) {
      pending.reject(new Error('Translation worker result did not match a translation request.'));
      return;
    }
    pending.resolveResult(message.result);
  }

  private settleAll(error: Error): void {
    this.pending.forEach((pending: PendingTranslation): void => pending.reject(error));
    this.pending.clear();
  }

  private nextRequestId(): number {
    const id = this.nextId;
    this.nextId++;
    return id;
  }
}
