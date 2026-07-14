# Me Page Android Layout Parity Design

## Goal

Match the currently reachable Android Me page while retaining the already
ported native actions and hidden route definitions for future use.

## Android source of truth

`MeFragment` inflates `fragment_me.xml` and hides Share, QR code, Like,
Official Website, Official Code, Feedback, and User Agreement. The normal page
therefore contains only:

- a 56dp action-bar-height horizontal blue gradient title;
- centered 17sp bold white `me_title` text, without a subtitle;
- a 1dp `#DBDBDB` divider;
- one full-width Version row;
- 29dp top/bottom row padding, 20dp side insets, the intrinsic 14dp version
  icon, 15dp icon/text gap, 16sp `#333333` label, and 13sp `#666666` version;
- no card border, rounded container, section title, or chevron on Version.

`fragment_me_new.xml` is not used by `MeFragment` and is not the parity source.

## HarmonyOS design

### Pure layout contract

Add a data-only layout specification for the 56vp title, 1vp divider, 29vp
vertical row padding, 20vp horizontal inset, 14vp icon, and 15vp icon gap. This
keeps the Android geometry explicit and unit-testable.

### Page structure

Replace the 210vp `GradientTitleBar` plus Account section with a page-private
56vp gradient title and the divider. Keep the item loop driven by
`visibleMeItems`; it currently renders only Version, matching Android. Use a
white full-size page and a Scroll for the row area.

### Row structure

Keep the existing `openItem()` and share/navigation services intact so hidden
catalog entries remain implementation-ready. Render the visible row without a
card shell: icon, label, trailing version, and a chevron only for genuinely
navigable rows. The Version item remains non-navigable and has no chevron.

### Behavior retained

- bundle-derived `V<versionName>` text and fallback;
- hidden Share, QR, web, and privacy catalog definitions;
- native share, QR page, Harmony web page, and privacy destinations;
- existing localization and bottom-tab routing.

## Excluded work

- no change to `visibleByDefault` flags;
- no re-exposure of Android-hidden rows;
- no College `GradientTitleBar` change;
- no device-only font-metric or density validation.

## Verification

- TDD the pure Android Me geometry constants;
- retain Me catalog, navigation, icon, version, share, and web-route tests;
- run full Hypium and read the exact result file;
- run `git diff --check` and unified HAP/AI acceptance;
- obtain independent review before fast-forwarding to master.
