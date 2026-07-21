# Task 3: API24 PoseNet

## Result

The PoseNet still-photo route now performs real single-person pose inference. It keeps CoreVision authoritative when that platform capability returns a valid result and falls back to a bundled MoveNet model through MindSpore Lite when CoreVision is absent or fails. The API24 x86_64 emulator passes labelled-fixture inference, negative/recovery checks, the production built-in flow, the system PhotoPicker flow, and the linked real-time camera-preview flow. The final tracked ABI is `arm64-v8a`.

## Model, provenance, and contract

- Upstream: Google MoveNet SinglePose Lightning FLOAT16 v4 from TensorFlow Hub, Apache-2.0.
- Source TFLite: 4,758,512 bytes, SHA-256 `0FAC2226112D0371903CA86E3853CEC24EF603A0B2F96F589B180F0EBDD135AB`.
- Conversion: official MindSpore Lite 2.6.0 converter, `--fmk=TFLITE --saveType=MINDIR_LITE --optimize=general --fp16=off`. Two clean conversions were byte-identical.
- Shipped MSLite model: 9,348,680 bytes, SHA-256 `972F3BE55A484B0A86A418693CF134C5BD5BD32B3418965891E7FF1DD2874677`.
- Input: UINT8 `serving_default_input:0`, NHWC `[1,192,192,3]`, exactly 110,592 bytes.
- Output: FLOAT32 `StatefulPartitionedCall:0`, `[1,1,17,3]`, exactly 204 bytes in COCO17 `(y,x,score)` order.

The preprocessor applies EXIF rotation, an aspect-preserving black letterbox, and RGB byte packing. Decoding reverses the letterbox into source-pixel coordinates and rejects non-finite or malformed tensors. A result needs at least six visible points and four skeleton edges; valid empty/no-person input is not reported as a successful pose. All local runtime instances share one serialized load/inference queue, and a failed request does not poison later inference.

The two tracked still fixtures have redistribution notices and exact hashes in `rawfile/posenet/NOTICE.md`. `skeleton_image.JPG` is Visitor7's CC BY-SA 3.0 `Man Standing.jpg`; `man_standing_indoor.jpg` is CharlieCLC's public-domain `Man-standing.jpg`. The ohosTest labels are project-authored manually reviewed COCO17 source-pixel coordinates. An earlier watermarked/uncertain fixture was not retained.

## Automatic and device evidence

A fresh LocalUnit run returned `BUILD SUCCESSFUL` with no assertion, error, or failure lines. Tests cover letterbox geometry, RGB pixels, exact tensor metadata, COCO17 decode, malformed/NaN output, CoreVision authority and fallback, shared single-load serialization, and failure recovery. The model verifier, PoseNet runtime contract guard, still-layout guard, central model guard, HAP isolation checks, and final arm64 acceptance all pass.

`PoseNativeTest` passed 1/1 on the API24 x86_64 emulator:

- Exact input/output names, shapes, dtypes, and byte sizes matched the production artifact.
- Fixture 1 returned 17 points and 12 lines; 17/17 labelled joints were accepted with mean normalized error `0.0326993850` and max `0.0558690364`.
- Fixture 2 returned 17 points and 12 lines; 15/15 labelled visible joints were accepted with mean normalized error `0.0271424414` and max `0.0618495562`.
- The two outputs differed by normalized average `0.1773315320`, proving input dependence. The event-loop timer ticked four times during inference.
- A solid-gray no-person image returned `ok=false`, zero skeletons, and the following valid fixture succeeded, proving negative handling and recovery.

## Production UI evidence

The built-in Detect action initially exposed a real UI defect: `rawfile://` could be decoded for inference but ArkUI rendered a gray image below the overlay. The PoseNet preview now resolves the two packaged stills through `$rawfile(...)`; after rebuilding, the actual photograph and the aligned skeleton render together. Its layout contains exactly 17 red point nodes and 12 green line nodes, followed by the visible `检测成功` toast.

The system PhotoPicker opened normally and returned an existing black-background full-body Gallery image. The production page automatically inferred it and rendered an aligned 17-point/12-line overlay. The linked `实时` action opened the app's live CameraService route and continuously displayed the current emulator camera feed alongside the template and similarity UI. The observed feed contained only a partial person at the bottom, so `similarity:0%` and no fabricated live skeleton are the correct evidence.

Ignored local screenshots/layouts include `task-3-reopen-ui-fix-after.png/json`, `task-3-gallery-preview.png/json`, and `task-3-live-route.png` under `../.superpowers/sdd/`.

## Evidence boundary

No arm64 physical-device inference is claimed. The final arm64 HAP build and exact payload verification are automatic evidence; inference and UI evidence are from the API24 x86_64 emulator. This PHEMU image has no functional system `cameraPicker` activity, and invoking it can block the ArkTS event loop. Production detects that hardware model and reports camera capture unavailable without hanging. Physical devices retain the native cameraPicker path; the separate in-app CameraService live preview is verified on the emulator.

Follow-up outside this PoseNet commit: the older `SegmentationNativeTest` reuses `posenet/skeleton_image.JPG` and derives its expected foreground with the shortcut “every non-white pixel is person.” The licensed PoseNet replacement has a real outdoor background, so that legacy segmentation oracle must be decoupled to a dedicated labelled-mask fixture before the full device suite is treated as fresh Portrait Segmentation evidence. This does not affect the PoseNet tests, the arm64 build/HAP acceptance, or the already recorded focused PoseNet device result.
