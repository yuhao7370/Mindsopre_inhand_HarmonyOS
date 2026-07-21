# Task 9: API24 Real-Time Object Detection

## Result

The real-time object-detection route now reuses the Task 8 NanoDet MNN detector on bounded, current-frame camera work. On the API24 x86_64 emulator, the production route continuously captures changing frames, completes one inference at a time, publishes only current results, stops without late publication, and recovers across repeated route re-entry. The final tracked ABI remains `arm64-v8a`.

## Runtime contract and fixes

- The route reuses the Task 8 process-global MNN session, preprocessor, decoder, labels, and bundled `nanodet_plus_m_320.mnn`; it adds no model copy, conversion, or session owner.
- `LiveRuntimeLoopService` retains the bounded policy: run immediately, tick every 1,000 ms, and drop a tick while one frame is in flight. Task 8's process-global queue remains the final guard against overlapping native session access across runner instances.
- A live object result is no longer cleared when the next inference starts. A current successful result atomically replaces the prior overlay; a valid successful empty result clears it; a failure or stale result preserves the last current overlay.
- Route generation and request identity are checked before inference publication. Leaving the route invalidates pending work, stops the loop and camera, and prevents a completed old request from publishing.
- The camera driver derives buffer-to-display content rotation from `CameraDevice.cameraOrientation`, current display rotation, and camera position. `PreviewOutput.getPreviewRotation(displayRotation)` is the fallback when sensor orientation is invalid. The API24 back-camera contract resolves to clockwise 90 degrees.
- Live boxes are transformed for 0/90/180/270-degree rotation, then mapped through the centered contain fit used by the preview. The overlay uses the current surface width and height. Differential-render keys include all four box coordinates so a size-only change cannot reuse an old box.
- Production hilog records only rotation, sampled frame/request/generation IDs, inference start/end/current/count, publication, failures, and stop. Normal frame sequencing is limited to frames 1-8 and every tenth frame; failures, rotation changes, and stop always log. It does not log image content or cache URIs.

## RED and GREEN evidence

- RED sequencing/overlay tests changed the live object workflow expectation from clearing at run start to retaining the visible result, and added failure preservation/current-success replacement, recovery after one frame failure, and rotated contain-fit mapping. The first fresh test build failed because `objectDetectionLiveOverlayBox` did not exist.
- The first implementation GREEN run returned 0 and printed `BUILD SUCCESSFUL in 39 s 165 ms`.
- API24 then exposed an orientation RED: both the no-argument and display-argument `PreviewOutput.getPreviewRotation` reported 0 even though the 1280x720 surface buffer and portrait preview were visibly related by a clockwise quarter turn. A pure sensor/display/camera-position test was added first; its fresh build failed because `livePreviewContentRotationDegrees` did not exist.
- The orientation implementation GREEN run returned 0 and printed `BUILD SUCCESSFUL in 37 s 688 ms`. It covers back and front formulas plus invalid-sensor fallback. The rebuilt API24 package then logged `preview ready rotation=90`.
- Independent review exposed three follow-up RED cases: frame-capture failure still cleared the prior overlay; the PreviewOutput fallback was queried before session configuration; and display rotation was sampled only at startup. Capture-specific preservation, dynamic service rotation, and bounded-log tests first failed with their new contracts absent.
- The follow-up implementation preserves the prior live object overlay on capture failure while updating failure status and recovering on the next tick. PreviewOutput fallback is queried only after session start. Each successful capture recomputes content rotation from cached sensor/camera position and the current display rotation. Normal logs are sampled rather than emitted at full frame cadence.
- Follow-up review found no remaining Critical or Important issue. Its sole Minor finding was that an unsampled `ok=false` result would not log; the final predicate test and implementation now log every failed result independently of normal sampling.
- The final fresh `hvigorw.bat test --no-daemon` run after all code changes returned 0 and printed `BUILD SUCCESSFUL in 42 s 380 ms`.
- Final `scripts/build-ai-runtime-acceptance.ps1` returned 0 in 72.6 seconds. It ran the Task 8 model, fixture-license, core-asset and native-safety guards; camera/layout guards; arm64 main and ohosTest HAP builds; and exact HAP structure/payload verification.

## API24 emulator evidence

The installed x86_64 HAP ran the production fixed-back-camera route:

- Eight captures taken 1.25 seconds apart were all distinct. Their sizes were 30,842-31,162 bytes and all eight SHA-256 values differ; the exact list and captured files are saved below.
- Production logs show `preview ready rotation=90`. Each sampled frame follows `inference=start` -> `inference=end ok=true current=true detections=0` -> `published`, with about 0.10-0.18 seconds of inference time and no overlapping start/end pairs. The final package logs frames 1-8, 10, and 20 but not ordinary frames 9 or 11-19.
- The final-device follow-up naturally hit a first capture failure, logged it, then recovered on the next one-second tick and published frames normally. The full hilog contains neither `GetPreviewRotation error` nor `session is nullptr`, confirming the fallback query now occurs after session configuration.
- The formal stop run completed and published frame 46, logged `loop stopped after frame=46`, and produced no further publication during the following four seconds.
- Three consecutive re-entries each logged rotation 90, published frames 1-5 in order, stopped after frame 5, and produced no late publication during the approximately three-second gap before the next entry.

Ignored local evidence, intentionally not committed as generated artifacts:

- `../.superpowers/sdd/task-9-evidence/api24-final-ui.jpeg`
- `../.superpowers/sdd/task-9-evidence/api24-final-ui-layout.json`
- `../.superpowers/sdd/task-9-evidence/api24-final-ui-hilog.txt`
- `../.superpowers/sdd/task-9-evidence/api24-final-live-hilog.txt`
- `../.superpowers/sdd/task-9-evidence/api24-final-frame-hashes.txt`
- `../.superpowers/sdd/task-9-evidence/api24-final-frames/frame-1.jpg` through `frame-8.jpg`
- `../.superpowers/sdd/task-9-evidence/api24-stop-hilog.txt`
- `../.superpowers/sdd/task-9-evidence/api24-three-reentries-hilog.txt`
- `../.superpowers/sdd/task-9-evidence/api24-followup-hilog.txt`
- `../.superpowers/sdd/task-9-evidence/api24-followup-stop-hilog.txt`

## Evidence boundary

The emulator's current room feed produced legitimate successful empty results, so this Task 9 run does not claim a visible positive live box or label. Positive NanoDet inference and overlay rendering remain independently established by Task 8: the licensed Labrador fixture produced a dog score of `0.680214` and box IoU `0.970155`, while the production PhotoPicker collage rendered 20 labeled confidence boxes. Task 9 adds evidence that changing camera frames reach that same verified detector, that rotation/contain mapping is covered for every quarter turn, and that only current results are published.

No arm64 physical-device inference is claimed. The arm64 evidence is the successful build, guard suite, and exact main/ohosTest HAP payload verification; all camera runtime evidence above comes from the API24 x86_64 emulator.
