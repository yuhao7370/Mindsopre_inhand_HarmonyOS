import { resourceManager } from '@kit.LocalizationKit';
import { FeatureWorkflow } from '../../features/runtime/FeatureWorkflowCatalog';
import { DefaultAiService } from './AiService';
import {
  CustomModelDefaultOrSelectedRunner,
  CustomModelInputPreprocessor,
  CustomModelRawfileRunner,
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
  ImageClassificationGestureRunner,
  GestureRunner,
  GestureService
} from './GestureService';
import {
  ImageClassificationSceneDetectionRunner,
  SceneDetectionRunner,
  SceneDetectionService
} from './SceneDetectionService';
import {
  HarmonyTextRecognitionRunner,
  LocalTextTranslationRunner,
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
  readonly sceneDetectionRunner?: SceneDetectionRunner;
}

let cachedHarmonyDefaultAiService: Promise<DefaultAiService> | undefined = undefined;
let cachedHarmonyLocalGestureAiService: Promise<DefaultAiService> | undefined = undefined;
let cachedHarmonyLocalSceneDetectionAiService: Promise<DefaultAiService> | undefined = undefined;

export function resetHarmonyRuntimeAiServiceCachesForTests(): void {
  cachedHarmonyDefaultAiService = undefined;
  cachedHarmonyLocalGestureAiService = undefined;
  cachedHarmonyLocalSceneDetectionAiService = undefined;
}

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

export function cachedHarmonyLocalSceneDetectionAiServiceForResourceManager(
  resourceManager: RawfileContentReader
): Promise<DefaultAiService> {
  if (cachedHarmonyLocalSceneDetectionAiService === undefined) {
    cachedHarmonyLocalSceneDetectionAiService = createHarmonyLocalSceneDetectionAiService(resourceManager);
  }
  return cachedHarmonyLocalSceneDetectionAiService;
}

export function cachedHarmonyLocalGestureAiServiceForResourceManager(
  resourceManager: RawfileContentReader
): Promise<DefaultAiService> {
  if (cachedHarmonyLocalGestureAiService === undefined) {
    const servicePromise = createHarmonyLocalGestureAiService(resourceManager);
    cachedHarmonyLocalGestureAiService = servicePromise;
    servicePromise.catch(() => {
      if (cachedHarmonyLocalGestureAiService === servicePromise) {
        cachedHarmonyLocalGestureAiService = undefined;
      }
    });
  }
  return cachedHarmonyLocalGestureAiService;
}

async function createHarmonyLocalGestureAiService(
  resourceManager: RawfileContentReader
): Promise<DefaultAiService> {
  return new DefaultAiService({
    gestureService: await createHarmonyLocalGestureService({
      resourceManager: resourceManager
    })
  });
}

async function createHarmonyLocalSceneDetectionAiService(
  resourceManager: RawfileContentReader
): Promise<DefaultAiService> {
  return new DefaultAiService({
    sceneDetectionService: await createHarmonyLocalSceneDetectionService({
      resourceManager: resourceManager
    })
  });
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
    return cachedHarmonyLocalGestureAiServiceForResourceManager(resourceManager);
  }
  if (workflow.aiMethod === 'detectScene') {
    return cachedHarmonyLocalSceneDetectionAiServiceForResourceManager(resourceManager);
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
    return new DefaultAiService({
      textRecognitionService: createHarmonyTextRecognitionService(options),
      textTranslationService: createHarmonyTextTranslationService(options)
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
    return new DefaultAiService({
      gestureService: await createHarmonyLocalGestureService(options)
    });
  }
  if (workflow.aiMethod === 'detectScene') {
    if (options.sceneDetectionRunner !== undefined) {
      return new DefaultAiService({
        sceneDetectionService: createHarmonySceneDetectionService(options.sceneDetectionRunner)
      });
    }
    return new DefaultAiService({
      sceneDetectionService: await createHarmonyLocalSceneDetectionService(options)
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
    tensorRunner: options.customModelTensorRunner ?? new CustomModelDefaultOrSelectedRunner({
      defaultModelRunner: new CustomModelRawfileRunner({
        resourceManager: options.resourceManager,
        modelRawfilePath: imageClassificationModelRawfilePath
      }),
      selectedModelRunner: new CustomModelSelectedFileRunner()
    })
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
    runner: options.textTranslationRunner ?? new LocalTextTranslationRunner()
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
    runner: options.poseRunner ?? new HarmonySkeletonDetectionRunner({
      resourceManager: options.resourceManager
    })
  });
}

export function createHarmonyGestureService(runner: GestureRunner): GestureService {
  return new GestureService({
    runner: runner
  });
}

export async function createHarmonyLocalGestureService(
  options: HarmonyImageClassificationRuntimeOptions
): Promise<GestureService> {
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
  return new GestureService({
    runner: new ImageClassificationGestureRunner({
      labels: labels,
      scoreRunner: scoreRunner
    })
  });
}

export function createHarmonySceneDetectionService(runner: SceneDetectionRunner): SceneDetectionService {
  return new SceneDetectionService({
    runner: runner
  });
}

export async function createHarmonyLocalSceneDetectionService(
  options: HarmonyImageClassificationRuntimeOptions
): Promise<SceneDetectionService> {
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
  return new SceneDetectionService({
    runner: new ImageClassificationSceneDetectionRunner({
      labels: labels,
      scoreRunner: scoreRunner
    })
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
