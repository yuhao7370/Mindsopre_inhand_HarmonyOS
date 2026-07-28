import { describe, expect, it } from '@ohos/hypium';
import {
  handwrittenDigitInputFromRgba,
  topHandwrittenDigitResults
} from '../main/ets/services/ai/HandwrittenDigitPreprocess';
import {
  HandwrittenDigitImagePreprocessor,
  HandwrittenDigitScoreRunner,
  HandwrittenDigitService
} from '../main/ets/services/ai/HandwrittenDigitService';

function assertThrows(action: () => void): void {
  let threw = false;
  try {
    action();
  } catch (_) {
    threw = true;
  }
  expect(threw).assertTrue();
}

function rgbaCanvas(width: number, height: number, value: number): Uint8Array {
  const rgba = new Uint8Array(width * height * 4);
  for (let index = 0; index < rgba.length; index += 4) {
    rgba[index] = value;
    rgba[index + 1] = value;
    rgba[index + 2] = value;
    rgba[index + 3] = 255;
  }
  return rgba;
}

function fillRect(rgba: Uint8Array, width: number, left: number, top: number, rectWidth: number,
  rectHeight: number, value: number): void {
  for (let y = top; y < top + rectHeight; y++) {
    for (let x = left; x < left + rectWidth; x++) {
      const offset = (y * width + x) * 4;
      rgba[offset] = value;
      rgba[offset + 1] = value;
      rgba[offset + 2] = value;
    }
  }
}

function foregroundCenter(input: Float32Array): Array<number> {
  let mass = 0;
  let centerX = 0;
  let centerY = 0;
  for (let y = 0; y < 28; y++) {
    for (let x = 0; x < 28; x++) {
      const value = input[y * 28 + x] * 0.3081 + 0.1307;
      mass += value;
      centerX += x * value;
      centerY += y * value;
    }
  }
  return [centerX / mass, centerY / mass];
}

class FixedDigitPreprocessor implements HandwrittenDigitImagePreprocessor {
  seenUri: string = '';
  readonly input: ArrayBuffer;

  constructor(input: ArrayBuffer) {
    this.input = input;
  }

  async createInput(imageUri: string): Promise<ArrayBuffer> {
    this.seenUri = imageUri;
    return this.input;
  }
}

class FixedDigitScoreRunner implements HandwrittenDigitScoreRunner {
  seenInput: ArrayBuffer | undefined = undefined;

  async predictLogits(input: ArrayBuffer): Promise<Array<number>> {
    this.seenInput = input;
    return [0, 1, 9, 0, 0, 0, 0, 0, 0, 0];
  }
}

export default function handwrittenDigitUnitTest(): void {
  describe('HandwrittenDigitUnitTest', () => {
    it('normalizesBlackInkOnWhiteAndWhiteInkOnBlack', 0, () => {
      const blackOnWhite = rgbaCanvas(40, 40, 255);
      fillRect(blackOnWhite, 40, 15, 7, 8, 27, 0);
      const whiteOnBlack = rgbaCanvas(40, 40, 0);
      fillRect(whiteOnBlack, 40, 15, 7, 8, 27, 255);

      const blackInput = new Float32Array(handwrittenDigitInputFromRgba(blackOnWhite, 40, 40));
      const whiteInput = new Float32Array(handwrittenDigitInputFromRgba(whiteOnBlack, 40, 40));

      expect(blackInput.length).assertEqual(28 * 28);
      expect(whiteInput.length).assertEqual(28 * 28);
      expect(blackInput[14 * 28 + 14] > 1).assertTrue();
      expect(whiteInput[14 * 28 + 14] > 1).assertTrue();
      expect(blackInput[0] < 0).assertTrue();
      expect(whiteInput[0] < 0).assertTrue();
    });

    it('centresAnOffCentreDigitBody', 0, () => {
      const rgba = rgbaCanvas(52, 52, 255);
      fillRect(rgba, 52, 2, 31, 10, 16, 0);

      const center = foregroundCenter(new Float32Array(handwrittenDigitInputFromRgba(rgba, 52, 52)));

      expect(center[0] > 12).assertTrue();
      expect(center[0] < 15).assertTrue();
      expect(center[1] > 12).assertTrue();
      expect(center[1] < 15).assertTrue();
    });

    it('rejectsBlankLowContrastAndMalformedRgba', 0, () => {
      const blank = rgbaCanvas(16, 16, 255);
      const lowContrast = rgbaCanvas(16, 16, 200);
      fillRect(lowContrast, 16, 5, 5, 5, 5, 190);

      assertThrows((): void => { handwrittenDigitInputFromRgba(blank, 16, 16); });
      assertThrows((): void => { handwrittenDigitInputFromRgba(lowContrast, 16, 16); });
      assertThrows((): void => { handwrittenDigitInputFromRgba(new Uint8Array(3), 1, 1); });
      assertThrows((): void => { handwrittenDigitInputFromRgba(new Uint8Array(4), 0, 1); });
    });

    it('decodesStableSoftmaxInDescendingTopThreeOrder', 0, () => {
      const predictions = topHandwrittenDigitResults([1000, 1003, 1001, 998, 1002, 1003, 1000, 999, 1002, 1001], 3);

      expect(predictions.length).assertEqual(3);
      expect(predictions[0].digit).assertEqual(1);
      expect(predictions[1].digit).assertEqual(5);
      expect(predictions[2].digit).assertEqual(4);
      expect(predictions[0].confidence > predictions[1].confidence).assertFalse();
      expect(predictions[1].confidence > predictions[2].confidence).assertTrue();
      expect(Math.abs(predictions[0].confidence - 0.3194) < 0.001).assertTrue();
    });

    it('usesDigitOrderToBreakEqualLogitTies', 0, () => {
      const predictions = topHandwrittenDigitResults([2, 2, 2, 0, 0, 0, 0, 0, 0, 0], 3);

      expect(predictions[0].digit).assertEqual(0);
      expect(predictions[1].digit).assertEqual(1);
      expect(predictions[2].digit).assertEqual(2);
    });

    it('rejectsInvalidLogitShapeLimitAndNonFiniteValues', 0, () => {
      assertThrows((): void => { topHandwrittenDigitResults([0, 1], 3); });
      assertThrows((): void => { topHandwrittenDigitResults([0, 0, 0, 0, 0, 0, 0, 0, 0, 0], 0); });
      assertThrows((): void => { topHandwrittenDigitResults([0, 0, 0, 0, Number.NaN, 0, 0, 0, 0, 0], 3); });
      assertThrows((): void => { topHandwrittenDigitResults([0, 0, 0, 0, Number.POSITIVE_INFINITY, 0, 0, 0, 0, 0], 3); });
    });

    it('runsInjectedPreprocessorAndModelForRecognition', 0, async () => {
      const input = new ArrayBuffer(28 * 28 * Float32Array.BYTES_PER_ELEMENT);
      const preprocessor = new FixedDigitPreprocessor(input);
      const runner = new FixedDigitScoreRunner();

      const predictions = await new HandwrittenDigitService({
        preprocessor: preprocessor,
        scoreRunner: runner
      }).recognizeDigit('file://digit.png');

      expect(preprocessor.seenUri).assertEqual('file://digit.png');
      expect(runner.seenInput === input).assertTrue();
      expect(predictions[0].digit).assertEqual(2);
    });
  });
}
