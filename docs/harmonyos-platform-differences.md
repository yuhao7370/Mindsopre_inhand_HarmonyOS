# HarmonyOS Platform Differences

Verified on 2026-07-09 with DevEco Studio SDK `6.1.1(24)`.

## Android-Reachable Default Surface

The parity target follows the UI that is reachable in the current Android
source, rather than every page that remains in that repository.

Current HarmonyOS behavior:

- The default bottom navigation contains two tabs, in Android order:
  `Experience` and `Me`.
- College code, resources, state handling, and routes are retained, but College
  is deliberately omitted from the default tab list because the current
  Android source does not expose that tab.
- Scene Detection still has its still/live implementations, route aliases,
  local runner, and tests, but its Experience card is deliberately hidden by
  default because the current Android source does not expose that entry.
- Hidden capabilities were not deleted, so a later product decision can expose
  them without rebuilding their implementation. They are not part of the
  current default UI acceptance surface.

## Experience Route

Android registers `/app/VisionFragment` for the Experience feature list even
though the fragment is normally hosted inside `MainActivity`.

Current HarmonyOS behavior:

- `/app/VisionFragment` is preserved as a router alias that opens the existing
  Experience feature catalog through a thin page wrapper.
- The main tab shell still uses the same reusable Experience component; no
  duplicate catalog data is introduced.
- Experience feature cards reuse the Android `fragment_vision.xml` drawable
  icons (`btn_posenet`, `btn_segment`, `btn_classification`, and peers) as
  HarmonyOS media resources, with the existing text fallback kept for
  non-feature icon tokens.

## Live Camera Startup

Android live camera activities start preview during page startup instead of
waiting for a separate input click.

Current HarmonyOS behavior:

- Live runtime routes whose only primary input is camera now start the shared
  camera preview automatically after the HarmonyOS surface is ready.
- Those auto-start routes no longer show a duplicate Camera input chip or an
  empty Inputs section. Object Camera still shows Select Model, while Portrait
  Segmentation keeps its separately rendered background-image grid.
- PoseNet follows Android's split: the still route does not auto-start camera
  preview, while the live skeleton route does.
- Shared live AI routes capture each preview frame into the normalized app
  cache slot `mindspore_live_frame.jpg` before running the existing image-based
  local runner.
- Live camera pages query `CameraKit` for supported camera positions and show
  the Switch Camera action only when both front and back cameras are available.
  If a workflow's Android-style preferred camera is unavailable, the page starts
  with the reported available camera instead. If capability discovery fails,
  HarmonyOS keeps the action visible to preserve the previous manual-switch
  behavior.

## Runtime Permission Recovery

Android shows the shared `app_need_permission` guidance and gives the user a
manual authorization path when camera/storage permissions are denied.

Current HarmonyOS behavior:

- The startup splash gate blocks app entry until camera/media runtime
  permissions are granted or the user exits.
- Feature Runtime pages now show the localized retry action when a workflow
  permission request is denied. Non-live workflows retry the current run, while
  live camera workflows retry the camera input startup so the preview and live
  loop recover through the same path as the original Android page.

## PoseNet

Android keeps a still PoseNet page at `/hms/PosenetMainActivitys` and a
separate live skeleton page at `/posenet/LiveSkeletonAnalyseActivity`.

Current HarmonyOS behavior:

- `/hms/PosenetMainActivitys` is a still-image workflow. Its visible image
  inputs are Photo and Camera, and it auto-runs pose detection after either
  user-selected image is ready.
- The Android sample `skeleton_image.JPG` is bundled as the entry preview at
  `rawfile://posenet/skeleton_image.JPG`, not as a separate visible input.
- The still page opens with that Android sample image already previewed, but it
  does not auto-run detection until the user taps the run action, matching the
  Android page's default image plus separate Detect button.
- The still page exposes a localized Real-time action that routes to
  `/posenet/LiveSkeletonAnalyseActivity`.
- The still and live PoseNet pages expose a usable MindSpore Lite
  `posenet_lite.html` help entry and a localized local Help dialog based on
  Android's summary copy.
- `/posenet/LiveSkeletonAnalyseActivity` remains the camera-only live route,
  auto-starts preview when the HarmonyOS surface is ready, and keeps the
  Android template similarity display.
- The live skeleton workflow now carries Android's default Yoga skeleton mode
  through the runtime factory into `PoseService`/`PoseRunner`, while the still
  PoseNet route remains in normal pose mode. The CoreVision fallback still uses
  the platform's generic skeleton detector, but its standard body point types
  are mapped back to Android's Yoga template point types for the similarity
  display unless a Yoga-specific runner/model is injected.
- Pose results that report success without any skeleton or points are
  normalized to the localized pose failure state, matching Android's empty
  skeleton-list failure path.
- Devices without `SystemCapability.AI.Vision.SkeletonDetection` can expose an
  undefined native skeleton module. Shared pose and Dance modules therefore use
  the SDK-stable numeric point identifiers without reading the optional native
  enum during module initialization. Their pages still load; an unavailable
  detector is handled by the existing async pose failure path instead of
  terminating the shared runtime page.
- Live Skeleton detections draw the same skeleton lines and points directly on
  the HarmonyOS camera preview, matching Android `SkeletonGraphic` overlay
  behavior while still reusing the shared captured-frame result state.
- The live camera preview also keeps Android's skeleton template and localized
  similarity readout in the preview layer, defaulting to `0%` until pose results
  arrive.
- The still PoseNet route now uses Android's dedicated single-preview layout:
  Back/title toolbar, one divider, a weight-9 gray image/skeleton surface, and
  the weight-1 Photo, Camera, Real-time, Detect action row.
- Detect restores the packaged `posenet/skeleton_image.JPG` through the
  existing initial-preview contract before running the existing pose workflow.
  Photo and Camera keep automatic detection, and Real-time keeps the linked
  Live Skeleton route.
- Current PoseNet still results show localized Android-style success/failure
  Toasts. Permission denial remains on the recovery overlay. The dedicated
  route no longer renders generic summary, input, permission, URI, status,
  result, or debug cards.
- Real-device letterboxing, EXIF direction, overlay thickness, Toast display,
  and picker/camera feel remain deferred; models and inference code are
  unchanged.

## Gesture Recognition

Android source uses HMS ML Kit `MLGestureAnalyzer` for still and live hand
gesture recognition. HarmonyOS does not expose the same ArkTS API, so the port
packages and runs the exact model from the official HMS gesture-model AAR.

Current HarmonyOS behavior:

- `GestureDetector.ms` from
  `com.huawei.hms:ml-computer-vision-gesture-model:2.1.0.300` is packaged with
  its pinned size and SHA-256. Despite its suffix, it is an MNN FlatBuffer, not
  a MindSpore Lite model.
- The production runtime loads the model through the bundled MNN shared
  library and the narrow C++/NAPI `libgesture_mnn.so` session, then applies the
  HMS-compatible preprocessing, YOLOv3 decode, confidence thresholds, NMS,
  and Android gesture-category mapping.
- The real local runner is the production default for both the still route and
  the shared live-camera loop; it is no longer an unavailable/injected-runner
  placeholder. The still flow runs after album or camera input, and the live
  flow refreshes detections and bounding boxes on the camera preview.
- The still gesture route exposes the Android-style Real-time action and
  auto-runs gesture analysis after album or camera image input is ready.
- The static Gesture route now uses the Android production screen structure:
  the Back/title toolbar, double divider, weighted gray image/overlay surface,
  original empty-state icon and prompt, and Photo/Camera/Real-time action row.
  It no longer exposes the shared Inputs, Permissions, URI, runtime metadata,
  or duplicate result cards. Failed current requests retain Android-style
  visible Toast feedback while continuing to use the HMS MNN detector.
- HMS still-image workflows that used Android's `btn_photo`/`btn_camera` now
  keep dedicated Photo and Camera button labels in HarmonyOS instead of falling
  back to the generic image/camera input labels.
- HMS still-image workflows that used Android's `btn_real_time` now keep a
  dedicated Real-time linked-route label in HarmonyOS instead of falling back to
  the generic live-route action label.
- The still Gesture and still Scene pages use Android's original image/camera/
  real-time prompt as their top runtime summary, while their live routes keep
  the generic feature summary.
- The production runtime does not substitute the bundled MobileNetV2/ImageNet
  classifier for this gesture model, avoiding the former `mitten` false
  positive.
- Explicit hand/gesture aliases such as `boxing_glove`, `thumb_up`, `fist`,
  `heart`, and `ok_gesture` remain available only when an injected or future
  score runner is explicitly opted in through `trustedGestureModelLabels`
  after its model is verified as trained and authorized for gestures.
- The same mapper also accepts common local gesture-model aliases such as
  `Closed_Fist`, `Open_Palm`, `Thumb_Up`, `Thumb_Down`, `DISS`,
  `like_gesture`, `thumb_down_gesture`, `Victory`, `Pointing_Up`, `OK sign`,
  `heart_gesture`, and `finger heart gesture`, plus common variants such as
  `palm`, `high_five`, `peace_sign`, and `thumbs_up_gesture`. The mapper also
  accepts controlled `gesture_` / `_gesture` wrappers such as `gesture_one`,
  `one_gesture`, `hand_five_gesture`, and `gesture_ok_sign`, mapping them back
  onto the Android `MLGesture` category set. Injected or future gesture runners
  that return those aliases are canonicalized to the Android labels so result
  rows and live overlays use the same localized strings as the Android app.
- An injected gesture score runner can return up to three distinct mapped
  Android gesture categories per run, preserving the score threshold and
  category de-duplication.
- `AndroidGestureModelRunner` preserves the Android `MLGesture`-style category,
  score, and optional-rectangle service contract around the local MNN detector.
- Gesture label matching intentionally uses stable English model labels
  internally even on Chinese devices.
- Host guards and tests cover provenance, preprocessing, tensor contracts,
  decoding, and fixture wiring. Real-image accuracy, phone performance, and
  device stability have not been validated; `GestureNative.test.ets` requires
  a device or emulator and has only been compiled into the test HAP here.

## Text Recognition

Android Text Recognition and Text Translation image flows configure HMS local
OCR with `MLLocalTextSetting.OCR_DETECT_MODE` and pin the recognition language
to `zh`.

Current HarmonyOS behavior:

- Text extraction keeps the Android route and image-input flow available.
- HarmonyOS uses `@kit.CoreVisionKit` OCR with direction detection enabled.
- The local DevEco SDK text-recognition configuration only exposes
  `isDirectionDetectionSupported` plus a read-only supported-language query;
  it does not expose an Android-equivalent language selector.
- HarmonyOS therefore relies on platform OCR language auto-detection instead
  of hard-coding Chinese recognition. Text Translation still applies the
  Android default target-language rule after OCR text is produced.
- Text Recognition uses Android's image-or-camera extraction prompt as its top
  runtime summary instead of the generic feature explanation.

## Image Orientation

Android album/file image flows call `BitmapUtils.getBitmapDegree()` and rotate
decoded bitmaps for EXIF orientation values 90, 180, and 270 degrees before
running local analysis.

Current HarmonyOS behavior:

- File-backed image decoding reads ImageKit `PropertyKey.ORIENTATION` and maps
  `Right-top`, `Bottom-right`, and `Left-bottom` to Android-compatible
  90/180/270 degree rotations.
- Classification, Custom Model, Style Transfer, Object Detection, PoseNet,
  Portrait Segmentation, Text Recognition, and Text Translation image OCR
  inputs decode PixelMaps with the EXIF rotation applied.
- Object Detection, PoseNet, and Portrait Segmentation also report rotated
  image dimensions so overlays use the same visual coordinate space as the
  decoded PixelMap.
- URI-backed overlay previews read the same EXIF orientation and render with
  ArkUI `UP`, `RIGHT`, `DOWN`, or `LEFT` orientation values so the preview
  background follows the decoded analysis input without introducing mirrored
  transforms.
- Mirrored EXIF orientations stay at the Android app's previous behavior: they
  are not transformed into mirror operations because `BitmapUtils` only handled
  the three pure rotation cases.

## Text Translation

Android source uses HMS ML Kit cloud translation through `MLRemoteTranslator`.
The HarmonyOS port replaces that cloud call with a packaged local translation
runtime for typed text and OCR text.

Current HarmonyOS behavior:

- Text translation keeps the Android route and the same typed-text, camera, and
  album-photo inputs. Camera and album inputs use HarmonyOS OCR, then pass the
  recognized text through the same local runner as typed input.
- The page exposes exactly the three Android inputs: typed text, camera capture,
  and album photo. It does not expose the generic shared live-camera translation
  input; the obsolete `liveCamera` input kind and its translation-only runtime
  branches have been removed, so Camera always follows the normal still-image
  OCR flow on this page.
- The production runtime constructs `MindSporeLiteTranslationRunner` for both
  typed text and OCR output. Both inputs share the same cached model bundle and
  keep Android's default target-language rule (`zh` text translates to `en`,
  other text translates to `zh`).
- Before tokenization, a deterministic ArkTS input policy collapses OCR-spaced
  runs of at least three single ASCII letters and separates URLs, email
  addresses, and code-like identifiers from model input. Those protected spans
  are copied exactly and in order; plain numbers, dates, names, and ordinary
  hyphenated words remain in model context. Punctuation- and newline-only
  separators are also copied instead of being sent to the model.
- Protected-only input performs no tensor inference. Mixed input translates
  only its model spans inside the existing serialized request queue, fails the
  complete request if any required model span is empty, and retains the
  original unnormalized text in `sourceText`.
- `LocalTextTranslationRunner` remains available only through explicit
  legacy/demo test injection. It is no longer an implicit `DefaultAiService` or
  runtime-factory fallback, so production does not substitute a finite
  dictionary for arbitrary input.
- The packaged model set is one verified `translation-models.tar.xz` containing
  `encoder.ms`, `decoder_prefill.ms`, and `decoder_step.ms`, accompanied by the
  SentencePiece/tokenizer runtime files, vocabulary, manifest, hashes, and
  license evidence. A narrow native XZ/TAR extractor validates and caches those
  three graphs in app-private storage before MindSpore Lite opens them.
- The retained V5 checkpoint and tokenizer remain byte-identical
  (`3b8b9a61910ae1b147947eef0168d6b0c5b8033d0a9059e82ef79cc468ce705f`
  and `e5528a5c3685d08f8868902d31febeb763eea8519f9997f43b05964b02554640`).
  Package verification still reports archive SHA-256
  `aecc2672dbf648f766456e86559da8858f2c1444a4e693398300dd4982a4a417`;
  no graph or tokenizer asset was rebuilt for this policy.
- The pinned 100-row host A/B gate reduced automatic preservation-corruption
  flags from 14 to 9: Chinese-to-English changed from 6 to 4 and
  English-to-Chinese from 8 to 5, with no direction regressing. Exact input,
  code, result, and artifact hashes are recorded in
  [`runtime-input-policy-v1.md`](../tools/translation/reports/runtime-input-policy-v1.md).
- ArkTS performs tokenization and encoder -> prefill -> step inference, chooses
  tokens with deterministic greedy decoding, and carries the decoder self/cross
  KV cache between steps. The native archive utility does not perform ML
  inference.
- Successful local-model results use the normal Android-compatible completion
  message and expose `runtimeSource=localModel`. The dedicated Android-shaped
  page exposes one translated-output field only; generic source, target,
  runtime, timing, and debug rows remain hidden. Source/translated newlines
  remain exact through typed and OCR flows.
- The translation workflow requests only camera/media permissions and never
  requests Internet or calls a network translation service. The application-
  level Internet declaration remains for unrelated web/help and resource
  features.
- Blank typed text and blank OCR output are treated as missing or failed input
  instead of successful empty translation/recognition results.
- Image-based translation keeps the selected-image preview and translated-only
  output without adding the unreachable Android result-save action. Its Copy
  action reads only the translated-output row: empty or failed translation does
  not fall back to the OCR/source text and retains the existing Copy-failed
  outcome.
- Package, host, and tensor-session checks do not promote this model beyond its
  recorded limitations: `manual-quality-gate-not-passed`,
  `local-learning-only-not-production-approved`, and device-not-validated
  (`device-functionality-not-validated` in the authorization manifest).
  `productionPromotionAllowed` remains `false`. Real translation quality,
  latency, memory use, and device stability remain unverified, and
  `TranslationNative.test.ets` has only been compiled into the test HAP here.

## Model File Overrides

Android pages that accept `.ms` model overrides try loading the selected model
before making it active, so a bad pick does not replace the previous working
model.

Current HarmonyOS behavior:

- Picked `.ms` files are read and compatibility-checked with MindSpore Lite
  before the app-cache override slot is overwritten.
- Incompatible picks return the localized model-incompatible status and leave
  any existing cached Object Detection, Custom Model, or Style Transfer model
  file intact.

## Picker Cancellation

Android image/model selection flows leave the previous preview and result on
screen when the user opens a picker and cancels it.

Current HarmonyOS behavior:

- Shared image, camera-capture, style-image, and `.ms` model pickers defer
  clearing runtime results until a new input is actually selected.
- Canceling those pickers now keeps the previous input URI, result rows, and
  visual overlay/preview state while showing the localized canceled status.
- Text Translation photo/camera cancellation also restores the pre-picker text
  editor visibility, so typed input stays visible when the user backs out of an
  image-based translation pick.
- Invalid selected model files still clear stale results and preserve the last
  compatible cached model, matching the model-override guard above.

## Runtime UI Polish

Android demo pages show user-facing titles, previews, and results rather than
internal runtime method names or raw picker URI summaries.

Current HarmonyOS behavior:

- The shared runtime page keeps internal `aiMethod` and selected-input summary
  state for workflow routing, copying, cancellation, and live-loop decisions,
  but no longer renders those fields directly in normal UI.
- Selected images and models remain visible through preview rows that show
  user-facing labels and file names, instead of raw picker paths or surface ids.
- Still image segmentation now uses Android's dedicated black double-preview
  page with Photo, Camera, Real-time, and secure Save controls. New inputs and
  failed runs retain the previous foreground Save target until a current local
  foreground conversion atomically succeeds.
- No registered workflow now uses the generic runtime fallback. The fallback
  remains only as an unknown-route defense; raw `detailText` stays internal
  `resultText` state and is not rendered.
- Custom Model still exposes its first 10 output values through the existing
  structured output row.
- The shared runtime shows a primary action only for PoseNet, Text Translation,
  and Custom Model, matching Android's manual Detect, Translate, and Execute
  controls. The remaining still/style routes and all live routes rely solely on
  automatic triggers and omit the generic Run button.
- The HAP build helper now runs a static guard to catch accidental re-exposure
  of those debug fields in `FeatureRuntimePage`.

## Runtime Execution Guard

Android still-image model pages such as Style Transfer and Custom Model keep an
`isRunningModel` flag so repeated taps do not start overlapping inference.

Current HarmonyOS behavior:

- The shared Feature Runtime page now keeps the same still-workflow guard:
  while a non-live workflow is running, the remaining manual action is disabled
  and repeated manual or automatic input/style-ready triggers are ignored.
- Live camera workflows only bypass the shared guard after the page is actually
  ready to enter the live runtime loop; fallback async runs are still guarded.
  Inside the live loop, camera refresh continues to use the existing frame guard
  so frame inference does not overlap.

## Image Classification

Android Image Classification displays labels from localized
`image_category_old` string arrays.

Current HarmonyOS behavior:

- HarmonyOS keeps the bundled MobileNetV2 model and ImageNet class order.
- Image Classification result labels now load the Android Chinese label table
  on Chinese locales while keeping the existing English rawfile for other
  locales.
- Build-time label verification covers both English and Chinese rawfiles and
  rejects UTF-8 BOMs so localized first labels do not receive hidden prefixes.
- The live camera preview shows the latest classification label in a bottom
  overlay, matching Android's `bottomLayout` / `HorTextView` result surface.
- Before a valid live classification label exists, the same overlay shows the
  Android `title_keep` prompt (`正在识别` / `Continue to identify`) instead of
  disappearing.

## Scene Detection

Android source uses HMS ML Kit scene detection through the `MLSceneDetection`
flow. The local HarmonyOS SDK does not expose a direct scene detection API
matching the Android still/live scene analyzer, and the Android project does
not ship a standalone HMS scene model that can be copied into HarmonyOS.

Current HarmonyOS behavior:

- Scene detection keeps the Android still and live route names available.
- The still route implementation is retained but hidden from the default
  Experience grid, matching the currently reachable Android UI. The live route
  remains retained and can be reached from the still route's Android-style
  Real-time action when that hidden capability is opened explicitly.
- The still scene route exposes the Android-style Real-time action and
  auto-runs scene analysis after album or camera image input is ready.
- The still route now uses Android's title-only toolbar, fixed 376vp gray
  preview frame, 266x356 fill image or `icon_style` prompt, exact Photo/Camera/
  Real-time row, and remaining-height scrollable Scene Count/Scene/Score rows
  instead of generic runtime cards. Android's declared but never-shown loading
  view remains absent.
- Accepted or cancelled input, run start, permission denial, empty results,
  and runtime failures retain the previous preview and successful text rows
  until a current non-empty result replaces them. Empty analyzer results alone
  show the existing failure Toast; runtime exceptions remain silent.
- The default HarmonyOS runtime now uses the bundled
  `model/resnet18-place365.ms` Places365 scene model with
  `labels/places365.txt`, then maps top Places365 labels into Android-style
  scene labels. It skips unmapped `other` candidates when useful scene labels
  are available, but keeps the highest-scoring Android `other` candidate when
  no more specific scene remains. This makes the still/live scene workflows
  runnable offline, but it is a local approximation rather than HMS ML Kit
  equivalent output.
- The local fallback keeps up to five distinct Android-mapped scene labels per
  run. This is broader than the earlier three-candidate proxy and closer to
  Android's multi-candidate result text while still avoiding the Places365
  softmax tail overwhelming result rows and live overlays.
- The Places365-to-Android mapper includes exact aliases for common indoor,
  outdoor, transport, food, office, school, retail, and water scenes such as
  `coffee_shop`, `bookstore`, `lecture_room`, `sky`, `river`, `runway`,
  `subway_station`, `alley`, `apartment_building`, `aquarium`/`fishpond`,
  `snowfield`/`ski_slope`/`mountain_snowy`, and
  `market`/`bazaar`/`flea_market`. It also covers direct Places365 scene
  aliases such as `heliport`, `boat_deck`, `lighthouse`, `glacier`/`iceberg`,
  `canyon`, `lobby`, `parking_lot`/`parking_garage`, `farm`/`field`/`lawn`,
  `house`/`cottage`/`mansion`, and Android/Places365 slash variants such as
  `basketball_court/indoor`, `bakery/shop`, `bazaar/indoor`,
  `bazaar/outdoor`, `cabin/outdoor`, and `apartment_building/outdoor`.
- Scene result display labels use a 104-entry readable Android-equivalent
  Chinese scene label table on Chinese locales while keeping the internal
  English/Places365 labels stable for mapping. Unit coverage checks equal table
  lengths, representative mappings, and common Unicode/mojibake corruption
  markers.
- A dedicated `AndroidSceneModelRunner` adapter now defines the future local
  model contract for Android `MLSceneDetection`-style result/confidence
  output. This lets a later HarmonyOS scene model plug into the current
  still/live runtime boundary without changing the UI result contract.
- The still and live scene routes expose a usable MindSpore Lite
  `scene_detection_lite.html` help entry and a localized local Help dialog.
- Scene result rows list every returned scene candidate with its confidence,
  matching Android's visible result text instead of showing only the top scene.
- The live scene route also overlays the localized scene count, each scene
  label, and its confidence on the camera preview, mirroring Android's
  `MLSenceDetectionGraphic` behavior while keeping the HarmonyOS overlay
  readable on top of live frames.
- Scene result rows and live overlays use the Android `Scene Count` /
  `场景计数` label while keeping the generic `Count` label for other workflows.
- A real scene detection runner can still be injected; if no service exists at
  all, the app reports the localized
  `feature_runtime_scene_runner_unavailable` adapter status.
- The live scene route now participates in the shared HarmonyOS live camera
  loop, so the local scene proxy or injected runner refreshes continuously at
  the 500ms fast-live cadence used for lightweight classification-style demos.

## Core MindSpore Lite Assets

- The five core `.ms` files used by Image Classification, Scene Detection,
  Object Detection, and Style Transfer are tracked as binary repository assets
  with exact byte-length and SHA-256 contracts.
- Clean normal builds run verifier-only model wiring and do not download these
  assets. The four downloader scripts are explicit manual recovery tools only;
  they publish a fully verified request-private same-directory partial without
  deleting or truncating the previous stable model on failure.
- The main-HAP payload guard binds all five models plus their Apache-2.0 license
  and provenance NOTICE to the exact tracked source bytes. The `ohosTest` HAP
  continues to reject copied application models.
- MindSpore Model Zoo trained models remain limited to non-commercial research
  and educational use. This private local-learning repository stays within
  that scope; no model-quality, commercial-use, or device-runtime claim is
  made. Exact sources and contracts are recorded in
  `docs/model-provenance/mindspore-lite-core-models.md`.

## Build, Signing, And Device Verification Boundary

- Hypium host tests are runnable on the workstation.
- Python model and package tests are runnable on the workstation.
- The main and `ohosTest` HAPs are assembled and structurally inspected on the
  workstation, including the main-package asset/native-library guard and the
  main/test pairing guard.
- `GestureNative.test.ets` and `TranslationNative.test.ets` are compiled into
  the `ohosTest` HAP, but are not executed without a device or emulator.
- The current build artifact is an unsigned HAP. It cannot be used as evidence
  of successful phone installation or launch until DevEco-supported signing is
  configured without committing private keys.
- `hdc list targets` reports no connected device in the current environment.
  Camera, permission, installation, launch, and real gesture/translation device
  behavior therefore remain pending a signed build and a HarmonyOS phone.

## Custom Model

Android Custom Model lets users pick an image and a `.ms` model file, but the
current Android `CustomModelExecutor` is marked UI-only and returns simulated
random output after a fake load.

Current HarmonyOS behavior:

- The Custom Model route and input flow are available from the Experience grid.
- The route now uses Android's dedicated Back/Help/More toolbar, Model/Photo/
  Camera action row, conditional 256vp image preview, Execute action, loading
  indicator, and scrollable output panel instead of the generic runtime cards.
- HarmonyOS keeps the user-selected `.ms` model override, caches it in the app
  cache, and runs it through MindSpore Lite with the Android 224x224 RGB unit
  input contract.
- Compatible picks are fully written and closed in a same-directory,
  request-private temporary file before a current-request check synchronously
  replaces the stable cache path. Stale picks and write/close/replace failures
  clean only their temporary file, preserving the last valid model bytes.
- A selected model is accepted only when it exposes exactly one NHWC float32
  input tensor shaped `[1, 224, 224, 3]` with 150,528 elements and 602,112
  bytes. The input uses RGB channel order with values normalized to `[0, 1]`.
  Inference results are decoded only from a non-empty float32 output tensor;
  incompatible selections are rejected before replacing the last valid cache.
- If the user has not selected a model file, HarmonyOS now matches Android and
  blocks execution with a "select a model first" status instead of running the
  bundled MobileNetV2 model as a default custom-model fallback.
- A newly opened Custom Model page does not restore the cached model into the
  session: the user explicitly picks a model, matching Android's Activity
  lifecycle. The last valid cache remains intact when a new selection is
  cancelled or rejected.
- Execute performs image/model/running preflight before the shared runtime.
  Its workflow permission list is empty because the HarmonyOS system model,
  photo, and camera pickers own their capability UI; sibling runtime permission
  paths are unchanged.
- HarmonyOS uses Android Custom Model's dedicated visible copy for Select
  Model, Select Photo, Take Photo, Output Result, the initial output
  placeholder, and the "select an image first" missing-input status.
- The visible output row mirrors Android's `tvOutput` content by showing the
  execution time separately plus the first 10 output float values, including
  Android's overflow note when more values are available.
- The Android local Help dialog is preserved as a localized HarmonyOS Help
  button. The content is updated to describe the required `.ms` model plus image
  selection before execution.
- Unlike Android's UI-only executor and random values, HarmonyOS deliberately
  retains real MindSpore Lite inference with the fixed one-input NHWC float32
  `[1, 224, 224, 3]`, RGB `[0, 1]`, first non-empty float32 output contract.
  General arbitrary-shape/dtype, multi-input, and multi-output model support is
  deferred to a separate model-contract design.
- Device checks for picker/camera presentation, image fit, loading animation,
  Toast appearance, and compatible-model inference performance remain
  deferred; this migration is validated by source guards, unit tests, and HAP
  builds only.

## Style Transfer

Android Style Transfer lets users choose content/style images, optional model
files, and a built-in style preset, then exposes a Recovery action that returns
the preview to the original content image after a styled result is shown.

Current HarmonyOS behavior:

- The route now uses Android's dedicated Back/Help/More toolbar, divider,
  fixed gray preview, Album/Camera/Recovery/secure-Save row, predict/transfer
  model row, and four-column scrollable style grid instead of generic runtime
  cards.
- The `styleImage` runtime capability remains intact for preset/custom
  selection, but it is not rendered as a duplicate top action. The final
  custom-style add tile is the sole custom style-image picker action.
- The built-in preset strip matches Android's visible `style0` through
  `style18` entries, followed by Android's final custom-style add tile. The
  tile opens the same style-image picker and shows the selected custom style as
  a highlighted thumbnail.
- After the content/original image is ready, selecting a built-in or album
  style image immediately runs style transfer, matching Android's style-list
  selection flow.
- While an async style-transfer run is in progress, HarmonyOS ignores new
  Style Transfer input picks or preset taps so the highlighted input continues
  to match the result being produced, mirroring Android's synchronous locked
  execution path.
- Cached custom predict/transfer `.ms` model files are restored from the app
  cache when the runtime page is recreated, matching Android's static
  custom-model path behavior after `recreate()`.
- HarmonyOS uses Style Transfer-specific input labels for the original-image
  album pick, camera capture, predict-model picker, and transfer-model picker,
  matching the Android page's dedicated button copy while localizing the English
  surface instead of preserving Chinese-only hardcoded labels.
- The Style Transfer page also uses Android's initial `title_choose_image`
  prompt as its idle status so the first-run page asks the user to choose a
  picture from the lower controls or album instead of showing a generic runtime
  message.
- Picking custom predict/transfer `.ms` models now reports the Android slot
  specific load feedback (`loaded predict`, `failed predict`, `loaded
  transfer`, `failed transfer`) instead of the shared generic model-ready or
  incompatible messages used by other model-based routes.
- A successful compatible model replacement retains both model slots, drops
  the active inference session, and resets the page like Android `recreate()`;
  cancelled, failed, incompatible, undefined, or stale cache work preserves
  the current page and last stable models.
- HarmonyOS shows the localized Recovery control whenever the Style Transfer
  page is open, matching Android's always-visible button. If no original image
  has been selected yet, the action reports the Android-style original-image
  prompt.
- After a styled output is produced, Recovery switches the visible preview back
  to the original/content image while keeping the last styled result saveable,
  matching Android's `originBitmap`/`resultBitmap` split.
- Failed runs and route-scoped Recovery/Save outcomes use localized Toasts now
  that the generic status card is absent. Styled RGBA conversion is awaited so
  a current result atomically replaces the previous owned `PixelMap`; stale or
  failed conversion cannot erase the existing preview or Save target.
- Android APK update/download-new-version behavior is intentionally not
  migrated.

## Object Detection

Android Object Detection ships a default SSD MindSpore model and lets users
replace it with a selected `.ms` model in both photo and live-camera flows.

Current HarmonyOS behavior:

- The Object Detection Photo and Real-time routes use the bundled
  `model/ssd.ms` model by default and decode SSD outputs with Android-compatible
  anchors, thresholds, and label mapping.
- Object labels now load the Android Chinese `object_category` table on
  Chinese locales while keeping the existing English labels for other locales.
- Build-time label verification covers both English and Chinese rawfiles and
  rejects UTF-8 BOMs so localized first labels do not receive hidden prefixes.
- The Experience cards keep Android's `Object Detection(Photo)` /
  `Object Detection(Real-time)` labels, while the runtime pages use the
  Android activity titles `Photo Detection` and `Camera Detection`.
- The optional `.ms` model picker on Object Detection routes uses the Android
  `Select Model` / `选择模型` action copy.
- Runtime result rows keep the top-detection summary and also list every
  detected object so the structured result matches the full detection detail.
- Empty SSD outputs are treated as object-detection failure, matching Android's
  `train_invalid` path when the analyzer returns no boxes for a still image;
  live camera refreshes simply clear the overlay until a later frame detects
  objects.
- `/imageobject/ObjectPhotoActivity` follows the Android page flow: opening the
  route prepares the album image input once, and a selected image immediately
  runs object detection.
- The Object Detection Photo route now uses its own full-height white page with
  the Android 56vp toolbar, one centered image/box overlay surface, and the
  blue `Select Model` action fixed 16vp from the bottom-right corner. Generic
  summary, input, permission, status, result, debug, save, and Run cards are
  not rendered on this route.
- Failed still-image detection keeps the selected image visible and reports
  the existing localized object-detection failure through a route-scoped
  Toast; Object Camera and other workflows do not use this feedback path.
- Because that initial album picker already supplies the photo, the Object
  Detection Photo page shows only `Select Model` as an input action, matching
  Android instead of exposing a redundant Photo action.
- The Object Detection Photo route keeps the HarmonyOS window awake while the
  page is visible, matching `android:keepScreenOn="true"` from Android's
  `activity_object_photo.xml` without affecting the live Object Camera route.
- If that initial album pick is cancelled, HarmonyOS returns to the previous
  page instead of leaving an empty runtime screen, matching Android's
  `finish()` path for invalid initial photo selection.
- Live Object Detection draws the same result boxes directly over the
  HarmonyOS camera preview, matching Android `ObjectCameraActivity`'s preview
  overlay behavior while still reusing the shared captured-frame result state.
- User-selected `.ms` files remain optional. When selected, HarmonyOS copies
  the file into the app cache as `object_detection_model.ms` before runtime use,
  so the MindSpore Lite runner receives an app-owned path instead of depending
  on the picker URI lifetime.
- After a compatible Object Photo model is published to that fixed cache slot,
  HarmonyOS immediately opens the initial-semantics photo picker, matching the
  Android activity recreation flow. Cancelled, incompatible, failed, or stale
  model work neither starts this follow-up nor replaces the last valid cache.
- The dedicated page continues to use the real bundled/cached SSD pipeline and
  existing orientation-aware box geometry. Picker presentation, rendered box
  alignment, Toast appearance, model accuracy, latency, and memory behavior
  remain deferred to device validation.
- Android APK update/download-new-version behavior is intentionally not
  migrated.

## Portrait Segmentation

Android Portrait Segmentation is a live camera page that runs body
segmentation, overlays the foreground on a selectable background, and supports
built-in plus album backgrounds.

Current HarmonyOS behavior:

- `/hms/ImageSegmentationActivity` remains the still image segmentation route,
  exposes the Android-style Real-time action, and auto-runs segmentation after
  album or camera image input is ready.
- The still, live, and portrait segmentation routes expose a usable MindSpore
  Lite `image_segmentation_lite.html` help entry and a localized local Help
  dialog.
- `/hms/PortraitSegmentationActivity` now starts the shared live camera
  preview and refreshes subject segmentation through the existing live runtime
  loop.
- The five Android-style built-in backgrounds and custom background picker are
  preserved as optional inputs, and the page starts with the Android `portrait1`
  background selected by default.
- Canceling the album picker keeps the current built-in or custom background,
  matching Android's `onActivityResult` behavior.
- Switching to another built-in or custom portrait background preserves the
  current foreground/result and updates the composite preview background, like
  Android's separate foreground/background image layers.
- Segmentation results without a foreground image are treated as failure,
  matching Android's still-image `getForeground() == null` guard instead of
  reporting success with only rectangle metadata.
- Live segmentation routes draw the detected foreground layer directly on the
  HarmonyOS camera preview, matching Android's foreground overlay behavior.
- HarmonyOS reuses the foreground/background composite preview and save path
  already used for still segmentation results; the live frame is captured
  through the current app-cache JPEG fallback rather than a native analyzer
  transactor.

## Me

Android Me keeps most rows hidden by default and builds the hidden share text by
appending the Android APK download/update page.

Current HarmonyOS behavior:

- The default visible Me surface still only shows Version, matching Android
  source visibility.
- Hidden share remains route/service-ready, but the payload now appends the
  MindSpore home page instead of the Android APK download URL because APK
  update/download-new-version behavior is intentionally not migrated.

## Dance Factory

Android Dance Factory combines CameraX video sampling, HMS skeleton detection,
and a pure Java scoring algorithm in `ModelDataUtils`.

Current HarmonyOS behavior:

- The route stays hidden from the default Experience grid, matching Android
  source visibility.
- The pure 70-frame scoring table, score formula, no-action/no-point error
  codes, and generic skeleton-point-to-frame conversion are ported to ArkTS in
  `DanceScoreService`.
- HarmonyOS `PoseResult` data is adapted into dance scoring frames through
  `DanceSamplingService`; it uses the Android 70-frame and 500ms sampling
  constants, reuses pose visibility filtering, and synthesizes the Android neck
  joint from the left/right shoulder midpoint.
- `/dance/DanceMainActivity` now opens a dedicated HarmonyOS Dance page with
  live camera preview, 70-frame live skeleton sampling, the original MindSpore
  reference video, 3/2/1 synchronized run start, Android-style result messages,
  and album save for the rendered result card. The unreachable Harmony-only
  template demo button and page branch have been removed; its pure scoring
  fixture remains only in unit coverage for the ported Android score contract.
- The Dance page keeps the HarmonyOS window awake while it is visible, matching
  Android's `FLAG_KEEP_SCREEN_ON` behavior without changing the app-wide screen
  policy.
- The prepare and live-preview areas reuse Android's original `prepare_bk` and
  `run_bk` bitmap backgrounds as decorative HarmonyOS media. Android's
  Chinese-only start/countdown bitmap labels are not rendered directly so the
  HarmonyOS page can keep localized text.
- The result screen reuses Android's `result_bk`, `dance_back`, `save`, and
  `play_again` bitmap assets, with the background rendered using cover scaling
  so the 1920x1080 image is not stretched on narrow HarmonyOS screens.
- The visible play-again action uses localized HarmonyOS text instead of the
  Chinese-only Android bitmap label, while keeping the Android action size and
  returning to the prepare state.
- The save action intentionally stays on HarmonyOS `SaveButton` so Gallery
  writes keep the platform short-term authorization flow; the Android save
  bitmap remains bundled for source parity but is not rendered over the secure
  component.
- HarmonyOS restores the Android reference-video cache behavior with the same
  `danceVideo2.mp4` name and 41,282,333-byte length check, but stores it in the
  app cache directory instead of public Downloads to fit HarmonyOS scoped
  storage.
- Reference-video downloads now surface progress in the Dance page while the
  cache file is being prepared, and download failures use the Android
  `Download failed` / `下载失败` copy.

## Intelligent Poetry

Android Intelligent Poetry opens the remote MindSpore poetry page in WebView,
registers a JavaScript interface named `android`, and receives generated poem
text through `android.getGeneratePoetry(text)` before opening a poster page.

Current HarmonyOS behavior:

- The feature remains hidden from the default Experience grid, matching Android
  source visibility.
- The Web route keeps the Android route name and loads the original remote
  MindSpore poetry URL.
- ArkWeb installs a JavaScript proxy with the same bridge name and method, then
  routes generated poem text into the HarmonyOS poster page.
- The poster page snapshots the rendered poster and uses HarmonyOS save/share
  services for image export.
- The poster page reuses Android's original poem background and frame assets
  with the same 20/60/80vp layout proportions for the poster body, poem text
  inset, and QR code.
- The poster footer also restores Android's `logo2` brand image above the
  localized MindSpore AI credit text, next to the original bundled QR code.
