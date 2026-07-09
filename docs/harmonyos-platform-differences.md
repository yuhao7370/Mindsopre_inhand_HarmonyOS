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
- The service returns the localized `feature_runtime_gesture_unsupported`
  platform status when no real gesture runner is injected.
- `/hms/LiveHandGestureAnalyseActivity` is treated as a single capture flow
  instead of starting a live preview loop, so the app does not suggest realtime
  hand gesture detection that the platform adapter cannot perform.

## Text Translation

Android source uses HMS ML Kit cloud translation through `MLRemoteTranslator`.
The local HarmonyOS SDK has Natural Language text processing and AI Caption
APIs, but no direct text translation API matching the Android flow of typed
text or OCR text to translated text.

Current HarmonyOS behavior:

- Text extraction uses HarmonyOS OCR.
- Text translation keeps the Android route and entry available.
- When no real translation runner is injected, the service returns the
  localized `feature_runtime_translation_unsupported` platform status while
  preserving recognized source text in the result details.
