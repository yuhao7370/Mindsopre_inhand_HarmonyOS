# Core on-device model notice

These pinned model files are committed to a private repository for this
project's private local learning use. No model-quality, device-runtime, or
commercial-use claim is made.

## MindSpore Model Zoo assets

The following trained-model assets come from the official MindSpore Model Zoo:

| File | Purpose | Official source | Bytes | SHA-256 |
| --- | --- | --- | ---: | --- |
| `mobilenetv2.ms` | Image classification (MSL2) | https://download.mindspore.cn/model_zoo/official/lite/quick_start/mobilenetv2.ms | 13988384 | `5A7CCD53BF92D8B294A703A1302D4230A311B2D19A8D212EEDD65FF6838CFA84` |

The MindSpore Model Zoo repository is licensed under Apache-2.0. Its model
README restricts trained models to non-commercial research and educational use.
The full Apache-2.0 text is included as `LICENSE-Apache-2.0.txt`.

`mobilenetv2.ms` is the official quick-start MSL2 asset. Its device contract is
float32 NHWC input `[1,224,224,3]` and float32 output `[1,1001]`; output index
0 is background, so the app maps output index `i + 1` to ImageNet label index
`i`. This trained model remains limited to this private repository's
non-commercial research, educational, and local learning use.

## Magenta arbitrary image stylization assets

The style-transfer network is Google/Magenta arbitrary-image-stylization-v1-256
FP16 release 1. The official Kaggle Models API reports Apache-2.0 for prediction
instance 950/version 1103 and transfer instance 951/version 1104. The full
Apache-2.0 text is included as `LICENSE-Apache-2.0.txt`.

| Artifact | Official source | Bytes | SHA-256 |
| --- | --- | ---: | --- |
| Prediction TFLite source | https://tfhub.dev/google/lite-model/magenta/arbitrary-image-stylization-v1-256/fp16/prediction/1?lite-format=tflite | 4708350 | `DF9578B4141EF1D826F33B5F8E6E8E31BDBBB507B4E1F7CCBD2547AC1299DA42` |
| `style_predict_fp16.mnn` | Converted audited artifact | 9354924 | `E23E713FA343B20B11110F8E02FFAA54E3E18B9CB17F26E42B3D7F32135144A6` |
| Transfer TFLite source | https://tfhub.dev/google/lite-model/magenta/arbitrary-image-stylization-v1-256/fp16/transfer/1?lite-format=tflite | 422086 | `53B5243ED5AA33E408DB7976C8A8E51A90A0F7708FD122A31428CD00FBDF6AA6` |
| `style_transform_fp16.mnn` | Converted audited artifact | 771144 | `079005963B9EBA264BDEF0CD78921612A99344771AE31ACD0423A730D6FB9724` |

Both shipped artifacts were converted with MNN 3.6.0:

```text
python -m MNN.tools.mnnconvert -f TFLITE --modelFile <source.tflite> --MNNModel <output.mnn> --bizCode MNN
```

MNN 3.6.0 writes a random 36-byte `mnn_uuid`; the acquisition script replaces
only that metadata with the source-SHA-derived UUID documented in the script,
then verifies the exact shipped hashes above. Prediction conversion closely
tracks the TFLite source, but transfer conversion is not claimed to be
numerically equivalent to TFLite. Acceptance instead checks the locked MNN
artifacts for exact tensor contracts, finite `[0,1]` output, visible content
change, and materially different output for two styles on API 24.

The bundled `styletransfer/style0.jpg` through `style18.jpg` bytes match the
Apache-2.0 `mindspore-ai/models` repository tag `r1.8`, commit
`8a0c1c4b4669918eaa9b8bc9e2314a710d1519a1`, under
`official/lite/MindSpore_inhand/styletransfer/src/main/res/drawable-xxhdpi/`.

## NanoDet object-detection asset

`nanodet_plus_m_320.mnn` is converted from the official NanoDet release asset
`nanodet-plus-m_320.onnx` at tag `v1.0.0-alpha-1`, exact source commit
`08bad3294608953b1e1a8aacc50f67336420a435`. NanoDet is licensed under
Apache-2.0 and carries `Copyright 2020-2021 RangiLyu`.

| Artifact | Official source | Bytes | SHA-256 |
| --- | --- | ---: | --- |
| Upstream ONNX | https://github.com/RangiLyu/nanodet/releases/download/v1.0.0-alpha-1/nanodet-plus-m_320.onnx | 4793615 | `4F12723CCE3D48E47CA92CB925BA74D97A965C069208EDCA660BBB9F7CE2C610` |
| Shipped MNN | Converted locally with MNN 3.6.0 | 4785492 | `8E0266D957F8CCA939952F4349639438967EB855FA2EDD1C430546EC0C447E9C` |

The exact conversion command is:

```text
mnnconvert -f ONNX --modelFile nanodet-plus-m_320.onnx --MNNModel nanodet_plus_m_320.mnn --bizCode MNN
```

The runtime contract is float32 BGR NCHW input `[1,3,320,320]`, normalized
with means `[103.53,116.28,123.675]` and standard deviations
`[57.375,57.12,58.395]`, and float32 output `[1,2125,112]`. The decoder uses
NanoDet strides `[8,16,32,64]`, 80 already-sigmoid class scores, and four
8-bin distribution-focal-loss regressions, followed by class-wise NMS.

## HarmonyOS sample asset

`resnet18-place365.ms` is used for scene recognition and comes from
https://gitee.com/harmonyos_samples/MSLiteSceneRecognition at fixed commit
`af40795ebb2a295d87cd6dcd1383782a78776cda`.

| File | Bytes | SHA-256 |
| --- | ---: | --- |
| `resnet18-place365.ms` | 45448504 | `286F2C85249FD51F6C437986E1C2C1F4EC10358A9B0EB97C886F2DC1AC63ECD9` |

That pinned source contains an Apache-2.0 `LICENSE` with
`Copyright 2025 Huawei Device Co., Ltd.` and no additional NOTICE file. The
complete Apache-2.0 text included beside these models covers this asset too.
