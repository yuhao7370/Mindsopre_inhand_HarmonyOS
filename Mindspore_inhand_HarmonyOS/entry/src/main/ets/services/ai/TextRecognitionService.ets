import { fileIo } from '@kit.CoreFileKit';
import { image } from '@kit.ImageKit';
import { textRecognition } from '@kit.CoreVisionKit';
import { createPixelMapWithExifOrientation } from './ImageDecodeOrientation';

export const translationLanguagePairsRawfilePath = 'hms/Country_pair_new.txt';

export interface TextRecognitionLine {
  readonly value: string;
}

export interface TextRecognitionBlock {
  readonly value: string;
  readonly lines: Array<TextRecognitionLine>;
}

export interface TextRecognitionResult {
  readonly ok: boolean;
  readonly text: string;
  readonly lineCount: number;
  readonly blockCount: number;
  readonly executionMs: number;
}

export interface TextRecognitionRunner {
  recognizeText(imageUri: string): Promise<TextRecognitionResult>;
}

export interface TextRecognitionServiceOptions {
  readonly runner: TextRecognitionRunner;
}

export class TextRecognitionService {
  private readonly runner: TextRecognitionRunner;

  constructor(options: TextRecognitionServiceOptions) {
    this.runner = options.runner;
  }

  async recognizeText(imageUri: string): Promise<TextRecognitionResult> {
    const startMs = Date.now();
    try {
      const result: TextRecognitionResult = await this.runner.recognizeText(imageUri);
      if (result.ok && !hasMeaningfulText(result.text)) {
        return {
          ok: false,
          text: result.text,
          lineCount: result.lineCount,
          blockCount: result.blockCount,
          executionMs: result.executionMs
        };
      }
      return result;
    } catch (_) {
      return {
        ok: false,
        text: '',
        lineCount: 0,
        blockCount: 0,
        executionMs: Date.now() - startMs
      };
    }
  }
}

export function hasMeaningfulText(text: string): boolean {
  return text.trim().length > 0;
}

export class HarmonyTextRecognitionRunner implements TextRecognitionRunner {
  async recognizeText(imageUri: string): Promise<TextRecognitionResult> {
    let imageFile: fileIo.File | undefined = undefined;
    let imageSource: image.ImageSource | undefined = undefined;
    let pixelMap: image.PixelMap | undefined = undefined;
    const startMs = Date.now();
    try {
      imageFile = await openTextRecognitionImageFile(imageUri);
      imageSource = image.createImageSource(imageFile.fd);
      pixelMap = await createPixelMapWithExifOrientation(imageSource);
      const result = await textRecognition.recognizeText({
        pixelMap: pixelMap
      }, {
        isDirectionDetectionSupported: true
      });
      const text = textRecognitionOutputFromBlocks(result.blocks);
      return {
        ok: hasMeaningfulText(text),
        text: text,
        lineCount: countTextRecognitionLines(result.blocks),
        blockCount: result.blocks.length,
        executionMs: Date.now() - startMs
      };
    } finally {
      if (pixelMap !== undefined) {
        await pixelMap.release();
      }
      if (imageSource !== undefined) {
        await imageSource.release();
      }
      if (imageFile !== undefined) {
        await closeTextRecognitionImageFile(imageFile);
      }
    }
  }
}

export interface TextTranslationLanguagePair {
  readonly name: string;
  readonly code: string;
}

export interface TextTranslationResult {
  readonly ok: boolean;
  readonly sourceText: string;
  readonly translatedText: string;
  readonly targetLanguage: string;
}

export interface TextTranslationRunner {
  translate(text: string, targetLanguage: string): Promise<TextTranslationResult>;
}

interface LocalTranslationPhrase {
  readonly source: string;
  readonly target: string;
}

const localChineseToEnglishPhrases: Array<LocalTranslationPhrase> = [
  { source: 'MindSpore \u638C\u4E2D\u5B9D', target: 'MindSpore Inhand' },
  { source: '\u4F53\u9A8C', target: 'experience' },
  { source: '\u89C6\u89C9\u56FE\u50CF\u6280\u672F', target: 'computer vision' },
  { source: '\u8BED\u97F3\u8BED\u4E49\u6280\u672F', target: 'speech semantic technology' },
  { source: '\u5B66\u9662', target: 'college' },
  { source: '\u6211\u7684', target: 'me' },
  { source: '\u4F53\u9A8C\u4E2D\u5FC3', target: 'Experience Center' },
  {
    source: 'HarmonyOS \u7248 AI \u793A\u4F8B\u5DF2\u5C31\u7EEA',
    target: 'AI demos ready for the HarmonyOS shell'
  },
  {
    source: '\u65B0\u4E00\u4EE3\u5168\u573A\u666FAI\u8BA1\u7B97\u6846\u67B6\uFF0C\u9080\u60A8\u9A6C\u4E0A\u4F53\u9A8C',
    target: 'Invite you to explore a new generation of ALL-Scenario AI Computing Framework'
  },
  {
    source: 'AI \u7231\u597D\u8005\u7684\u4E00\u7AD9\u5F0F\u534F\u540C\u5B66\u4E60\u3001\u6F14\u793A\u3001\u4F53\u9A8C\u5E73\u53F0',
    target: 'a one-stop platform of collaborative learning, demonstrating, and experiencing for AI users'
  },
  {
    source: 'MindSpore \u9700\u8981\u76F8\u673A\u548C\u5A92\u4F53\u8BBF\u95EE\u6743\u9650\uFF0C\u6388\u6743\u540E\u624D\u80FD\u7EE7\u7EED\u4F7F\u7528',
    target: 'MindSpore needs camera and media access. Grant these permissions to continue'
  },
  {
    source: 'MindSpore \u662F\u5168\u573A\u666F AI \u8BA1\u7B97\u6846\u67B6',
    target: 'MindSpore is a full-scenario AI computing framework'
  },
  { source: '\u6587\u672C\u7FFB\u8BD1\u5DF2\u5B8C\u6210', target: 'text translation completed' },
  {
    source: '\u672C\u9875\u63D0\u4F9B\u672C\u5730\u5B66\u4E60\u5165\u53E3\uFF0C\u5E76\u901A\u8FC7\u7F51\u9875\u6253\u5F00\u5916\u90E8\u8D44\u6E90',
    target: 'this page provides local learning entries and opens external resources in a web page'
  },
  {
    source: '\u56FE\u50CF\u5206\u7C7B\u53EF\u4EE5\u63A8\u6D4B\u56FE\u7247\u4E2D\u51FA\u73B0\u7269\u4F53\u7684\u6240\u5C5E\u7C7B\u522B',
    target: 'Image classification can infer the category of the object in the picture'
  },
  {
    source: '\u7167\u7247\u68C0\u6D4B\u53EF\u4EE5\u8BC6\u522B\u51FA\u56FE\u4E2D\u7269\u4F53\u7684\u7C7B\u522B\uFF0C\u5E76\u540C\u65F6\u6807\u793A\u7269\u4F53\u4F4D\u7F6E\u3002',
    target: 'Photo detection can identify the category of the object and mark its position in the image'
  },
  {
    source: '\u89C6\u9891\u68C0\u6D4B\u53EF\u4EE5\u8BC6\u522B\u51FA\u6444\u50CF\u5934\u4E2D\u7269\u4F53\u7684\u7C7B\u522B\uFF0C\u5E76\u540C\u65F6\u6807\u793A\u7269\u4F53\u4F4D\u7F6E\u3002',
    target: 'Camera detection can identify the category of the object and mark its position in the camera'
  },
  {
    source: '\u9AA8\u9ABC\u68C0\u6D4B\u53EF\u4EE5\u8BC6\u522B\u6444\u50CF\u5934\u4E2D\uFF0C\u4E0D\u540C\u59FF\u52BF\u4E0B\u4EBA\u4F53\u7684\u9762\u90E8\u4E94\u5B98\u4E0E\u80A2\u4F53\u59FF\u52BF\u3002',
    target: 'Posenet can identify the facial features and body postures of human in different positions in the camera'
  },
  {
    source: '\u98CE\u683C\u8FC1\u79FB\u53EF\u4EE5\u6839\u636EAPP\u5185\u7F6E\u7684\u6807\u51C6\u56FE\u7247\u6539\u53D8\u7528\u6237\u76EE\u6807\u56FE\u7247\u7684\u827A\u672F\u98CE\u683C\u3002',
    target: 'Style transfer can change the art style of users target images based on the standard image in the APP'
  },
  {
    source: '\u56FE\u50CF\u5206\u5272\u7528\u4E8E\u68C0\u6D4B\u76EE\u6807\u5728\u56FE\u7247\u4E2D\u7684\u4F4D\u7F6E\u6216\u8005\u56FE\u7247\u4E2D\u51FA\u73B0\u7684\u7269\u4F53\u662F\u5C5E\u4E8E\u4F55\u79CD\u7C7B\u522B\u7684\u3002',
    target: 'Image segmentation is used to detect the position of the target or the category of the object in the picture'
  },
  {
    source: '\u5783\u573E\u5206\u7C7B\u53EF\u8BC6\u522B\u51FA\u955C\u5934\u4E2D\u7269\u4F53\u6240\u5C5E\u7684\u5783\u573E\u7C7B\u522B\u3002',
    target: 'Garbage classification identifies the garbage category of the object detected by the camera lens'
  },
  {
    source: '\u573A\u666F\u68C0\u6D4B\u53EF\u4EE5\u5224\u65AD\u76EE\u6807\u573A\u666F\u7684\u7C7B\u578B',
    target: 'Scene detection can estimate the category of the target scene'
  },
  {
    source: '\u8BF7\u70B9\u51FB\u4E0B\u65B9\u56FE\u7247\u3001\u76F8\u673A\u3001\u5B9E\u65F6\u8FDB\u884C\u8BC6\u522B',
    target: 'Please click on the picture below, camera, and real-time recognition'
  },
  {
    source: '\u8BF7\u70B9\u51FB\u4E0B\u65B9\u56FE\u7247\u3001\u76F8\u673A\u8FDB\u884C\u63D0\u53D6',
    target: 'Please click on the picture below and the camera to extract'
  },
  {
    source: '\u672A\u68C0\u6D4B\u5230\u624B\u52BF\uFF0C\u518D\u6362\u4E00\u5F20\u56FE\u7247\u8BD5\u8BD5',
    target: 'No gesture detected, try another image'
  },
  {
    source: '\u56FE\u50CF\u5206\u5272\u5931\u8D25\uFF0C\u518D\u6362\u4E00\u5F20\u56FE\u7247\u8BD5\u8BD5',
    target: 'Image segmentation failed, try another image'
  },
  { source: '\u9009\u62E9\u6A21\u578B', target: 'Select Model' },
  { source: '\u9009\u62E9\u56FE\u7247', target: 'Select Photo' },
  { source: '\u62CD\u7167', target: 'Take Photo' },
  { source: '\u6267\u884C', target: 'Execute' },
  { source: '\u8F93\u51FA\u7ED3\u679C', target: 'Output Result' },
  { source: '\u6A21\u578B\u8F93\u51FA\u5C06\u663E\u793A\u5728\u8FD9\u91CC...', target: 'Model output will appear here...' },
  { source: '\u5E2E\u52A9', target: 'Help' },
  { source: '\u66F4\u591A', target: 'More' },
  {
    source: '\u8FD9\u662F\u4E00\u4E2A\u81EA\u5B9A\u4E49\u6A21\u578B\u6A21\u5757\uFF0C' +
      '\u60A8\u53EF\u4EE5\u5728\u8FD9\u91CC\u5B9E\u73B0\u81EA\u5DF1\u7684AI\u6A21\u578B\u529F\u80FD\u3002',
    target: 'This is a custom model module where you can implement your own AI model functionality.'
  },
  { source: '\u8BF7\u5148\u9009\u62E9\u539F\u59CB\u56FE\u7247', target: 'Please select an original picture first' },
  { source: '\u5148\u524D\u7684\u6A21\u578B\u4ECD\u5728\u8FD0\u884C', target: 'Previous Model still running' },
  {
    source: '\u70B9\u51FB\u4E0B\u65B9\u56FE\u7247\u6216\u76F8\u673A\u9009\u62E9\u7167\u7247',
    target: 'Please click a picture below or choose a photo from your album'
  },
  { source: '\u6062\u590D', target: 'RECOVERY' },
  { source: '\u9009\u62E9\u98CE\u683C', target: 'Choose a Style' },
  { source: '\u89E3\u6790\u5931\u8D25', target: 'ModelExecute failed' },
  { source: '\u573A\u666F\u8BA1\u6570', target: 'Scene Count' },
  { source: '\u573A\u666F', target: 'Scene' },
  { source: '\u5F97\u5206', target: 'Score' },
  { source: '\u63A8\u7406\u65F6\u95F4\uFF1A', target: 'Inference Time:' },
  { source: '\u6B63\u5728\u8BC6\u522B', target: 'Continue to identify' },
  {
    source: '\u60A8\u9009\u62E9\u7684\u56FE\u50CF\u8DEF\u5F84\u65E0\u6548\u3002\u8BF7\u518D\u6B21\u9009\u62E9',
    target: 'The image path you selected is not valid. Please choose again'
  },
  {
    source: '\u5BF9\u4E0D\u8D77\uFF0C\u6B64\u56FE\u7247\u4E2D\u6CA1\u6709\u4EFB\u4F55\u7269\u4F53\u3002' +
      '\u8BF7\u5C1D\u8BD5\u53E6\u4E00\u5F20\u56FE\u7247',
    target: 'Sorry, there is no object identified in this picture. Try another picture'
  },
  { source: '\u4EBA', target: 'human' },
  { source: '\u6C7D\u8F66', target: 'automobile' },
  { source: '\u4EA4\u901A\u706F', target: 'traffic signal' },
  { source: '\u8FD9\u662F\u4E00\u4E2A', target: 'this is a' },
  { source: '\u4F60\u597D\u4E16\u754C', target: 'hello world' },
  { source: '\u4F60\u597D', target: 'hello' },
  { source: '\u8C22\u8C22', target: 'thank you' },
  { source: '\u65E9\u4E0A\u597D', target: 'good morning' },
  { source: '\u665A\u4E0A\u597D', target: 'good evening' },
  { source: '\u4E2D\u56FD', target: 'China' },
  { source: '\u6587\u672C', target: 'text' },
  { source: '\u7FFB\u8BD1', target: 'translation' },
  { source: '\u8BF7\u8F93\u5165\u9700\u8981\u7FFB\u8BD1\u7684\u5185\u5BB9', target: 'Please enter the content to be translated' },
  { source: '\u5F53\u524D\u5185\u5BB9\u4E3A\u7A7A', target: 'The current content is empty' },
  { source: '\u79BB\u7EBF\u7FFB\u8BD1', target: 'Offline Translation' },
  { source: '\u68C0\u6D4B\u8BED\u8A00', target: 'Detection language' },
  { source: '\u56FE\u7247', target: 'image' },
  { source: '\u8BC6\u522B', target: 'recognition' },
  { source: '\u68C0\u6D4B', target: 'detect' },
  { source: '\u89C6\u9891', target: 'video' },
  { source: '\u590D\u5236', target: 'copy' },
  { source: '\u4FDD\u5B58', target: 'SAVE' },
  { source: '\u590D\u5236\u6210\u529F', target: 'Copied successfully' },
  { source: '\u4FDD\u5B58\u6210\u529F', target: 'Save success' },
  { source: '\u6CA1\u6709\u9700\u8981\u4FDD\u5B58\u7684\u56FE\u7247', target: 'Null Image needed to save' },
  { source: '\u4FDD\u5B58\u5931\u8D25', target: 'Save Failure' },
  { source: '\u7B80\u8981\u8BF4\u660E', target: 'Summary' },
  { source: '\u9AA8\u9ABC\u68C0\u6D4B', target: 'PoseNet' },
  { source: '\u6211\u7684\u4E8C\u7EF4\u7801', target: 'My QR Code' },
  { source: '\u5B98\u65B9\u7F51\u7AD9', target: 'Official Website' },
  { source: '\u5B98\u65B9\u4EE3\u7801\u4ED3', target: 'Official Code' },
  { source: '\u95EE\u9898\u53CD\u9988', target: 'Feedback' },
  { source: '\u7528\u6237\u534F\u8BAE\u548C\u9690\u79C1\u653F\u7B56', target: 'User Agreement and Privacy Policy' },
  { source: '\u5FEB\u901F\u5165\u95E8', target: 'Quick Start' },
  { source: '\u8BAD\u7EC3\u6A21\u578B', target: 'Train' },
  { source: '\u6267\u884C\u63A8\u7406', target: 'Inference' },
  { source: '\u7AEF\u4FA7\u5E94\u7528', target: 'Applications' },
  { source: '\u8BBA\u575B\u63D0\u95EE', target: 'Ask on forum' },
  { source: '\u53C2\u8003\u89C6\u9891', target: 'Reference video' },
  { source: '\u67E5\u770B', target: 'View' },
  { source: '~\u70B9\u4EAE\u60A8\u7684\u5B66\u4E60\u4E4B\u65C5~', target: '~Illuminate your learning trip~' },
  { source: '\u4EBA\u5DE5\u667A\u80FD', target: 'artificial intelligence' },
  { source: '\u673A\u5668\u5B66\u4E60', target: 'machine learning' },
  { source: '\u6DF1\u5EA6\u5B66\u4E60', target: 'deep learning' },
  { source: '\u534E\u4E3A', target: 'Huawei' },
  { source: '\u6607\u601D', target: 'MindSpore' },
  { source: '\u6A21\u578B', target: 'model' },
  { source: '\u56FE\u50CF\u5206\u7C7B', target: 'image classification' },
  { source: '\u76EE\u6807\u68C0\u6D4B', target: 'object detection' },
  { source: '\u5BF9\u8C61\u68C0\u6D4B', target: 'object detection' },
  { source: '\u5BF9\u8C61\u68C0\u6D4B\u56FE\u7247', target: 'Object Detection(Photo)' },
  { source: '\u5BF9\u8C61\u68C0\u6D4B\u5B9E\u65F6', target: 'Object Detection(Real-time)' },
  { source: '\u4EBA\u50CF\u5206\u5272', target: 'portrait segmentation' },
  { source: '\u59FF\u6001\u4F30\u8BA1', target: 'pose estimation' },
  { source: '\u624B\u52BF\u8BC6\u522B', target: 'gesture recognition' },
  { source: '\u573A\u666F\u68C0\u6D4B', target: 'scene detection' },
  { source: '\u6587\u672C\u63D0\u53D6', target: 'text extraction' },
  { source: '\u5B9E\u65F6\u7FFB\u8BD1', target: 'real-time translation' },
  { source: '\u98CE\u683C\u8FC1\u79FB', target: 'style transfer' },
  { source: '\u81EA\u5B9A\u4E49\u6A21\u578B', target: 'custom model' },
  { source: '\u53EF\u4EE5\u5728\u624B\u673A\u4E0A\u8FD0\u884C', target: 'can run on phone' },
  { source: '\u5728\u624B\u673A\u4E0A\u8FD0\u884C', target: 'run on phone' },
  { source: '\u53EF\u4EE5', target: 'can' },
  { source: '\u8FD0\u884C', target: 'run' },
  { source: '\u5728\u624B\u673A\u4E0A', target: 'on phone' },
  { source: '\u5B9E\u65F6', target: 'real-time' },
  { source: '\u76F8\u673A', target: 'camera' },
  { source: '\u7167\u7247', target: 'photo' }
];

const localEnglishToChinesePhrases: Array<LocalTranslationPhrase> = [
  { source: 'mindspore inhand', target: 'MindSpore \u638C\u4E2D\u5B9D' },
  { source: 'experience', target: '\u4F53\u9A8C' },
  { source: 'computer vision', target: '\u89C6\u89C9\u56FE\u50CF\u6280\u672F' },
  { source: 'speech semantic technology', target: '\u8BED\u97F3\u8BED\u4E49\u6280\u672F' },
  { source: 'college', target: '\u5B66\u9662' },
  { source: 'me', target: '\u6211\u7684' },
  { source: 'experience center', target: '\u4F53\u9A8C\u4E2D\u5FC3' },
  {
    source: 'ai demos ready for the harmonyos shell',
    target: 'HarmonyOS \u7248 AI \u793A\u4F8B\u5DF2\u5C31\u7EEA'
  },
  {
    source: 'invite you to explore a new generation of all-scenario ai computing framework',
    target: '\u65B0\u4E00\u4EE3\u5168\u573A\u666FAI\u8BA1\u7B97\u6846\u67B6\uFF0C\u9080\u60A8\u9A6C\u4E0A\u4F53\u9A8C'
  },
  {
    source: 'a one-stop platform of collaborative learning, demonstrating, and experiencing for AI users',
    target: 'AI \u7231\u597D\u8005\u7684\u4E00\u7AD9\u5F0F\u534F\u540C\u5B66\u4E60\u3001\u6F14\u793A\u3001\u4F53\u9A8C\u5E73\u53F0'
  },
  {
    source: 'mindspore needs camera and media access grant these permissions to continue',
    target: 'MindSpore \u9700\u8981\u76F8\u673A\u548C\u5A92\u4F53\u8BBF\u95EE\u6743\u9650\uFF0C\u6388\u6743\u540E\u624D\u80FD\u7EE7\u7EED\u4F7F\u7528'
  },
  {
    source: 'mindspore is a full-scenario ai computing framework',
    target: 'MindSpore \u662F\u5168\u573A\u666F AI \u8BA1\u7B97\u6846\u67B6'
  },
  { source: 'text translation completed', target: '\u6587\u672C\u7FFB\u8BD1\u5DF2\u5B8C\u6210' },
  {
    source: 'this page provides local learning entries and opens external resources in a web page',
    target: '\u672C\u9875\u63D0\u4F9B\u672C\u5730\u5B66\u4E60\u5165\u53E3\uFF0C\u5E76\u901A\u8FC7\u7F51\u9875\u6253\u5F00\u5916\u90E8\u8D44\u6E90'
  },
  {
    source: 'image classification can infer the category of the object in the picture',
    target: '\u56FE\u50CF\u5206\u7C7B\u53EF\u4EE5\u63A8\u6D4B\u56FE\u7247\u4E2D\u51FA\u73B0\u7269\u4F53\u7684\u6240\u5C5E\u7C7B\u522B'
  },
  {
    source: 'image classification can infer the category of the object in the picture and indicate the probability of different categories',
    target: '\u56FE\u50CF\u5206\u7C7B\u53EF\u4EE5\u63A8\u6D4B\u56FE\u7247\u4E2D\u51FA\u73B0\u7269\u4F53\u7684\u6240\u5C5E\u7C7B\u522B\uFF0C\u5E76\u6807\u793A\u4E0D\u540C\u7C7B\u522B\u7684\u53EF\u80FD\u6027\u6982\u7387\u3002'
  },
  {
    source: 'photo detection can identify the category of the object and mark its position in the image',
    target: '\u7167\u7247\u68C0\u6D4B\u53EF\u4EE5\u8BC6\u522B\u51FA\u56FE\u4E2D\u7269\u4F53\u7684\u7C7B\u522B\uFF0C\u5E76\u540C\u65F6\u6807\u793A\u7269\u4F53\u4F4D\u7F6E\u3002'
  },
  {
    source: 'camera detection can identify the category of the object and mark its position in the camera',
    target: '\u89C6\u9891\u68C0\u6D4B\u53EF\u4EE5\u8BC6\u522B\u51FA\u6444\u50CF\u5934\u4E2D\u7269\u4F53\u7684\u7C7B\u522B\uFF0C\u5E76\u540C\u65F6\u6807\u793A\u7269\u4F53\u4F4D\u7F6E\u3002'
  },
  {
    source: 'posenet can identify the facial features and body postures of human in different positions in the camera',
    target: '\u9AA8\u9ABC\u68C0\u6D4B\u53EF\u4EE5\u8BC6\u522B\u6444\u50CF\u5934\u4E2D\uFF0C\u4E0D\u540C\u59FF\u52BF\u4E0B\u4EBA\u4F53\u7684\u9762\u90E8\u4E94\u5B98\u4E0E\u80A2\u4F53\u59FF\u52BF\u3002'
  },
  {
    source: 'style transfer can change the art style of users target images based on the standard image in the app',
    target: '\u98CE\u683C\u8FC1\u79FB\u53EF\u4EE5\u6839\u636EAPP\u5185\u7F6E\u7684\u6807\u51C6\u56FE\u7247\u6539\u53D8\u7528\u6237\u76EE\u6807\u56FE\u7247\u7684\u827A\u672F\u98CE\u683C\u3002'
  },
  {
    source: 'image segmentation is used to detect the position of the target or the category of the object in the picture',
    target: '\u56FE\u50CF\u5206\u5272\u7528\u4E8E\u68C0\u6D4B\u76EE\u6807\u5728\u56FE\u7247\u4E2D\u7684\u4F4D\u7F6E\u6216\u8005\u56FE\u7247\u4E2D\u51FA\u73B0\u7684\u7269\u4F53\u662F\u5C5E\u4E8E\u4F55\u79CD\u7C7B\u522B\u7684\u3002'
  },
  {
    source: 'garbage classification identifies the garbage category of the object detected by the camera lens',
    target: '\u5783\u573E\u5206\u7C7B\u53EF\u8BC6\u522B\u51FA\u955C\u5934\u4E2D\u7269\u4F53\u6240\u5C5E\u7684\u5783\u573E\u7C7B\u522B\u3002'
  },
  {
    source: 'scene detection can estimate the category of the target scene',
    target: '\u573A\u666F\u68C0\u6D4B\u53EF\u4EE5\u5224\u65AD\u76EE\u6807\u573A\u666F\u7684\u7C7B\u578B'
  },
  {
    source: 'please click on the picture below camera and real time recognition',
    target: '\u8BF7\u70B9\u51FB\u4E0B\u65B9\u56FE\u7247\u3001\u76F8\u673A\u3001\u5B9E\u65F6\u8FDB\u884C\u8BC6\u522B'
  },
  {
    source: 'please click on the picture below and the camera to extract',
    target: '\u8BF7\u70B9\u51FB\u4E0B\u65B9\u56FE\u7247\u3001\u76F8\u673A\u8FDB\u884C\u63D0\u53D6'
  },
  {
    source: 'no gesture detected try another image',
    target: '\u672A\u68C0\u6D4B\u5230\u624B\u52BF\uFF0C\u518D\u6362\u4E00\u5F20\u56FE\u7247\u8BD5\u8BD5'
  },
  {
    source: 'image segmentation failed try another image',
    target: '\u56FE\u50CF\u5206\u5272\u5931\u8D25\uFF0C\u518D\u6362\u4E00\u5F20\u56FE\u7247\u8BD5\u8BD5'
  },
  { source: 'select model', target: '\u9009\u62E9\u6A21\u578B' },
  { source: 'select photo', target: '\u9009\u62E9\u56FE\u7247' },
  { source: 'take photo', target: '\u62CD\u7167' },
  { source: 'execute', target: '\u6267\u884C' },
  { source: 'select image', target: '\u9009\u62E9\u56FE\u7247' },
  { source: 'output result', target: '\u8F93\u51FA\u7ED3\u679C' },
  { source: 'model output will appear here', target: '\u6A21\u578B\u8F93\u51FA\u5C06\u663E\u793A\u5728\u8FD9\u91CC...' },
  { source: 'help', target: '\u5E2E\u52A9' },
  { source: 'more', target: '\u66F4\u591A' },
  {
    source: 'this is a custom model module where you can implement your own ai model functionality',
    target: '\u8FD9\u662F\u4E00\u4E2A\u81EA\u5B9A\u4E49\u6A21\u578B\u6A21\u5757\uFF0C' +
      '\u60A8\u53EF\u4EE5\u5728\u8FD9\u91CC\u5B9E\u73B0\u81EA\u5DF1\u7684AI\u6A21\u578B\u529F\u80FD\u3002'
  },
  { source: 'please select an original picture first', target: '\u8BF7\u5148\u9009\u62E9\u539F\u59CB\u56FE\u7247' },
  { source: 'previous model still running', target: '\u5148\u524D\u7684\u6A21\u578B\u4ECD\u5728\u8FD0\u884C' },
  {
    source: 'please click a picture below or choose a photo from your album',
    target: '\u70B9\u51FB\u4E0B\u65B9\u56FE\u7247\u6216\u76F8\u673A\u9009\u62E9\u7167\u7247'
  },
  { source: 'recovery', target: '\u6062\u590D' },
  { source: 'choose a style', target: '\u9009\u62E9\u98CE\u683C' },
  { source: 'modelexecute failed', target: '\u89E3\u6790\u5931\u8D25' },
  { source: 'scene count', target: '\u573A\u666F\u8BA1\u6570' },
  { source: 'scenes', target: '\u573A\u666F' },
  { source: 'scene', target: '\u573A\u666F' },
  { source: 'score', target: '\u5F97\u5206' },
  { source: 'inference time', target: '\u63A8\u7406\u65F6\u95F4\uFF1A' },
  { source: 'continue to identify', target: '\u6B63\u5728\u8BC6\u522B' },
  {
    source: 'the image path you selected is not valid please choose again',
    target: '\u60A8\u9009\u62E9\u7684\u56FE\u50CF\u8DEF\u5F84\u65E0\u6548\u3002\u8BF7\u518D\u6B21\u9009\u62E9'
  },
  {
    source: 'sorry there is no object identified in this picture try another picture',
    target: '\u5BF9\u4E0D\u8D77\uFF0C\u6B64\u56FE\u7247\u4E2D\u6CA1\u6709\u4EFB\u4F55\u7269\u4F53\u3002' +
      '\u8BF7\u5C1D\u8BD5\u53E6\u4E00\u5F20\u56FE\u7247'
  },
  { source: 'human', target: '\u4EBA' },
  { source: 'automobile', target: '\u6C7D\u8F66' },
  { source: 'traffic signal', target: '\u4EA4\u901A\u706F' },
  { source: 'this is a', target: '\u8FD9\u662F\u4E00\u4E2A' },
  { source: 'this is an', target: '\u8FD9\u662F\u4E00\u4E2A' },
  { source: 'hello world', target: '\u4F60\u597D\u4E16\u754C' },
  { source: 'good morning', target: '\u65E9\u4E0A\u597D' },
  { source: 'good evening', target: '\u665A\u4E0A\u597D' },
  { source: 'thank you', target: '\u8C22\u8C22' },
  { source: 'thanks', target: '\u8C22\u8C22' },
  { source: 'hello', target: '\u4F60\u597D' },
  { source: 'china', target: '\u4E2D\u56FD' },
  { source: 'text', target: '\u6587\u672C' },
  { source: 'translation', target: '\u7FFB\u8BD1' },
  { source: 'please enter the content to be translated', target: '\u8BF7\u8F93\u5165\u9700\u8981\u7FFB\u8BD1\u7684\u5185\u5BB9' },
  { source: 'the current content is empty', target: '\u5F53\u524D\u5185\u5BB9\u4E3A\u7A7A' },
  { source: 'offline translation', target: '\u79BB\u7EBF\u7FFB\u8BD1' },
  { source: 'detection language', target: '\u68C0\u6D4B\u8BED\u8A00' },
  { source: 'image', target: '\u56FE\u7247' },
  { source: 'recognition', target: '\u8BC6\u522B' },
  { source: 'detect', target: '\u68C0\u6D4B' },
  { source: 'video', target: '\u89C6\u9891' },
  { source: 'copy', target: '\u590D\u5236' },
  { source: 'save', target: '\u4FDD\u5B58' },
  { source: 'copied successfully', target: '\u590D\u5236\u6210\u529F' },
  { source: 'save success', target: '\u4FDD\u5B58\u6210\u529F' },
  { source: 'null image needed to save', target: '\u6CA1\u6709\u9700\u8981\u4FDD\u5B58\u7684\u56FE\u7247' },
  { source: 'save failure', target: '\u4FDD\u5B58\u5931\u8D25' },
  { source: 'summary', target: '\u7B80\u8981\u8BF4\u660E' },
  { source: 'posenet', target: '\u9AA8\u9ABC\u68C0\u6D4B' },
  { source: 'my qr code', target: '\u6211\u7684\u4E8C\u7EF4\u7801' },
  { source: 'official website', target: '\u5B98\u65B9\u7F51\u7AD9' },
  { source: 'official code', target: '\u5B98\u65B9\u4EE3\u7801\u4ED3' },
  { source: 'feedback', target: '\u95EE\u9898\u53CD\u9988' },
  { source: 'user agreement and privacy policy', target: '\u7528\u6237\u534F\u8BAE\u548C\u9690\u79C1\u653F\u7B56' },
  { source: 'quick start', target: '\u5FEB\u901F\u5165\u95E8' },
  { source: 'train', target: '\u8BAD\u7EC3\u6A21\u578B' },
  { source: 'inference', target: '\u6267\u884C\u63A8\u7406' },
  { source: 'applications', target: '\u7AEF\u4FA7\u5E94\u7528' },
  { source: 'ask on forum', target: '\u8BBA\u575B\u63D0\u95EE' },
  { source: 'reference video', target: '\u53C2\u8003\u89C6\u9891' },
  { source: 'view', target: '\u67E5\u770B' },
  { source: '~illuminate your learning trip~', target: '~\u70B9\u4EAE\u60A8\u7684\u5B66\u4E60\u4E4B\u65C5~' },
  { source: 'artificial intelligence', target: '\u4EBA\u5DE5\u667A\u80FD' },
  { source: 'machine learning', target: '\u673A\u5668\u5B66\u4E60' },
  { source: 'deep learning', target: '\u6DF1\u5EA6\u5B66\u4E60' },
  { source: 'huawei', target: '\u534E\u4E3A' },
  { source: 'mindspore', target: '\u6607\u601D' },
  { source: 'model', target: '\u6A21\u578B' },
  { source: 'image classification', target: '\u56FE\u50CF\u5206\u7C7B' },
  { source: 'object detection', target: '\u76EE\u6807\u68C0\u6D4B' },
  { source: 'object detection photo', target: '\u5BF9\u8C61\u68C0\u6D4B(\u56FE\u7247)' },
  { source: 'object detection real time', target: '\u5BF9\u8C61\u68C0\u6D4B(\u5B9E\u65F6)' },
  { source: 'portrait segmentation', target: '\u4EBA\u50CF\u5206\u5272' },
  { source: 'pose estimation', target: '\u59FF\u6001\u4F30\u8BA1' },
  { source: 'gesture recognition', target: '\u624B\u52BF\u8BC6\u522B' },
  { source: 'scene detection', target: '\u573A\u666F\u68C0\u6D4B' },
  { source: 'text extraction', target: '\u6587\u672C\u63D0\u53D6' },
  { source: 'real time translation', target: '\u5B9E\u65F6\u7FFB\u8BD1' },
  { source: 'style transfer', target: '\u98CE\u683C\u8FC1\u79FB' },
  { source: 'custom model', target: '\u81EA\u5B9A\u4E49\u6A21\u578B' },
  { source: 'can run on the phone', target: '\u53EF\u4EE5\u5728\u624B\u673A\u4E0A\u8FD0\u884C' },
  { source: 'can run on phone', target: '\u53EF\u4EE5\u5728\u624B\u673A\u4E0A\u8FD0\u884C' },
  { source: 'runs on the phone', target: '\u5728\u624B\u673A\u4E0A\u8FD0\u884C' },
  { source: 'runs on phone', target: '\u5728\u624B\u673A\u4E0A\u8FD0\u884C' },
  { source: 'run on the phone', target: '\u5728\u624B\u673A\u4E0A\u8FD0\u884C' },
  { source: 'run on phone', target: '\u5728\u624B\u673A\u4E0A\u8FD0\u884C' },
  { source: 'can', target: '\u53EF\u4EE5' },
  { source: 'run', target: '\u8FD0\u884C' },
  { source: 'runs', target: '\u8FD0\u884C' },
  { source: 'on the phone', target: '\u5728\u624B\u673A\u4E0A' },
  { source: 'on phone', target: '\u5728\u624B\u673A\u4E0A' },
  { source: 'real time', target: '\u5B9E\u65F6' },
  { source: 'camera', target: '\u76F8\u673A' },
  { source: 'photo', target: '\u56FE\u7247' }
];

export interface TextTranslationServiceOptions {
  readonly runner: TextTranslationRunner;
  readonly languagePairs?: Array<TextTranslationLanguagePair>;
}

export class TextTranslationService {
  private readonly runner: TextTranslationRunner;
  private readonly languagePairs?: Array<TextTranslationLanguagePair>;

  constructor(options: TextTranslationServiceOptions) {
    this.runner = options.runner;
    this.languagePairs = options.languagePairs;
  }

  async translateText(text: string): Promise<TextTranslationResult> {
    const targetLanguage = androidDefaultTranslationTargetLanguage(text);
    if (!translationLanguagePairSupportsTarget(this.languagePairs, targetLanguage)) {
      return {
        ok: false,
        sourceText: text,
        translatedText: '',
        targetLanguage: targetLanguage
      };
    }
    try {
      return await this.runner.translate(text, targetLanguage);
    } catch (_) {
      return {
        ok: false,
        sourceText: text,
        translatedText: '',
        targetLanguage: targetLanguage
      };
    }
  }
}

export class LocalTextTranslationRunner implements TextTranslationRunner {
  async translate(text: string, targetLanguage: string): Promise<TextTranslationResult> {
    const normalizedTargetLanguage = normalizeLocalTranslationTargetLanguage(targetLanguage);
    const translatedText = localTranslatedText(text, normalizedTargetLanguage);
    return {
      ok: translatedText.length > 0,
      sourceText: text,
      translatedText: translatedText,
      targetLanguage: normalizedTargetLanguage
    };
  }
}

export function textRecognitionOutputFromBlocks(blocks: Array<TextRecognitionBlock>): string {
  const lines: Array<string> = [];
  blocks.forEach((block: TextRecognitionBlock) => {
    block.lines.forEach((line: TextRecognitionLine) => {
      lines.push(line.value);
    });
  });
  if (lines.length === 0) {
    return '';
  }
  return `${lines.join('\n')}\n`;
}

export function countTextRecognitionLines(blocks: Array<TextRecognitionBlock>): number {
  let count = 0;
  blocks.forEach((block: TextRecognitionBlock) => {
    count += block.lines.length;
  });
  return count;
}

export function containsAndroidChineseText(text: string): boolean {
  for (let index = 0; index < text.length; index++) {
    const code = text.charCodeAt(index);
    if ((code >= 0x4E00 && code <= 0x9FA5) ||
      (code >= 0xFF00 && code <= 0xFFEF) ||
      (code >= 0x2E80 && code <= 0x2EFF) ||
      (code >= 0x3000 && code <= 0x303F) ||
      (code >= 0x31C0 && code <= 0x31EF)) {
      return true;
    }
  }
  return false;
}

export function androidDefaultTranslationTargetLanguage(text: string): string {
  return containsAndroidChineseText(text) ? 'en' : 'zh';
}

export function parseTranslationLanguagePairs(content: string): Array<TextTranslationLanguagePair> {
  const pairs: Array<TextTranslationLanguagePair> = [];
  content.split('\n').forEach((line: string) => {
    const trimmed = line.trim();
    if (trimmed.length === 0) {
      return;
    }
    const separator = trimmed.lastIndexOf(' ');
    if (separator <= 0 || separator >= trimmed.length - 1) {
      return;
    }
    pairs.push({
      name: trimmed.substring(0, separator),
      code: trimmed.substring(separator + 1)
    });
  });
  return pairs;
}

export function translationLanguagePairSupportsTarget(
  languagePairs: Array<TextTranslationLanguagePair> | undefined,
  targetLanguage: string
): boolean {
  if (languagePairs === undefined || languagePairs.length === 0) {
    return true;
  }
  const normalizedTargetLanguage = normalizeLocalTranslationTargetLanguage(targetLanguage);
  return languagePairs.some((pair: TextTranslationLanguagePair) =>
    normalizeLocalTranslationTargetLanguage(pair.code) === normalizedTargetLanguage);
}

export function localTranslatedText(text: string, targetLanguage: string): string {
  const target = normalizeLocalTranslationTargetLanguage(targetLanguage);
  if (target !== 'en' && target !== 'zh') {
    return '';
  }
  const phrases = target === 'en' ? localChineseToEnglishPhrases : localEnglishToChinesePhrases;
  const translatedLines: Array<string> = [];
  const lines = text.split('\n');
  for (let index = 0; index < lines.length; index++) {
    const translatedLine = localTranslatedLine(lines[index], phrases, target);
    if (translatedLine.length > 0) {
      translatedLines.push(translatedLine);
    } else if (lines[index].trim().length > 0) {
      return '';
    }
  }
  return translatedLines.join('\n');
}

function localTranslatedLine(line: string, phrases: Array<LocalTranslationPhrase>, targetLanguage: string): string {
  const normalizedLine = normalizeLocalTranslationPhrase(line);
  if (normalizedLine.length === 0) {
    return '';
  }
  for (let index = 0; index < phrases.length; index++) {
    if (normalizedLine === normalizeLocalTranslationPhrase(phrases[index].source)) {
      return phrases[index].target;
    }
  }
  if (targetLanguage === 'en') {
    return localComposedChineseToEnglishLine(normalizedLine, phrases);
  }
  if (targetLanguage === 'zh') {
    return localComposedEnglishToChineseLine(normalizedLine, phrases);
  }
  return '';
}

function localComposedChineseToEnglishLine(
  normalizedLine: string,
  phrases: Array<LocalTranslationPhrase>
): string {
  const source = normalizedLine.split(' ').join('');
  const translatedParts: Array<string> = [];
  let cursor = 0;
  while (cursor < source.length) {
    const match = longestLocalPhrasePrefix(source, cursor, phrases);
    if (match === undefined) {
      return '';
    }
    translatedParts.push(match.target);
    cursor += normalizeLocalTranslationPhrase(match.source).split(' ').join('').length;
  }
  return translatedParts.join(' ');
}

function localComposedEnglishToChineseLine(
  normalizedLine: string,
  phrases: Array<LocalTranslationPhrase>
): string {
  const tokens = normalizedLine.split(' ').filter((token: string) => token.length > 0);
  const translatedParts: Array<string> = [];
  let cursor = 0;
  while (cursor < tokens.length) {
    const match = longestLocalPhraseTokenMatch(tokens, cursor, phrases);
    if (match === undefined) {
      return '';
    }
    translatedParts.push(match.target);
    cursor += normalizeLocalTranslationPhrase(match.source).split(' ')
      .filter((token: string) => token.length > 0).length;
  }
  return translatedParts.join('');
}

function longestLocalPhrasePrefix(
  source: string,
  cursor: number,
  phrases: Array<LocalTranslationPhrase>
): LocalTranslationPhrase | undefined {
  let best: LocalTranslationPhrase | undefined = undefined;
  let bestLength = 0;
  for (let index = 0; index < phrases.length; index++) {
    const phraseSource = normalizeLocalTranslationPhrase(phrases[index].source).split(' ').join('');
    if (phraseSource.length > bestLength && source.indexOf(phraseSource, cursor) === cursor) {
      best = phrases[index];
      bestLength = phraseSource.length;
    }
  }
  return best;
}

function longestLocalPhraseTokenMatch(
  tokens: Array<string>,
  cursor: number,
  phrases: Array<LocalTranslationPhrase>
): LocalTranslationPhrase | undefined {
  let best: LocalTranslationPhrase | undefined = undefined;
  let bestLength = 0;
  for (let index = 0; index < phrases.length; index++) {
    const phraseTokens = normalizeLocalTranslationPhrase(phrases[index].source).split(' ')
      .filter((token: string) => token.length > 0);
    if (phraseTokens.length > bestLength && localPhraseTokensMatch(tokens, cursor, phraseTokens)) {
      best = phrases[index];
      bestLength = phraseTokens.length;
    }
  }
  return best;
}

function localPhraseTokensMatch(tokens: Array<string>, cursor: number, phraseTokens: Array<string>): boolean {
  if (cursor + phraseTokens.length > tokens.length) {
    return false;
  }
  for (let index = 0; index < phraseTokens.length; index++) {
    if (tokens[cursor + index] !== phraseTokens[index]) {
      return false;
    }
  }
  return true;
}

function normalizeLocalTranslationTargetLanguage(targetLanguage: string): string {
  const normalized = targetLanguage.trim().toLowerCase();
  if (normalized === 'zh-hk') {
    return 'zh';
  }
  return normalized;
}

function normalizeLocalTranslationPhrase(text: string): string {
  let value = text.split('\r').join('').trim().toLowerCase();
  const separators: Array<string> =
    ['(', ')', '[', ']', '{', '}', '\uFF08', '\uFF09', '\u3010', '\u3011', '-', '_', '/', '\\'];
  for (let index = 0; index < separators.length; index++) {
    value = value.split(separators[index]).join(' ');
  }
  const punctuation: Array<string> = ['.', ',', '!', '?', ':', ';', '\uFF0C', '\u3002', '\uFF01', '\uFF1F'];
  for (let index = 0; index < punctuation.length; index++) {
    value = value.split(punctuation[index]).join('');
  }
  return value.split(' ').filter((part: string) => part.length > 0).join(' ');
}

async function openTextRecognitionImageFile(imageUri: string): Promise<fileIo.File> {
  try {
    return await fileIo.open(imageUri, fileIo.OpenMode.READ_ONLY);
  } catch (_) {
    throw new Error('Unable to open image input for text recognition.');
  }
}

async function closeTextRecognitionImageFile(imageFile: fileIo.File): Promise<void> {
  try {
    await fileIo.close(imageFile);
  } catch (_) {
  }
}
