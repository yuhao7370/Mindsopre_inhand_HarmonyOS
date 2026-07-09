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
import { HarmonyStyleTransferInputPreprocessor } from './HarmonyStyleTransferInputPreprocessor';
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
  MindSporeLiteStyleTransferTensorRunner,
  StyleTransferRunner,
  StyleTransferService,
  StyleTransferInputPreprocessor,
  StyleTransferMindSporeRunner,
  StyleTransferTensorRunner,
  stylePredictModelRawfilePath,
  styleTransferModelRawfilePath
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
import {
  HarmonySubjectSegmentationRunner,
  SegmentationRunner,
  SegmentationService
} from './SegmentationService';
import {
  HarmonySkeletonDetectionRunner,
  PoseRunner,
  PoseService
} from './PoseService';
import {
  GestureRunner,
  GestureService
} from './GestureService';
import {
  HarmonyTextRecognitionRunner,
  TextRecognitionRunner,
  TextRecognitionService,
  TextTranslationRunner,
  TextTranslationService
} from './TextRecognitionService';

export interface HarmonyImageClassificationRuntimeOptions {
  readonly resourceManager: RawfileContentReader;
  readonly inputPreprocessor?: ImageClassificationInputPreprocessor;
  readonly tensorRunner?: ImageClassificationTensorRunner;
  readonly customModelPreprocessor?: CustomModelInputPreprocessor;
  readonly customModelTensorRunner?: CustomModelTensorRunner;
  readonly objectDetectionPreprocessor?: ObjectDetectionInputPreprocessor;
  readonly objectDetectionRunner?: ObjectDetectionRunner;
  readonly objectDetectionTensorRunner?: ObjectDetectionTensorRunner;
  readonly styleTransferPreprocessor?: StyleTransferInputPreprocessor;
  readonly styleTransferRunner?: StyleTransferRunner;
  readonly styleTransferTensorRunner?: StyleTransferTensorRunner;
  readonly textRecognitionRunner?: TextRecognitionRunner;
  readonly textTranslationRunner?: TextTranslationRunner;
  readonly segmentationRunner?: SegmentationRunner;
  readonly poseRunner?: PoseRunner;
  readonly gestureRunner?: GestureRunner;
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
  if (workflow.aiMethod === 'recognizeText') {
    return createRuntimeAiServiceForWorkflow(workflow, {
      resourceManager: resourceManager
    });
  }
  if (workflow.aiMethod === 'translateText') {
    return createRuntimeAiServiceForWorkflow(workflow, {
      resourceManager: resourceManager
    });
  }
  if (workflow.aiMethod === 'segmentPerson') {
    return createRuntimeAiServiceForWorkflow(workflow, {
      resourceManager: resourceManager
    });
  }
  if (workflow.aiMethod === 'detectPose') {
    return createRuntimeAiServiceForWorkflow(workflow, {
      resourceManager: resourceManager
    });
  }
  if (workflow.aiMethod === 'detectGesture') {
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
  if (workflow.aiMethod === 'recognizeText') {
    return new DefaultAiService({
      textRecognitionService: createHarmonyTextRecognitionService(options)
    });
  }
  if (workflow.aiMethod === 'translateText') {
    if (options.textTranslationRunner !== undefined) {
      return new DefaultAiService({
        textRecognitionService: createHarmonyTextRecognitionService(options),
        textTranslationService: createHarmonyTextTranslationService(options)
      });
    }
    return new DefaultAiService({
      textRecognitionService: createHarmonyTextRecognitionService(options)
    });
  }
  if (workflow.aiMethod === 'segmentPerson') {
    return new DefaultAiService({
      segmentationService: createHarmonySegmentationService(options)
    });
  }
  if (workflow.aiMethod === 'detectPose') {
    return new DefaultAiService({
      poseService: createHarmonyPoseService(options)
    });
  }
  if (workflow.aiMethod === 'detectGesture') {
    if (options.gestureRunner !== undefined) {
      return new DefaultAiService({
        gestureService: createHarmonyGestureService(options.gestureRunner)
      });
    }
    return new DefaultAiService();
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
  const runner = options.styleTransferRunner ?? createHarmonyStyleTransferRunner(options);
  return new StyleTransferService({
    runner: runner
  });
}

export function createHarmonyStyleTransferRunner(
  options: HarmonyImageClassificationRuntimeOptions
): StyleTransferRunner {
  return new StyleTransferMindSporeRunner({
    preprocessor: options.styleTransferPreprocessor ?? new HarmonyStyleTransferInputPreprocessor({
      resourceManager: options.resourceManager
    }),
    tensorRunner: options.styleTransferTensorRunner ?? new MindSporeLiteStyleTransferTensorRunner({
      resourceManager: options.resourceManager,
      predictModelRawfilePath: stylePredictModelRawfilePath,
      transferModelRawfilePath: styleTransferModelRawfilePath
    })
  });
}

export function createHarmonyTextRecognitionService(
  options: HarmonyImageClassificationRuntimeOptions
): TextRecognitionService {
  return new TextRecognitionService({
    runner: options.textRecognitionRunner ?? new HarmonyTextRecognitionRunner()
  });
}

export function createHarmonyTextTranslationService(
  options: HarmonyImageClassificationRuntimeOptions
): TextTranslationService {
  return new TextTranslationService({
    runner: options.textTranslationRunner!
  });
}

export function createHarmonySegmentationService(
  options: HarmonyImageClassificationRuntimeOptions
): SegmentationService {
  return new SegmentationService({
    runner: options.segmentationRunner ?? new HarmonySubjectSegmentationRunner()
  });
}

export function createHarmonyPoseService(
  options: HarmonyImageClassificationRuntimeOptions
): PoseService {
  return new PoseService({
    runner: options.poseRunner ?? new HarmonySkeletonDetectionRunner()
  });
}

export function createHarmonyGestureService(runner: GestureRunner): GestureService {
  return new GestureService({
    runner: runner
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
