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
import { HarmonyObjectDetectionInputPreprocessor } from './HarmonyObjectDetectionInputPreprocessor';
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
import {
  StyleTransferRunner,
  StyleTransferService
} from './StyleTransferService';
import {
  MindSporeLiteObjectDetectionTensorRunner,
  objectCategoryLabelRawfilePath,
  objectDetectionModelRawfilePath,
  ObjectDetectionInputPreprocessor,
  ObjectDetectionMindSporeRunner,
  ObjectDetectionRunner,
  ObjectDetectionService,
  ObjectDetectionTensorRunner,
  parseObjectCategoryLabels
} from './ObjectDetectionService';
import { MindSporeLiteModelRunner, RawfileContentReader } from './MindSporeLiteModelRunner';

export interface HarmonyImageClassificationRuntimeOptions {
  readonly resourceManager: RawfileContentReader;
  readonly inputPreprocessor?: ImageClassificationInputPreprocessor;
  readonly tensorRunner?: ImageClassificationTensorRunner;
  readonly customModelPreprocessor?: CustomModelInputPreprocessor;
  readonly customModelTensorRunner?: CustomModelTensorRunner;
  readonly objectDetectionPreprocessor?: ObjectDetectionInputPreprocessor;
  readonly objectDetectionRunner?: ObjectDetectionRunner;
  readonly objectDetectionTensorRunner?: ObjectDetectionTensorRunner;
  readonly styleTransferRunner?: StyleTransferRunner;
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
  if (workflow.aiMethod === 'detectObjects') {
    return createRuntimeAiServiceForWorkflow(workflow, {
      resourceManager: resourceManager
    });
  }
  if (workflow.aiMethod === 'runStyleTransfer') {
    return createRuntimeAiServiceForWorkflow(workflow, {
      resourceManager: resourceManager
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
  if (workflow.aiMethod === 'detectObjects') {
    const objectDetectionService = await createHarmonyObjectDetectionService(options);
    return new DefaultAiService({
      objectDetectionService: objectDetectionService
    });
  }
  if (workflow.aiMethod === 'runStyleTransfer') {
    return new DefaultAiService({
      styleTransferService: createHarmonyStyleTransferService(options)
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

export async function createHarmonyObjectDetectionService(
  options: HarmonyImageClassificationRuntimeOptions
): Promise<ObjectDetectionService> {
  const labels = await loadObjectDetectionLabels(options.resourceManager);
  const runner = options.objectDetectionRunner ?? createHarmonyObjectDetectionRunner(options);
  return new ObjectDetectionService({
    labels: labels,
    runner: runner
  });
}

export function createHarmonyObjectDetectionRunner(
  options: HarmonyImageClassificationRuntimeOptions
): ObjectDetectionRunner {
  return new ObjectDetectionMindSporeRunner({
    preprocessor: options.objectDetectionPreprocessor ?? new HarmonyObjectDetectionInputPreprocessor(),
    tensorRunner: options.objectDetectionTensorRunner ?? new MindSporeLiteObjectDetectionTensorRunner({
      resourceManager: options.resourceManager,
      modelRawfilePath: objectDetectionModelRawfilePath
    })
  });
}

export function createHarmonyStyleTransferService(
  options: HarmonyImageClassificationRuntimeOptions
): StyleTransferService {
  return new StyleTransferService({
    runner: options.styleTransferRunner
  });
}

export async function loadImageClassificationLabels(resourceManager: RawfileContentReader): Promise<Array<string>> {
  const content = await resourceManager.getRawFileContent(imageCategoryLabelRawfilePath);
  return parseImageCategoryLabels(rawfileAsciiContentToText(content));
}

export async function loadObjectDetectionLabels(resourceManager: RawfileContentReader): Promise<Array<string>> {
  const content = await resourceManager.getRawFileContent(objectCategoryLabelRawfilePath);
  return parseObjectCategoryLabels(rawfileAsciiContentToText(content));
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
