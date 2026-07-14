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
gaps, 18vp side insets, 8vp column gaps, and exact heights
`0/50/50/117/117/184` for zero through five items. Also clamp a negative item
count to zero. Run Hypium and record the expected missing-export compile
failure.

## Task 2: Add the pure layout specification

**Files:**

- Add: `Mindspore_inhand_HarmonyOS/entry/src/main/ets/common/data/ExperienceLayoutSpec.ets`

Export the Android constants and a clamped `experienceGridHeightVp()` helper
using `rows = ceil(max(0, itemCount) / 2)` and
`rows * 50 + (rows - 1) * 17`, with zero rows returning zero. Keep the module
free of ArkUI dependencies.

## Task 3: Port the Android page geometry

**Files:**

- Modify: `Mindspore_inhand_HarmonyOS/entry/src/main/ets/pages/ExperiencePage.ets`

Keep `ExperienceHeader` fixed outside the content Scroll and use a white page
with 30vp top/bottom content padding. Replace the single-column card list with
a non-scrollable `1fr 1fr` Grid, explicit calculated height, 18vp side insets,
8vp column gap, 17vp row gap, and stable item keys. Replace the current
flanking-line group title with native ArkUI 2vp `#66000000` dashed top/bottom
lines, a centered 16fp label with 8vp vertical margins, and 24vp spacing after
a previous Grid. Add a private compact section-title builder matching Android's
x=18/top=23 3x12 `#6189FF` marker, x=28/top=20 13fp bold label, and 15vp Grid
offset. Preserve the existing catalog loop and navigation callback.

## Task 4: Match Android card geometry

**Files:**

- Modify: `Mindspore_inhand_HarmonyOS/entry/src/main/ets/common/components/FeatureCard.ets`

Set the card to 50vp, use a 28x22vp Contain icon, 5vp icon/label gap, 4vp
horizontal padding, 12fp single-line text, and a 1vp `#E6E6E6` outline with
5vp radius. Use normal-weight `#333333` label text. Keep the transparent/white
default and existing action API. Do not change icon lookup or feature data.
Omit Android's pressed fill/radius until a simple, reliable ArkUI state style
is verified.

## Task 5: Verify and integrate

Run full `hvigorw test --no-daemon`, read the exact result count, run
`git diff --check`, and run unified HAP/AI acceptance. Obtain independent
review, fix findings, fast-forward into `master`, repeat master verification,
then remove the worktree and branch.
