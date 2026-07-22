# Task 5: Gesture Recognition

Status: `emulator_pass`.

## Defect and fix

The API24 x86_64 runtime reports the `napi_get_typedarray_info` length for a
`Float32Array` in bytes while the production boundary treated it as an element
count. A correctly sized 150,528-element gesture input was therefore rejected
as if it had 602,112 elements.

The NAPI boundary now validates the JavaScript-visible `length`, the backing
`ArrayBuffer`, the byte offset, and both observed metadata conventions before
copying exactly 150,528 floats. This also verifies non-zero-offset typed-array
views without weakening the input-size contract.

## Oracle and automated verification

- The positive fixture is MediaPipe Model Maker's Apache-2.0 `Four` image at
  pinned commit `0ad5a71bcdff3d756dc5b07f93765aaeb4152538`; SHA-256
  `197F8A11CB74A2ECFF8AA106271E5D3088A64C8FEA691DC081385FB8BA4A6AA0`.
- The independently authored solid-gray negative has SHA-256
  `69A6B38DBE20F182F658D7DE3C545F6BECCF892C951BC008532543517D2C8DFE`.
- The old fixture with unresolved redistribution provenance was removed.
- On the API24 emulator, the native test passed 1/1. `Four` decoded as category
  3 with score `0.9031183391820973` and box IoU `0.9999774151087018`; the gray
  fixture decoded to zero detections. Repeated positive inference was bitwise
  deterministic and all output values were finite.
- The same real Four and gray MNN results were then published consecutively
  through the production live-result projector. The current generation changed
  from one scored Four rectangle to an empty image/detection state, while a
  stale-generation empty result was rejected. The device log records
  `gesture-live-transition=four->empty stale-overlay=false stale-score=false`.
- LocalUnit drives `LiveRuntimeLoopService` and `DefaultAiService` over the same
  fixture sequence and asserts the page-facing state changes from Four to empty
  dimensions, URI, detections, overlay, and score.
- Fixture, license, hash, model-manifest, native ABI/contract, and HAP payload
  guards passed, including their negative mutation cases.
- Fresh `hvigorw test --no-daemon` and the final ARM64
  `build-ai-runtime-acceptance.ps1` both exited 0.

## Production UI and live route

The production PhotoPicker selected the same licensed positive image and
rendered the expected hand rectangle with `90.3%`. Selecting the gray negative
next removed the old box/score and displayed the no-gesture prompt.

The final production x86_64 HAP also ran the linked real-time route against the
host UVC camera. Three bounded samples of the camera region had distinct
SHA-256 values:

- `28AE4062FE258DF3D97290EBC17BFEDF2C989B6E3DA9885CCEF6B367A7DC354A`
- `4BE474F3A89E2D50CFA86AA54934CCD83611CE7C2C985F93EA79273D405ACB75`
- `9F573696F80BC0F83661CC3A82971279E1E46B3FAC0E2116C3B42971B8FCBC81`

The sampled room scene contained no hand and continuously produced a valid
empty display with no stale hand rectangle or percentage. The live workflow
clears visual state before each frame and again before publishing a current
result, so an empty frame cannot retain an earlier positive overlay.

DevEco Studio exposed the host UVC feed but no native still-image or video
injection path. A physical-camera hand transition is therefore not claimed;
the production live publication transition is instead covered deterministically
with the licensed real MNN positive and negative results above. No arm64
physical-device run is claimed; the final tracked arm64 HAP and native payloads
were built and verified exactly.
