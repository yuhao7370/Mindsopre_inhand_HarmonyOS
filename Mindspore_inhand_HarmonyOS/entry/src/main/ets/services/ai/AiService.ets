import { FeatureWorkflow } from '../../features/runtime/FeatureWorkflowCatalog';
import { AppStringKey } from '../../common/i18n/AppStrings';
import {
  ImageClassificationResult,
  ImageClassificationRunResult,
  ImageClassificationService
} from './ImageClassificationService';
import { CustomModelRunResult, CustomModelService } from './CustomModelService';

export type AiRunCode =
  'NATIVE_ADAPTER_PENDING' |
  'MISSING_INPUT' |
  'CUSTOM_MODEL_SIMULATED' |
  'CUSTOM_MODEL_DONE' |
  'CUSTOM_MODEL_FAILED' |
  'CLASSIFICATION_MODEL_PENDING' |
  'CLASSIFICATION_DONE' |
  'CLASSIFICATION_FAILED';

export interface AiRunInputs {
  readonly imageUri?: string;
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
}

export class DefaultAiService {
  private readonly imageClassificationService: ImageClassificationService;
  private readonly customModelService?: CustomModelService;

  constructor(options?: AiServiceOptions) {
    this.imageClassificationService = options?.imageClassificationService ?? new ImageClassificationService({
      labels: []
    });
    this.customModelService = options?.customModelService;
  }

  async run(workflow: FeatureWorkflow, inputs: AiRunInputs = {}): Promise<AiRunResult> {
    if (workflow.aiMethod === 'classifyImage') {
      return this.classifyImage(inputs);
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
