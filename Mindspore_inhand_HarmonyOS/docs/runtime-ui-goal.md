# Runtime UI goal

Updated: 2026-07-27

Goal: modernize every feature-runtime page in the approved HarmonyOS visual
language without changing feature visibility or inference semantics. Verify
each workflow with focused guards, mutation coverage, LocalUnit/build checks,
and real HDC touch/accessibility/screenshot evidence. Commit each completed
workflow separately.

## Live task list

- [x] Tasks 0–13: shared runtime UI and image/camera workflows.
- [x] Task 14: portrait segmentation (`3c75b78` through `fc7a496`).
- [x] Task 15: text translation (`83b3425`).
- [x] Task 16: style transfer (`cff3322`).
- [x] Task 17: custom model (`0b53955`; implementation retained; entry stays hidden).
- [x] Task 18: final cross-workflow verification, production HAP, review,
  and branch integration (`00498ca` through `a37851b`).

Task 18 acceptance covers production/default and isolated-harness/3.2x HDC
evidence for Text Translation, Style Transfer, and Custom Model. All six
manifests, LocalUnit, focused source/mutation guards, ArkTS compilation, and
the arm64-v8a/x86_64 HAP payload verifier pass. Custom Model remains hidden
from the production catalog.

The accepted Task 14 evidence is recorded in `task-14-report.md`. Its two
harness worktrees must remain dirty because the signed manifests bind their
exact candidate diffs.

## Resume prompt

> Continue the Runtime UI goal from `docs/runtime-ui-goal.md` and
> `docs/superpowers/plans/2026-07-24-harmony-feature-runtime-ui.md`. Read the
> latest git log and task report, resume at the first unchecked task, keep
> hidden features hidden, use HDC touch/accessibility/screenshots instead of
> Computer Use, obtain independent subagent review, and commit each completed
> workflow separately.
