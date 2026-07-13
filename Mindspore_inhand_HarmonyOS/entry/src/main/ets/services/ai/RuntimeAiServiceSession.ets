import { FeatureWorkflow } from '../../features/runtime/FeatureWorkflowCatalog';
import { DefaultAiService } from './AiService';

export type RuntimeAiServiceCreator = () => Promise<DefaultAiService>;

export class RuntimeAiServiceSession {
  private routeName: string = '';
  private servicePromise: Promise<DefaultAiService> | undefined = undefined;
  private generation: number = 0;

  async getOrCreate(workflow: FeatureWorkflow, creator: RuntimeAiServiceCreator): Promise<DefaultAiService> {
    if (this.servicePromise !== undefined && this.routeName !== workflow.routeName) {
      this.invalidate();
    }
    if (this.servicePromise === undefined) {
      this.routeName = workflow.routeName;
      const generation = ++this.generation;
      const created = creator();
      this.servicePromise = created;
      try {
        const service = await created;
        if (this.servicePromise !== created || this.generation !== generation) {
          throw new Error('runtime ai service invalidated');
        }
        return service;
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
    const released = this.servicePromise;
    this.routeName = '';
    this.servicePromise = undefined;
    this.generation++;
    if (released !== undefined) {
      released.then(async (service: DefaultAiService) => {
        await service.stop();
      }).catch(() => {});
    }
  }
}
