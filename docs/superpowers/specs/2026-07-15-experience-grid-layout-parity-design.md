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
count (`2`), card height (`50vp`), row gap (`17vp`), side inset (`18vp`), and
inter-column gap (`8vp`). Its deterministic height is
`rows * 50 + (rows - 1) * 17`, where
`rows = ceil(max(0, itemCount) / 2)` and zero rows return zero. The explicit
height lets ArkUI render a two-column Grid without clipping or nested scrolling.

### Page structure

Keep the `ExperienceHeader` fixed above the content `Scroll`, with a white page
background and `30vp` top/bottom content padding. Preserve the catalog-driven
`ForEach`, but replace the current single-column card container with a
non-scrollable `1fr 1fr` Grid using the explicit height, `18vp` side insets,
`8vp` column gap, and `17vp` row gap.

Render group headings between native ArkUI `2vp` `#66000000` dashed top/bottom
borders. A group after a previous Grid starts `24vp` below it; the centered
`16fp` bold label has `8vp` above and below. Use a page-private section title
with a `3vp` by `12vp` `#6189FF` marker at x=18/top=23, a `13fp` bold label at
x=28/top=20, and a Grid `15vp` below it, so College and Me retain their
existing shared `SectionTitle` style.

### Card structure

Keep `FeatureCard` as the click target and preserve its item/action API. Match
the Android button geometry with `50vp` height, a `28vp` by `22vp` Contain
icon, `5vp` icon/label gap, `12fp` single-line text, `4vp` horizontal padding,
and a `1vp` `#E6E6E6` outline with `5vp` radius. Keep normal-weight `#333333`
label text and the stable transparent default over the white page. The Android
pressed fill/radius state is excluded until a simple, reliable ArkUI state
style can be verified.

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
- no pressed-state styling without a reliable ArkUI state contract;
- no device-only density or touch-target validation.

## Verification

- TDD the pure two-column row/height contract for zero, odd, and even counts;
- retain catalog/order/icon tests;
- run full Hypium and read the exact result file;
- run `git diff --check` and unified HAP/AI acceptance;
- obtain independent task and branch review before fast-forwarding to master.
