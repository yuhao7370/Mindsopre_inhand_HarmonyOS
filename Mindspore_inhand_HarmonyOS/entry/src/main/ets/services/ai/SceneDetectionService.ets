import { ImageClassificationScoreRunner, parseImageCategoryLabels } from './ImageClassificationService';

export interface SceneDetection {
  readonly label: string;
  readonly score: number;
}

export interface SceneDetectionResult {
  readonly ok: boolean;
  readonly scenes: Array<SceneDetection>;
  readonly failureKind?: SceneDetectionFailureKind;
  readonly imageWidth?: number;
  readonly imageHeight?: number;
  readonly executionMs: number;
}

export type SceneDetectionFailureKind = 'empty' | 'runtime';

export interface SceneDetectionRunner {
  detectScenes(imageUri: string): Promise<SceneDetectionResult>;
}

export interface AndroidSceneModelDetection {
  readonly result: string;
  readonly confidence: number;
}

export interface AndroidSceneModelResult {
  readonly scenes: Array<AndroidSceneModelDetection>;
  readonly imageWidth?: number;
  readonly imageHeight?: number;
  readonly executionMs?: number;
}

export interface AndroidSceneModelDetector {
  detectAndroidScenes(imageUri: string): Promise<AndroidSceneModelResult>;
}

export interface SceneDetectionServiceOptions {
  readonly runner: SceneDetectionRunner;
  readonly labelLocale?: string;
}

export const sceneDetectionLabelRawfilePath: string = 'labels/places365.txt';
export const sceneDetectionModelRawfilePath: string = 'model/resnet18-place365.ms';
export const places365SceneLabelCount: number = 365;
export const localSceneDetectionMaxSceneCount: number = 5;
export const androidSceneDetectionLabels: Array<string> = [
  'stage', 'beach', 'bluesky', 'sunset', 'food', 'flower', 'greenplant', 'snow', 'night', 'Text',
  'cat', 'dog', 'fireworks', 'overcast', 'fallen', 'panda', 'car', 'oldbuildings', 'bicycle',
  'waterfall', 'playground', 'corridor', 'cabin', 'washroom', 'kitchen', 'bedroom', 'diningroom',
  'livingroom', 'skyscraper', 'bridge', 'waterside', 'mountain', 'overlook', 'construction',
  'islam', 'european', 'footballfield', 'baseballfield', 'tenniscourt', 'carinside',
  'badmintoncourt', 'pingpangcourt', 'swimmingpool', 'alpaca', 'library', 'supermarket',
  'restaurant', 'tiger', 'penguin', 'elephant', 'dinosaur', 'watersurface', 'indoorbasketballco',
  'bowlingalley', 'classroom', 'rabbit', 'rhinoceros', 'camel', 'tortoise', 'leopard', 'giraffe',
  'peacock', 'kangaroo', 'lion', 'motorcycle', 'aircraft', 'train', 'ship', 'glasses', 'watch',
  'highwheels', 'washingmachine', 'airconditioner', 'camera', 'map', 'keyboard', 'redenvelope',
  'fucharacter', 'xicharacter', 'dragondance', 'liondance', 'go', 'teddybear', 'transformer',
  'thesmurfs', 'littlepony', 'butterfly', 'ladybug', 'dragonfly', 'billiardroom', 'meetingroom',
  'office', 'bar', 'mallcourtyard', 'deer', 'cathedralhall', 'bee', 'helicopter', 'mahjong',
  'chess', 'mcDonalds', 'ornamentalfish', 'widebuildings', 'other'
];
export const androidSceneDetectionLabelsZh: Array<string> = [
  '舞台', '沙滩', '蓝天', '日出日落', '美食', '花朵', '绿植', '雪景', '夜景', '文字',
  '猫', '狗', '烟花', '阴天', '秋叶', '熊猫', '汽车', '中式建筑', '自行车', '瀑布',
  '游乐场', '走廊巷道', '火车飞机内', '卫生间', '厨房', '卧室', '餐厅', '客厅', '摩天大楼+塔', '桥梁',
  '海滨/湖滨', '山峰', '城市俯瞰', '工地', '伊斯兰式建筑', '欧式建筑', '足球场', '棒球场', '网球场', '轿车内部',
  '羽毛球馆', '乒乓球馆', '游泳馆', '羊驼', '图书馆', '超市', '饭店', '老虎', '企鹅', '大象',
  '恐龙', '水面', '室内篮球场', '保龄球馆', '教室', '兔子', '犀牛', '骆驼', '乌龟', '豹子',
  '长颈鹿', '孔雀', '袋鼠', '狮子', '电动车/摩托车', '飞机', '火车', '轮船', '眼镜', '手表',
  '高跟鞋', '洗衣机', '空调', '相机', '地图', '键盘', '红包', '福字', '囍字', '舞龙',
  '舞狮', '围棋', '泰迪熊', '变形金刚', '蓝精灵', '小马宝莉', '蝴蝶', '瓢虫', '蜻蜓', '桌球房',
  '会议室', '办公室', '酒吧', '商场中庭', '梅花鹿', '教堂正厅', '蜜蜂', '直升机', '麻将', '象棋',
  '麦当劳', '观赏鱼', '广角城楼', '其他'
];

export interface ImageClassificationSceneDetectionRunnerOptions {
  readonly labels: Array<string>;
  readonly scoreRunner: ImageClassificationScoreRunner;
  readonly maxScenes?: number;
}

interface SceneLabelKeywordMap {
  readonly sceneLabel: string;
  readonly keywords: Array<string>;
}

interface SceneLabelAliasMap {
  readonly sceneLabel: string;
  readonly aliases: Array<string>;
}

const localSceneLabelDenyList: Array<string> = [
  'crane',
  'sea_lion',
  'tiger_beetle'
];

const places365SceneLabelAliasMaps: Array<SceneLabelAliasMap> = [
  { sceneLabel: 'aircraft', aliases: ['airfield', 'airplane_cabin', 'airport_terminal', 'runway'] },
  { sceneLabel: 'baseballfield', aliases: ['baseball_field'] },
  { sceneLabel: 'indoorbasketballco', aliases: ['basketball_court', 'basketball_court/indoor'] },
  { sceneLabel: 'bedroom', aliases: ['bedchamber', 'childs_room', 'dorm_room', 'hotel_room'] },
  { sceneLabel: 'bluesky', aliases: ['sky'] },
  { sceneLabel: 'washroom', aliases: ['bathroom', 'shower'] },
  { sceneLabel: 'bowlingalley', aliases: ['bowling_alley'] },
  { sceneLabel: 'bar', aliases: ['beer_garden', 'beer_hall', 'pub', 'wet_bar'] },
  { sceneLabel: 'bridge', aliases: ['aqueduct', 'rope_bridge'] },
  { sceneLabel: 'car', aliases: ['garage', 'parking_garage', 'parking_lot'] },
  { sceneLabel: 'carinside', aliases: ['car_interior'] },
  { sceneLabel: 'cathedralhall', aliases: ['church'] },
  { sceneLabel: 'classroom', aliases: ['art_school', 'kindergarden_classroom', 'lecture_room', 'schoolhouse'] },
  { sceneLabel: 'meetingroom', aliases: ['conference_center', 'conference_room', 'banquet_hall'] },
  { sceneLabel: 'construction', aliases: ['construction_site'] },
  { sceneLabel: 'corridor', aliases: ['alley', 'lobby'] },
  { sceneLabel: 'diningroom', aliases: ['dining_room'] },
  { sceneLabel: 'flower', aliases: ['florist_shop'] },
  { sceneLabel: 'footballfield', aliases: ['football_field', 'soccer_field'] },
  { sceneLabel: 'food', aliases: ['bakery', 'bakery/shop', 'ice_cream_parlor'] },
  { sceneLabel: 'greenplant', aliases: ['bamboo_forest', 'botanical_garden', 'corn_field', 'farm', 'field', 'forest', 'forest_path', 'forest_road', 'formal_garden', 'greenhouse', 'hayfield', 'japanese_garden', 'lawn', 'orchard', 'rainforest', 'roof_garden', 'topiary_garden', 'tree_farm', 'vegetable_garden', 'vineyard', 'zen_garden'] },
  { sceneLabel: 'helicopter', aliases: ['heliport'] },
  { sceneLabel: 'islam', aliases: ['mosque'] },
  { sceneLabel: 'library', aliases: ['archive', 'bookstore'] },
  { sceneLabel: 'livingroom', aliases: ['living_room'] },
  { sceneLabel: 'mallcourtyard', aliases: ['shopping_mall'] },
  { sceneLabel: 'mountain', aliases: ['canyon'] },
  { sceneLabel: 'office', aliases: ['computer_room', 'home_office', 'office_building', 'office_cubicles', 'server_room'] },
  { sceneLabel: 'ornamentalfish', aliases: ['aquarium', 'fishpond'] },
  { sceneLabel: 'playground', aliases: ['amusement_park', 'water_park'] },
  { sceneLabel: 'restaurant', aliases: ['cafeteria', 'coffee_shop', 'diner', 'fastfood_restaurant', 'food_court', 'pizzeria', 'restaurant_kitchen', 'restaurant_patio', 'sushi_bar'] },
  { sceneLabel: 'ship', aliases: ['boat_deck'] },
  { sceneLabel: 'snow', aliases: ['glacier', 'iceberg', 'mountain_snowy', 'ski_slope', 'snowfield'] },
  { sceneLabel: 'stage', aliases: ['amphitheater', 'auditorium', 'movie_theater', 'television_studio'] },
  { sceneLabel: 'supermarket', aliases: ['bazaar', 'bazaar/indoor', 'bazaar/outdoor', 'flea_market', 'market'] },
  { sceneLabel: 'swimmingpool', aliases: ['swimming_hole', 'swimming_pool'] },
  { sceneLabel: 'train', aliases: ['railroad_track', 'subway_station', 'train_interior', 'train_station'] },
  { sceneLabel: 'waterside', aliases: ['beach_house', 'boardwalk', 'harbor', 'lighthouse', 'pier'] },
  { sceneLabel: 'watersurface', aliases: ['canal', 'creek', 'lagoon', 'ocean', 'pond', 'river', 'swamp', 'underwater', 'wave'] },
  { sceneLabel: 'cabin', aliases: ['cabin/outdoor'] },
  { sceneLabel: 'widebuildings', aliases: ['apartment_building', 'apartment_building/outdoor', 'building_facade', 'cottage', 'downtown', 'hotel', 'house', 'mansion', 'residential_neighborhood', 'shopfront', 'street'] }
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
  private readonly labelLocale: string;

  constructor(options: SceneDetectionServiceOptions) {
    this.runner = options.runner;
    this.labelLocale = options.labelLocale ?? '';
  }

  async detectScenes(imageUri: string): Promise<SceneDetectionResult> {
    const startMs = Date.now();
    try {
      return localizedSceneDetectionResult(await this.runner.detectScenes(imageUri), this.labelLocale);
    } catch (_) {
      return {
        ok: false,
        scenes: [],
        failureKind: 'runtime',
        executionMs: Date.now() - startMs
      };
    }
  }
}

export class AndroidSceneModelRunner implements SceneDetectionRunner {
  private readonly detector: AndroidSceneModelDetector;

  constructor(detector: AndroidSceneModelDetector) {
    this.detector = detector;
  }

  async detectScenes(imageUri: string): Promise<SceneDetectionResult> {
    const startMs = Date.now();
    try {
      const modelResult = await this.detector.detectAndroidScenes(imageUri);
      const scenes = androidSceneModelDetections(modelResult.scenes);
      return {
        ok: scenes.length > 0,
        scenes: scenes,
        failureKind: scenes.length === 0 ? 'empty' : undefined,
        imageWidth: modelResult.imageWidth,
        imageHeight: modelResult.imageHeight,
        executionMs: modelResult.executionMs ?? Date.now() - startMs
      };
    } catch (_) {
      return {
        ok: false,
        scenes: [],
        failureKind: 'runtime',
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
        failureKind: scenes.length === 0 ? 'empty' : undefined,
        executionMs: Date.now() - startMs
      };
    } catch (_) {
      return {
        ok: false,
        scenes: [],
        failureKind: 'runtime',
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
  const otherCandidates: Array<SceneDetection> = [];
  const scanLimit = Math.min(scores.length, labels.length);
  for (let index = 0; index < scanLimit; index++) {
    const score = scores[index];
    const label = sceneLabelForImageClassificationLabel(labels[index]);
    if (!Number.isFinite(score) || !(score > 0)) {
      continue;
    }
    const candidate: SceneDetection = {
      label: label,
      score: score
    };
    if (label === 'other') {
      otherCandidates.push(candidate);
    } else {
      candidates.push(candidate);
    }
  }
  candidates.sort((left: SceneDetection, right: SceneDetection) => right.score - left.score);
  otherCandidates.sort((left: SceneDetection, right: SceneDetection) => right.score - left.score);

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
  if (scenes.length === 0 && otherCandidates.length > 0) {
    scenes.push(otherCandidates[0]);
  }
  return normalizeSelectedSceneScores(scenes);
}

function normalizeSelectedSceneScores(scenes: Array<SceneDetection>): Array<SceneDetection> {
  let selectedScoreSum = 0;
  for (let index = 0; index < scenes.length; index++) {
    selectedScoreSum += scenes[index].score;
  }
  if (!(selectedScoreSum > 0) || !Number.isFinite(selectedScoreSum)) {
    return [];
  }
  const normalizedScenes: Array<SceneDetection> = [];
  for (let index = 0; index < scenes.length; index++) {
    const scene = scenes[index];
    const normalizedScene: SceneDetection = {
      label: scene.label,
      score: scene.score / selectedScoreSum
    };
    normalizedScenes.push(normalizedScene);
  }
  return normalizedScenes;
}

function androidSceneModelDetections(
  detections: Array<AndroidSceneModelDetection>
): Array<SceneDetection> {
  const scenes: Array<SceneDetection> = [];
  for (let index = 0; index < detections.length; index++) {
    const detection = detections[index];
    scenes.push({
      label: sceneLabelForImageClassificationLabel(detection.result),
      score: detection.confidence
    });
  }
  return scenes;
}

export function parseSceneDetectionLabels(rawText: string): Array<string> {
  return parseImageCategoryLabels(rawText);
}

export function sceneDetectionDisplayLabel(label: string, labelLocale: string): string {
  if (!isChineseSceneLabelLocale(labelLocale)) {
    return label;
  }
  const normalized = normalizeSceneLabel(label);
  for (let index = 0; index < androidSceneDetectionLabels.length; index++) {
    if (normalizeSceneLabel(androidSceneDetectionLabels[index]) === normalized) {
      return androidSceneDetectionLabelsZh[index];
    }
  }
  return label;
}

export function sceneLabelForImageClassificationLabel(label: string): string {
  const normalized = normalizeSceneLabel(label);
  if (isDeniedSceneLabel(normalized)) {
    return 'other';
  }
  const androidSceneLabel = androidSceneLabelForNormalizedLabel(normalized);
  if (androidSceneLabel.length > 0) {
    return androidSceneLabel;
  }
  const places365SceneLabel = sceneLabelForPlaces365Label(normalized);
  if (places365SceneLabel.length > 0) {
    return places365SceneLabel;
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

function androidSceneLabelForNormalizedLabel(normalizedLabel: string): string {
  for (let index = 0; index < androidSceneDetectionLabels.length; index++) {
    const label = androidSceneDetectionLabels[index];
    if (normalizeSceneLabel(label) === normalizedLabel) {
      return label;
    }
  }
  return '';
}

function sceneLabelForPlaces365Label(normalizedLabel: string): string {
  for (let index = 0; index < places365SceneLabelAliasMaps.length; index++) {
    const entry = places365SceneLabelAliasMaps[index];
    for (let aliasIndex = 0; aliasIndex < entry.aliases.length; aliasIndex++) {
      if (normalizeSceneLabel(entry.aliases[aliasIndex]) === normalizedLabel) {
        return entry.sceneLabel;
      }
    }
  }
  return '';
}

function normalizeSceneLabel(label: string): string {
  return label.trim().toLowerCase().split(' ').join('_').split('-').join('_').split('/').join('_');
}

function localizedSceneDetectionResult(result: SceneDetectionResult, labelLocale: string): SceneDetectionResult {
  const scenes: Array<SceneDetection> = [];
  result.scenes.forEach((scene: SceneDetection) => {
    scenes.push({
      label: sceneDetectionDisplayLabel(scene.label, labelLocale),
      score: scene.score
    });
  });
  return {
    ok: result.ok,
    scenes: scenes,
    failureKind: result.failureKind ?? (scenes.length === 0 ? 'empty' : undefined),
    imageWidth: result.imageWidth,
    imageHeight: result.imageHeight,
    executionMs: result.executionMs
  };
}

function isChineseSceneLabelLocale(locale: string): boolean {
  const normalized = locale.toLowerCase().split('_').join('-');
  return normalized === 'zh' || normalized.startsWith('zh-');
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
