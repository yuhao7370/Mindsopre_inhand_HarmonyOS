import { ImageClassificationScoreRunner, imageCategoryLabelCount } from './ImageClassificationService';

export interface SceneDetection {
  readonly label: string;
  readonly score: number;
}

export interface SceneDetectionResult {
  readonly ok: boolean;
  readonly scenes: Array<SceneDetection>;
  readonly imageWidth?: number;
  readonly imageHeight?: number;
  readonly executionMs: number;
}

export interface SceneDetectionRunner {
  detectScenes(imageUri: string): Promise<SceneDetectionResult>;
}

export interface SceneDetectionServiceOptions {
  readonly runner: SceneDetectionRunner;
}

export const localSceneDetectionMaxSceneCount: number = 3;

export interface ImageClassificationSceneDetectionRunnerOptions {
  readonly labels: Array<string>;
  readonly scoreRunner: ImageClassificationScoreRunner;
  readonly maxScenes?: number;
}

interface SceneLabelKeywordMap {
  readonly sceneLabel: string;
  readonly keywords: Array<string>;
}

const localSceneLabelDenyList: Array<string> = [
  'crane',
  'sea_lion',
  'tiger_beetle'
];

const localSceneLabelKeywordMaps: Array<SceneLabelKeywordMap> = [
  { sceneLabel: 'beach', keywords: ['beach', 'seashore', 'sandbar', 'coast'] },
  { sceneLabel: 'waterside', keywords: ['lakeside', 'lake', 'dock', 'pier', 'boathouse'] },
  { sceneLabel: 'waterfall', keywords: ['waterfall'] },
  { sceneLabel: 'mountain', keywords: ['alp', 'mountain', 'valley', 'volcano', 'cliff'] },
  { sceneLabel: 'snow', keywords: ['snowmobile', 'ski', 'snowplow'] },
  { sceneLabel: 'greenplant', keywords: ['forest', 'greenhouse', 'rapeseed', 'corn', 'hay'] },
  { sceneLabel: 'flower', keywords: ['daisy', 'orchid', 'rose', 'flower'] },
  { sceneLabel: 'food', keywords: ['espresso', 'pizza', 'cheeseburger', 'hotdog', 'ice_cream', 'pretzel', 'bagel', 'guacamole'] },
  { sceneLabel: 'restaurant', keywords: ['restaurant', 'dining', 'plate', 'menu'] },
  { sceneLabel: 'cathedralhall', keywords: ['church', 'cathedral', 'monastery'] },
  { sceneLabel: 'bridge', keywords: ['bridge', 'viaduct'] },
  { sceneLabel: 'skyscraper', keywords: ['skyscraper', 'tower', 'palace', 'castle'] },
  { sceneLabel: 'construction', keywords: ['bulldozer', 'harvester'] },
  { sceneLabel: 'kitchen', keywords: ['kitchen', 'stove', 'microwave', 'dishwasher', 'refrigerator'] },
  { sceneLabel: 'bedroom', keywords: ['bed', 'crib'] },
  { sceneLabel: 'library', keywords: ['library', 'bookshop', 'bookcase'] },
  { sceneLabel: 'supermarket', keywords: ['grocery', 'shopping'] },
  { sceneLabel: 'office', keywords: ['desk', 'laptop', 'monitor', 'printer'] },
  { sceneLabel: 'classroom', keywords: ['school', 'classroom'] },
  { sceneLabel: 'bar', keywords: ['bar', 'beer'] },
  { sceneLabel: 'swimmingpool', keywords: ['pool'] },
  { sceneLabel: 'footballfield', keywords: ['football'] },
  { sceneLabel: 'baseballfield', keywords: ['baseball'] },
  { sceneLabel: 'tenniscourt', keywords: ['tennis'] },
  { sceneLabel: 'cat', keywords: ['tabby', 'tiger_cat', 'persian_cat', 'siamese_cat', 'egyptian_cat', 'cat'] },
  { sceneLabel: 'dog', keywords: ['dog', 'hound', 'terrier', 'retriever', 'spaniel', 'poodle', 'husky', 'malamute'] },
  { sceneLabel: 'panda', keywords: ['panda'] },
  { sceneLabel: 'ornamentalfish', keywords: ['tench', 'goldfish', 'fish', 'shark', 'ray', 'eel', 'sturgeon'] },
  { sceneLabel: 'tiger', keywords: ['tiger'] },
  { sceneLabel: 'elephant', keywords: ['elephant'] },
  { sceneLabel: 'lion', keywords: ['lion'] },
  { sceneLabel: 'rabbit', keywords: ['rabbit', 'hare'] },
  { sceneLabel: 'butterfly', keywords: ['butterfly'] },
  { sceneLabel: 'bee', keywords: ['bee'] },
  { sceneLabel: 'ladybug', keywords: ['ladybug'] },
  { sceneLabel: 'car', keywords: ['car', 'cab', 'taxi', 'limousine', 'jeep', 'minivan', 'ambulance', 'fire_engine', 'police_van'] },
  { sceneLabel: 'bicycle', keywords: ['bicycle', 'mountain_bike'] },
  { sceneLabel: 'motorcycle', keywords: ['motorcycle', 'moped', 'motor_scooter'] },
  { sceneLabel: 'aircraft', keywords: ['airliner', 'warplane', 'airship', 'airplane'] },
  { sceneLabel: 'helicopter', keywords: ['helicopter'] },
  { sceneLabel: 'train', keywords: ['train', 'locomotive'] },
  { sceneLabel: 'ship', keywords: ['ship', 'schooner', 'liner', 'speedboat', 'gondola', 'canoe', 'yawl'] },
  { sceneLabel: 'camera', keywords: ['camera'] },
  { sceneLabel: 'watch', keywords: ['watch'] },
  { sceneLabel: 'keyboard', keywords: ['keyboard'] },
  { sceneLabel: 'map', keywords: ['map'] }
];

export class SceneDetectionService {
  private readonly runner: SceneDetectionRunner;

  constructor(options: SceneDetectionServiceOptions) {
    this.runner = options.runner;
  }

  async detectScenes(imageUri: string): Promise<SceneDetectionResult> {
    const startMs = Date.now();
    try {
      return await this.runner.detectScenes(imageUri);
    } catch (_) {
      return {
        ok: false,
        scenes: [],
        executionMs: Date.now() - startMs
      };
    }
  }
}

export class ImageClassificationSceneDetectionRunner implements SceneDetectionRunner {
  private readonly labels: Array<string>;
  private readonly scoreRunner: ImageClassificationScoreRunner;
  private readonly maxScenes: number;

  constructor(options: ImageClassificationSceneDetectionRunnerOptions) {
    this.labels = options.labels;
    this.scoreRunner = options.scoreRunner;
    this.maxScenes = options.maxScenes ?? localSceneDetectionMaxSceneCount;
  }

  async detectScenes(imageUri: string): Promise<SceneDetectionResult> {
    const startMs = Date.now();
    try {
      const scores = await this.scoreRunner.predictScores(imageUri);
      const scenes = topLocalSceneDetections(scores, this.labels, this.maxScenes);
      return {
        ok: scenes.length > 0,
        scenes: scenes,
        executionMs: Date.now() - startMs
      };
    } catch (_) {
      return {
        ok: false,
        scenes: [],
        executionMs: Date.now() - startMs
      };
    }
  }
}

export function topLocalSceneDetections(
  scores: Array<number>,
  labels: Array<string>,
  maxScenes: number = localSceneDetectionMaxSceneCount
): Array<SceneDetection> {
  const candidates: Array<SceneDetection> = [];
  const scanLimit = Math.min(scores.length, labels.length, imageCategoryLabelCount);
  for (let index = 0; index < scanLimit; index++) {
    const score = scores[index];
    if (score > 0) {
      candidates.push({
        label: sceneLabelForImageClassificationLabel(labels[index]),
        score: score
      });
    }
  }
  candidates.sort((left: SceneDetection, right: SceneDetection) => right.score - left.score);

  const limit = maxScenes > 0 ? maxScenes : localSceneDetectionMaxSceneCount;
  const scenes: Array<SceneDetection> = [];
  for (let index = 0; index < candidates.length; index++) {
    const candidate = candidates[index];
    if (!hasSceneLabel(scenes, candidate.label)) {
      scenes.push(candidate);
    }
    if (scenes.length >= limit) {
      break;
    }
  }
  return scenes;
}

export function sceneLabelForImageClassificationLabel(label: string): string {
  const normalized = normalizeSceneLabel(label);
  if (isDeniedSceneLabel(normalized)) {
    return 'other';
  }
  for (let index = 0; index < localSceneLabelKeywordMaps.length; index++) {
    const entry = localSceneLabelKeywordMaps[index];
    for (let keywordIndex = 0; keywordIndex < entry.keywords.length; keywordIndex++) {
      if (sceneLabelContainsKeyword(normalized, entry.keywords[keywordIndex])) {
        return entry.sceneLabel;
      }
    }
  }
  return 'other';
}

function normalizeSceneLabel(label: string): string {
  return label.trim().toLowerCase().split(' ').join('_').split('-').join('_').split('/').join('_');
}

function sceneLabelContainsKeyword(label: string, keyword: string): boolean {
  return label === keyword ||
    label.startsWith(`${keyword}_`) ||
    label.endsWith(`_${keyword}`) ||
    label.indexOf(`_${keyword}_`) >= 0;
}

function isDeniedSceneLabel(label: string): boolean {
  for (let index = 0; index < localSceneLabelDenyList.length; index++) {
    if (localSceneLabelDenyList[index] === label) {
      return true;
    }
  }
  return false;
}

function hasSceneLabel(scenes: Array<SceneDetection>, label: string): boolean {
  for (let index = 0; index < scenes.length; index++) {
    if (scenes[index].label === label) {
      return true;
    }
  }
  return false;
}
