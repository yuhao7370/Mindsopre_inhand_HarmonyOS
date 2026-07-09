import { resourceManager } from '@kit.LocalizationKit';
import { FeatureWorkflow } from '../../features/runtime/FeatureWorkflowCatalog';
import { DefaultAiService } from './AiService';
import {
  CustomModelInputPreprocessor,
  CustomModelSelectedFileRunner,
  CustomModelService,
  CustomModelTensorRunner
} from './CustomModelService';
import { HarmonyCustomModelInputPreprocessor } from './HarmonyCustomModelInputPreprocessor';
import { HarmonyImageClassificationInputPreprocessor } from './HarmonyImageInputPreprocessor';
import {
  ImageClassificationInputPreprocessor,
  ImageClassificationMindSporeScoreRunner,
  ImageClassificationTensorRunner
} from './ImageClassificationPipeline';
import {
  imageCategoryLabelRawfilePath,
  imageClassificationModelRawfilePath,
  ImageClassificationService,
  parseImageCategoryLabels
} from './ImageClassificationService';
import { MindSporeLiteModelRunner, RawfileContentReader } from './MindSporeLiteModelRunner';

export interface HarmonyImageClassificationRuntimeOptions {
  readonly resourceManager: RawfileContentReader;
  readonly inputPreprocessor?: ImageClassificationInputPreprocessor;
  readonly tensorRunner?: ImageClassificationTensorRunner;
  readonly customModelPreprocessor?: CustomModelInputPreprocessor;
  readonly customModelTensorRunner?: CustomModelTensorRunner;
}

let cachedHarmonyDefaultAiService: Promise<DefaultAiService> | undefined = undefined;

export class HarmonyRawfileContentReader implements RawfileContentReader {
  private readonly resourceManager: resourceManager.ResourceManager;

  constructor(resourceManager: resourceManager.ResourceManager) {
    this.resourceManager = resourceManager;
  }

  async getRawFileContent(path: string): Promise<Uint8Array> {
    return this.resourceManager.getRawFileContent(path);
  }
}

export function cachedHarmonyDefaultAiServiceForResourceManager(
  resourceManager: RawfileContentReader
): Promise<DefaultAiService> {
  if (cachedHarmonyDefaultAiService === undefined) {
    cachedHarmonyDefaultAiService = createHarmonyDefaultAiService({
      resourceManager: resourceManager
    });
  }
  return cachedHarmonyDefaultAiService;
}

export function cachedRuntimeAiServiceForHarmonyResourceManager(
  workflow: FeatureWorkflow,
  manager: resourceManager.ResourceManager
): Promise<DefaultAiService> {
  return cachedRuntimeAiServiceForWorkflow(workflow, new HarmonyRawfileContentReader(manager));
}

export async function cachedRuntimeAiServiceForWorkflow(
  workflow: FeatureWorkflow,
  resourceManager: RawfileContentReader
): Promise<DefaultAiService> {
  if (workflow.aiMethod === 'classifyImage') {
    return cachedHarmonyDefaultAiServiceForResourceManager(resourceManager);
  }
  if (workflow.aiMethod === 'runCustomModel') {
    return new DefaultAiService({
      customModelService: createHarmonyCustomModelService({
        resourceManager: resourceManager
      })
    });
  }
  return new DefaultAiService();
}

export async function createRuntimeAiServiceForWorkflow(
  workflow: FeatureWorkflow,
  options: HarmonyImageClassificationRuntimeOptions
): Promise<DefaultAiService> {
  if (workflow.aiMethod === 'classifyImage') {
    return createHarmonyDefaultAiService(options);
  }
  if (workflow.aiMethod === 'runCustomModel') {
    return new DefaultAiService({
      customModelService: createHarmonyCustomModelService(options)
    });
  }
  return new DefaultAiService();
}

export async function createHarmonyDefaultAiService(
  options: HarmonyImageClassificationRuntimeOptions
): Promise<DefaultAiService> {
  const imageClassificationService = await createHarmonyImageClassificationService(options);
  return new DefaultAiService({
    imageClassificationService: imageClassificationService
  });
}

export async function createHarmonyImageClassificationService(
  options: HarmonyImageClassificationRuntimeOptions
): Promise<ImageClassificationService> {
  const labels = await loadImageClassificationLabels(options.resourceManager);
  const tensorRunner = options.tensorRunner ?? new MindSporeLiteModelRunner({
    resourceManager: options.resourceManager,
    modelRawfilePath: imageClassificationModelRawfilePath
  });
  const preprocessor = options.inputPreprocessor ?? new HarmonyImageClassificationInputPreprocessor();
  const scoreRunner = new ImageClassificationMindSporeScoreRunner({
    preprocessor: preprocessor,
    tensorRunner: tensorRunner
  });
  return new ImageClassificationService({
    labels: labels,
    scoreRunner: scoreRunner
  });
}

export function createHarmonyCustomModelService(
  options: HarmonyImageClassificationRuntimeOptions
): CustomModelService {
  return new CustomModelService({
    preprocessor: options.customModelPreprocessor ?? new HarmonyCustomModelInputPreprocessor(),
    tensorRunner: options.customModelTensorRunner ?? new CustomModelSelectedFileRunner()
  });
}

export async function loadImageClassificationLabels(resourceManager: RawfileContentReader): Promise<Array<string>> {
  const content = await resourceManager.getRawFileContent(imageCategoryLabelRawfilePath);
  return parseImageCategoryLabels(rawfileAsciiContentToText(content));
}

export function rawfileAsciiContentToText(content: Uint8Array): string {
  const chunks: Array<string> = [];
  let chunk = '';
  for (let index = 0; index < content.length; index++) {
    chunk += String.fromCharCode(content[index]);
    if (chunk.length >= 1024) {
      chunks.push(chunk);
      chunk = '';
    }
  }
  if (chunk.length > 0) {
    chunks.push(chunk);
  }
  return chunks.join('');
}
