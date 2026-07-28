import { describe, expect, it } from '@ohos/hypium';
import {
  CustomModelTensorMetadata,
  parseCustomModelPackageManifest,
  validateCustomModelTensorContract
} from '../main/ets/services/ai/CustomModelPackage';

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
      "maxTokens":8,"padId":0,"unkId":1,"bosId":2,"eosId":3,
      "inputIdsTensor":"input_ids","attentionMaskTensor":"attention_mask"
    }
  },
  "output":{
    "kind":"raw",
    "tensor":{"name":"output","dtype":"FLOAT32","shape":[1,2]}
  }
}`;

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
  });
}
