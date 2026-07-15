# Core MindSpore Lite model provenance

## Scope

These assets are committed to a private repository for reproducible local
learning and development. This record does not claim production suitability,
model quality, commercial permission, or verified HarmonyOS device behavior.

## Fixed assets

| File | Purpose | Bytes | SHA-256 | Official source |
| --- | --- | ---: | --- | --- |
| `mobilenetv2.ms` | Image classification | 14014408 | `F88C8C410D1148F5614994038680C245E1788C80E578D093E536572D08ECC514` | https://download.mindspore.cn/model_zoo/official/lite/mobilenetv2_imagenet/mobilenetv2.ms |
| `ssd.ms` | Object detection | 17515528 | `0AAB891E297109836120F4F0A43C1547F813D4B530948F2926DE171FFF91B553` | https://download.mindspore.cn/model_zoo/official/lite/ssd_mobilenetv2_lite/ssd.ms |
| `style_predict_quant.ms` | Style embedding | 3022576 | `6737696ACC9B2F3ACF7460FEE986614B0107DF347EC9947D9D346D085AFCFBCC` | https://download.mindspore.cn/model_zoo/official/lite/style_lite/style_predict_quant.ms |
| `style_transfer_quant.ms` | Style transfer | 256864 | `AEB4963C3906B90F9480E96CC29C39F6BC9CF9DE1ED84C370308E5A0B5B82682` | https://download.mindspore.cn/model_zoo/official/lite/style_lite/style_transfer_quant.ms |
| `resnet18-place365.ms` | Scene recognition | 45448504 | `286F2C85249FD51F6C437986E1C2C1F4EC10358A9B0EB97C886F2DC1AC63ECD9` | https://gitee.com/harmonyos_samples/MSLiteSceneRecognition at `af40795ebb2a295d87cd6dcd1383782a78776cda` |

The first four files are official MindSpore Model Zoo trained-model assets.
The Model Zoo repository uses Apache-2.0, while its model README restricts
trained models to non-commercial research and educational use. The private
local-learning scope of this project stays within that narrower boundary; a
fresh licensing review is required before any broader distribution or use.

The pinned `MSLiteSceneRecognition` commit contains an Apache-2.0 `LICENSE`
with `Copyright 2025 Huawei Device Co., Ltd.` and no additional NOTICE file.
The complete Apache-2.0 text is stored beside the models as
`LICENSE-Apache-2.0.txt`; the packaged summary is `NOTICE.md`.

## Reproducible build boundary

The five stable `.ms` files are ordinary tracked Git binaries with exact byte
and SHA-256 contracts. `ensure-mindspore-models.ps1` only runs verifiers, so a
clean normal build verifies repository assets without networking. The four
`download-*-model*.ps1` scripts remain explicit manual recovery tools only.
They validate a request-private same-directory partial before atomic
publication and preserve the previous stable file on failure.

`check-core-model-assets.ps1` enforces the source contracts and
`verify-ai-runtime-haps.ps1` binds the five models, `LICENSE-Apache-2.0.txt`,
and `NOTICE.md` to their exact source bytes inside the main HAP. The test HAP
continues to reject copied application models. These host checks do not prove
inference accuracy, device performance, installation, signing, or launch.
