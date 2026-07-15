# Core MindSpore Lite model notice

These pinned model files are committed to a private repository for this
project's private local learning use. No model-quality, device-runtime, or
commercial-use claim is made.

## MindSpore Model Zoo assets

The following trained-model assets come from the official MindSpore Model Zoo:

| File | Purpose | Official source | Bytes | SHA-256 |
| --- | --- | --- | ---: | --- |
| `mobilenetv2.ms` | Image classification | https://download.mindspore.cn/model_zoo/official/lite/mobilenetv2_imagenet/mobilenetv2.ms | 14014408 | `F88C8C410D1148F5614994038680C245E1788C80E578D093E536572D08ECC514` |
| `ssd.ms` | Object detection | https://download.mindspore.cn/model_zoo/official/lite/ssd_mobilenetv2_lite/ssd.ms | 17515528 | `0AAB891E297109836120F4F0A43C1547F813D4B530948F2926DE171FFF91B553` |
| `style_predict_quant.ms` | Style embedding | https://download.mindspore.cn/model_zoo/official/lite/style_lite/style_predict_quant.ms | 3022576 | `6737696ACC9B2F3ACF7460FEE986614B0107DF347EC9947D9D346D085AFCFBCC` |
| `style_transfer_quant.ms` | Style transfer | https://download.mindspore.cn/model_zoo/official/lite/style_lite/style_transfer_quant.ms | 256864 | `AEB4963C3906B90F9480E96CC29C39F6BC9CF9DE1ED84C370308E5A0B5B82682` |

The MindSpore Model Zoo repository is licensed under Apache-2.0. Its model
README restricts trained models to non-commercial research and educational use.
The full Apache-2.0 text is included as `LICENSE-Apache-2.0.txt`.

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
