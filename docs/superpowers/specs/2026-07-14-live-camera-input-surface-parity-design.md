# Live Camera Input Surface Android Parity Design

## Context

Seven Android live-camera activities start their preview as part of page startup
and do not expose a separate action that starts the camera again:

- live skeleton analysis;
- live image segmentation;
- portrait segmentation;
- live image classification;
- live hand gesture analysis;
- live scene detection;
- object camera detection.

HarmonyOS already auto-starts the same seven routes, but the shared runtime page
also renders their catalog `camera` input as a Camera chip. Pressing the extra
chip clears the current result/overlay and restarts preview, so it is both a UI
parity gap and an avoidable interruption to the live result stream.

The catalog must keep `camera` as a runtime input: it drives permission,
auto-start, resume, and service selection. The fix therefore needs a separate
user-visible input policy rather than deleting the runtime input.

## Decision

Add `visibleInputKindsForWorkflow(workflow)` beside the existing workflow input
helpers. It starts from `runtimeInputKindsForWorkflow(workflow)` and removes:

1. the input returned by `autoStartInputKindForWorkflow(workflow)`; and
2. Portrait's `backgroundImage`, because that input is already represented by
   the dedicated Android-style background grid.

The shared runtime page will use this helper for input chips. It will render the
Inputs heading and chip Flex only when at least one visible input exists, so the
camera-only live pages do not retain an empty input header.

This produces the intended live surfaces:

- Live Skeleton, Segmentation Live, Portrait, Image Camera, Gesture Live, and
  Scene Live: no input chips.
- Object Camera: only Select Model (`modelFile`).

Still routes continue to show their Photo/Camera inputs. Portrait continues to
show its background grid. All seven routes continue to keep `camera` in their
runtime catalog and continue auto-starting preview.

## Regression Contract

Hypium will use an exact seven-route matrix. For every route it will prove:

- runtime inputs still include `camera`;
- auto-start remains `camera`;
- visible inputs exclude `camera`;
- the visible list is exact (empty except Object Camera=`modelFile`).

Additional assertions keep PoseNet, Segmentation Still, Gesture Still, and Scene
Still at exact visible inputs `photo,camera`, and keep Portrait's dedicated
background input out of the chip surface.

## Scope

In scope:

- Add the pure visible-input helper.
- Use it for the runtime page's chip surface and suppress an empty heading.
- Add exact unit contracts and align the platform-parity documentation.

Out of scope:

- Changing camera startup, frame processing, permissions, resume, or switching.
- Changing model selection or portrait/style grids.
- Device/emulator validation.
- The separate Object Photo and Style Transfer input-surface gaps.

## Acceptance

- Focused Hypium RED demonstrates the seven live Camera chips are currently
  exposed; GREEN proves the exact visible matrix.
- Full Hypium has zero failures/errors.
- Unified acceptance passes the main HAP, both native contracts, ohosTest HAP,
  and dual-HAP structure verification.
- No device behavior is claimed.
