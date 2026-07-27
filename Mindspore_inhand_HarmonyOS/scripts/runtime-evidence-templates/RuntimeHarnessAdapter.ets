import { hilog } from '@kit.PerformanceAnalysisKit';
import { FeatureWorkflow } from '../features/runtime/FeatureWorkflowCatalog';
import { AiRunInputs, AiRunResult, AiSegmentationData, DefaultAiService } from '../services/ai/AiService';
import { SegmentationRectangle, SegmentationResult } from '../services/ai/SegmentationService';
import { LiveCameraPosition } from '../services/camera/LiveCameraService';

interface RuntimeHarnessParams {
  readonly runtimeEvidenceRunId?: string;
  readonly runtimeEvidenceMode?: string;
}

interface RuntimeSession {
  instances: number;
  sequence: number;
  lastCameraPosition?: LiveCameraPosition;
  lastSuccessFingerprint?: string;
}

export class RuntimeHarnessAdapter {
  private static readonly sessions: Map<string, RuntimeSession> = new Map<string, RuntimeSession>();
  private readonly runId: string;
  private readonly instance: number;
  private readonly session: RuntimeSession;
  private failurePublished: boolean = false;
  private retryAllowed: boolean = false;
  private recovered: boolean = false;
  private reentrySuccessObserved: boolean = false;
  private restorePublished: boolean = false;
  private failureDueAt: number = 0;

  private constructor(runId: string, instance: number) {
    this.runId = runId;
    this.instance = instance;
    const existing = RuntimeHarnessAdapter.sessions.get(runId);
    this.session = existing ?? { instances: 0, sequence: 0 };
    this.session.instances = instance;
    RuntimeHarnessAdapter.sessions.set(runId, this.session);
  }

  static fromParams(params: object): RuntimeHarnessAdapter | undefined {
    const harness = params as RuntimeHarnessParams;
    const runId = harness.runtimeEvidenceRunId ?? '';
    if (harness.runtimeEvidenceMode !== 'portrait' || runId.length === 0) {
      return undefined;
    }
    const nextInstance = (RuntimeHarnessAdapter.sessions.get(runId)?.instances ?? 0) + 1;
    return new RuntimeHarnessAdapter(runId, nextInstance);
  }

  observeCamera(position: LiveCameraPosition): void {
    if (this.instance > 1 && !this.restorePublished) {
      this.restorePublished = true;
      this.session.lastCameraPosition = position;
      this.emit('camera.restore', `,"cameraPosition":"${position}"`);
      return;
    }
    if (this.session.lastCameraPosition === position) {
      return;
    }
    this.session.lastCameraPosition = position;
    this.emit('camera.position.observed', `,"cameraPosition":"${position}"`);
  }

  allowRetry(): void {
    this.retryAllowed = true;
  }

  async run(
    aiService: DefaultAiService,
    workflow: FeatureWorkflow,
    inputs: AiRunInputs
  ): Promise<AiRunResult> {
    if (workflow.aiMethod !== 'segmentPerson') {
      return aiService.run(workflow, inputs);
    }
    if (this.instance > 1 && this.reentrySuccessObserved && !this.retryAllowed && !this.recovered &&
      (this.failurePublished || Date.now() >= this.failureDueAt)) {
      const failure: AiRunResult = {
        ok: false,
        code: 'SEGMENTATION_FAILED',
        aiMethod: 'segmentPerson',
        messageKey: 'feature_runtime_segmentation_failed',
        detailText: 'Runtime evidence transient segmentation failure.'
      };
      if (!this.failurePublished) {
        this.failurePublished = true;
        this.emit('service.failure',
          `,"errorCode":"${failure.code}","preservedResultFingerprint":"${this.session.lastSuccessFingerprint ?? ''}"`);
      }
      return failure;
    }
    const result = this.syntheticSegmentationResult(inputs);
    const fingerprint = this.resultFingerprint(result);
    this.session.lastSuccessFingerprint = fingerprint;
    if (this.instance > 1 && !this.reentrySuccessObserved) {
      this.reentrySuccessObserved = true;
      this.failureDueAt = Date.now() + 4000;
      return result;
    }
    if (this.instance > 1 && this.retryAllowed) {
      this.retryAllowed = false;
      this.recovered = true;
      this.emit('service.success', `,"resultFingerprint":"${fingerprint}"`);
    }
    return result;
  }

  private syntheticSegmentationResult(inputs: AiRunInputs): AiRunResult {
    const size = 16;
    const rgba = new Uint8Array(size * size * 4);
    for (let offset = 0; offset < rgba.length; offset += 4) {
      const value = (offset / 4) % 2 === 0 ? 72 : 216;
      rgba[offset] = value;
      rgba[offset + 1] = 118;
      rgba[offset + 2] = 255;
      rgba[offset + 3] = 255;
    }
    const rectangle: SegmentationRectangle = { left: 0, top: 0, width: size, height: size };
    const segmentation: SegmentationResult = {
      ok: true,
      subjectCount: 1,
      detailCount: 1,
      foregroundAvailable: true,
      foregroundImageRgba: rgba.buffer as ArrayBuffer,
      foregroundImageWidth: size,
      foregroundImageHeight: size,
      imageWidth: size,
      imageHeight: size,
      rectangles: [rectangle],
      executionMs: 1
    };
    const data: AiSegmentationData = {
      kind: 'segmentation',
      imageUri: inputs.imageUri ?? '',
      backgroundImageUri: inputs.backgroundImageUri ?? '',
      result: segmentation
    };
    const result: AiRunResult = {
      ok: true,
      code: 'SEGMENTATION_DONE',
      aiMethod: 'segmentPerson',
      messageKey: 'feature_runtime_segmentation_done',
      detailText: 'Runtime evidence synthetic portrait segmentation.',
      data: data
    };
    return result;
  }

  private emit(type: string, fields: string): void {
    this.session.sequence += 1;
    const eventId = `${this.runId}-${this.session.sequence}`;
    const payload = `{"runId":"${this.runId}","type":"${type}","eventId":"${eventId}"${fields}}`;
    hilog.info(0, 'MIH_RUNTIME_EVIDENCE', 'MIH_RUNTIME_EVENT %{public}s', payload);
  }

  private resultFingerprint(result: AiRunResult): string {
    if (result.data?.kind !== 'segmentation') {
      return `${result.code}:${result.aiMethod}:${result.data?.kind ?? 'none'}`;
    }
    const segmentation = result.data.result;
    return `${result.code}:${result.data.imageUri}:${result.data.backgroundImageUri}:` +
      `${segmentation.subjectCount}:${segmentation.detailCount}:` +
      `${segmentation.imageWidth ?? 0}x${segmentation.imageHeight ?? 0}:` +
      `${segmentation.foregroundImageWidth ?? 0}x${segmentation.foregroundImageHeight ?? 0}:` +
      `${segmentation.foregroundImageRgba?.byteLength ?? 0}`;
  }
}
