# Me Page Android Layout Parity Implementation Plan

**Goal:** Replace the oversized Harmony Me header/card section with Android's
compact title and single visible Version row without changing feature data.

**Architecture:** A pure layout spec owns exact Android geometry. `MePage`
keeps all current service and navigation code but renders the visible catalog
inside an Android-shaped page-private shell.

## Task 1: Lock the Android geometry in RED

**Files:**

- Modify: `Mindspore_inhand_HarmonyOS/entry/src/test/LocalUnit.test.ets`

Import the missing Me layout spec and assert title `56`, divider `1`, vertical
padding `29`, side inset `20`, icon `14`, and icon gap `15`. Run Hypium and
record the missing-module compile failure.

## Task 2: Add the pure layout spec

**Files:**

- Add: `Mindspore_inhand_HarmonyOS/entry/src/main/ets/common/data/MeLayoutSpec.ets`

Export only the Android constants; keep the module free of ArkUI dependencies.

## Task 3: Port the title and page structure

**Files:**

- Modify: `Mindspore_inhand_HarmonyOS/entry/src/main/ets/pages/MePage.ets`

Remove the Me usage of `GradientTitleBar` and `SectionTitle`. Add a 56vp
horizontal `#59BBE3` to `#6189FF` gradient title with centered 17fp bold white
text, followed by a 1vp `#DBDBDB` divider. Keep the title outside the row
Scroll, use a full-size white page, and preserve the visible catalog loop.

## Task 4: Port the Version row geometry

**Files:**

- Modify: `Mindspore_inhand_HarmonyOS/entry/src/main/ets/pages/MePage.ets`

Render rows full-width without card background, radius, or border. Use 20vp
horizontal and 29vp vertical padding, a 14vp icon with 15vp gap, 16fp
`#333333` label, and 13fp `#666666` trailing value. Keep chevrons conditional
on navigation so Version has none. Do not change catalog visibility or action
services.

## Task 5: Verify and integrate

Run full `hvigorw test --no-daemon`, read the exact result count, run
`git diff --check`, and run unified HAP/AI acceptance. Obtain independent
review, fast-forward into `master`, repeat master verification, then remove the
worktree and branch.
