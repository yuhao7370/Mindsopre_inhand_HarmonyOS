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
      this.generation++;
      this.servicePromise = creator();
    }
    const pending = this.servicePromise;
    const generation = this.generation;
    const routeName = this.routeName;
    try {
      const service = await pending;
      if (this.servicePromise !== pending || this.generation !== generation ||
        this.routeName !== routeName || routeName !== workflow.routeName) {
        throw new Error('runtime ai service invalidated');
      }
      return service;
    } catch (_) {
      if (this.servicePromise === pending && this.generation === generation && this.routeName === routeName) {
        this.invalidate();
      }
      throw new Error('runtime ai service creation failed');
    }
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
