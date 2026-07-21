import { i18n, resourceManager } from '@kit.LocalizationKit';
import { AppRoute } from '../../app/AppRoutes';
import { FeatureWorkflow, poseModeForWorkflow } from '../../features/runtime/FeatureWorkflowCatalog';
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
  LocalMnnStyleTransferTensorRunner,
  StyleTransferRunner,
  StyleTransferService,
  StyleTransferInputPreprocessor,
  StyleTransferMindSporeRunner,
  StyleTransferTensorRunner,
  stylePredictModelRawfilePath,
  styleTransferModelRawfilePath
} from './StyleTransferService';
import {
  LocalMnnObjectDetectionRunner,
  objectCategoryLabelRawfilePath,
  objectDetectionModelRawfilePath,
  ObjectDetectionInputPreprocessor,
  ObjectDetectionMindSporeRunner,
  ObjectDetectionRunner,
  ObjectDetectionService,
  ObjectDetectionTensorRunner,
  parseObjectCategoryLabels
} from './ObjectDetectionService';
import {
  imageClassificationScoresFromOutputTensor,
  MindSporeLiteModelRunner,
  RawfileContentReader
} from './MindSporeLiteModelRunner';
import {
  MindSporeLiteTranslationRunner,
  productionTranslationModelBundleFactory,
  resetTranslationModelCacheForTests,
  TranslationModelBundleFactory,
  TranslationModelResourceManager,
  TranslationRawFileDescriptor,
  TranslationProductionBundleOptions
} from './MindSporeLiteTranslationRunner';
import { TranslationWorkerClient } from './TranslationWorkerClient';
import {
  CoreVisionFallbackSegmentationRunner,
  HarmonySubjectSegmentationRunner,
  LocalMnnSegmentationRunner,
  SegmentationAndroidScene,
  SegmentationRunner,
  SegmentationService
} from './SegmentationService';
import {
  CoreVisionFallbackPoseRunner,
  HarmonySkeletonDetectionRunner,
  LocalMoveNetPoseRunner,
  moveNetModelRawfilePath,
  PoseRunner,
  PoseService
} from './PoseService';
import {
  AndroidGestureModelDetector,
  AndroidGestureModelRunner,
  HarmonyGestureRegionEstimator,
  ImageClassificationGestureRunner,
  GestureRegionEstimator,
  GestureRunner,
  GestureService
} from './GestureService';
import {
  HmsGestureImageLoader,
  HmsGestureModelDetector,
  hmsGestureConfidenceThresholdForLiveMode
} from './HmsGestureModelDetector';
import { HmsGestureNativeSessionFactory } from './HmsGestureNativeSession';
import {
  ImageClassificationSceneDetectionRunner,
  parseSceneDetectionLabels,
  SceneDetectionRunner,
  SceneDetectionService,
  sceneDetectionLabelRawfilePath,
  sceneDetectionModelRawfilePath
} from './SceneDetectionService';
import {
  CoreVisionFallbackTextRecognitionRunner,
  HarmonyTextRecognitionRunner,
  LocalMnnTextRecognitionRunner,
  parseTranslationLanguagePairs,
  TextRecognitionRunner,
  TextRecognitionService,
  TextTranslationLanguagePair,
  TextTranslationRunner,
  TextTranslationService,
  translationLanguagePairsRawfilePath
} from './TextRecognitionService';

export interface HarmonyImageClassificationRuntimeOptions {
  readonly resourceManager: RawfileContentReader;
  readonly labelLocale?: string;
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
  readonly translationModelBundleFactory?: TranslationModelBundleFactory;
  readonly translationModelResourceManager?: TranslationModelResourceManager;
  readonly translationModelCacheRoot?: string;
  readonly segmentationRunner?: SegmentationRunner;
  readonly poseRunner?: PoseRunner;
  readonly gestureRunner?: GestureRunner;
  readonly androidGestureModelDetector?: AndroidGestureModelDetector;
  readonly hmsGestureNativeSessionFactory?: HmsGestureNativeSessionFactory;
  readonly hmsGestureImageLoader?: HmsGestureImageLoader;
  readonly trustedGestureModelLabels?: boolean;
  readonly gestureRegionEstimator?: GestureRegionEstimator;
  readonly sceneDetectionRunner?: SceneDetectionRunner;
}

let cachedHarmonyDefaultAiService: Promise<DefaultAiService> | undefined = undefined;
let cachedHarmonyDefaultAiServiceLocale: string = '';
let cachedHarmonyLocalSceneDetectionAiService: Promise<DefaultAiService> | undefined = undefined;
let cachedHarmonyLocalSceneDetectionAiServiceLocale: string = '';
let harmonyRuntimeLabelLocaleForTests: string | undefined = undefined;

export function resetHarmonyRuntimeAiServiceCachesForTests(): void {
  resetTranslationModelCacheForTests();
  cachedHarmonyDefaultAiService = undefined;
  cachedHarmonyDefaultAiServiceLocale = '';
  cachedHarmonyLocalSceneDetectionAiService = undefined;
  cachedHarmonyLocalSceneDetectionAiServiceLocale = '';
  harmonyRuntimeLabelLocaleForTests = undefined;
}

export function setHarmonyRuntimeLabelLocaleForTests(locale?: string): void {
  harmonyRuntimeLabelLocaleForTests = locale;
}

export class HarmonyRawfileContentReader implements RawfileContentReader {
  private readonly resourceManager: resourceManager.ResourceManager;

  constructor(resourceManager: resourceManager.ResourceManager) {
    this.resourceManager = resourceManager;
  }

  async getRawFileContent(path: string): Promise<Uint8Array> {
    return this.resourceManager.getRawFileContent(path);
  }

  async getRawFd(path: string): Promise<TranslationRawFileDescriptor> {
    return await this.resourceManager.getRawFd(path);
  }

  async closeRawFd(path: string): Promise<void> {
    await this.resourceManager.closeRawFd(path);
  }
}

export const harmonyTranslationModelCacheRoot: string =
  '/data/storage/el2/base/files/translation';

class HarmonyTranslationProductionOptions implements TranslationProductionBundleOptions {
  readonly resourceManager: TranslationModelResourceManager;
  readonly cacheRoot: string;

  constructor(resourceManager: TranslationModelResourceManager, cacheRoot: string) {
    this.resourceManager = resourceManager;
    this.cacheRoot = cacheRoot;
  }
}

export function cachedHarmonyDefaultAiServiceForResourceManager(
  resourceManager: RawfileContentReader
): Promise<DefaultAiService> {
  const labelLocale = currentLabelLocale();
  if (cachedHarmonyDefaultAiService === undefined || cachedHarmonyDefaultAiServiceLocale !== labelLocale) {
    const servicePromise = createHarmonyDefaultAiService({
      resourceManager: resourceManager,
      labelLocale: labelLocale
    });
    cachedHarmonyDefaultAiService = servicePromise;
    cachedHarmonyDefaultAiServiceLocale = labelLocale;
    servicePromise.catch(() => {
      if (cachedHarmonyDefaultAiService === servicePromise) {
        cachedHarmonyDefaultAiService = undefined;
        cachedHarmonyDefaultAiServiceLocale = '';
      }
    });
  }
  return cachedHarmonyDefaultAiService;
}

export function cachedHarmonyLocalSceneDetectionAiServiceForResourceManager(
  resourceManager: RawfileContentReader
): Promise<DefaultAiService> {
  const labelLocale = currentLabelLocale();
  if (cachedHarmonyLocalSceneDetectionAiService === undefined ||
    cachedHarmonyLocalSceneDetectionAiServiceLocale !== labelLocale) {
    const servicePromise = createHarmonyLocalSceneDetectionAiService(resourceManager, labelLocale);
    cachedHarmonyLocalSceneDetectionAiService = servicePromise;
    cachedHarmonyLocalSceneDetectionAiServiceLocale = labelLocale;
    servicePromise.catch(() => {
      if (cachedHarmonyLocalSceneDetectionAiService === servicePromise) {
        cachedHarmonyLocalSceneDetectionAiService = undefined;
        cachedHarmonyLocalSceneDetectionAiServiceLocale = '';
      }
    });
  }
  return cachedHarmonyLocalSceneDetectionAiService;
}

async function createHarmonyLocalSceneDetectionAiService(
  resourceManager: RawfileContentReader,
  labelLocale: string
): Promise<DefaultAiService> {
  return new DefaultAiService({
    sceneDetectionService: await createHarmonyLocalSceneDetectionService({
      resourceManager: resourceManager,
      labelLocale: labelLocale
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
    return createRuntimeAiServiceForWorkflow(workflow, {
      resourceManager: resourceManager
    });
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
    const textTranslationService = await createHarmonyTextTranslationService(options);
    return new DefaultAiService({
      textRecognitionService: createHarmonyTextRecognitionService(options),
      textTranslationService: textTranslationService
    });
  }
  if (workflow.aiMethod === 'segmentPerson') {
    return new DefaultAiService({
      segmentationService: createHarmonySegmentationService(options, workflow)
    });
  }
  if (workflow.aiMethod === 'detectPose') {
    return new DefaultAiService({
      poseService: createHarmonyPoseService(options, workflow)
    });
  }
  if (workflow.aiMethod === 'detectGesture') {
    if (options.gestureRunner !== undefined) {
      return new DefaultAiService({
        gestureService: createHarmonyGestureService(options.gestureRunner)
      });
    }
    return new DefaultAiService({
      gestureService: createHarmonyHmsGestureService(options, workflow)
    });
  }
  if (workflow.aiMethod === 'detectScene') {
    if (options.sceneDetectionRunner !== undefined) {
      return new DefaultAiService({
        sceneDetectionService: createHarmonySceneDetectionService(
          options.sceneDetectionRunner,
          labelLocaleForOptions(options)
        )
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
  const labels = await loadImageClassificationLabels(options.resourceManager, labelLocaleForOptions(options));
  const tensorRunner = options.tensorRunner ?? new MindSporeLiteModelRunner({
    resourceManager: options.resourceManager,
    modelRawfilePath: imageClassificationModelRawfilePath,
    outputTensorDecoder: imageClassificationScoresFromOutputTensor
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
  const labels = await loadObjectDetectionLabels(options.resourceManager, labelLocaleForOptions(options));
  const runner = options.objectDetectionRunner ?? createHarmonyObjectDetectionRunner(options);
  return new ObjectDetectionService({
    labels: labels,
    runner: runner
  });
}

export function createHarmonyObjectDetectionRunner(
  options: HarmonyImageClassificationRuntimeOptions
): ObjectDetectionRunner {
  if (options.objectDetectionTensorRunner === undefined) {
    return new LocalMnnObjectDetectionRunner({
      resourceManager: options.resourceManager,
      modelRawfilePath: objectDetectionModelRawfilePath,
      preprocessor: options.objectDetectionPreprocessor ?? new HarmonyObjectDetectionInputPreprocessor()
    });
  }
  return new ObjectDetectionMindSporeRunner({
    preprocessor: options.objectDetectionPreprocessor ?? new HarmonyObjectDetectionInputPreprocessor(),
    tensorRunner: options.objectDetectionTensorRunner
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
    tensorRunner: options.styleTransferTensorRunner ?? new LocalMnnStyleTransferTensorRunner({
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
    runner: options.textRecognitionRunner ?? new CoreVisionFallbackTextRecognitionRunner(
      new HarmonyTextRecognitionRunner(),
      new LocalMnnTextRecognitionRunner({ resourceManager: options.resourceManager })
    )
  });
}

export async function createHarmonyTextTranslationService(
  options: HarmonyImageClassificationRuntimeOptions
): Promise<TextTranslationService> {
  const languagePairs = await loadOptionalTranslationLanguagePairs(options.resourceManager);
  const productionOptions = new HarmonyTranslationProductionOptions(
    options.translationModelResourceManager ?? options.resourceManager as TranslationModelResourceManager,
    options.translationModelCacheRoot ?? harmonyTranslationModelCacheRoot
  );
  return new TextTranslationService({
    runner: options.textTranslationRunner ?? (options.translationModelBundleFactory === undefined ?
      new TranslationWorkerClient(productionOptions) :
      new MindSporeLiteTranslationRunner({ bundleFactory: options.translationModelBundleFactory })),
    languagePairs: languagePairs
  });
}

export function createHarmonySegmentationService(
  options: HarmonyImageClassificationRuntimeOptions,
  workflow?: FeatureWorkflow
): SegmentationService {
  const androidScene = workflow === undefined ? 'all' : segmentationAndroidSceneForWorkflow(workflow);
  return new SegmentationService({
    runner: options.segmentationRunner ?? new CoreVisionFallbackSegmentationRunner(
      new HarmonySubjectSegmentationRunner({ androidScene: androidScene }),
      new LocalMnnSegmentationRunner({
        resourceManager: options.resourceManager,
        androidScene: androidScene
      })
    )
  });
}

export function segmentationAndroidSceneForWorkflow(workflow: FeatureWorkflow): SegmentationAndroidScene {
  if (workflow.routeName === AppRoute.SEGMENTATION_STILL.name) {
    return 'all';
  }
  return 'foregroundOnly';
}

export function createHarmonyPoseService(
  options: HarmonyImageClassificationRuntimeOptions,
  workflow?: FeatureWorkflow
): PoseService {
  return new PoseService({
    mode: workflow === undefined ? 'normal' : poseModeForWorkflow(workflow),
    runner: options.poseRunner ?? new CoreVisionFallbackPoseRunner(
      new HarmonySkeletonDetectionRunner({
        resourceManager: options.resourceManager
      }),
      new LocalMoveNetPoseRunner({
        resourceManager: options.resourceManager,
        modelRawfilePath: moveNetModelRawfilePath
      })
    )
  });
}

export function createHarmonyGestureService(runner: GestureRunner): GestureService {
  return new GestureService({
    runner: runner
  });
}

export function createHarmonyHmsGestureService(
  options: HarmonyImageClassificationRuntimeOptions,
  workflow: FeatureWorkflow
): GestureService {
  const detector = options.androidGestureModelDetector ?? new HmsGestureModelDetector({
    resourceManager: options.resourceManager,
    nativeSessionFactory: options.hmsGestureNativeSessionFactory,
    imageLoader: options.hmsGestureImageLoader,
    confidenceThreshold: hmsGestureConfidenceThresholdForLiveMode(workflow.liveMode)
  });
  return new GestureService({
    runner: new AndroidGestureModelRunner(detector)
  });
}

export async function createHarmonyLocalGestureService(
  options: HarmonyImageClassificationRuntimeOptions
): Promise<GestureService> {
  const labels = await loadImageClassificationLabels(options.resourceManager, '');
  const tensorRunner = options.tensorRunner ?? new MindSporeLiteModelRunner({
    resourceManager: options.resourceManager,
    modelRawfilePath: imageClassificationModelRawfilePath,
    outputTensorDecoder: imageClassificationScoresFromOutputTensor
  });
  const preprocessor = options.inputPreprocessor ?? new HarmonyImageClassificationInputPreprocessor();
  const scoreRunner = new ImageClassificationMindSporeScoreRunner({
    preprocessor: preprocessor,
    tensorRunner: tensorRunner
  });
  return new GestureService({
    runner: new ImageClassificationGestureRunner({
      labels: labels,
      trustedGestureModelLabels: options.trustedGestureModelLabels,
      regionEstimator: options.gestureRegionEstimator ?? new HarmonyGestureRegionEstimator(),
      scoreRunner: scoreRunner
    })
  });
}

export function createHarmonySceneDetectionService(
  runner: SceneDetectionRunner,
  labelLocale: string = ''
): SceneDetectionService {
  return new SceneDetectionService({
    runner: runner,
    labelLocale: labelLocale
  });
}

export async function createHarmonyLocalSceneDetectionService(
  options: HarmonyImageClassificationRuntimeOptions
): Promise<SceneDetectionService> {
  const labels = await loadSceneDetectionLabels(options.resourceManager);
  const tensorRunner = options.tensorRunner ?? new MindSporeLiteModelRunner({
    resourceManager: options.resourceManager,
    modelRawfilePath: sceneDetectionModelRawfilePath
  });
  const preprocessor = options.inputPreprocessor ?? new HarmonyImageClassificationInputPreprocessor();
  const scoreRunner = new ImageClassificationMindSporeScoreRunner({
    preprocessor: preprocessor,
    tensorRunner: tensorRunner
  });
  return new SceneDetectionService({
    labelLocale: labelLocaleForOptions(options),
    runner: new ImageClassificationSceneDetectionRunner({
      labels: labels,
      scoreRunner: scoreRunner
    })
  });
}

export async function loadSceneDetectionLabels(resourceManager: RawfileContentReader): Promise<Array<string>> {
  const content = await resourceManager.getRawFileContent(sceneDetectionLabelRawfilePath);
  return parseSceneDetectionLabels(rawfileUtf8ContentToText(content));
}

export async function loadImageClassificationLabels(
  resourceManager: RawfileContentReader,
  labelLocale: string = ''
): Promise<Array<string>> {
  const content = await resourceManager.getRawFileContent(imageCategoryLabelRawfilePathForLocale(labelLocale));
  return parseImageCategoryLabels(rawfileUtf8ContentToText(content));
}

export async function loadObjectDetectionLabels(
  resourceManager: RawfileContentReader,
  labelLocale: string = ''
): Promise<Array<string>> {
  const content = await resourceManager.getRawFileContent(objectCategoryLabelRawfilePathForLocale(labelLocale));
  return parseObjectCategoryLabels(rawfileUtf8ContentToText(content));
}

export async function loadTranslationLanguagePairs(
  resourceManager: RawfileContentReader
): Promise<Array<TextTranslationLanguagePair>> {
  const content = await resourceManager.getRawFileContent(translationLanguagePairsRawfilePath);
  return parseTranslationLanguagePairs(rawfileAsciiContentToText(content));
}

async function loadOptionalTranslationLanguagePairs(
  resourceManager: RawfileContentReader
): Promise<Array<TextTranslationLanguagePair> | undefined> {
  try {
    return await loadTranslationLanguagePairs(resourceManager);
  } catch (_) {
    return undefined;
  }
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

export function rawfileUtf8ContentToText(content: Uint8Array): string {
  const chars: Array<string> = [];
  let index = 0;
  while (index < content.length) {
    const first = content[index];
    let codePoint = 0;
    let byteCount = 1;
    if (first < 0x80) {
      codePoint = first;
    } else if ((first & 0xE0) === 0xC0 && index + 1 < content.length) {
      codePoint = ((first & 0x1F) << 6) | (content[index + 1] & 0x3F);
      byteCount = 2;
    } else if ((first & 0xF0) === 0xE0 && index + 2 < content.length) {
      codePoint = ((first & 0x0F) << 12) | ((content[index + 1] & 0x3F) << 6) | (content[index + 2] & 0x3F);
      byteCount = 3;
    } else if ((first & 0xF8) === 0xF0 && index + 3 < content.length) {
      codePoint = ((first & 0x07) << 18) | ((content[index + 1] & 0x3F) << 12) |
        ((content[index + 2] & 0x3F) << 6) | (content[index + 3] & 0x3F);
      byteCount = 4;
    } else {
      codePoint = 0xFFFD;
    }

    if (!(chars.length === 0 && codePoint === 0xFEFF)) {
      if (codePoint <= 0xFFFF) {
        chars.push(String.fromCharCode(codePoint));
      } else {
        const adjusted = codePoint - 0x10000;
        chars.push(String.fromCharCode(0xD800 + (adjusted >> 10)));
        chars.push(String.fromCharCode(0xDC00 + (adjusted & 0x3FF)));
      }
    }
    index += byteCount;
  }
  return chars.join('');
}

export function imageCategoryLabelRawfilePathForLocale(locale: string): string {
  if (isChineseLabelLocale(locale)) {
    return 'labels/zh_CN/image_category_old.txt';
  }
  return imageCategoryLabelRawfilePath;
}

export function objectCategoryLabelRawfilePathForLocale(locale: string): string {
  if (isChineseLabelLocale(locale)) {
    return 'labels/zh_CN/object_category.txt';
  }
  return objectCategoryLabelRawfilePath;
}

function labelLocaleForOptions(options: HarmonyImageClassificationRuntimeOptions): string {
  if (options.labelLocale !== undefined) {
    return options.labelLocale;
  }
  return currentLabelLocale();
}

function currentLabelLocale(): string {
  if (harmonyRuntimeLabelLocaleForTests !== undefined) {
    return harmonyRuntimeLabelLocaleForTests;
  }
  try {
    return i18n.System.getAppPreferredLanguage();
  } catch (_) {
    return '';
  }
}

function isChineseLabelLocale(locale: string): boolean {
  const normalized = locale.toLowerCase().split('_').join('-');
  return normalized === 'zh' || normalized.startsWith('zh-');
}
