# Object Photo Input Surface Android Parity Design

## Context

Android `ObjectPhotoActivity` opens the album picker during `onCreate()` and its
layout exposes only the Select Model button after the picker returns. There is
no second Photo action in `activity_object_photo.xml`.

HarmonyOS already matches the startup behavior through
`initialInputKindForWorkflow(ObjectPhoto) === 'photo'`, including immediate
detection and leaving the page when the initial pick is cancelled. The shared
input surface still renders Photo plus Select Model, however, so it exposes an
Android-incompatible re-pick action.

The previous live-camera parity increment established a pure distinction
between runtime inputs and user-visible input chips. Object Photo is the same
policy shape: `photo` remains a required runtime input, but it is implicitly
prepared during route entry and should not also be rendered as a chip.

## Decision

Extend `visibleInputKindsForWorkflow(workflow)` so the hidden implicit input is:

1. `autoStartInputKindForWorkflow(workflow)`, when present; otherwise
2. `initialInputKindForWorkflow(workflow)`, when present.

The existing Portrait `backgroundImage` grid exclusion remains unchanged.

For Object Photo this changes the visible list from `['photo', 'modelFile']` to
exactly `['modelFile']`, while preserving:

- catalog/runtime `photo`;
- initial album picker `photo`;
- immediate object detection after selection;
- Select Model;
- cancellation/back and keep-screen-on behavior.

No page change is required because `FeatureRuntimePage` already renders the
shared visible-input helper.

## Regression Contract

Hypium will assert the complete Object Photo input surface:

- runtime inputs are exactly `['photo', 'modelFile']`;
- initial input is `photo`;
- auto-start input is undefined;
- visible inputs are exactly `['modelFile']`.

It will also retain the exact seven live-route matrix and the still Photo/Camera
matrix from the previous increment, ensuring the generalized implicit-input
rule does not regress live or ordinary still workflows.

## Scope

In scope:

- Extend the pure visible-input policy.
- Add the exact Object Photo regression contract.
- Align platform-parity documentation.

Out of scope:

- Picker, model cache, inference, cancellation, or page lifecycle changes.
- Adding a new Android Object Photo re-pick control.
- Style Transfer input order/custom-style chip parity.
- Device/emulator validation.

## Acceptance

- Test-only RED proves Object Photo still exposes Photo.
- GREEN produces the exact runtime/initial/visible contract.
- Full Hypium has zero failures/errors.
- Unified acceptance passes both native contracts and both HAPs.
- No device behavior is claimed.
