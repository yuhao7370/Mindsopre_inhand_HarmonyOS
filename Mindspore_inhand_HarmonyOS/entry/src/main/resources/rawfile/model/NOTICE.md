# Core MindSpore Lite model notice

These pinned model files are committed to a private repository for this
project's private local learning use. No model-quality, device-runtime, or
commercial-use claim is made.

## MindSpore Model Zoo assets

The following trained-model assets come from the official MindSpore Model Zoo:

| File | Purpose | Official source | Bytes | SHA-256 |
| --- | --- | --- | ---: | --- |
| `mobilenetv2.ms` | Image classification (MSL2) | https://download.mindspore.cn/model_zoo/official/lite/quick_start/mobilenetv2.ms | 13988384 | `5A7CCD53BF92D8B294A703A1302D4230A311B2D19A8D212EEDD65FF6838CFA84` |
| `style_predict_quant.ms` | Style embedding | https://download.mindspore.cn/model_zoo/official/lite/style_lite/style_predict_quant.ms | 3022576 | `6737696ACC9B2F3ACF7460FEE986614B0107DF347EC9947D9D346D085AFCFBCC` |
| `style_transfer_quant.ms` | Style transfer | https://download.mindspore.cn/model_zoo/official/lite/style_lite/style_transfer_quant.ms | 256864 | `AEB4963C3906B90F9480E96CC29C39F6BC9CF9DE1ED84C370308E5A0B5B82682` |

The MindSpore Model Zoo repository is licensed under Apache-2.0. Its model
README restricts trained models to non-commercial research and educational use.
The full Apache-2.0 text is included as `LICENSE-Apache-2.0.txt`.

`mobilenetv2.ms` is the official quick-start MSL2 asset. Its device contract is
float32 NHWC input `[1,224,224,3]` and float32 output `[1,1001]`; output index
0 is background, so the app maps output index `i + 1` to ImageNet label index
`i`. This trained model remains limited to this private repository's
non-commercial research, educational, and local learning use.

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
