# Custom Model Default Local Model Plan

## Goal

Make Custom Model runnable without requiring the user to pick a model first,
while preserving the selected `.ms` model override path.

## Steps

1. Treat the model file as optional in the HarmonyOS runtime workflow.
2. Use the bundled MobileNetV2 MindSpore model as the default custom-model
   runner when no user model is selected.
3. Keep selected `.ms` files routed through the existing cached file runner.
4. Preserve the Android 224x224 RGB unit input contract and generic tensor
   summary output.
5. Document that this improves on Android's UI-only random-output executor.
