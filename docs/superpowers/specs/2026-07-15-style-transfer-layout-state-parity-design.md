# Style Transfer Android Layout and State Parity Design

## Context

Android's reachable `/styletransfer/StyleMainActivity` uses a dedicated page,
not a generic AI form. `activity_main_style.xml` contains a white action bar, a
1dp divider, a fixed 265dp gray preview with a centered 256dp image or empty
prompt and an 80dp loading indicator, a four-action row for Album, Camera,
Recovery, and Save, a two-action row for predict and transfer model files, and
a four-column grid containing `style0` through `style18` plus one custom-style
tile.

HarmonyOS already has the functional pieces: album and camera content input,
the 19+1 style grid, automatic inference after style selection, a real local
MindSpore Lite pipeline, atomic fixed-slot model caching, model restoration,
Recovery state, an app-owned styled `PixelMap`, Gallery saving through a secure
`SaveButton`, local Help, and the Android More URL. The remaining default-route
mismatch is that Style Transfer still renders through the generic runtime
summary/input/permission/status/result cards.

## Goal

Give Style Transfer a dedicated Android-shaped HarmonyOS surface and close the
visible terminal/model-reload state gaps without replacing or duplicating its
existing runtime, picker, cache, inference, grid, or save services.

## Non-Goals

- No new model, preprocessor, decoder, picker, cache, or save implementation.
- No new dependency, page route, or string resource.
- No Android APK update/download-new-version behavior.
- No changes to Object Photo, Object Camera, Custom Model, segmentation, or
  scene routes.
- No claim that rendering, secure SaveButton presentation, picker/camera feel,
  model accuracy, latency, memory, or lifecycle behavior was verified on a
  device.

## Chosen Architecture

Add one exact route predicate and one dedicated builder to the existing
`FeatureRuntimePage`. This keeps the current request-generation, stale-result,
model-cache, inference-session, `PixelMap` ownership, permission-recovery, and
page lifecycle paths as the single source of truth.

Creating a separate page/controller was rejected because it would duplicate
the highest-risk state paths. Restyling the generic fallback was rejected
because it would retain UI that Android never renders.

## Route And Feedback Policies

Add these pure catalog policies:

- `usesAndroidStyleTransferLayout(workflow)` is true only for
  `AppRoute.STYLE_TRANSFER`.
- `styleTransferResultToastKey(workflow, resultOk)` returns the existing
  `feature_runtime_style_transfer_failed` key only for failed Style Transfer
  runs.
- `styleTransferModelCacheToastKey(workflow, inputKind, messageKey)` returns
  the supplied model-cache message only for Style Transfer predict/transfer
  model inputs.
- `shouldResetStyleTransferPageAfterModelCacheResult(workflow, inputKind,
  resultOk)` is true only for successful Style Transfer predict/transfer model
  cache results.
- Style Transfer content, camera, and style-image inputs preserve the last
  styled `PixelMap` after a successful pick. Content and camera picks switch
  the visible preview to the new original; a style-image pick leaves the
  currently visible preview in place until the new run succeeds.
- Style Transfer predict/transfer model inputs also preserve the current page
  while cache work is cancelled, incompatible, failed, undefined, or stale.
  The successful cache path performs its explicit recreate-style reset only
  after the stale gate and compatible atomic publish.
- Style Transfer does not clear its visual result at run start, on a failed AI
  result, on the successful AI result before its `PixelMap` replacement is
  ready, on permission failure, or on a thrown run. The existing
  portrait-segmentation preservation behavior remains unchanged.

The selector and Toast/reset policies remain negative for sibling routes,
unrelated input kinds, successful inference Toasts, and failed cache resets.
The preservation policies use the explicit positives above.

## Dedicated Page

The page is a full-height white `Stack` containing the Android-shaped `Column`
and the existing `runtimePermissionRecoveryOverlay`, so permission denial does
not lose its recovery path when the generic Permissions card is absent:

1. Reuse the existing 56vp Android action toolbar with Back, localized title,
   Help, and More, followed by a 1vp divider.
2. Render a 265vp gray preview. The centered visible image is the styled
   `PixelMap` after success, the original content image before inference or
   after Recovery, or the existing style icon plus choose-image prompt when no
   content is ready. Show the existing 80vp `LoadingProgress` over the preview
   while inference is running.
3. Render Android's first 37vp action row in this exact order: Album, Camera,
   Recovery, Save. Album and Camera reuse `prepareInput`; Recovery reuses the
   existing original-preview state. Save remains an always-visible HarmonyOS
   secure `SaveButton` in the Android position.
4. Render a second 37vp row for Select Predict Model and Select Transfer Model.
5. Render the existing localized Choose a Style title and existing 19+1 grid
   in four columns with Android-equivalent 20vp outer margins and 10vp gaps.
   The grid consumes the remaining height and scrolls vertically, so all five
   rows remain reachable on short screens.

All input and style-selection actions are disabled or rejected by the existing
non-live runtime guard while a transfer is running. Recovery and the secure
SaveButton are also visibly disabled and defensively rejected in their
handlers while `workflowRunning`; this covers programmatic or delayed clicks,
not only the rendered control state. The dedicated builder contains no generic
summary, Inputs, Permissions, status/result row, debug, file-preview, separate
styled-result, or generic Run cards.

## State And Error Flow

- Content selection updates the original preview without auto-running and
  retains the previous styled `PixelMap` as the Save target, matching
  Android's separate `originBitmap` and `resultBitmap` fields. Every accepted
  content, camera, or style pick first invalidates any pending styled-image
  replacement without releasing the current owner value, so an older async
  conversion cannot overwrite the newly selected page state.
- Built-in or custom style selection retains the existing content-required
  guard and automatically starts the existing Style Transfer pipeline. The
  visible preview remains stable while that asynchronous run is pending.
- Successful inference displays the styled `PixelMap`; Recovery displays the
  original again without destroying the last styled `PixelMap`, so Save still
  saves the last generated result like Android's separate `originBitmap` and
  `resultBitmap`. A successful AI result preserves the old preview and Save
  target while the new RGBA output is converted. The run remains
  `workflowRunning` until conversion settles; only a current owner request may
  atomically accept the new `PixelMap` and release the old one.
- Failed results and thrown runs show the existing localized Style Transfer
  failure Toast because the generic status card is no longer visible. Neither
  path clears the visible preview or the last styled Save target: after a new
  content pick this leaves the new original visible, while after a new style
  pick it leaves whichever original or styled preview was already visible.
- Invalid output dimensions/bytes or a rejected `PixelMap` conversion follow
  the same failed-run status and Toast path, invalidate the pending owner
  request, preserve the prior preview/Save target, and settle before
  `workflowRunning` becomes false. A stale conversion releases its newly
  created map and produces no user feedback.
- Permission failure preserves the previous preview/Save target while the
  full-page permission-recovery overlay presents retry/settings actions.
- Recovery without an original image shows the existing original-required
  Toast. Recovery is a no-op while a transfer is running.
- Save invokes the current `ResultImageSaveService` and surfaces its existing
  missing/success/failure message as a Toast through a Style-Transfer-only
  wrapper; the shared segmentation save path gains no Toast. A denied secure
  SaveButton click immediately maps to the existing save-failed Toast. Save is
  a no-op while a transfer is running.
- Predict/transfer model cache results show their existing slot-specific
  success/failure Toast.
- After a successful compatible model is atomically published and the stale
  request check has passed, retain both model URIs, discard the current
  inference session, and reset `imageInputUri`, `contentImageUri`,
  `styleImageUri`, selected-input summary, styled result, preview-recovery
  flag, result rows, and status back to the workflow's initial value. This
  matches Android's `recreate()` page reset. Cancelled, incompatible, failed,
  undefined, or stale model work preserves the current page, session, visible
  preview, Save target, and last stable cache.

## Verification

- Hypium tests cover the exact Style Transfer selector, result Toast, model
  cache Toast, successful-reset policy, original-preview switching, old-result
  preservation, and run-start/failure/success-before-replacement preservation
  with sibling-route, model-kind, and data-kind negatives.
- A dependency-free PowerShell guard bounds the dedicated builder and critical
  result/cache/save/recovery call sites, rejects generic cards, checks exact
  layout/order, full-page permission recovery, remaining-height scrolling,
  running guards, permission/result/conversion preservation, pending-owner
  invalidation, route-scoped Toasts, and top-level build wiring.
- Mutation fixtures prove comments, template raw text, quoted strings, wrong
  selectors, stale-gate decoys, and executable generic-card injections cannot
  make the guard pass.
- Existing Style Transfer grid, auto-run, recovery, cache, save-service, local
  model, Custom Model, Object Photo, and i18n tests remain green.
- Fresh Hypium and unified acceptance must pass in the feature worktree and
  again on merged `master`; main and `ohosTest` HAP payloads remain verified.
