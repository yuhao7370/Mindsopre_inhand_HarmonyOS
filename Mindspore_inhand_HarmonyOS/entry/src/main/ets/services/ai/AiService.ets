import { FeatureWorkflow } from '../../features/runtime/FeatureWorkflowCatalog';
import { AppStringKey } from '../../common/i18n/AppStrings';

export type AiRunCode =
  'NATIVE_ADAPTER_PENDING' |
  'MISSING_INPUT' |
  'CUSTOM_MODEL_SIMULATED';

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

export class DefaultAiService {
  async run(workflow: FeatureWorkflow, inputs: AiRunInputs = {}): Promise<AiRunResult> {
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

  private runCustomModel(inputs: AiRunInputs): AiRunResult {
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
    return {
      ok: true,
      code: 'CUSTOM_MODEL_SIMULATED',
      aiMethod: 'runCustomModel',
      messageKey: 'feature_runtime_custom_model_done',
      detailText: this.customModelSummary(modelUri, imageUri)
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
