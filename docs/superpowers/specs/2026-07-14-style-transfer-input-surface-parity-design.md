# Style Transfer Input Surface Android Parity Design

## Context

Android Style Transfer presents its top actions in this order: Album, Camera,
Recovery, Save. Predict/transfer model selectors follow on the next row. Style
selection is not a top action: nineteen built-in thumbnails are followed by one
custom-style add tile, and that final tile opens the style-image picker.

HarmonyOS has already ported the same 19+1 style grid and custom-style picker,
but the shared input chip list still exposes `styleImage` a second time. Its
current primary input order is Camera then original/content image, the reverse
of Android's Album then Camera order.

The runtime must retain `styleImage`: built-in styles and the custom add tile use
that input kind to update state and trigger inference. Only its duplicate chip
should disappear.

## Decision

1. Reorder the Style Transfer workflow's primary runtime inputs to
   `contentImage, camera, styleImage`, matching Android's Album→Camera surface
   without removing any capability.
2. Extend `visibleInputKindsForWorkflow()` to exclude `styleImage` only for the
   Style Transfer route, because the dedicated 19+1 grid is its visible UI.
3. Keep the optional predict and transfer model inputs visible and ordered after
   Album and Camera.

The exact visible input list becomes:

```text
contentImage, camera, stylePredictModelFile, styleTransferModelFile
```

The runtime list still includes `styleImage`; the grid, custom picker,
auto-run-after-style-ready, recovery, save, and model override behavior remain
unchanged. No page code change is required because it already renders the
shared visible-input helper and the separate style grid.

## Regression Contract

Hypium will assert:

- exact Style Transfer primary catalog order
  `contentImage,camera,styleImage`;
- exact full runtime order including both optional model files;
- exact visible order without `styleImage`;
- `styleImage` remains a supported runtime input and its existing auto-run/grid
  contracts remain green;
- Object Photo, live-camera, and still-route visibility matrices remain green.

## Scope

In scope:

- Reorder Style Transfer catalog inputs.
- Filter the duplicate style-image chip in the pure visibility policy.
- Add exact unit coverage and update the parity document.

Out of scope:

- Grid rendering, picker, inference, recovery, save, or model-cache changes.
- Layout pixel matching beyond input presence/order.
- Device/emulator validation.

## Acceptance

- Test-only RED proves the current Camera-first and duplicate-style surface.
- GREEN produces exact runtime and visible lists.
- Full Hypium has zero failures/errors.
- Unified acceptance passes both native contracts and both HAPs.
- No device behavior is claimed.
