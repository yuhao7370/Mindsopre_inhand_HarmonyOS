export const objectCategoryLabelRawfilePath: string = 'labels/object_category.txt';
export const objectCategoryLabelCount: number = 81;
export const objectDetectionModelRawfilePath: string = 'model/ssd.ms';
export const objectDetectionModelDownloadUrl: string =
  'https://download.mindspore.cn/model_zoo/official/lite/ssd_mobilenetv2_lite/ssd.ms';

export function parseObjectCategoryLabels(rawText: string): Array<string> {
  const labels: Array<string> = [];
  rawText.split('\n').forEach((line: string) => {
    const label = line.split('\r').join('').trim();
    if (label.length > 0) {
      labels.push(label);
    }
  });
  return labels;
}
