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

interface TranslationWorkerMessageEvent { readonly data: Object; }
interface WorkerErrorLike { readonly message?: string; }

export interface TranslationWorkerPort {
  onmessage?: (event: TranslationWorkerMessageEvent) => void;
  onerror?: (event: Object) => void;
  onAllErrors?: (event: Object) => void;
  onexit?: (code: number) => void;
  postMessage(message: Object): void;
  terminate(): void;
}

export interface TranslationWorkerPreparedFiles {
  readonly directory: string;
  readonly manifest: Object;
}

export interface TranslationWorkerClientDependencies {
  prepare: () => Promise<TranslationWorkerPreparedFiles>;
  getTokenizerRuntime: () => Promise<string>;
  createWorker: () => TranslationWorkerPort;
  requestTimeoutMs?: number;
}

interface PendingTranslation {
  readonly resolveResult?: (result: TextTranslationResult) => void;
  readonly resolveReady?: () => void;
  readonly reject: (error: Error) => void;
  readonly timer: number;
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

class ProductionTranslationWorkerDependencies implements TranslationWorkerClientDependencies {
  private readonly options: TranslationProductionBundleOptions;

  constructor(options: TranslationProductionBundleOptions) { this.options = options; }

  async prepare(): Promise<TranslationWorkerPreparedFiles> {
    return await prepareProductionTranslationModelFiles(this.options);
  }

  async getTokenizerRuntime(): Promise<string> {
    return asciiContentToText(await this.options.resourceManager.getRawFileContent(translationTokenizerRuntimeRawfilePath));
  }

  createWorker(): TranslationWorkerPort {
    return new worker.ThreadWorker('entry/ets/workers/TranslationWorker.ets') as TranslationWorkerPort;
  }

  readonly requestTimeoutMs: number = 30000;
}

export class TranslationWorkerClient implements TextTranslationRunner {
  private readonly dependencies: TranslationWorkerClientDependencies;
  private worker?: TranslationWorkerPort;
  private initialization?: Promise<void>;
  private nextId: number = 1;
  private generation: number = 0;
  private readonly pending: Map<number, PendingTranslation> = new Map();

  constructor(options: TranslationProductionBundleOptions, dependencies?: TranslationWorkerClientDependencies) {
    this.dependencies = dependencies ?? new ProductionTranslationWorkerDependencies(options);
  }

  async translate(text: string, targetLanguage: string): Promise<TextTranslationResult> {
    try {
      await this.ensureInitialized();
      return await this.request(text, targetLanguage);
    } catch (_) {
      return { ok: false, sourceText: text, translatedText: '', targetLanguage: targetLanguage,
        runtimeSource: 'localModel', errorCode: 'MODEL_EXECUTION_FAILED' };
    }
  }

  stop(): Promise<void> { this.terminate(); return Promise.resolve(); }

  terminate(): void {
    const instance = this.worker;
    const generation = this.generation;
    this.failWorker(instance, generation, new Error('Translation worker was terminated.'));
  }

  private async ensureInitialized(): Promise<void> {
    if (this.initialization === undefined) {
      this.generation++;
      const generation = this.generation;
      const initialization = this.startWorker(generation);
      this.initialization = initialization;
      initialization.catch((error: Error): void => this.failWorker(this.worker, generation, error));
    }
    await this.initialization;
  }

  private async startWorker(generation: number): Promise<void> {
    const prepared = await this.dependencies.prepare();
    this.ensureActive(generation);
    const tokenizerRuntime = await this.dependencies.getTokenizerRuntime();
    this.ensureActive(generation);
    const instance = this.dependencies.createWorker();
    if (!this.isActive(generation)) {
      this.detachAndTerminate(instance);
      throw new Error('Translation worker was terminated while starting.');
    }
    this.worker = instance;
    instance.onmessage = (event: TranslationWorkerMessageEvent): void => this.onMessage(instance, generation, event.data);
    instance.onerror = (event: Object): void =>
      this.failWorker(instance, generation, new Error(`Translation worker error: ${workerErrorMessage(event)}`));
    instance.onAllErrors = (event: Object): void =>
      this.failWorker(instance, generation, new Error(`Translation worker global error: ${workerErrorMessage(event)}`));
    instance.onexit = (code: number): void =>
      this.failWorker(instance, generation, new Error(`Translation worker exited with code ${code}.`));
    const id = this.nextRequestId();
    const ready = this.createPending(instance, generation, id, true);
    const message: TranslationWorkerInitializeMessage = {
      kind: 'initialize', id: id, directory: prepared.directory, manifest: prepared.manifest, tokenizerRuntime: tokenizerRuntime
    };
    this.post(instance, generation, id, message);
    await ready;
    this.ensureActive(generation);
  }

  private async request(text: string, targetLanguage: string): Promise<TextTranslationResult> {
    const instance = this.worker;
    const generation = this.generation;
    if (instance === undefined) throw new Error('Translation worker is unavailable.');
    const id = this.nextRequestId();
    const result = this.createPending(instance, generation, id, false);
    const message: TranslationWorkerTranslateMessage = { kind: 'translate', id: id, text: text, targetLanguage: targetLanguage };
    this.post(instance, generation, id, message);
    return await result as TextTranslationResult;
  }

  private createPending(instance: TranslationWorkerPort, generation: number, id: number, isReady: boolean): Promise<void | TextTranslationResult> {
    return new Promise<void | TextTranslationResult>((resolve, reject): void => {
      const timer = setTimeout((): void => {
        if (this.pending.has(id)) this.failWorker(instance, generation, new Error('Translation worker request timed out.'));
      }, this.dependencies.requestTimeoutMs ?? 30000) as number;
      this.pending.set(id, isReady ? { resolveReady: (): void => resolve(), reject: reject, timer: timer } :
        { resolveResult: (result: TextTranslationResult): void => resolve(result), reject: reject, timer: timer });
    });
  }

  private post(instance: TranslationWorkerPort, generation: number, id: number, message: Object): void {
    try { instance.postMessage(message); } catch (error) {
      this.clearPending(id);
      this.failWorker(instance, generation, error as Error);
    }
  }

  private onMessage(instance: TranslationWorkerPort, generation: number, payload: Object): void {
    if (!this.isCurrent(instance, generation) || !isTranslationWorkerMessage(payload)) return;
    const message = payload as TranslationWorkerMessage;
    const pending = this.pending.get(message.id);
    if (pending === undefined) return;
    if (message.kind !== 'ready' && message.kind !== 'result' && message.kind !== 'error') return;
    this.clearPending(message.id);
    if (!message.ok || message.kind === 'error') { pending.reject(new Error(message.error ?? 'Translation worker failed.')); return; }
    if (message.kind === 'ready' && pending.resolveReady !== undefined) { pending.resolveReady(); return; }
    if (message.kind === 'result' && pending.resolveResult !== undefined && isTranslationResult(message.result)) {
      pending.resolveResult(message.result as TextTranslationResult); return;
    }
    pending.reject(new Error('Translation worker response did not match its request.'));
  }

  private failWorker(instance: TranslationWorkerPort | undefined, generation: number, error: Error): void {
    if (!this.isCurrent(instance, generation)) return;
    this.worker = undefined;
    this.initialization = undefined;
    this.generation++;
    if (instance !== undefined) this.detachAndTerminate(instance);
    this.settleAll(error);
  }

  private isCurrent(instance: TranslationWorkerPort | undefined, generation: number): boolean {
    return generation === this.generation && instance === this.worker;
  }

  private isActive(generation: number): boolean { return generation === this.generation; }

  private ensureActive(generation: number): void {
    if (!this.isActive(generation)) throw new Error('Translation worker was terminated while starting.');
  }

  private clearPending(id: number): void {
    const pending = this.pending.get(id);
    if (pending !== undefined) clearTimeout(pending.timer);
    this.pending.delete(id);
  }

  private settleAll(error: Error): void {
    this.pending.forEach((pending: PendingTranslation): void => { clearTimeout(pending.timer); pending.reject(error); });
    this.pending.clear();
  }

  private detachAndTerminate(instance: TranslationWorkerPort): void {
    instance.onmessage = undefined; instance.onerror = undefined; instance.onAllErrors = undefined; instance.onexit = undefined;
    try { instance.terminate(); } catch (_) {}
  }

  private nextRequestId(): number { const id = this.nextId; this.nextId++; return id; }
}

function isTranslationWorkerMessage(value: Object): boolean {
  const message = value as TranslationWorkerMessage;
  return message !== null && typeof message.kind === 'string' && Number.isInteger(message.id) && typeof message.ok === 'boolean';
}

function isTranslationResult(value: TextTranslationResult | undefined): boolean {
  return value !== undefined && typeof value.ok === 'boolean' && typeof value.sourceText === 'string' &&
    typeof value.translatedText === 'string' && typeof value.targetLanguage === 'string';
}

function workerErrorMessage(value: Object): string {
  const event = value as WorkerErrorLike;
  return event.message ?? 'unknown error';
}
