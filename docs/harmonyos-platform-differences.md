# HarmonyOS Platform Differences

Verified on 2026-07-09 with DevEco Studio SDK `6.1.1(24)`.

## Experience Route

Android registers `/app/VisionFragment` for the Experience feature list even
though the fragment is normally hosted inside `MainActivity`.

Current HarmonyOS behavior:

- `/app/VisionFragment` is preserved as a router alias that opens the existing
  Experience feature catalog through a thin page wrapper.
- The main tab shell still uses the same reusable Experience component; no
  duplicate catalog data is introduced.

## Live Camera Startup

Android live camera activities start preview during page startup instead of
waiting for a separate input click.

Current HarmonyOS behavior:

- Live runtime routes whose only primary input is camera now start the shared
  camera preview automatically after the HarmonyOS surface is ready.
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

- `/hms/PosenetMainActivitys` is a still-image workflow. It offers the Android
  sample image, album image, and camera capture inputs and auto-runs pose
  detection after an image input is ready.
- The Android sample `skeleton_image.JPG` is bundled as
  `rawfile://posenet/skeleton_image.JPG`.
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
- Live Skeleton detections draw the same skeleton lines and points directly on
  the HarmonyOS camera preview, matching Android `SkeletonGraphic` overlay
  behavior while still reusing the shared captured-frame result state.
- The live camera preview also keeps Android's skeleton template and localized
  similarity readout in the preview layer, defaulting to `0%` until pose results
  arrive.

## Gesture Recognition

Android source uses HMS ML Kit `MLGestureAnalyzer` for still and live hand
gesture recognition. The local HarmonyOS SDK exports `@kit.CoreVisionKit`
capabilities for OCR, face, object detection, subject segmentation, and
skeleton detection, but it does not expose an equivalent hand gesture or hand
landmark API.

Current HarmonyOS behavior:

- `Gesture Recognition` keeps the Android route and entry available.
- The still gesture route exposes the Android-style Real-time action and
  auto-runs gesture analysis after album or camera image input is ready.
- The default HarmonyOS runtime reuses the bundled MobileNetV2 image
  classification model as a conservative local approximation. With the bundled
  ImageNet labels this currently only treats the exact `mitten` class as a
  hand-adjacent positive; hand-adjacent or gesture labels such as
  `boxing_glove`, `thumb_up`, `fist`, `heart`, and `ok_gesture` are also mapped
  when provided by an injected or future score runner.
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
- The local image-classification fallback keeps up to three distinct mapped
  Android gesture categories per run, preserving the score threshold and
  category de-duplication while moving closer to Android's multi-gesture
  overlay behavior.
- The gesture fallback intentionally keeps English ImageNet labels internally
  even on Chinese devices, because its conservative matching depends on stable
  model label names.
- This fallback is not equivalent to HMS hand gesture recognition. Non-hand
  images and labels outside the conservative map fail with the localized
  gesture failure status instead of inventing output.
- A real gesture runner can still be injected; if no gesture service exists at
  all, the app reports the localized
  `feature_runtime_gesture_runner_unavailable` adapter status.
- The live gesture route now participates in the shared HarmonyOS live camera
  loop, so the local fallback or injected gesture runner refreshes continuously
  at the 500ms fast-live cadence used for lightweight classification-style
  demos.
- Live gesture detections with bounding rectangles are drawn directly over the
  HarmonyOS camera preview, reusing the still-image gesture overlay renderer to
  mirror Android's `HandGestureGraphic` behavior.

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
The local HarmonyOS SDK has Natural Language text processing and AI Caption
APIs, but no direct text translation API matching the Android flow of typed
text or OCR text to translated text.

Current HarmonyOS behavior:

- Text extraction uses HarmonyOS OCR.
- Text translation keeps the Android route and entry available.
- The default HarmonyOS runtime and low-level `DefaultAiService` include a
  small offline dictionary fallback for common demo phrases in Chinese and
  English, including the app name, Experience subtitle, app intro, College
  summary copy, permission/status copy, Android/HMS feature help sentences for
  the bundled vision demos, Android/HMS prompt and failure copy, short
  action/status labels such as `detect`, `video`, `copy`, `SAVE`, and
  `Copied successfully`, the main shell tab and Experience section labels, and
  Android title strings that use parenthesized or hyphenated separators such as
  `Object Detection(Photo)` and `Real-time translation`. It can compose known
  adjacent phrases such as `Hello, MindSpore!` and preserves Android's default
  target-language rule (`zh` text translates to `en`, other text translates to
  `zh`).
- This fallback is not equivalent to HMS cloud translation. Unknown phrases
  fail with the localized text-translation failure status instead of inventing
  output.
- A real translation runner can still be injected. Without one, known typed or
  OCR-recognized phrases use the bundled local fallback while unknown phrases
  preserve the source text in result details, rows, and copy action.

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
- The HAP build helper now runs a static guard to catch accidental re-exposure
  of those debug fields in `FeatureRuntimePage`.

## Runtime Execution Guard

Android still-image model pages such as Style Transfer and Custom Model keep an
`isRunningModel` flag so repeated taps do not start overlapping inference.

Current HarmonyOS behavior:

- The shared Feature Runtime page now keeps the same still-workflow guard:
  while a non-live workflow is running, the Run action is disabled and repeated
  auto-run/manual triggers are ignored.
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

## Scene Detection

Android source uses HMS ML Kit scene detection through the `MLSceneDetection`
flow. The local HarmonyOS SDK does not expose a direct scene detection API
matching the Android still/live scene analyzer, and the Android project does
not ship a standalone HMS scene model that can be copied into HarmonyOS.

Current HarmonyOS behavior:

- Scene detection keeps the Android still and live route names available.
- The still route is visible from the default Experience grid. The live route
  remains runtime-only and is reached from the still route's Android-style
  Real-time action.
- The still scene route exposes the Android-style Real-time action and
  auto-runs scene analysis after album or camera image input is ready.
- The default HarmonyOS runtime now uses the bundled
  `model/resnet18-place365.ms` Places365 scene model with
  `labels/places365.txt`, then maps top Places365 labels into Android-style
  scene labels and skips unmapped `other` candidates instead of displaying
  them ahead of useful scene labels. This makes the still/live scene workflows
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
  `canyon`, and `lobby`.
- Scene result display labels now use a recovered/readable Android-equivalent
  Chinese scene label table on Chinese locales while keeping the internal
  English/Places365 labels stable for mapping.
- The still and live scene routes expose a usable MindSpore Lite
  `scene_detection_lite.html` help entry and a localized local Help dialog.
- Scene result rows list every returned scene candidate with its confidence,
  matching Android's visible result text instead of showing only the top scene.
- The live scene route also overlays the localized scene count, each scene
  label, and its confidence on the camera preview, mirroring Android's
  `MLSenceDetectionGraphic` behavior while keeping the HarmonyOS overlay
  readable on top of live frames.
- A real scene detection runner can still be injected; if no service exists at
  all, the app reports the localized
  `feature_runtime_scene_runner_unavailable` adapter status.
- The live scene route now participates in the shared HarmonyOS live camera
  loop, so the local scene proxy or injected runner refreshes continuously at
  the 500ms fast-live cadence used for lightweight classification-style demos.

## Custom Model

Android Custom Model lets users pick an image and a `.ms` model file, but the
current Android `CustomModelExecutor` is marked UI-only and returns simulated
random output after a fake load.

Current HarmonyOS behavior:

- The Custom Model route and input flow are available from the Experience grid.
- HarmonyOS keeps the user-selected `.ms` model override, caches it in the app
  cache, and runs it through MindSpore Lite with the Android 224x224 RGB unit
  input contract.
- If the user has not selected a model file, HarmonyOS now matches Android and
  blocks execution with a "select a model first" status instead of running the
  bundled MobileNetV2 model as a default custom-model fallback.
- The visible output row mirrors Android's `tvOutput` content by showing the
  execution time separately plus the first 10 output float values, including
  Android's overflow note when more values are available.
- The Android local Help dialog is preserved as a localized HarmonyOS Help
  button. The content is updated to describe the required `.ms` model plus image
  selection before execution.

## Style Transfer

Android Style Transfer lets users choose content/style images, optional model
files, and a built-in style preset, then exposes a Recovery action that returns
the preview to the original content image after a styled result is shown.

Current HarmonyOS behavior:

- The shared runtime keeps the existing content image, style image, built-in
  preset, and optional `.ms` model inputs intact.
- The built-in preset strip matches Android's visible `style0` through
  `style18` entries. Android's final add tile is represented by the localized
  custom style-image input instead of another built-in preset.
- After the content/original image is ready, selecting a built-in or album
  style image immediately runs style transfer, matching Android's style-list
  selection flow.
- After a styled output is produced, HarmonyOS now shows a localized Recovery
  control that clears only the styled preview and restores the original/content
  preview state.
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
- Empty SSD outputs are treated as object-detection failure, matching Android's
  `train_invalid` path when the analyzer returns no boxes for a still image;
  live camera refreshes simply clear the overlay until a later frame detects
  objects.
- `/imageobject/ObjectPhotoActivity` follows the Android page flow: opening the
  route prepares the album image input once, and a selected image immediately
  runs object detection.
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
- `/dance/DanceMainActivity` now opens a dedicated HarmonyOS Dance page with a
  template scoring demo, live camera preview, 70-frame live skeleton sampling,
  the original MindSpore reference video, 3/2/1 synchronized run start,
  Android-style result messages, and album save for the rendered result card.
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
  cache file is being prepared.

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
