# Runtime Detail Summary Visibility Implementation Plan

**Goal:** Hide raw `detailText` summaries from the generic runtime UI without
changing any AI execution or structured result behavior.

**Architecture:** Remove one rendering block and make the existing build-time
debug UI guard reject its return. Keep `resultText` as internal state.

## Task 1: Lock the regression in RED

**Files:**

- Modify: `Mindspore_inhand_HarmonyOS/scripts/check-runtime-debug-ui.ps1`

Add a whitespace-tolerant forbidden pattern for a Text component bound directly
to `this.resultText`. Run the guard against the unchanged page and record the
expected failure.

## Task 2: Remove the raw visible summary

**Files:**

- Modify: `Mindspore_inhand_HarmonyOS/entry/src/main/ets/pages/FeatureRuntimePage.ets`
- Modify: `docs/harmonyos-platform-differences.md`

Delete only the generic fallback's final `if (this.resultText.length > 0)`
render block. Do not alter state, assignments, result projections, status,
visual controls, or specialized builders. Document that raw detail summaries
remain internal.

## Task 3: Verify and integrate

Run the debug guard, full `hvigorw test --no-daemon`, `git diff --check`, and
unified HAP/AI acceptance. Obtain independent review, fast-forward to master,
repeat master verification, then remove the worktree and branch.
