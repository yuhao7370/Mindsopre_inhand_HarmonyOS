# Gesture Local Fallback Plan

## Goal

Make the default HarmonyOS Gesture Recognition workflow runnable without HMS
`MLGestureAnalyzer`, while clearly documenting that the result is a conservative
local approximation rather than an equivalent hand-gesture model.

## Steps

1. Add a local `GestureRunner` that reuses MobileNetV2 classification scores.
2. Map only conservative hand/gesture-related labels to Android gesture
   categories, and fail honestly for unrelated images.
3. Inject the local runner by default from the runtime factory while preserving
   explicit runner injection.
4. Cover mapping, success, failure, and default factory behavior in unit tests.
5. Update the platform-differences note.
