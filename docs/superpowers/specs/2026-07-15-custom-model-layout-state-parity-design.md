# Custom Model Layout and State Android Parity Design

## Goal

Replace the generic HarmonyOS Custom Model runtime surface with Android's
dedicated page and visible state transitions while preserving the existing
real MindSpore Lite model cache, compatibility validation, preprocessing, and
inference implementation.

The Android executor is UI-only and returns simulated output. HarmonyOS keeps
its stricter real-model contract: one NHWC float32 input shaped
`[1, 224, 224, 3]`, RGB normalized to `[0, 1]`, and a non-empty float32 first
output tensor. General arbitrary-model shape/dtype support is not part of this
layout migration.

## Approaches considered

1. Add Custom Model conditions throughout the generic Scroll/Card builder.
   This scatters route checks across header, input, preview, permission, run,
   and result sections.
2. Add one Custom Model-only builder in `FeatureRuntimePage`. This is selected:
   it reuses the current page state and services but gives the route one clear
   Android-shaped presentation boundary.
3. Add a new page and route. This would duplicate picker, cache, permission,
   help, request-generation, and inference-session logic.

## Page structure

Add `usesAndroidCustomModelLayout()` scoped only to `AppRoute.CUSTOM_MODEL` and
select `customModelAndroidLayout()` before the generic fallback.

The page contains, in order:

- the existing 56vp toolbar with Back, Help, and More actions enabled;
- one 1vp divider;
- a 14vp top margin and three equal 37vp buttons: Select Model, Select Photo,
  Take Photo;
- no image container before an image is selected;
- after image selection, a 265vp gray container with a centered 256vp image;
- an 80vp loading indicator centered over the image while inference runs;
- a full-width 40vp Execute button with 20vp side margins and 14vp top margin;
- a white output panel filling the remaining height, with 20vp side/bottom
  margins, a bold Output Result title, and a gray scrollable text surface.

The dedicated branch does not render generic summary, input chips, model-file
preview, permission card, URI/status metadata, result rows, or debug/save UI.
It keeps the focused runtime permission recovery overlay for an actual
permission/capability failure.

Model, Photo, and Camera buttons are disabled while inference is running so a
new input cannot invalidate the visible run. Execute remains clickable to
produce Android's already-running feedback.

## Input and model state

Model selection continues to use the existing `.ms` picker, cache filename,
compatibility check, and last-valid-model preservation. A current successful
selection shows the existing model-ready Toast. Cache or compatibility
failure shows its existing localized failure Toast. Cancellation is silent.

Successful model, photo, or camera selection preserves the current output
text, matching Android. Cancelled and failed selections also leave the last
output and last valid model intact. Selecting a new image replaces only the
preview input.

Custom Model does not silently restore a cached model into a newly created
page/session. The cache file may remain for development convenience, but the
user must explicitly select a model after entering the route, matching the
Android Activity lifecycle. Other model-backed routes keep their restoration
behavior.

Custom Model uses system camera/photo/model pickers and does not request the
workflow's broad camera/media permission set when Execute is pressed. Implement
this by changing only the Custom Model workflow's `requiredPermissions` to
`[]`; `runWorkflow()` and every sibling workflow keep their existing permission
path. The system photo and camera pickers own their capability UI. A focused
catalog test must prove Custom Model has no workflow permission request while
sibling routes retain their current permissions.

## Execute preflight and Toasts

The Custom Model Execute handler performs this pure, route-scoped preflight
before `PermissionService` or `AiService`:

1. no image: Toast `feature_runtime_custom_model_image_required`;
2. no selected model: Toast `feature_runtime_custom_model_model_required`;
3. run already active: Toast `feature_runtime_custom_model_already_running`;
4. otherwise call the existing `runWorkflow()`.

Preflight failure does not change the output text. New model-picker Toasts
and run-result changes continue to respect existing request-generation checks;
cancelled or stale operations must not show late feedback.

## Output resolver

The output text surface uses one deterministic state order:

- initial or input-ready with no previous result: the existing output
  placeholder;
- running: `feature_runtime_custom_model_running_output`;
- successful result: the existing `resultText`, which already contains the
  Android completion text, execution time, first ten values, and overflow
  note;
- failed result or runtime exception:
  `feature_runtime_custom_model_failure_output`;
- permission denial: the localized permission-denied text, with recovery
  actions supplied by the overlay;
- after a later model/image pick: retain the previous success or failure
  output instead of replacing it with input-ready metadata.

Only a successful summary or localized inference/runtime failure text is a
persistent terminal output. On a Custom Model result failure or runtime
exception, the page stores the localized failure-output text in its existing
`resultText` state. Permission denial, picker-ready/cancel metadata, and
preflight Toasts do not write persistent `resultText`; specifically, the
Custom Model permission-denied branch must not store the requested-permission
name list used by generic routes. A later successful pick therefore preserves
terminal success/failure output, while a pick after permission denial returns
to the placeholder. Raw model/image diagnostic paths are never surfaced.

The output resolver order is fixed as: running, permission denial, non-empty
persistent terminal `resultText`, then placeholder.

Add these exact localized keys in base, `zh_CN`, and `en_US`:

- `feature_runtime_custom_model_execute`: `执行` / `Execute`;
- `feature_runtime_custom_model_running_output`:
  `模型正在执行...\n\n正在对所选图片运行推理...` /
  `Model execution in progress...\n\nRunning inference on selected image...`;
- `feature_runtime_custom_model_already_running`:
  `模型已在运行。` / `Model is already running.`;
- `feature_runtime_custom_model_failure_output`:
  `模型执行失败！\n\n错误：未能获得推理结果` /
  `Model execution failed!\n\nError: Failed to get inference result`.

Android's successful output is hard-coded English in the reference Activity,
so this increment keeps the already equivalent `resultText` format instead of
introducing a second formatter.

## Verification

- Hypium exhaustively tests the Custom Model-only selector across all 16
  workflows and `undefined`.
- Pure policy tests cover preflight ordering, output state resolution, output
  preservation for all three Custom Model inputs, no session restore, and
  unaffected sibling routes.
- Catalog tests prove Custom Model has `requiredPermissions=[]` so Execute does
  not request broad camera/media permissions; sibling permission contracts are
  unchanged.
- Existing service tests continue to cover image/model requirements, cache
  compatibility, inference failure, execution time, and the first ten values.
- A dependency-free PowerShell guard checks the dedicated build branch,
  toolbar actions, divider, action order and geometry, preview visibility and
  dimensions, loading indicator, always-clickable Execute action, output
  surface, generic-UI exclusions, model-picker Toast call sites, preflight
  before `runWorkflow()`, and executable `build-hap.ps1` wiring.
- Guard mutation checks must reject a widened selector, reordered actions,
  an always-visible empty preview, disabled Execute, generic status/model
  preview return, and a commented build invocation.
- Complete Hypium, unified AI runtime HAP acceptance, and `git diff --check`
  must pass before and after merge.

## Deferred device checks

Real-device work remains limited to system picker/camera presentation, image
fit, progress animation, Toast appearance, and real compatible `.ms` inference
performance. Supporting arbitrary model shapes, dtypes, layouts, multiple
inputs, or multiple outputs requires a separate model-contract design.
