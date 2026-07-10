# Scene Detection Local Runner Plan

## Goal

Make the HarmonyOS Scene Detection still/live workflows runnable without HMS ML Kit by reusing the bundled MobileNetV2 classifier as a local scene proxy.

## Constraints

- Android APK update/download is intentionally out of scope.
- Do not add network dependencies or new binary models unless needed.
- Keep Android route names and existing result UI.
- Preserve i18n keys; document that this is a local approximation, not an HMS-equivalent scene model.
- Keep the app buildable.

## Steps

1. Add failing unit coverage for classification-score-to-scene mapping and default runtime injection.
2. Implement a scene runner that converts top classification labels into Android-style scene labels.
3. Wire Scene workflows to the default local runner in the Harmony runtime factory.
4. Update platform differences documentation.
5. Run unit tests, HAP build, whitespace checks, and focused review.
