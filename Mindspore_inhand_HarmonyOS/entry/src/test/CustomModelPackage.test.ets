import { describe, expect, it } from '@ohos/hypium';
import {
  CustomModelTensorValue,
  CustomModelTensorMetadata,
  decodeCustomModelOutput,
  encodeCustomModelText,
  imageTensorFromRgba,
  parseCustomModelPackageManifest,
  validateCustomModelTensorContract
} from '../main/ets/services/ai/CustomModelPackage';
import {
  CustomModelArchiveEntry,
  customModelPackageFilesMatchManifest,
  validateCustomModelPackageArchive
} from '../main/ets/services/ai/CustomModelPackageService';

const digest: string = '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

const imageManifest: string = `{
  "version":1,
  "name":"颜色分类",
  "model":{"file":"model.ms","sha256":"${digest}"},
  "input":{
    "kind":"image",
    "tensors":[{"name":"input","dtype":"FLOAT32","shape":[1,2,2,3],"format":"NHWC"}],
    "image":{
      "width":2,"height":2,"layout":"NHWC","color":"RGB","resize":"fit",
      "mean":[0,0,0],"std":[1,1,1]
    }
  },
  "output":{
    "kind":"classification",
    "tensor":{"name":"output","dtype":"FLOAT32","shape":[1,3]},
    "labels":{"file":"labels.txt","sha256":"${digest}"},
    "topK":2
  }
}`;

const textManifest: string = `{
  "version":1,
  "name":"文字分类",
  "model":{"file":"model.ms","sha256":"${digest}"},
  "input":{
    "kind":"text",
    "tensors":[
      {"name":"input_ids","dtype":"INT32","shape":[1,8]},
      {"name":"attention_mask","dtype":"INT32","shape":[1,8]}
    ],
    "text":{
      "tokenizer":{"file":"tokenizer.ttok","sha256":"${digest}"},
      "maxTokens":8,"padId":5,"unkId":1,"bosId":2,"eosId":0,
      "inputIdsTensor":"input_ids","attentionMaskTensor":"attention_mask"
    }
  },
  "output":{
    "kind":"raw",
    "tensor":{"name":"output","dtype":"FLOAT32","shape":[1,2]}
  }
}`;

const ttokTable: string =
  `TTOK2\t${digest}\t${digest}\t6\t6\t6\t1\t-10\t1\t1\t1\n` +
  'N\t20\t20\n' +
  'P\t0\t0\t3\t3c,2f,73,3e\n' +
  'P\t1\t-1\t2\t3c,75,6e,6b,3e\n' +
  'P\t2\t-1\t3\t3c,73,3e\n' +
  'P\t3\t1\t1\t2581,68,69\n' +
  'P\t4\t1\t1\t2581,62,79,65\n' +
  'P\t5\t-1\t3\t3c,70,61,64,3e\n' +
  'V\t0\t3c,2f,73,3e\n' +
  'V\t1\t3c,75,6e,6b,3e\n' +
  'V\t2\t3c,73,3e\n' +
  'V\t3\t2581,68,69\n' +
  'V\t4\t2581,62,79,65\n' +
  'V\t5\t3c,70,61,64,3e';

function rejectsManifest(content: string): boolean {
  try {
    parseCustomModelPackageManifest(content);
    return false;
  } catch (_) {
    return true;
  }
}

export default function customModelPackageUnitTest(): void {
  describe('CustomModelPackageUnitTest', () => {
    it('parsesStrictImageAndTextPackages', 0, () => {
      const image = parseCustomModelPackageManifest(imageManifest);
      const text = parseCustomModelPackageManifest(textManifest);
      expect(image.input.kind).assertEqual('image');
      expect(image.output.kind).assertEqual('classification');
      expect(text.input.kind).assertEqual('text');
      expect(text.input.text?.attentionMaskTensor).assertEqual('attention_mask');
    });

    it('rejectsUnsupportedVersionsPathsDigestsAndImageNormalization', 0, () => {
      expect(rejectsManifest(imageManifest.replace('"version":1', '"version":2'))).assertTrue();
      expect(rejectsManifest(imageManifest.replace('"model.ms"', '"../model.ms"'))).assertTrue();
      expect(rejectsManifest(imageManifest.replace('"model.ms"', '"nested/model.ms"'))).assertTrue();
      expect(rejectsManifest(imageManifest.replace(digest, digest.toUpperCase()))).assertTrue();
      expect(rejectsManifest(imageManifest.replace('"std":[1,1,1]', '"std":[1,0,1]'))).assertTrue();
      expect(rejectsManifest(imageManifest.replace('"shape":[1,2,2,3]', '"shape":[1,0,2,3]'))).assertTrue();
    });

    it('requiresTokenizerForTextAndMatchingRealTensors', 0, () => {
      expect(rejectsManifest(textManifest.replace(
        '"tokenizer":{"file":"tokenizer.ttok","sha256":"' + digest + '"},',
        ''
      ))).assertTrue();

      const manifest = parseCustomModelPackageManifest(textManifest);
      const inputs: Array<CustomModelTensorMetadata> = [
        { name: 'input', dtype: 'FLOAT32', shape: [1, 2, 2, 3], format: 'NHWC', elementNum: 12, dataSize: 48 }
      ];
      const outputs: Array<CustomModelTensorMetadata> = [
        { name: 'output', dtype: 'FLOAT32', shape: [1, 2], format: 'NHWC', elementNum: 2, dataSize: 8 }
      ];
      let rejected = false;
      try {
        validateCustomModelTensorContract(manifest, inputs, outputs);
      } catch (_) {
        rejected = true;
      }
      expect(rejected).assertTrue();
    });

    it('rejectsOversizedNestedLinkedAndUnexpectedArchiveEntries', 0, () => {
      const valid: Array<CustomModelArchiveEntry> = [
        { name: 'manifest.json', size: 700, isFile: true, isSymbolicLink: false },
        { name: 'model.ms', size: 600, isFile: true, isSymbolicLink: false },
        { name: 'labels.txt', size: 16, isFile: true, isSymbolicLink: false }
      ];
      expect(validateCustomModelPackageArchive(1316, 1316, valid)).assertTrue();
      expect(validateCustomModelPackageArchive(256 * 1024 * 1024 + 1, 1316, valid)).assertFalse();
      expect(validateCustomModelPackageArchive(1316, 512 * 1024 * 1024 + 1, valid)).assertFalse();
      expect(validateCustomModelPackageArchive(1316, 1316, [
        { name: '/nested/model.ms', size: 600, isFile: true, isSymbolicLink: false }
      ])).assertFalse();
      expect(validateCustomModelPackageArchive(1316, 1316, [
        { name: 'model.ms', size: 600, isFile: true, isSymbolicLink: true }
      ])).assertFalse();

      const manifest = parseCustomModelPackageManifest(imageManifest);
      expect(customModelPackageFilesMatchManifest(manifest, valid)).assertTrue();
      expect(customModelPackageFilesMatchManifest(manifest, valid.concat([
        { name: 'extra.bin', size: 1, isFile: true, isSymbolicLink: false }
      ]))).assertFalse();
    });

    it('buildsExactImageAndTextInputTensors', 0, () => {
      const nchwManifest = parseCustomModelPackageManifest(imageManifest
        .replace('"shape":[1,2,2,3],"format":"NHWC"', '"shape":[1,3,1,2],"format":"NCHW"')
        .replace('"height":2,"layout":"NHWC","color":"RGB"', '"height":1,"layout":"NCHW","color":"BGR"')
        .replace('"mean":[0,0,0],"std":[1,1,1]', '"mean":[0.5,0,0],"std":[0.5,1,1]'));
      const rgba = new Uint8Array([255, 0, 64, 255, 0, 128, 255, 255]);
      const values = new Float32Array(imageTensorFromRgba(rgba, 2, 1, nchwManifest));
      expect(values.length).assertEqual(6);
      expect(Math.abs(values[0] - -0.4980392) < 0.000001).assertTrue();
      expect(Math.abs(values[1] - 1) < 0.000001).assertTrue();
      expect(Math.abs(values[2] - 0) < 0.000001).assertTrue();
      expect(Math.abs(values[3] - 0.5019608) < 0.000001).assertTrue();
      expect(Math.abs(values[4] - 1) < 0.000001).assertTrue();
      expect(Math.abs(values[5] - 0) < 0.000001).assertTrue();

      const text = parseCustomModelPackageManifest(textManifest);
      const tensors = encodeCustomModelText('hi', ttokTable, text);
      const ids = new Int32Array(tensors.get('input_ids')!);
      const mask = new Int32Array(tensors.get('attention_mask')!);
      expect(Array.from(ids).join(',')).assertEqual('2,3,0,5,5,5,5,5');
      expect(Array.from(mask).join(',')).assertEqual('1,1,1,0,0,0,0,0');
    });

    it('decodesClassificationTextAndRawOutputsWithoutGuessing', 0, () => {
      const classification = parseCustomModelPackageManifest(imageManifest);
      const scoreBuffer = new Float32Array([0.1, 0.7, 0.2]).buffer as ArrayBuffer;
      const scoreOutput: Array<CustomModelTensorValue> = [{
        name: 'output', dtype: 'FLOAT32', shape: [1, 3], data: scoreBuffer
      }];
      const classificationText = decodeCustomModelOutput(
        classification,
        scoreOutput,
        ['红色', '绿色', '蓝色'],
        ''
      );
      expect(classificationText).assertEqual('1. 绿色 70.00%\n2. 蓝色 20.00%');

      const textOutputManifest = parseCustomModelPackageManifest(textManifest
        .replace('"kind":"raw"', '"kind":"text"')
        .replace('"dtype":"FLOAT32","shape":[1,2]', '"dtype":"INT32","shape":[1,8]'));
      const tokenBuffer = new Int32Array([2, 3, 4, 0, 5, 5, 5, 5]).buffer as ArrayBuffer;
      const tokenOutput: Array<CustomModelTensorValue> = [{
        name: 'output', dtype: 'INT32', shape: [1, 8], data: tokenBuffer
      }];
      expect(decodeCustomModelOutput(textOutputManifest, tokenOutput, [], ttokTable)).assertEqual('hi bye');

      const rawText = decodeCustomModelOutput(
        parseCustomModelPackageManifest(textManifest.replace('"shape":[1,2]', '"shape":[1,3]')),
        scoreOutput,
        [],
        ''
      );
      expect(rawText.indexOf('output · FLOAT32 · [1, 3] · 3 values')).assertEqual(0);
    });
  });
}
