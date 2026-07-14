# Experience Grid Android Layout Parity Implementation Plan

**Goal:** Replace the Harmony Experience page's single-column cards with the
Android two-column Flow geometry without changing its data or navigation.

**Architecture:** A pure layout spec supplies testable Android constants and
the Grid height. `ExperiencePage` owns only page-specific group/section
geometry, while `FeatureCard` retains the existing click contract.

## Task 1: Lock the Android grid contract in RED

**Files:**

- Modify: `Mindspore_inhand_HarmonyOS/entry/src/test/LocalUnit.test.ets`

Import the missing layout spec and require two columns, 50vp cards, 17vp row
gaps, and exact heights for zero through five items. Run Hypium and record the
expected missing-export compile failure.

## Task 2: Add the pure layout specification

**Files:**

- Add: `Mindspore_inhand_HarmonyOS/entry/src/main/ets/common/data/ExperienceLayoutSpec.ets`

Export the Android constants and a clamped `experienceGridHeightVp()` helper.
Keep the module free of ArkUI dependencies.

## Task 3: Port the Android page geometry

**Files:**

- Modify: `Mindspore_inhand_HarmonyOS/entry/src/main/ets/pages/ExperiencePage.ets`

Replace the single-column card list with a non-scrollable two-column Grid,
explicit calculated height, Android side/row/column spacing, and stable item
keys. Replace the current flanking-line group title with top/bottom dividers.
Add a private compact section-title builder matching Android's 3x12 marker and
13fp bold label. Preserve the existing catalog loop and navigation callback.

## Task 4: Match Android card geometry

**Files:**

- Modify: `Mindspore_inhand_HarmonyOS/entry/src/main/ets/common/components/FeatureCard.ets`

Set the card to 50vp, compact the Android media icon and label spacing, use
12fp single-line text, and retain the 1vp rounded gray outline and existing
action API. Do not change icon lookup or feature data.

## Task 5: Verify and integrate

Run full `hvigorw test --no-daemon`, read the exact result count, run
`git diff --check`, and run unified HAP/AI acceptance. Obtain independent
review, fix findings, fast-forward into `master`, repeat master verification,
then remove the worktree and branch.

