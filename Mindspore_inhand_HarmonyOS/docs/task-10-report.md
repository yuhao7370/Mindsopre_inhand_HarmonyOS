# Task 10: API24 Style Transfer

## Result

The still-image Style Transfer route now runs the licensed two-stage model on the API24 x86_64 emulator, produces visibly different output for different styles, recovers after a rejected model replacement, and exposes Save only for the current successful result. The final tracked ABI is restored to `arm64-v8a`; the arm64 main and ohosTest HAPs build and pass exact payload/isolation checks.

## Baseline and root cause

The legacy `style_predict_quant.ms` and `style_transfer_quant.ms` assets reached the API24 MindSpore Lite loader but failed before inference. The captured baseline hilog contains `Invalid mslite model`, `Invalid model_buf`, `Build model failed`, `Failed to create model`, and `failed to get model`. The old page also enabled its secure Save control without an accepted current Style Transfer result.

Ignored baseline evidence:

- `../.superpowers/sdd/task10-baseline-hilog.txt`
- `../.superpowers/sdd/task10-ui-before-result.json`

## Licensed model and tensor contract

The replacement is Google/Magenta arbitrary-image-stylization-v1-256 FP16 release 1. The official Kaggle model instances report Apache-2.0, and the complete Apache-2.0 text remains bundled beside the model notice.

| Stage | Official TFLite | Source bytes / SHA-256 | Shipped MNN bytes / SHA-256 |
|---|---|---|---|
| Prediction | TFHub FP16 prediction release 1; Kaggle instance 950/version 1103 | 4,708,350 / `DF9578B4141EF1D826F33B5F8E6E8E31BDBBB507B4E1F7CCBD2547AC1299DA42` | 9,354,924 / `E23E713FA343B20B11110F8E02FFAA54E3E18B9CB17F26E42B3D7F32135144A6` |
| Transfer | TFHub FP16 transfer release 1; Kaggle instance 951/version 1104 | 422,086 / `53B5243ED5AA33E408DB7976C8A8E51A90A0F7708FD122A31428CD00FBDF6AA6` | 771,144 / `079005963B9EBA264BDEF0CD78921612A99344771AE31ACD0423A730D6FB9724` |

Both artifacts use MNN 3.6.0 default TFLite conversion:

```text
python -m MNN.tools.mnnconvert -f TFLITE --modelFile <source.tflite> --MNNModel <output.mnn> --bizCode MNN
```

MNN writes a random 36-byte `mnn_uuid`; the acquisition script replaces only that metadata with a source-SHA-derived UUID and then verifies the exact shipped hash. The downloader verifies source and output bytes, uses temporary files, and publishes only a complete verified pair.

The prediction contract is float32 RGB `[0,1]`, NHWC `style_image [1,256,256,3]`, with output `mobilenet_conv/Conv/BiasAdd [1,1,1,100]`. Transfer consumes float32 RGB `[0,1]` `content_image [1,384,384,3]` plus that named embedding and returns `transformer/expand/conv3/conv/Sigmoid [1,384,384,3]` in `[0,1]`. Content preprocessing performs a centered square crop and resize to 384; styles use the audited 256 contract. The converted transfer graph is not claimed to be numerically equivalent to TFLite.

The built-in style0-style18 bytes match `mindspore-ai/models` branch r1.8 at commit `8a0c1c4b4669918eaa9b8bc9e2314a710d1519a1`, under Apache-2.0.

## Runtime, cache, and save fixes

- `libstyle_transfer_mnn.so` owns prediction and transfer sessions, validates exact names/shapes/float32/NHWC layout for every input and output, and probes the real prediction-to-transfer path before replacing the active pair. A malformed replacement rejects without releasing the last-good pair.
- Load, validation, and inference run as Promise-backed native async work. A process-global ArkTS tail serializes every runner instance over the shared native session. Built-in models are reused; custom fixed cache URIs reload on each queued request so replaced same-path content takes effect.
- Typed-array validation checks the JS-visible length, backing range, exact float counts, finite inputs, and empty buffers before pointer arithmetic.
- Custom predict and transfer selections call their stage validator and then a no-swap native pair validator against the current other custom stage, or the built-in stage when no custom file exists, before any stable-cache write. Pair failure leaves the previous file, restart recovery, and active native pair intact.
- The two audited built-in models are completely downloaded, converted, and hash-verified before publication. Their publisher replaces both as one rollback-safe transaction; an injected second-member failure restores both prior stable files. If rollback itself fails, the original publication error is preserved, rollback context is reported, and recovery backup/discard artifacts are retained.
- Result readiness is independent of the displayed PixelMap. It becomes true only after the current request's new PixelMap is accepted and becomes false on input/model/style change, run start, failure, recovery, page exit, malformed output, and preview conversion failure.
- The secure Save button, callback, and async entry point all require idle workflow + current ready result + no save in flight. The shared save path takes single-flight ownership before its first await.

## RED/GREEN evidence

Tests were added before the implementation for model paths/contracts, MNN runner ordering and process-wide serialization, centered crop, native validators, cache publication, same-URI custom reload, readiness policy, and save single-flight behavior. The initial RED run failed on missing MNN exports/cache contracts. After implementation, the first GREEN `hvigorw test --no-daemon` run printed `BUILD SUCCESSFUL in 36 s 563 ms`; the final pre-commit fresh run returned 0 and printed `BUILD SUCCESSFUL in 38 s 298 ms`.

The permanent API24 device test uses a programmatically generated 640x360 geometric JPEG, production preprocessing, licensed style0/style1, production model assets, and the production local runner. It also ticks a UI timer during native work and attempts a malformed pair before reusing the last-good pair.

The follow-up review started RED with missing pair-cache contracts and pair publisher module. LocalUnit reported the missing `StyleTransferModelPairCompatibilityChecker` export and fourth constructor argument, while the publisher test failed to import its absent module. The first strict-layout device fixture then proved the old validator accepted a model whose Input `dformat` alone changed from NHWC to NCHW. The corrected fixture parses FlatBuffers tables with bounds checks, mutates only Input `dformat` bytes, and verifies every other byte (including names, dims, and dtype metadata) is unchanged.

The Style Transfer device case passed in 2,441 ms with:

- UI timer ticks: 4
- prediction: 15 ms; transfer: 103 ms
- output-vs-content MAE: `0.3238518` and `0.3735619`
- style0-vs-style1 MAE: `0.0694815`
- changed-pixel ratio: `0.9998915`
- exact float output size: `384 * 384 * 3`, all finite and within `[0,1]`

The follow-up API24 x86_64 case passed 1/1 in 2,827 ms. Both real models and the real pair validate; same-name/shape/float32 models with only Input `dformat` changed to NCHW are rejected by the predict and transfer validators. A rejected no-swap pair validation and a rejected pair load both preserve the active last-good pair. The strict-layout run recorded 5 event-loop ticks, prediction 12 ms, transfer 105 ms, content MAE `0.32385/0.37356`, style MAE `0.06948`, and changed-pixel ratio `0.999891`.

The wider 19-test device invocation still contained two pre-existing failures outside Task 10: the Gesture test could not create its module context (401), and Translation timed out. The Style Transfer test itself passed, so this report does not misstate the full unrelated suite as green.

## Production API24 UI and Gallery evidence

The production Style Transfer page was opened through the Experience Center. Before a result, its layout reports `SaveButton enabled=false`. The system PhotoPicker first opens a preview; pressing its bottom `完成` control returned an existing Gallery photo to the production page. Selecting style0 ran the real model, rendered an obviously oil-painted person image, selected the style border, and changed the secure Save control to enabled.

The first save action opened the system short-term permission confirmation `允许“MindSpore掌中宝”应用保存图片和视频？`. Two rapid clicks before confirming created only one `SaveUIExtension` session. After `允许`, the Gallery asset count increased from 6 to 7 and the created URI was:

```text
file://media/Photo/7/IMG_1784638121_006/MindSpore_Result_1784637954240.jpg
```

After that save completed, one deliberate click increased the count from 7 to 8. Hilog records file ID 8 and:

```text
file://media/Photo/8/IMG_1784638151_007/MindSpore_Result_1784638051387.jpg
```

Pressing `恢复原图` restored the content preview and the captured layout reports `SaveButton enabled=false`, so a retained old styled PixelMap cannot be saved as a current result. Importing the content photo had already produced the same disabled stale-save state before the new run.

Ignored UI/save evidence:

- `../.superpowers/sdd/task10-content-loaded.json`
- `../.superpowers/sdd/task10-result-style0.json`
- `../.superpowers/sdd/task10-result-style0.jpeg`
- `../.superpowers/sdd/task10-result-style0-hilog.txt`
- `../.superpowers/sdd/task10-save-dialog.json`
- `../.superpowers/sdd/task10-save-before-assets.txt`
- `../.superpowers/sdd/task10-save-after-allow-assets.txt`
- `../.superpowers/sdd/task10-save-double-hilog.txt`
- `../.superpowers/sdd/task10-save-after-deliberate-assets.txt`
- `../.superpowers/sdd/task10-save-deliberate-hilog.txt`
- `../.superpowers/sdd/task10-recovery-disabled.json`
- `../.superpowers/sdd/task10-recovery-disabled.jpeg`

## Final arm64 gates and boundary

The tracked build profile is `arm64-v8a`. Model hashes, core asset/license/downloader safety, cache tests, Style Transfer layout/readiness mutation fixtures, native ABI, HAP tamper/isolation fixtures, LocalUnit, main HAP, Gesture/Translation native contracts, and ohosTest HAP all pass. The follow-up final `scripts/build-ai-runtime-acceptance.ps1` returned 0 in 53.6 seconds, and `verify-ai-runtime-haps.ps1` confirmed exact main/test structure and payload bytes. The main HAP contains both MNNs, `libstyle_transfer_mnn.so`, and `libMNN.so`; ohosTest contains neither copied models nor AI native libraries.

Two early LocalUnit invocations did not enter compilation because the shell used an invalid SDK level: first `...\sdk\default\openharmony`, then `...\sdk\default`. This project and Hvigor require `DEVECO_SDK_HOME=F:\Program Files\Huawei\DevEco Studio\sdk`; the deeper `default\openharmony` path remains the native/HDC platform root. With the SDK container corrected, the fresh LocalUnit run and both full acceptance runs executed normally. These configuration errors are not reported as code regressions.

No arm64 physical-device inference is claimed. Runtime/UI/save evidence is from the API24 x86_64 emulator; arm64 evidence is build, native-contract, and exact HAP verification. The initial system save confirmation is expected platform behavior and is recorded rather than hidden.
