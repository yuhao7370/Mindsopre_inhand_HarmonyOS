# HarmonyOS Platform Differences

Verified on 2026-07-09 with DevEco Studio SDK `6.1.1(24)`.

## Gesture Recognition

Android source uses HMS ML Kit `MLGestureAnalyzer` for still and live hand
gesture recognition. The local HarmonyOS SDK exports `@kit.CoreVisionKit`
capabilities for OCR, face, object detection, subject segmentation, and
skeleton detection, but it does not expose an equivalent hand gesture or hand
landmark API.

Current HarmonyOS behavior:

- `Gesture Recognition` keeps the Android route and entry available.
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
  all, the app keeps the localized `feature_runtime_gesture_unsupported`
  platform status.

## Text Translation

Android source uses HMS ML Kit cloud translation through `MLRemoteTranslator`.
The local HarmonyOS SDK has Natural Language text processing and AI Caption
APIs, but no direct text translation API matching the Android flow of typed
text or OCR text to translated text.

Current HarmonyOS behavior:

- Text extraction uses HarmonyOS OCR.
- Text translation keeps the Android route and entry available.
- The default HarmonyOS runtime includes a small offline dictionary fallback
  for common demo phrases in Chinese and English. It can compose known adjacent
  phrases such as `Hello, MindSpore!` or `你好昇思`, and preserves Android's
  default target-language rule (`zh` text translates to `en`, other text
  translates to `zh`).
- This fallback is not equivalent to HMS cloud translation. Unknown phrases
  fail with the localized text-translation failure status instead of inventing
  output.
- A real translation runner can still be injected; if no translation service
  exists at all, the app keeps the localized
  `feature_runtime_translation_unsupported` platform status while preserving
  recognized source text in result details, rows, and copy action.

## Scene Detection

Android source uses HMS ML Kit scene detection through the `MLSceneDetection`
flow. The local HarmonyOS SDK does not expose a direct scene detection API
matching the Android still/live scene analyzer, and the Android project does
not ship a standalone HMS scene model that can be copied into HarmonyOS.

Current HarmonyOS behavior:

- Scene detection keeps the Android still and live route names available.
- The routes are runtime-ready but hidden from the default Experience grid,
  matching the current Android app shell visibility.
- The default HarmonyOS runtime now reuses the bundled MobileNetV2 image
  classification model and maps top classification labels into Android-style
  scene labels. This makes the still/live scene workflows runnable offline, but
  it is a local approximation rather than HMS ML Kit equivalent output.
- A real scene detection runner can still be injected; if no service exists at
  all, the app keeps the localized `feature_runtime_scene_unsupported` platform
  status.

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
  the original MindSpore reference video stream, 3/2/1 synchronized run start,
  Android-style result messages, and album save for the rendered result card.
- HarmonyOS streams the original remote reference video URL directly through the
  platform `Video` component instead of caching the 39MB mp4 into public
  Downloads like the Android implementation.

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
