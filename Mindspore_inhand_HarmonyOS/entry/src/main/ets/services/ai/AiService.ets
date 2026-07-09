import { FeatureWorkflow } from '../../features/runtime/FeatureWorkflowCatalog';
import { AppStringKey } from '../../common/i18n/AppStrings';

export type AiFailureCode = 'NATIVE_ADAPTER_PENDING';

export interface AiRunResult {
  readonly ok: boolean;
  readonly code: AiFailureCode;
  readonly aiMethod: string;
  readonly messageKey: AppStringKey;
}

export class DefaultAiService {
  async run(workflow: FeatureWorkflow): Promise<AiRunResult> {
    return {
      ok: false,
      code: 'NATIVE_ADAPTER_PENDING',
      aiMethod: workflow.aiMethod,
      messageKey: 'feature_runtime_pending_adapter'
    };
  }
}
