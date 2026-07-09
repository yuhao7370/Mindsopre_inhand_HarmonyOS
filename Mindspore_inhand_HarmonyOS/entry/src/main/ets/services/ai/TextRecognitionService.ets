import { fileIo } from '@kit.CoreFileKit';
import { image } from '@kit.ImageKit';
import { textRecognition } from '@kit.CoreVisionKit';

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
      return await this.runner.recognizeText(imageUri);
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

export class HarmonyTextRecognitionRunner implements TextRecognitionRunner {
  async recognizeText(imageUri: string): Promise<TextRecognitionResult> {
    let imageFile: fileIo.File | undefined = undefined;
    let imageSource: image.ImageSource | undefined = undefined;
    let pixelMap: image.PixelMap | undefined = undefined;
    const startMs = Date.now();
    try {
      imageFile = await openTextRecognitionImageFile(imageUri);
      imageSource = image.createImageSource(imageFile.fd);
      pixelMap = await imageSource.createPixelMap();
      const result = await textRecognition.recognizeText({
        pixelMap: pixelMap
      }, {
        isDirectionDetectionSupported: true
      });
      const text = textRecognitionOutputFromBlocks(result.blocks);
      return {
        ok: text.length > 0,
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

export interface TextTranslationServiceOptions {
  readonly runner: TextTranslationRunner;
}

export class TextTranslationService {
  private readonly runner: TextTranslationRunner;

  constructor(options: TextTranslationServiceOptions) {
    this.runner = options.runner;
  }

  async translateText(text: string): Promise<TextTranslationResult> {
    const targetLanguage = androidDefaultTranslationTargetLanguage(text);
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
