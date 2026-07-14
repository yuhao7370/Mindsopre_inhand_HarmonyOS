# Experience Grid Android Layout Parity Design

## Goal

Match the visible Android Experience page structure while preserving the
already-aligned feature catalog, route names, order, and hidden entries.

## Android source of truth

`fragment_experience.xml`, `fragment_vision.xml`, and `btn_vision_item.xml`
define:

- the existing 160dp Experience header;
- 30dp top and bottom content padding;
- group headings between full-width horizontal dividers;
- compact section markers at 18dp from the left, with 13sp bold text;
- a Flow with at most two 44%-wide items per row;
- 50dp cards, 17dp vertical row gaps, and approximately 18dp side insets;
- 12sp single-line labels, compact Android drawable icons, and a 1dp gray
  rounded outline.

The Android page keeps Dance, Poetry, and Scene hidden in the normal catalog.
Those items are not part of this layout increment.

## HarmonyOS design

### Pure layout contract

Add a small data-only layout specification containing the Android column
count, card height, row gap, side inset, inter-column gap, and a deterministic
grid-height function. The explicit height lets ArkUI render a two-column Grid
inside the existing Scroll without clipping or nested scrolling.

### Page structure

Keep `ExperienceHeader` and the catalog-driven `ForEach`. Replace the current
single-column card container with a non-scrollable two-column Grid. Render
group headings as Android-style top divider, centered title, and bottom
divider. Use a page-private compact section title so College and Me retain
their existing shared `SectionTitle` styling.

### Card structure

Keep `FeatureCard` as the click target and preserve its item/action API. Match
the Android button geometry with 50vp height, compact icon bounds, 12fp
single-line text, 4vp horizontal padding, and a 1vp gray rounded outline.

### Behavior retained

- the same 10 visible feature items and exact order;
- the same Experience/Advanced grouping and empty-section filtering;
- the same icon resource mapping;
- the same route lookup and router parameters;
- the same hidden Dance, Poetry, and Scene route readiness;
- the same localization and header.

## Excluded work

- no feature catalog or route changes;
- no AI, model, camera, or permission changes;
- no Me-page changes in this increment;
- no device-only density or touch-target validation.

## Verification

- TDD the pure two-column row/height contract for zero, odd, and even counts;
- retain catalog/order/icon tests;
- run full Hypium and read the exact result file;
- run `git diff --check` and unified HAP/AI acceptance;
- obtain independent task and branch review before fast-forwarding to master.

