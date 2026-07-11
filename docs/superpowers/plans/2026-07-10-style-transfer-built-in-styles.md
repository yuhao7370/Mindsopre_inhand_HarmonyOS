# Style Transfer Built-In Styles Plan

> Correction (2026-07-12): Android ships `style19.jpg` and `style20.jpg`,
> but `StyleMainActivity.IMAGES` exposes only `style0` through `style18` plus
> `icon_default` as the add/custom-style tile. HarmonyOS was realigned to that
> visible Android preset list after this historical plan.

## Goal

Restore Android's full built-in style image set in the HarmonyOS Style Transfer flow. The Android `styletransfer` module ships `style0.jpg` through `style20.jpg`; HarmonyOS currently exposes only `style0.jpg` through `style18.jpg`.

## Constraints

- Keep the existing Style Transfer page and runner behavior.
- Do not add dependencies or change model execution.
- Preserve i18n/resource structure; style thumbnails are image assets, not strings.
- Keep the project buildable after the slice.

## Steps

1. Update the existing Style Transfer unit test to expect 21 built-in styles and the `style20.jpg` rawfile URI.
2. Verify the test fails before implementation.
3. Copy `style19.jpg` and `style20.jpg` from the Android source into HarmonyOS `base/media` and `rawfile/styletransfer`.
4. Extend `builtInStyleTransferStyles` and `builtInStyleTransferStyleCount` to include ids 19 and 20.
5. Run unit tests, HAP build, static checks, and whitespace check.
6. Request focused code review, fix any Important/Critical findings, then commit.
