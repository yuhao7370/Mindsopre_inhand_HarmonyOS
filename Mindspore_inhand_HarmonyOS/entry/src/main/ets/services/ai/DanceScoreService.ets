export const danceNoPointScore = -2;
export const danceNoActScore = -1;

export interface DanceFrameData {
  readonly id: number;
  readonly sinRightElbow: number;
  readonly sinRightWrist: number;
  readonly sinLeftElbow: number;
  readonly sinLeftWrist: number;
  readonly sinLeftKnee: number;
  readonly sinLeftAnkle: number;
  readonly rightElbowMissing: boolean;
  readonly rightWristMissing: boolean;
  readonly leftElbowMissing: boolean;
  readonly leftWristMissing: boolean;
  readonly leftKneeMissing: boolean;
  readonly leftAnkleMissing: boolean;
}

export interface DancePoint {
  readonly x: number;
  readonly y: number;
}

export interface DanceSkeletonPoints {
  readonly neck: DancePoint;
  readonly rightElbow: DancePoint;
  readonly rightWrist: DancePoint;
  readonly leftElbow: DancePoint;
  readonly leftWrist: DancePoint;
  readonly leftKnee: DancePoint;
  readonly leftAnkle: DancePoint;
}

const noPointScale = 0.4;
const noActScale = 0.4;

const danceModelData: Array<number> = [
  1, -0.447213595, -0.707106781, -0.196116135, -0.707106781, -0.948683298, -0.707106781,
  2, -0.447213595, -0.707106781, -0.196116135, -0.707106781, -0.948683298, -0.707106781,
  3, -0.447213595, -0.447213595, 0.5, -0.447213595, -0.948683298, -0.707106781,
  4, -0.447213595, -0.707106781, -0.196116135, -0.707106781, -0.948683298, -0.707106781,
  5, -0.447213595, -0.707106781, -0.196116135, -0.707106781, -0.948683298, -0.707106781,
  6, -0.447213595, -0.707106781, -0.196116135, -0.707106781, -0.948683298, -0.707106781,
  7, -0.447213595, -0.447213595, -0.196116135, -0.447213595, -0.948683298, -0.707106781,
  8, -0.447213595, -0.447213595, -0.196116135, -0.707106781, -0.948683298, -0.707106781,
  9, -0.447213595, -0.707106781, -0.196116135, -0.447213595, -0.948683298, -0.707106781,
  10, -0.447213595, -0.707106781, 0.5, 0.5, -0.948683298, -0.707106781,
  11, -0.447213595, -0.707106781, -0.196116135, -0.707106781, -0.948683298, -0.707106781,
  12, -0.447213595, -0.707106781, -0.196116135, -0.707106781, -0.948683298, -0.707106781,
  13, -0.707106781, -0.707106781, 0.5, -1, -1, -0.948683298,
  14, -0.707106781, -0.707106781, 0.5, -0.707106781, -1, -0.948683298,
  15, -0.707106781, -0.447213595, 0.5, -1, -1, -0.948683298,
  16, -0.707106781, -0.447213595, 0.5, -0.707106781, -1, -0.948683298,
  17, -0.707106781, -0.447213595, 0.5, -0.707106781, -1, -0.948683298,
  18, -0.447213595, -0.447213595, -0.707106781, -0.707106781, -0.948683298, -0.707106781,
  19, -0.707106781, -0.707106781, -0.894427191, -1, -0.948683298, -0.832050294,
  20, -0.447213595, -0.707106781, -0.707106781, -0.447213595, -0.948683298, -0.948683298,
  21, -0.447213595, -0.707106781, -0.196116135, -0.447213595, -0.948683298, -0.707106781,
  22, -0.316227766, -0.316227766, -0.371390676, -0.447213595, -0.948683298, -0.6,
  23, -0.447213595, -0.447213595, -0.196116135, -0.447213595, -0.948683298, -0.948683298,
  24, -0.447213595, -0.707106781, -0.316227766, -1, -1, -0.832050294,
  25, -0.447213595, -0.707106781, -0.316227766, -1, -1, -0.832050294,
  26, -1, -1, -1, 0.5, -0.948683298, -0.948683298,
  27, -1, -1, -1, -0.894427191, -0.948683298, -0.948683298,
  28, -0.447213595, -0.447213595, -0.196116135, -0.707106781, -0.948683298, -0.707106781,
  29, -0.447213595, -0.707106781, -0.196116135, -0.447213595, -0.948683298, -0.707106781,
  30, -0.447213595, 0.624695048, -0.196116135, 0.9701425, -0.948683298, -0.707106781,
  31, -0.447213595, 0.514495755, -0.196116135, 0.948683298, -0.948683298, -0.707106781,
  32, -0.447213595, -0.707106781, -0.196116135, -0.707106781, -0.948683298, -0.707106781,
  33, -0.447213595, -0.707106781, -0.196116135, -0.707106781, -0.948683298, -0.707106781,
  34, -0.447213595, -0.707106781, -0.196116135, -0.316227766, -0.948683298, -0.707106781,
  35, -0.447213595, 0.554700196, -0.196116135, 0.948683298, -0.948683298, -0.707106781,
  36, -0.447213595, -0.707106781, -0.196116135, -0.447213595, -0.948683298, -0.948683298,
  37, -0.447213595, -0.707106781, -0.196116135, -0.707106781, -0.948683298, -0.707106781,
  38, -0.447213595, -0.316227766, -0.196116135, -0.316227766, -0.948683298, -0.707106781,
  39, -0.447213595, -0.554700196, -0.196116135, -0.316227766, -0.948683298, -0.707106781,
  40, -0.447213595, -0.707106781, -0.196116135, -0.707106781, -0.948683298, -0.707106781,
  41, -0.447213595, -0.707106781, -0.196116135, -0.707106781, -0.948683298, -0.707106781,
  42, -0.447213595, -0.707106781, -0.196116135, -0.707106781, -0.948683298, -0.707106781,
  43, -0.447213595, -0.707106781, -0.196116135, -0.447213595, -0.948683298, -0.707106781,
  44, -0.447213595, -0.447213595, -0.196116135, -0.707106781, -0.948683298, -0.707106781,
  45, -0.447213595, -0.707106781, -0.196116135, -0.554700196, -0.948683298, -0.707106781,
  46, -0.447213595, -0.447213595, -0.196116135, -0.894427191, -0.948683298, -0.707106781,
  47, -0.447213595, -0.554700196, -0.196116135, -0.894427191, -0.948683298, -0.707106781,
  48, -0.707106781, -0.447213595, -0.447213595, -0.707106781, -0.948683298, -0.894427191,
  49, -0.447213595, -0.447213595, -0.447213595, -0.707106781, -0.948683298, -0.948683298,
  50, -0.447213595, -0.447213595, -0.447213595, -0.707106781, -0.948683298, -0.948683298,
  51, -0.447213595, -0.707106781, -0.447213595, -0.707106781, -0.948683298, -0.948683298,
  52, -0.447213595, -0.447213595, -0.447213595, -0.894427191, -0.948683298, -1,
  53, -0.447213595, -0.447213595, 0.707106781, -0.447213595, -0.948683298, -0.707106781,
  54, -0.707106781, -0.707106781, 0.5, -0.707106781, -0.948683298, -0.832050294,
  55, -0.447213595, -0.707106781, -0.196116135, -0.707106781, -0.948683298, -0.707106781,
  56, -0.447213595, -0.707106781, -0.196116135, -0.447213595, -0.948683298, -0.707106781,
  57, -0.316227766, -0.447213595, -0.316227766, -0.316227766, -0.948683298, -0.6,
  58, -0.316227766, -0.447213595, -0.316227766, -0.316227766, -0.948683298, -0.707106781,
  59, -0.447213595, -0.707106781, -0.242535625, -0.707106781, -0.948683298, -0.707106781,
  60, -0.447213595, -0.707106781, -0.242535625, -0.707106781, -0.948683298, -0.707106781,
  61, -0.447213595, -0.707106781, -0.242535625, -0.707106781, -0.948683298, -0.832050294,
  62, -0.447213595, -0.707106781, -0.242535625, -0.894427191, -0.948683298, -0.832050294,
  63, -0.447213595, -0.707106781, -0.242535625, -0.894427191, -0.948683298, -0.707106781,
  64, -0.447213595, -0.707106781, -0.196116135, -0.707106781, -0.948683298, -0.707106781,
  65, -0.447213595, -0.447213595, -0.196116135, -0.447213595, -0.948683298, -0.707106781,
  66, -0.316227766, -0.316227766, -0.371390676, -0.447213595, -0.948683298, -0.6,
  67, -0.447213595, -0.707106781, -0.196116135, -0.707106781, -0.948683298, -0.707106781,
  68, -0.447213595, -0.707106781, -0.196116135, -0.707106781, -0.948683298, -0.707106781,
  69, -0.447213595, -0.707106781, -0.196116135, -0.447213595, -0.948683298, -0.707106781,
  70, -0.447213595, -0.447213595, -0.196116135, -0.707106781, -0.948683298, -0.707106781
];

export function danceTemplateFrames(): Array<DanceFrameData> {
  const frames: Array<DanceFrameData> = [];
  for (let index = 0; index < danceModelData.length; index += 7) {
    frames.push({
      id: danceModelData[index],
      sinRightElbow: danceModelData[index + 1],
      sinRightWrist: danceModelData[index + 2],
      sinLeftElbow: danceModelData[index + 3],
      sinLeftWrist: danceModelData[index + 4],
      sinLeftKnee: danceModelData[index + 5],
      sinLeftAnkle: danceModelData[index + 6],
      rightElbowMissing: false,
      rightWristMissing: false,
      leftElbowMissing: false,
      leftWristMissing: false,
      leftKneeMissing: false,
      leftAnkleMissing: false
    });
  }
  return frames;
}

export function danceFrameFromPoints(id: number, points: DanceSkeletonPoints): DanceFrameData {
  return {
    id: id,
    sinRightElbow: dancePointSin(points.rightElbow, points.neck),
    sinRightWrist: dancePointSin(points.rightWrist, points.neck),
    sinLeftElbow: dancePointSin(points.leftElbow, points.neck),
    sinLeftWrist: dancePointSin(points.leftWrist, points.neck),
    sinLeftKnee: dancePointSin(points.leftKnee, points.neck),
    sinLeftAnkle: dancePointSin(points.leftAnkle, points.neck),
    rightElbowMissing: isDancePointMissing(points.rightElbow),
    rightWristMissing: isDancePointMissing(points.rightWrist),
    leftElbowMissing: isDancePointMissing(points.leftElbow),
    leftWristMissing: isDancePointMissing(points.leftWrist),
    leftKneeMissing: isDancePointMissing(points.leftKnee),
    leftAnkleMissing: isDancePointMissing(points.leftAnkle)
  };
}

export function danceScoreFromFrames(realFrames: Array<DanceFrameData | undefined>): number {
  const templateFrames = danceTemplateFrames();
  const frameCount = Math.min(realFrames.length, templateFrames.length);
  let sum = 0;
  let noDataNumber = 0;
  let sumRightElbowMissing = 0;
  let sumRightWristMissing = 0;
  let sumLeftElbowMissing = 0;
  let sumLeftWristMissing = 0;
  let sumLeftKneeMissing = 0;
  let sumLeftAnkleMissing = 0;

  for (let index = 0; index < frameCount; index++) {
    const realFrame = realFrames[index];
    if (realFrame === undefined) {
      noDataNumber++;
      continue;
    }

    const templateFrame = templateFrames[index];
    sum += dancePoseDelta(templateFrame.sinRightElbow, realFrame.sinRightElbow) +
      dancePoseDelta(templateFrame.sinRightWrist, realFrame.sinRightWrist) +
      dancePoseDelta(templateFrame.sinLeftElbow, realFrame.sinLeftElbow) +
      dancePoseDelta(templateFrame.sinLeftWrist, realFrame.sinLeftWrist) +
      dancePoseDelta(templateFrame.sinLeftKnee, realFrame.sinLeftKnee) +
      dancePoseDelta(templateFrame.sinLeftAnkle, realFrame.sinLeftAnkle);

    sumRightElbowMissing += missingFlag(realFrame.rightElbowMissing);
    sumRightWristMissing += missingFlag(realFrame.rightWristMissing);
    sumLeftElbowMissing += missingFlag(realFrame.leftElbowMissing);
    sumLeftWristMissing += missingFlag(realFrame.leftWristMissing);
    sumLeftKneeMissing += missingFlag(realFrame.leftKneeMissing);
    sumLeftAnkleMissing += missingFlag(realFrame.leftAnkleMissing);
  }

  const validFrameCount = frameCount - noDataNumber;
  const onPointValue = validFrameCount * noPointScale;
  if (sumRightElbowMissing >= onPointValue ||
    sumRightWristMissing >= onPointValue ||
    sumLeftElbowMissing >= onPointValue ||
    sumLeftWristMissing >= onPointValue ||
    sumLeftKneeMissing >= onPointValue ||
    sumLeftAnkleMissing > onPointValue) {
    return danceNoPointScore;
  }
  if (validFrameCount <= 0) {
    return danceNoPointScore;
  }

  if (danceStandardDeviation(realFrames, frameCount) <= noActScale) {
    return danceNoActScore;
  }

  const average = sum / validFrameCount / 6;
  let score = 100 - 120 * (average - 0.5);
  if (score >= 100) {
    score = 98;
  } else if (score < 60) {
    score = 63;
  }
  return score;
}

function dancePointSin(point: DancePoint, neck: DancePoint): number {
  const dy = point.y - neck.y;
  const dx = point.x - neck.x;
  const length = Math.sqrt(dy * dy + dx * dx);
  if (length === 0) {
    return 0.5;
  }
  return dy / length;
}

function isDancePointMissing(point: DancePoint): boolean {
  return point.x === 0 && point.y === 0;
}

function dancePoseDelta(templateValue: number, realValue: number): number {
  if (Math.abs(templateValue) === 0.5) {
    return Math.abs(templateValue - realValue - 0.5) / 2;
  }
  return Math.abs(templateValue - realValue) / 2;
}

function missingFlag(missing: boolean): number {
  return missing ? 1 : 0;
}

function danceStandardDeviation(realFrames: Array<DanceFrameData | undefined>, frameCount: number): number {
  let nullSum = 0;
  let sum = 0;
  for (let index = 0; index < frameCount; index++) {
    const frame = realFrames[index];
    if (frame === undefined || isDanceDeviationFrameInvalid(frame)) {
      nullSum++;
    } else {
      sum += danceDeviationFrameSum(frame);
    }
  }
  const validFrameCount = frameCount - nullSum;
  if (validFrameCount <= 0) {
    return 0;
  }

  const average = sum / validFrameCount;
  let variance = 0;
  for (let index = 0; index < frameCount; index++) {
    const frame = realFrames[index];
    if (frame !== undefined && !isDanceDeviationFrameInvalid(frame)) {
      const frameSum = danceDeviationFrameSum(frame);
      variance += (frameSum - average) * (frameSum - average);
    }
  }
  return Math.sqrt(variance / validFrameCount);
}

function isDanceDeviationFrameInvalid(frame: DanceFrameData): boolean {
  return frame.sinRightElbow === 0.5 ||
    frame.sinRightWrist === 0.5 ||
    frame.sinLeftElbow === 0.5 ||
    frame.sinLeftWrist === 0.5 ||
    frame.sinLeftKnee === 0.5 ||
    frame.sinLeftAnkle === 0.5;
}

function danceDeviationFrameSum(frame: DanceFrameData): number {
  return frame.sinRightElbow +
    frame.sinRightWrist +
    frame.sinLeftElbow +
    frame.sinLeftWrist +
    frame.sinLeftKnee +
    frame.sinLeftAnkle;
}
