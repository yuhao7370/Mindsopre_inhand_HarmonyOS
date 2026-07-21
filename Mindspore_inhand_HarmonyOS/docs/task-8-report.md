# Task 8: API24 Still-Photo Object Detection

## Result

The still-photo route now uses a local NanoDet-Plus M 320 model through a dedicated MNN NAPI boundary. The API24 x86_64 emulator accepts the shipped artifact, runs the production image preprocessor and decoder, and renders class, confidence, and bounding-box overlays for an image selected through the production PhotoPicker. The final tracked ABI is `arm64-v8a`.

## Root cause and runtime contract

The legacy `ssd.ms` artifact was a 17,515,528-byte MindSpore Lite model that API24 rejected as `Invalid mslite model`, so the former 300x300 SSD tensor path could not reach inference. It was replaced, rather than relabeled, with the official NanoDet release contract:

- Upstream: `nanodet-plus-m_320.onnx`, NanoDet tag `v1.0.0-alpha-1`, source commit `08bad3294608953b1e1a8aacc50f67336420a435`.
- License: Apache-2.0, copyright 2020-2021 RangiLyu; the complete tracked Apache-2.0 text remains packaged beside the core models.
- Upstream ONNX: 4,793,615 bytes, SHA-256 `4F12723CCE3D48E47CA92CB925BA74D97A965C069208EDCA660BBB9F7CE2C610`.
- Conversion: MNN 3.6.0, `mnnconvert -f ONNX --modelFile nanodet-plus-m_320.onnx --MNNModel nanodet_plus_m_320.mnn --bizCode MNN`.
- Shipped MNN: 4,785,492 bytes, SHA-256 `8E0266D957F8CCA939952F4349639438967EB855FA2EDD1C430546EC0C447E9C`.
- Input: float32 BGR NCHW tensor `data`, shape `[1,3,320,320]`, means `[103.53,116.28,123.675]`, standard deviations `[57.375,57.12,58.395]`.
- Output: float32 tensor `output`, shape `[1,2125,112]`; 80 sigmoid class scores followed by four 8-bin DFL regressions at strides `[8,16,32,64]`, then class-wise NMS.

The native loader validates the only input and output names, dtypes, shapes, host sizes, and finite first output before publishing a candidate session. A rejected candidate does not replace the loaded model. Custom object-detection files use the dedicated stable cache name `object_detection_model.mnn`; other MindSpore cache slots retain `.ms` names. Cache preflight runs the same native model/output probe before atomic replacement, so an invalid override cannot replace the last valid cached model.

The NAPI model session is process-global, so all ArkTS runner instances now share one queue per runtime. Each load and its prediction stay atomic across runner instances. Immutable bundled rawfiles may reuse the loaded session; a custom URI is read and loaded on every queued request so replacement content at the same cache URI cannot be mistaken for the prior model. A valid finite `[1,2125,112]` inference with no detections is a successful empty result, while a wrong-sized or non-finite raw tensor is rejected before decoding.

The native boundary rejects zero-length model views before pointer arithmetic (`validateModel` resolves `false`; `loadModel` rejects), constructs all allocating model metadata before replacing the live session, and applies one explicit cleanup policy to async-work deletion failures. Fixture redistribution selects CC BY-SA 3.0 and records its canonical license URI, attribution, retouch history, and unchanged-byte status; an automatic guard verifies those statements and the fixture hash through five negative mutations.

## RED and GREEN evidence

- RED device baseline: the legacy still route stopped at API24 model loading with `Invalid mslite model`; no real class/confidence/box inference was possible.
- The first full LocalUnit run during closure exposed one real stale assertion: `usesUniqueSameDirectoryTempTokensAndKeepsSiblingStableNames` still expected `object_detection_model.ms`. Hvigor itself returned 0 while Hypium printed the assertion error. The assertion was corrected only for the two object-detection routes.
- Independent review exposed three additional RED cases: a valid empty decoder result was reported as failure; malformed raw tensors were indistinguishable from a legitimate no-signal result; and per-runner queues allowed two runners to overlap load/predict on the process-global native session while same-URI replacement content was skipped. Service/AiService empty-result tests, runner-to-service wrong-size/non-finite tests, and cross-runner interleaving/mutable same-URI tests failed before their follow-up fixes and now pass.
- GREEN LocalUnit: a fresh `hvigorw.bat test --no-daemon` returned 0, printed `BUILD SUCCESSFUL`, and contained zero `ERROR`, `FAILED`, or `AssertException` lines.
- GREEN supply-chain/HAP guards: object model and 81-label verifiers pass; core asset guard plus 16 mutation fixtures pass; exact HAP fixture plus 16 invalid HAP fixtures pass, including tampered/missing/copied object model and `libobject_detection_mnn.so` cases.
- GREEN arm64 acceptance: `scripts/build-ai-runtime-acceptance.ps1` returned 0, built the main and ohosTest HAPs, and verified their exact structures and payload bytes with final ABI `arm64-v8a`.

## API24 emulator and UI evidence

`ObjectDetectionNativeTest` passed 4/4 on the API24 x86_64 emulator:

- Empty `Uint8Array(0)` and an empty non-zero-offset subarray both returned `false` from validation and were rejected by loading without entering native model parsing.
- The production artifact loaded as `data [1,3,320,320]` to `output [1,2125,112]`; its first output was finite and non-zero. Malformed load was rejected, and the prior valid session still inferred afterward.
- The licensed Wikimedia Commons Labrador fixture passed through `HarmonyObjectDetectionInputPreprocessor` and the production decoder three times with the same result. The best dog result was score `0.6802144646644592`, box `[51.75085978571212,36.12126614568653,643.729175792449,548.1309714530502]`, IoU `0.9701549988030088` against the project-authored box, above thresholds 0.65 and 0.85.
- A programmatically generated solid-gray JPEG produced zero detections.

The production route opened the system PhotoPicker and reused existing Gallery content. `portrait1.jpg` was actually a grass-field image and produced no visible detection. A second controlled attempt selected the existing `hagrid-example.jpeg` collage; the production page rendered 20 colored boxes with visible labels and confidence, including `1-人-54.65%`, `2-人-54.18%`, `3-人-48.65%`, and `15-瓶子-39.26%`. The production path emits no object-detection-specific hilog line, so the saved screenshot and layout are the UI oracle.

Ignored local evidence, intentionally not committed as large/generated artifacts:

- `../.superpowers/sdd/task-8-evidence/api24-object-photo-hagrid-result.png`
- `../.superpowers/sdd/task-8-evidence/api24-object-photo-hagrid-layout.json`
- `../.superpowers/sdd/task-8-evidence/api24-object-photo-picker-layout.json`

The Labrador fixture is the unchanged 700x577 Wikimedia Commons file: original photograph by Elf, derivative work by Djmirko, and retouch by FT2. This project explicitly selects CC BY-SA 3.0 for redistribution and records the canonical license URI, modification status, SHA-256, and separate project-authored manual detection box in the ohosTest fixture notice.

## Evidence boundary

No arm64 physical-device inference is claimed. The final arm64 build and exact HAP payload checks pass, while inference and PhotoPicker UI evidence come from the API24 x86_64 emulator. The independent `scripts/test-build-ai-runtime-acceptance-wiring.ps1` has a pre-existing stale expectation for old hard-coded top-level arm64 verifier calls and fails against both HEAD and this worktree; both involved files have identical Git blob hashes to HEAD. The real `scripts/build-ai-runtime-acceptance.ps1` completes successfully and is the arm64 acceptance evidence used here.
