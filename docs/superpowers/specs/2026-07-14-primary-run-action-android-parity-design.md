# Android Primary Run Action Parity Design

Date: 2026-07-14
Status: approved by delegated execution authority

## Problem

`FeatureRuntimePage` renders its primary action through
`shouldShowPrimaryRunAction()`. The current policy hides the action only for
camera-only live workflows, so every other workflow receives a generic Run
button.

That is broader than Android's reachable UI. Android exposes a manual primary
action only for:

- PoseNet: Detect
- Text Translation: Translate
- Custom Model: Execute

Android's still Gesture, Segmentation, Scene Detection, Text Recognition, and
Object Photo pages run after an input is selected. Style Transfer runs after a
style becomes ready. Their HarmonyOS equivalents already implement those
automatic triggers, so their extra Run button is redundant and breaks 1:1 UI
parity.

## Constraints

- Preserve all 16 workflow routes and their input controls.
- Preserve camera-only live startup.
- Preserve still-image auto-run behavior and Object Photo's initial picker.
- Preserve Style Transfer's style-ready auto-run behavior.
- Preserve manual actions for PoseNet, Text Translation, and Custom Model.
- Do not change AI services, permissions, model assets, navigation, or result
  rendering.
- Do not add a feature flag, dependency, or per-workflow schema field.
- Device execution remains outside this increment.

## Options Considered

### A. Explicit manual-action route allowlist

Return `true` only for PoseNet, Text Translation, and Custom Model.

This is selected. It directly encodes Android's reachable contract and fails
closed when a future route is added.

### B. Denylist every automatic route

This preserves the current default but requires every future automatic route
to remember to opt out. It is more fragile than the Android contract.

### C. Add a `showPrimaryRunAction` workflow field

This makes the catalog verbose and duplicates a policy used in only one place.
It is unnecessary for the current fixed route set.

## Design

`shouldShowPrimaryRunAction()` will compare `workflow.routeName` with the three
Android manual-action routes. `undefined` and the remaining 13 routes return
`false`.

The page builder remains unchanged and continues to use that policy. No
automatic-run helper changes are needed.

The host test will cover every entry in `featureWorkflows`, plus `undefined`,
so a new route cannot silently inherit a Run action. Documentation will state
that both live and automatic still workflows omit the generic action, while
the shared execution guard still protects manual and automatic triggers.

## Acceptance

- PoseNet, Text Translation, and Custom Model return `true`.
- The other 13 current workflows and `undefined` return `false`.
- Existing auto-run tests remain unchanged and pass.
- Complete Hypium host tests pass.
- Unified HAP acceptance builds and verifies main and ohosTest HAPs.
- No device-functionality claim is made.
