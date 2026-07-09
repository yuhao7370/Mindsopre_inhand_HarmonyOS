import { DefaultAiService } from './AiService';
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
}

let cachedHarmonyDefaultAiService: Promise<DefaultAiService> | undefined = undefined;

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
