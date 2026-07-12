import { FeatureWorkflow } from '../../features/runtime/FeatureWorkflowCatalog';
import { DefaultAiService } from './AiService';

export type RuntimeAiServiceCreator = () => Promise<DefaultAiService>;

export class RuntimeAiServiceSession {
  private routeName: string = '';
  private servicePromise: Promise<DefaultAiService> | undefined = undefined;

  async getOrCreate(workflow: FeatureWorkflow, creator: RuntimeAiServiceCreator): Promise<DefaultAiService> {
    if (this.servicePromise === undefined || this.routeName !== workflow.routeName) {
      this.routeName = workflow.routeName;
      const created = creator();
      this.servicePromise = created;
      try {
        return await created;
      } catch (_) {
        if (this.servicePromise === created) {
          this.invalidate();
        }
        throw new Error('runtime ai service creation failed');
      }
    }
    return await this.servicePromise;
  }

  invalidate(): void {
    this.routeName = '';
    this.servicePromise = undefined;
  }
}
