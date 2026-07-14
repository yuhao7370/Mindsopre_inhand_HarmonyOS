# Text Translation Reachable Save Parity Design

Date: 2026-07-14  
Status: approved by delegated execution authority

## Goal

Make the HarmonyOS text-translation result surface match the controls reachable
in the Android app without changing local Chinese-English translation, OCR,
copying, or image selection.

## Evidence And Scope

Android `TextTranslationActivity` declares an `onClickSave()` method, but
`activity_text_translation.xml` contains no view bound to that method and no
save control. The reachable Android translation page exposes text translation,
camera, album, result text, and copy.

HarmonyOS currently adds a translation-result snapshot plus `SaveButton` after
camera or album translation succeeds. This is a visible HarmonyOS-only action,
so it conflicts with the project's reachable-surface 1:1 target.

## Considered Approaches

1. Remove the translation snapshot/save action. Selected because it exactly
   matches Android and deletes unused special-case code.
2. Keep it as a HarmonyOS enhancement. Rejected because the requested target is
   1:1 migration, not a superset UI.
3. Hide it behind a feature flag. Rejected because no product mode requires the
   extra action and the flag would add configuration without user value.

## Design

- Delete the translation-only save-visibility helper and preview component.
- Remove the translation snapshot component ID and translated-row readiness
  helper when they have no remaining callers.
- Keep the shared image-save controls used by style transfer, segmentation,
  QR code, dance, and poetry unchanged.
- Keep translation copy, typed input, camera/album OCR, request generation, and
  the packaged local model unchanged.
- Extend the existing translation parity guard so a future translation snapshot
  save path fails the build.

## Verification

- A host test asserts that translation has copy support but no result-image save
  action.
- The translation parity guard rejects the removed helper/component names.
- Full Hypium tests, Python translation tests, HAP build, and AI-runtime HAP
  pairing verification remain green.
- Device/emulator execution remains outside this increment, as requested.
