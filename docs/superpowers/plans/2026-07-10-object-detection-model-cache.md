# Object Detection Model Cache Plan

Goal: make HarmonyOS Object Detection match Android's optional custom `.ms`
model behavior for both photo and live-camera routes.

Scope:

1. Keep bundled `model/ssd.ms` as the default Object Detection model.
2. Treat picked `modelFile` inputs for Object Photo and Object Camera as
   optional replacements, not required primary inputs.
3. Copy selected object detection model files into the app cache before runtime
   use, using `object_detection_model.ms`.
4. Reuse the existing MindSpore Lite object detection runner and selected-model
   URI path.
5. Skip Android APK update/download-new-version behavior per user direction.

Verification:

- Red/green unit tests for the object detection cache slot and cache-service
  write path.
- `hvigorw.bat test --no-daemon`
- `scripts/build-hap.ps1`
