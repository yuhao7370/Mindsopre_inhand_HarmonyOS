export const stylePredictModelRawfilePath: string = 'model/style_predict_quant.ms';
export const styleTransferModelRawfilePath: string = 'model/style_transfer_quant.ms';
export const stylePredictModelDownloadUrl: string =
  'https://download.mindspore.cn/model_zoo/official/lite/style_lite/style_predict_quant.ms';
export const styleTransferModelDownloadUrl: string =
  'https://download.mindspore.cn/model_zoo/official/lite/style_lite/style_transfer_quant.ms';
export const styleTransferStyleImageSize: number = 256;
export const styleTransferContentImageSize: number = 384;
export const styleTransferChannels: number = 3;
export const styleTransferOutputFloatCount: number =
  styleTransferContentImageSize * styleTransferContentImageSize * styleTransferChannels;

export interface StyleTransferResult {
  readonly ok: boolean;
  readonly outputFloatCount: number;
  readonly predictMs: number;
  readonly transferMs: number;
  readonly executionMs: number;
}

export interface StyleTransferRunner {
  run(contentImageUri: string, styleImageUri: string): Promise<StyleTransferResult>;
}

export interface StyleTransferServiceOptions {
  readonly runner?: StyleTransferRunner;
}

export class StyleTransferService {
  private readonly runner?: StyleTransferRunner;

  constructor(options: StyleTransferServiceOptions) {
    this.runner = options.runner;
  }

  async run(contentImageUri: string, styleImageUri: string): Promise<StyleTransferResult> {
    if (this.runner === undefined) {
      return emptyStyleTransferResult();
    }
    try {
      return await this.runner.run(contentImageUri, styleImageUri);
    } catch (_) {
      return emptyStyleTransferResult();
    }
  }
}

function emptyStyleTransferResult(): StyleTransferResult {
  return {
    ok: false,
    outputFloatCount: 0,
    predictMs: 0,
    transferMs: 0,
    executionMs: 0
  };
}
