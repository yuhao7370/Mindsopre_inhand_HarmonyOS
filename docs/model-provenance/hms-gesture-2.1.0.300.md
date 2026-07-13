# HMS gesture model 2.1.0.300 provenance

## Scope

This asset is committed for local learning and reproducible development in a
private repository. This record does not assert that the upstream model may be
redistributed publicly. Huawei's upstream terms continue to apply; perform a
new licensing review before publishing the repository or distributing the
model in an application.

## Fixed source

- Artifact: `com.huawei.hms:ml-computer-vision-gesture-model:2.1.0.300`
- Official AAR: `https://developer.huawei.com/repo/com/huawei/hms/ml-computer-vision-gesture-model/2.1.0.300/ml-computer-vision-gesture-model-2.1.0.300.aar`
- AAR SHA-256: `92FD6AE357E3C5B0407F8E0FED1644D7E01604F9399AF97F23E87C7D2F8CD01C`
- Extracted entry: `assets/GestureDetector.ms`
- Model size: `2269168` bytes
- Model SHA-256: `A3440EF5B102BB9D25D984A8A2CA44EF4FC0557B65F0AC236176375FF9FFA5DA`

The import script verifies the AAR before extraction and verifies the extracted
model before copying only that model into the HarmonyOS rawfile directory.

## Verified format and contract

Despite its `.ms` suffix, the file is an Alibaba MNN FlatBuffer rather than a
MindSpore Lite model. FlatBuffer inspection and the matching arm64 detector
library establish the following contract:

- Input: `data`, `FLOAT32`, NCHW `[1,3,224,224]`
- Preprocessing: direct nearest-neighbor stretch, BGR channel order, mean zero,
  divide each channel value by 255
- Outputs: `layer89-conv-hand [1,60,7,7]`,
  `layer101-conv-hand [1,60,14,14]`, and
  `layer113-conv-hand [1,60,28,28]`
- YOLOv3 anchors by stride: 32 = `(105,101) (133,135) (174,150)`; 16 =
  `(32,37) (47,37) (65,56)`; 8 = `(19,19) (25,27) (35,26)`
- Thresholds: still `0.6`, live `0.1`, class-local NMS IoU `0.45`
- Classes: 15 model classes; class 14 maps to the public `UNKNOWN` fallback
- Result count: no business-level cap after NMS

The machine-readable copy of this contract is stored beside the model in
`manifest.json` and is checked by `scripts/verify-hms-gesture-model.ps1`.
