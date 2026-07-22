# HarmonyOS Experience UI Redesign

## Goal

Replace the Android-like Experience catalog treatment with the selected C mockup: a blue-violet immersive header, a floating white content surface, rounded two-column feature cards, and a floating bottom navigation treatment. Hide Custom Model from the catalog without deleting its route or runtime.

## Scope

- Keep the nine visible features: PoseNet, Portrait Segmentation, Image Classification, Gesture Recognition, Text Extraction, Text Translation, Object Detection (Photo), Object Detection (Real-time), and Style Transfer.
- Hide Dance Factory, Intelligent Poetry, Scene Detection, and Custom Model while keeping their routes and implementations ready.
- Generate one project-owned icon for every catalog feature, including the four hidden entries, plus a HarmonyOS-inspired header illustration.
- Preserve the existing navigation and feature workflows.

## Visual System

- Blue-to-violet ambient hero with distributed orbit/ring imagery; no HarmonyOS logo or copied trademark.
- White page surface with a large top radius overlapping the hero.
- Two-column cards with at least 44 vp touch targets, 16 vp radius, subtle blue-gray border, and distinct pictographic icons.
- Clear group headings without dashed dividers. Experience and Advanced remain separate, with their technology subsection labels.
- Bottom navigation remains readable and never covers the final feature row.

## Behavior and Accessibility

- Feature cards remain full-card tap targets and route through the existing `openFeature` path.
- Text contrast remains at least equivalent to the current primary text colors.
- Long labels may wrap to two lines; no functional label is truncated into ambiguity.
- Hidden items remain discoverable through `allExperienceFeatures` for route and regression tests but are absent from `visibleExperienceSections`.

## Verification

- LocalUnit proves nine visible entries, Custom Model hidden, all thirteen features mapped to unique generated media, and the new layout constants.
- Build the dual-ABI HAP and install it on the API24 emulator.
- Capture top and scrolled screenshots to confirm icons, hierarchy, scrolling, and bottom-bar clearance.

