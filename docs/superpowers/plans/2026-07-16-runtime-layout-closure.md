# Runtime Layout Closure Implementation Plan

**Goal:** Make the completed 16-workflow Android layout migration fail closed
when a registered workflow loses its dedicated layout, overlaps a sibling
layout, or invokes the wrong builder.

**Architecture:** Add an exhaustive Hypium selector-union assertion and a
qualified source guard for the `FeatureRuntimePage.build()` selector-to-builder
chain. Keep production ArkTS unchanged.

## Task 1: Define the exhaustive selector-union contract

**File:**

- Modify `Mindspore_inhand_HarmonyOS/entry/src/test/LocalUnit.test.ets`

Add a deliberately incomplete aggregate match-count assertion and run Hypium
to record RED. Complete it with all ten boolean selectors, both specialized
live values, and simple-live. Assert 16 registered workflows, exactly one match
per workflow, and zero matches for `undefined`.

Commit as `test: close registered workflow layout union`.

## Task 2: Qualify the structural guard in RED

**Files:**

- Add `Mindspore_inhand_HarmonyOS/scripts/check-runtime-layout-closure.ps1`
- Add `Mindspore_inhand_HarmonyOS/scripts/test-runtime-layout-closure-guard.ps1`

Write the mutation suite first. The valid fixture contains the exact 13-branch
`build()` chain and a generic final `else`. Mutations cover missing, swapped,
changed, reordered, early-fallback, decoy, and missing-wiring cases. Run the
suite and record RED because the production guard does not exist.

## Task 3: Implement and wire the minimal guard

**Files:**

- Implement `check-runtime-layout-closure.ps1`
- Modify `Mindspore_inhand_HarmonyOS/scripts/build-hap.ps1`

Bound source inspection to the real `build()` method, remove comments and
quoted strings for decoy checks, require the exact selector/builder sequence,
and require the generic final branch. Inspect `build-hap.ps1` through its
PowerShell AST so only a top-level invocation counts as wiring.

Run the valid fixture, every mutation, the production guard, and PowerShell
parse checks. Commit as `test: guard runtime layout closure`.

## Task 4: Verify and integrate

Run full Hypium, `build-hap.ps1`, `build-ai-runtime-acceptance.ps1`,
`git diff --check`, and worktree cleanliness. Obtain an independent review,
repair any findings through guard-first mutations, fast-forward to `master`,
repeat master acceptance, and remove the feature worktree and branch.

Update `docs/harmonyos-platform-differences.md` only if verification reveals a
statement that is not already accurate; do not add redundant progress prose.
