# Still Scene Detection Android Layout and State Parity Design

## Context

Android preserves `/hms/SenceDetectionStillAnalyseActivity` as a dedicated
compatibility page even though its default Vision entry is hidden and the
visible icon routes to Dance. The page is white, with a title-only toolbar and
divider, a gray 376dp preview frame containing a centered 266x356 image or an
`icon_style` prompt, a Photo/Camera/Real-time row, and a remaining-height
scrollable text result. Its declared 80dp progress view stays invisible.

HarmonyOS already preserves the route, local Places365 MindSpore Lite model,
localized labels, photo/camera auto-run, permissions, request-generation
gates, and linked live-scene route. Still scene is the last registered workflow
that falls through to the generic runtime cards.

## Goal

Replace the final generic workflow surface with the Android-shaped still-scene
page while reusing the existing local model/runtime and matching Android's
visible input, result replacement, cancellation, and failure semantics.

## Non-Goals

- No new model, label set, SDK, service, route, dependency, permission, string,
  or media asset.
- No change to live scene detection, scene model preprocessing/postprocessing,
  label localization, or the hidden/default navigation inventory.
- No emulation of Android's obsolete external-storage/file-provider details.
- No visible loading indicator: Android declares one but never toggles it.
- No device validation claim for layout, picker/camera feel, accuracy, latency,
  memory, or lifecycle behavior.

## Chosen Architecture

Keep `FeatureRuntimePage` as the sole controller. Add an exact route selector,
small pure text-state/feedback policies, and a dedicated builder before the
generic fallback. Continue using `resultRows` as the structured single source
of truth, but create exact Android still rows from the successful
`SceneDetectionResult`: one scene-count row followed by separate Scene and
Score rows for every candidate. Do not expose image-path, execution-time,
summary, permission, debug, or status cards.

## Route And State Policies

Add these pure catalog policies:

- `usesAndroidStillSceneLayout(workflow)` is true only for
  `AppRoute.SCENE_STILL`.
- `stillSceneResultToastKey(workflow, resultCode)` returns the existing
  `feature_runtime_scene_failed` key only for a still-scene empty-result code.
  It returns no Toast for the distinct scene-runtime-failure code.
- `shouldPreserveRuntimeTextResultOnAiResult(workflow, resultOk)` is true only
  for failed still-scene results. It is also used by the permission and thrown
  failure paths to keep the last successful text in the absence of a generic
  status card.
- Still-scene photo and camera inputs preserve the previous result rows/text
  when a new input becomes ready.
- Still-scene run start does not clear the previous result. A successful result
  replaces it; an ordinary failed result, permission denial, or thrown run
  preserves it.
- Running still-scene photo/camera input changes are rejected by the shared
  input policy as well as disabled in the dedicated builder, so delayed or
  programmatic callbacks cannot replace an in-flight input.

The selector, Toast, and text-preservation policies remain false for live
scene detection, still/live segmentation, Style Transfer, and every sibling
route.

## Dedicated Page

Render a full-height white `Stack` containing the page and the existing
full-page permission-recovery overlay:

1. Reuse the 56vp title-only Android toolbar and add a 1vp divider.
2. Render a full-width 376vp `#E6E6E6` centered preview frame. When an input exists,
   render `imageInputUri` at exactly 266x356vp with `ImageFit.Fill`, matching
   Android `fitXY`, and 10vp effective frame space. Otherwise center the
   existing `icon_style` at its Android intrinsic size of approximately
   69.33x56.33vp above the localized
   `workflow_summary_scene_still_android_prompt` at 16fp with 10vp spacing.
3. Render a 37vp row with 14vp top margin in exact Photo, Camera, Real-time
   order. Match the XML margins exactly: Photo uses 20/5vp, Camera 5/5vp, and
   Real-time 5/5vp. Use the Android idle colors `#F4F3F8`/`#666666` and 5vp
   radius. Reuse `prepareInput('photo')`, `prepareInput('camera')`, and the
   existing linked live route.
4. Render the remaining height as a vertically scrollable, margin-20vp result
   area with 14vp top margin. Render the exact still-scene rows: localized
   Scene Count, then localized Scene and Score on separate lines for every
   candidate. Format each score as a percent with at most two fractional digits
   (`50%`, `74.1%`, `74.12%`), matching Android `NumberFormat` for the
   project's Chinese and English locales. Do not show the model image path or
   execution time.

Photo, Camera, and Real-time are visibly disabled while a run is active. The
existing picker guard remains authoritative, and a route-only live wrapper
defensively rejects delayed/programmatic navigation while running.

## Result And Failure Flow

- An accepted input updates the preview immediately and auto-runs the existing
  local Places365 workflow while retaining the previous text result.
- A cancelled picker preserves both preview and result. With no prior preview,
  the prompt remains visible; with a prior preview, the prior image remains.
- A successful non-empty scene result atomically replaces `resultRows` and the
  dedicated scroll area. The service returns localized labels and numeric
  scores; the still-row adapter owns the Android percentage formatting.
- A successful analyzer call with no scenes preserves the previous text and
  shows the existing scene-failed Toast, matching Android's `displayFailure()`
  visible behavior.
- A thrown analyzer/runtime failure preserves the previous text and remains
  silent, matching Android's failure listener, which records values but shows
  no UI. The scene service/runner result therefore carries an explicit
  empty-versus-runtime failure kind, and `AiService` maps those to distinct
  result codes without adding a new user-visible string.
- Permission denial preserves the previous text and preview while the
  full-page recovery overlay supplies retry/settings actions.
- No scene result is mirrored into the live overlay state because the existing
  `updateSceneOverlay` remains live-only.

## Verification

- Hypium tests cover the exact selector, empty-only Toast, scene failure
  provenance through runner/service/`AiService`, Android-shaped result rows,
  input-ready preservation, running input rejection, no-clear-at-start policy,
  failed text preservation, successful replacement policy, and sibling
  negatives.
- A fail-closed PowerShell guard verifies the exact layout hierarchy/dimensions,
  prompt, button order/margins, running guards, filtered result area, permission
  overlay, result/failure call sites, and top-level selection before fallback.
- Mutation fixtures reject comment/string decoys, wrong routes, wrong
  dimensions/order, loading indicators, generic cards, collapsed Scene/Score
  rows, missing failure provenance/preservation, wrong Toast behavior, missing
  input/live guards, and absent build wiring.
- Existing scene model/label, live scene, input, permission, route, i18n,
  Style Transfer, segmentation, and package tests remain green.
- Fresh Hypium and unified acceptance pass in an isolated worktree and again on
  merged `master`; main and `ohosTest` HAP structures remain verified.
