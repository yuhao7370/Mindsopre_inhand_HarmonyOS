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
- `/posenet/LiveSkeletonAnalyseActivity` remains the camera-only live route,
  auto-starts preview when the HarmonyOS surface is ready, and keeps the
  Android template similarity display.

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
  hand-adjacent positive; exact gesture labels such as `boxing_glove`,
  `thumb_up`, `fist`, `heart`, and `ok_gesture` are also mapped when provided
  by an injected or future score runner.
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
  English, including the app intro and College summary copy. It can compose
  known adjacent phrases such as `Hello, MindSpore!` and preserves Android's
  default target-language rule (`zh` text translates to `en`, other text
  translates to `zh`).
- This fallback is not equivalent to HMS cloud translation. Unknown phrases
  fail with the localized text-translation failure status instead of inventing
  output.
- A real translation runner can still be injected. Without one, known typed or
  OCR-recognized phrases use the bundled local fallback while unknown phrases
  preserve the source text in result details, rows, and copy action.

## Scene Detection

Android source uses HMS ML Kit scene detection through the `MLSceneDetection`
flow. The local HarmonyOS SDK does not expose a direct scene detection API
matching the Android still/live scene analyzer, and the Android project does
not ship a standalone HMS scene model that can be copied into HarmonyOS.

Current HarmonyOS behavior:

- Scene detection keeps the Android still and live route names available.
- The routes are runtime-ready but hidden from the default Experience grid,
  matching the current Android app shell visibility.
- The still scene route exposes the Android-style Real-time action and
  auto-runs scene analysis after album or camera image input is ready.
- The default HarmonyOS runtime now uses the bundled
  `model/resnet18-place365.ms` Places365 scene model with
  `labels/places365.txt`, then maps top Places365 labels into Android-style
  scene labels. This makes the still/live scene workflows runnable offline,
  but it is a local approximation rather than HMS ML Kit equivalent output.
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
- If the user has not selected a model file, HarmonyOS uses the bundled
  MobileNetV2 MindSpore model as a local default instead of blocking at missing
  input. The result is still shown as a generic tensor summary, matching the
  Android screen shape rather than turning the page into Image Classification.
- The Android local Help dialog is preserved as a localized HarmonyOS Help
  button. The content is updated to describe the optional `.ms` model and the
  bundled local fallback model.

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
- `/imageobject/ObjectPhotoActivity` follows the Android page flow: opening the
  route prepares the album image input once, and a selected image immediately
  runs object detection.
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
- `/hms/PortraitSegmentationActivity` now starts the shared live camera
  preview and refreshes subject segmentation through the existing live runtime
  loop.
- The five Android-style built-in backgrounds and custom background picker are
  preserved as optional inputs.
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
- HarmonyOS restores the Android reference-video cache behavior with the same
  `danceVideo2.mp4` name and 41,282,333-byte length check, but stores it in the
  app cache directory instead of public Downloads to fit HarmonyOS scoped
  storage.

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
