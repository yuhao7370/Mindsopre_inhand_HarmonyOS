export const imageCategoryLabelRawfilePath: string = 'labels/image_category_old.txt';
export const imageCategoryLabelCount: number = 1000;

export interface ImageClassificationResult {
  readonly ok: boolean;
  readonly index: number;
  readonly label: string;
  readonly score: number;
}

export function parseImageCategoryLabels(rawText: string): Array<string> {
  const labels: Array<string> = [];
  rawText.split('\n').forEach((line: string) => {
    const label = line.split('\r').join('').trim();
    if (label.length > 0) {
      labels.push(label);
    }
  });
  return labels;
}

export function topClassificationResult(scores: Array<number>, labels: Array<string>): ImageClassificationResult {
  if (scores.length === 0 || labels.length === 0) {
    return emptyClassificationResult();
  }

  let maxIndex = 0;
  let maxScore = scores[0];
  for (let index = 1; index < scores.length; index++) {
    const score = scores[index];
    if (score > maxScore) {
      maxScore = score;
      maxIndex = index;
    }
  }

  if (maxIndex >= labels.length) {
    return {
      ok: false,
      index: maxIndex,
      label: '',
      score: maxScore
    };
  }

  return {
    ok: true,
    index: maxIndex,
    label: labels[maxIndex],
    score: maxScore
  };
}

function emptyClassificationResult(): ImageClassificationResult {
  return {
    ok: false,
    index: -1,
    label: '',
    score: 0
  };
}
