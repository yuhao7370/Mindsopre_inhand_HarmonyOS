import { FeatureWorkflow } from '../../features/runtime/FeatureWorkflowCatalog';
import { AppStringKey } from '../../common/i18n/AppStrings';
import {
  ImageClassificationResult,
  ImageClassificationRunResult,
  ImageClassificationService
} from './ImageClassificationService';
import { CustomModelRunResult, CustomModelService } from './CustomModelService';
import {
  ObjectDetection,
  ObjectDetectionRunResult,
  ObjectDetectionService
} from './ObjectDetectionService';
import {
  StyleTransferResult,
  StyleTransferService
} from './StyleTransferService';

export type AiRunCode =
  'NATIVE_ADAPTER_PENDING' |
  'MISSING_INPUT' |
  'CUSTOM_MODEL_SIMULATED' |
  'CUSTOM_MODEL_DONE' |
  'CUSTOM_MODEL_FAILED' |
  'CLASSIFICATION_MODEL_PENDING' |
  'CLASSIFICATION_DONE' |
  'CLASSIFICATION_FAILED' |
  'OBJECT_DETECTION_DONE' |
  'OBJECT_DETECTION_FAILED' |
  'STYLE_TRANSFER_DONE' |
  'STYLE_TRANSFER_FAILED';

export interface AiRunInputs {
  readonly imageUri?: string;
  readonly contentImageUri?: string;
  readonly styleImageUri?: string;
  readonly modelUri?: string;
  readonly text?: string;
}

export interface AiRunResult {
  readonly ok: boolean;
  readonly code: AiRunCode;
  readonly aiMethod: string;
  readonly messageKey: AppStringKey;
  readonly detailText: string;
}

export interface AiServiceOptions {
  readonly imageClassificationService?: ImageClassificationService;
  readonly customModelService?: CustomModelService;
  readonly objectDetectionService?: ObjectDetectionService;
  readonly styleTransferService?: StyleTransferService;
}

export class DefaultAiService {
  private readonly imageClassificationService: ImageClassificationService;
  private readonly customModelService?: CustomModelService;
  private readonly objectDetectionService?: ObjectDetectionService;
  private readonly styleTransferService?: StyleTransferService;

  constructor(options?: AiServiceOptions) {
    this.imageClassificationService = options?.imageClassificationService ?? new ImageClassificationService({
      labels: []
    });
    this.customModelService = options?.customModelService;
    this.objectDetectionService = options?.objectDetectionService;
    this.styleTransferService = options?.styleTransferService;
  }

  async run(workflow: FeatureWorkflow, inputs: AiRunInputs = {}): Promise<AiRunResult> {
    if (workflow.aiMethod === 'classifyImage') {
      return this.classifyImage(inputs);
    }
    if (workflow.aiMethod === 'detectObjects') {
      return this.detectObjects(inputs);
    }
    if (workflow.aiMethod === 'runStyleTransfer') {
      return this.runStyleTransfer(inputs);
    }
    if (workflow.aiMethod === 'runCustomModel') {
      return this.runCustomModel(inputs);
    }
    return {
      ok: false,
      code: 'NATIVE_ADAPTER_PENDING',
      aiMethod: workflow.aiMethod,
      messageKey: 'feature_runtime_pending_adapter',
      detailText: ''
    };
  }

  private async runStyleTransfer(inputs: AiRunInputs): Promise<AiRunResult> {
    if (this.styleTransferService === undefined) {
      return {
        ok: false,
        code: 'NATIVE_ADAPTER_PENDING',
        aiMethod: 'runStyleTransfer',
        messageKey: 'feature_runtime_pending_adapter',
        detailText: ''
      };
    }

    const contentImageUri = inputs.contentImageUri ?? '';
    const styleImageUri = inputs.styleImageUri ?? '';
    if (contentImageUri.length === 0 || styleImageUri.length === 0) {
      return {
        ok: false,
        code: 'MISSING_INPUT',
        aiMethod: 'runStyleTransfer',
        messageKey: 'feature_runtime_missing_input',
        detailText: ''
      };
    }

    const result = await this.styleTransferService.run(contentImageUri, styleImageUri);
    if (!result.ok) {
      return {
        ok: false,
        code: 'STYLE_TRANSFER_FAILED',
        aiMethod: 'runStyleTransfer',
        messageKey: 'feature_runtime_style_transfer_failed',
        detailText: this.styleTransferSummary(result, contentImageUri, styleImageUri)
      };
    }
    return {
      ok: true,
      code: 'STYLE_TRANSFER_DONE',
      aiMethod: 'runStyleTransfer',
      messageKey: 'feature_runtime_style_transfer_done',
      detailText: this.styleTransferSummary(result, contentImageUri, styleImageUri)
    };
  }

  private async detectObjects(inputs: AiRunInputs): Promise<AiRunResult> {
    if (this.objectDetectionService === undefined) {
      return {
        ok: false,
        code: 'NATIVE_ADAPTER_PENDING',
        aiMethod: 'detectObjects',
        messageKey: 'feature_runtime_pending_adapter',
        detailText: ''
      };
    }

    const imageUri = inputs.imageUri ?? '';
    if (imageUri.length === 0) {
      return {
        ok: false,
        code: 'MISSING_INPUT',
        aiMethod: 'detectObjects',
        messageKey: 'feature_runtime_missing_input',
        detailText: ''
      };
    }

    const result: ObjectDetectionRunResult =
      await this.objectDetectionService.detectObjects(imageUri, inputs.modelUri);
    if (result.ok) {
      return {
        ok: true,
        code: 'OBJECT_DETECTION_DONE',
        aiMethod: 'detectObjects',
        messageKey: 'feature_runtime_object_detection_done',
        detailText: this.objectDetectionSummary(result.detections, imageUri, inputs.modelUri ?? '')
      };
    }
    return {
      ok: false,
      code: 'OBJECT_DETECTION_FAILED',
      aiMethod: 'detectObjects',
      messageKey: 'feature_runtime_object_detection_failed',
      detailText: this.objectDetectionFailureSummary(result, imageUri, inputs.modelUri ?? '')
    };
  }

  private async classifyImage(inputs: AiRunInputs): Promise<AiRunResult> {
    const imageUri = inputs.imageUri ?? '';
    if (imageUri.length === 0) {
      return {
        ok: false,
        code: 'MISSING_INPUT',
        aiMethod: 'classifyImage',
        messageKey: 'feature_runtime_missing_input',
        detailText: ''
      };
    }

    const result: ImageClassificationRunResult = await this.imageClassificationService.classifyImage(imageUri);
    if (result.code === 'MODEL_PENDING') {
      return {
        ok: false,
        code: 'CLASSIFICATION_MODEL_PENDING',
        aiMethod: 'classifyImage',
        messageKey: 'feature_runtime_classification_pending',
        detailText: ''
      };
    }
    if (result.ok) {
      return {
        ok: true,
        code: 'CLASSIFICATION_DONE',
        aiMethod: 'classifyImage',
        messageKey: 'feature_runtime_classification_done',
        detailText: this.imageClassificationSummary(result.classification, imageUri)
      };
    }
    return {
      ok: false,
      code: 'CLASSIFICATION_FAILED',
      aiMethod: 'classifyImage',
      messageKey: 'feature_runtime_classification_failed',
      detailText: this.imageClassificationFailureSummary(result, imageUri)
    };
  }

  private async runCustomModel(inputs: AiRunInputs): Promise<AiRunResult> {
    const modelUri = inputs.modelUri ?? '';
    const imageUri = inputs.imageUri ?? '';
    if (modelUri.length === 0 || imageUri.length === 0) {
      return {
        ok: false,
        code: 'MISSING_INPUT',
        aiMethod: 'runCustomModel',
        messageKey: 'feature_runtime_missing_input',
        detailText: ''
      };
    }
    if (this.customModelService !== undefined) {
      return this.runCustomModelWithService(this.customModelService, modelUri, imageUri);
    }
    return {
      ok: true,
      code: 'CUSTOM_MODEL_SIMULATED',
      aiMethod: 'runCustomModel',
      messageKey: 'feature_runtime_custom_model_done',
      detailText: this.customModelSummary(modelUri, imageUri)
    };
  }

  private async runCustomModelWithService(
    service: CustomModelService,
    modelUri: string,
    imageUri: string
  ): Promise<AiRunResult> {
    try {
      const result = await service.run(modelUri, imageUri);
      if (!result.ok) {
        return this.customModelFailedResult(modelUri, imageUri);
      }
      return {
        ok: true,
        code: 'CUSTOM_MODEL_DONE',
        aiMethod: 'runCustomModel',
        messageKey: 'feature_runtime_custom_model_done',
        detailText: this.customModelExecutionSummary(result)
      };
    } catch (_) {
      return this.customModelFailedResult(modelUri, imageUri);
    }
  }

  private customModelFailedResult(modelUri: string, imageUri: string): AiRunResult {
    return {
      ok: false,
      code: 'CUSTOM_MODEL_FAILED',
      aiMethod: 'runCustomModel',
      messageKey: 'feature_runtime_custom_model_failed',
      detailText: `model=${this.lastPathSegment(modelUri)}\nimage=${this.lastPathSegment(imageUri)}`
    };
  }

  private customModelSummary(modelUri: string, imageUri: string): string {
    const seed = this.seedForInputs(modelUri, imageUri);
    const lines: Array<string> = [
      `model=${this.lastPathSegment(modelUri)}`,
      `image=${this.lastPathSegment(imageUri)}`,
      'executionMs=100'
    ];
    for (let index = 0; index < 10; index++) {
      const value = ((seed + (index + 1) * 7919) % 100000) / 100000;
      lines.push(`output[${index}]=${value.toFixed(6)}`);
    }
    return lines.join('\n');
  }

  private customModelExecutionSummary(result: CustomModelRunResult): string {
    const lines: Array<string> = [
      'Model execution completed!',
      '',
      `Execution time: ${result.executionMs}ms`,
      '',
      'Output data (first 10 values):'
    ];
    const displayCount = Math.min(10, result.output.length);
    for (let index = 0; index < displayCount; index++) {
      lines.push(`Value[${index}]: ${result.output[index].toFixed(6)}`);
    }
    if (result.output.length > 10) {
      lines.push('... (showing first 10 values)');
    }
    return lines.join('\n');
  }

  private imageClassificationSummary(classification: ImageClassificationResult, imageUri: string): string {
    const lines: Array<string> = [
      `label=${classification.label}`,
      `score=${classification.score.toFixed(6)}`,
      `index=${classification.index}`,
      `image=${this.lastPathSegment(imageUri)}`
    ];
    return lines.join('\n');
  }

  private imageClassificationFailureSummary(result: ImageClassificationRunResult, imageUri: string): string {
    const lines: Array<string> = [
      `image=${this.lastPathSegment(imageUri)}`,
      `reason=${result.code}`,
      `index=${result.classification.index}`,
      `score=${result.classification.score.toFixed(6)}`
    ];
    return lines.join('\n');
  }

  private objectDetectionSummary(detections: Array<ObjectDetection>, imageUri: string, modelUri: string): string {
    const lines: Array<string> = [
      `image=${this.lastPathSegment(imageUri)}`
    ];
    if (modelUri.length > 0) {
      lines.push(`model=${this.lastPathSegment(modelUri)}`);
    }
    lines.push(`detections=${detections.length}`);
    detections.forEach((detection: ObjectDetection, index: number) => {
      const label = detection.label.length > 0 ? detection.label : `${detection.labelId}`;
      lines.push(`${index + 1}. ${label} ${(detection.score * 100).toFixed(2)}% ` +
        `[${detection.left.toFixed(0)},${detection.top.toFixed(0)},` +
        `${detection.right.toFixed(0)},${detection.bottom.toFixed(0)}]`);
    });
    return lines.join('\n');
  }

  private objectDetectionFailureSummary(
    result: ObjectDetectionRunResult,
    imageUri: string,
    modelUri: string
  ): string {
    const lines: Array<string> = [
      `image=${this.lastPathSegment(imageUri)}`,
      `reason=${result.code}`
    ];
    if (modelUri.length > 0) {
      lines.push(`model=${this.lastPathSegment(modelUri)}`);
    }
    return lines.join('\n');
  }

  private styleTransferSummary(
    result: StyleTransferResult,
    contentImageUri: string,
    styleImageUri: string
  ): string {
    const lines: Array<string> = [
      `content=${this.lastPathSegment(contentImageUri)}`,
      `style=${this.lastPathSegment(styleImageUri)}`,
      `outputFloats=${result.outputFloatCount}`,
      `predictMs=${result.predictMs}`,
      `transferMs=${result.transferMs}`,
      `executionMs=${result.executionMs}`
    ];
    return lines.join('\n');
  }

  private seedForInputs(modelUri: string, imageUri: string): number {
    const source = `${modelUri}|${imageUri}`;
    let seed = 17;
    for (let index = 0; index < source.length; index++) {
      seed = (seed * 31 + source.charCodeAt(index)) % 100000;
    }
    return seed;
  }

  private lastPathSegment(uri: string): string {
    const normalized = uri.split('\\').join('/');
    const parts = normalized.split('/');
    if (parts.length === 0) {
      return uri;
    }
    return parts[parts.length - 1];
  }
}
