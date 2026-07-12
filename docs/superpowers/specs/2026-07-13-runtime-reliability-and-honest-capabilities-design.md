# Runtime Reliability And Honest Capabilities Design

## Context

The HarmonyOS port already has real platform or MindSpore implementations for
classification, object detection, style transfer, OCR, pose, segmentation,
scene detection, camera input, media save, Dance, Poetry, and Custom Model.
Two independent completion audits found that build success does not yet prove
runtime parity:

- the visible Gesture workflow always returns an empty result in production;
- Text Translation is a finite offline phrase dictionary;
- live workflows recreate AI services and can repeatedly reload models;
- visual-result `PixelMap` instances are overwritten without release;
- Custom Model accepts files whose tensor contract the fixed preprocessor
  cannot satisfy;
- hidden Scene Detection contains mojibake Chinese labels.

Real Android-equivalent hand gesture and general translation remain dependent
on an authorized model or service that is not present in the repository or the
installed HarmonyOS API 24 SDK. This design improves every gap that can be
closed locally without pretending those two external capabilities exist.

## Chosen Approach

Three approaches were considered:

1. Patch each call site independently. This is the smallest immediate diff,
   but it leaves service lifetime and native image ownership scattered through
   the 2,800-line runtime page.
2. Extract two narrow ownership boundaries, then apply targeted behavior fixes.
   This adds only the abstractions justified by repeated lifecycle bugs and is
   the selected approach.
3. Split `FeatureRuntimePage` into one page per feature. This would reduce file
   size most, but duplicates shared camera/picker behavior and creates excessive
   regression risk for the current migration phase.

The user explicitly delegated review and continuation decisions to subagents;
both independent audits selected the second approach.

## Runtime AI Session

Add `RuntimeAiServiceSession`, a page-scoped owner of one in-flight/resolved
`DefaultAiService` promise for the current workflow. Repeated live frames reuse
the same service and therefore the same MindSpore runner/model cache. A service
creation failure clears the cached promise so the next frame can retry.

The session is invalidated when:

- a selected Object Detection, Style Transfer, or Custom Model file is
  successfully replaced at its stable cache path;
- the page disappears;
- the requested workflow route changes.

This preserves model replacement semantics while preventing the default live
Object Detection path from loading `ssd.ms` every 500 ms.

## Visual Result Ownership

Add `RuntimePixelMapOwner`, one instance for the styled image and one for the
segmentation foreground. It owns exactly one `PixelMap`-compatible object and a
generation counter.

- Replacing or clearing a value releases the previous value once.
- An asynchronous result accepted for the current generation becomes owned.
- A result arriving after clear/page exit is rejected and released immediately.
- Release failures are swallowed because cleanup must not replace the visible
  inference result with an unrelated error.

`FeatureRuntimePage` remains the ArkUI state owner; the helper only centralizes
native-resource lifetime and stale-result rejection.

## Custom Model Contract

The port intentionally improves Android's UI-only random executor by running a
real selected MindSpore model. Its preprocessor is nevertheless fixed to one
NHWC float32 tensor with shape `[1, 224, 224, 3]`, RGB channel order, and values
normalized to `[0, 1]`.

Model-file compatibility checking must reject a Custom Model file unless its
single input matches that exact contract. Other routes keep their existing
loadability check. Runtime output must be present and float32 before it is
decoded. The existing incompatible-model message is reused, and the last valid
cached file must remain untouched.

## Honest Gesture And Translation Status

The production factory must not construct a deliberately disabled ImageNet
gesture service. Until a real `GestureRunner` is injected, `DefaultAiService`
uses the existing explicit `feature_runtime_gesture_runner_unavailable` status.
The still/live routes and adapter contract stay intact.

`LocalTextTranslationRunner` marks its results as the offline dictionary
source. Known phrases report an offline-demo completion status. Unknown phrases
report a dedicated offline-dictionary unsupported status rather than the
generic cloud-like translation failure. Injected translation runners retain the
normal Android-compatible success/failure messages.

These changes do not count either capability as 1:1 complete; they make the
remaining external boundary visible and testable.

## Scene Labels And Dead Paths

Replace the corrupted `androidSceneDetectionLabelsZh` literals with readable
Chinese labels aligned one-to-one with `androidSceneDetectionLabels`. Add a
guard that rejects Unicode replacement characters and known mojibake markers.

Remove the unused Dance template-demo page method and remove the now-unreachable
live Text Translation helper branches left after the Android input set was
restored to text/camera/photo. Do not add result sharing where Android has no
equivalent action, and do not reintroduce the disabled APK updater.

## Testing And Verification

Each behavior follows RED-GREEN-REFACTOR with focused Hypium tests:

- repeated session access creates once, invalidation recreates, and failed
  creation retries;
- owned PixelMaps release on replace/clear and stale async results release;
- Custom Model metadata accepts only the fixed NHWC float32 contract;
- the default Gesture service reports runner unavailable;
- offline and injected translation results use different status keys;
- Chinese scene labels contain no corruption markers and keep exact count.

After task-level reviews, run all Hypium tests, every static/model build guard,
and HAP assembly. Then use the installed Pura 90 emulator if it reaches `hdc`;
otherwise retain emulator startup/signing as an explicit external verification
gap rather than claiming runtime success.

## Non-Goals

- No unlicensed third-party hand-gesture model.
- No API key, credential, or undocumented HMS cloud call.
- No full per-feature page rewrite.
- No exposure of Android-hidden College, Scene, Dance, Poetry, QR, or Me rows.
- No Android APK update flow in a HarmonyOS package.
