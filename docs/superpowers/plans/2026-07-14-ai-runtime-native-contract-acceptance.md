# AI Runtime Native Contract Acceptance Implementation Plan

> Execute in an isolated worktree with test-first evidence and independent code
> review. Do not modify model or native implementation files.

## Goal

Make `scripts/build-ai-runtime-acceptance.ps1` fail closed when either the HMS
gesture native bridge or the local-translation XZ native bridge violates its
existing source/ELF contract.

## Task 1: Add a failing wiring contract

Files:

- Create: `Mindspore_inhand_HarmonyOS/scripts/test-build-ai-runtime-acceptance-wiring.ps1`

The test reads `build-ai-runtime-acceptance.ps1` and asserts:

- exactly one invocation of `verify-gesture-native-contract.ps1`;
- exactly one invocation of `test-translation-xz-native-contract.ps1`;
- both invocations occur after the `build-hap.ps1` invocation;
- both invocations occur before the `entry@ohosTest` assemble command;
- gesture verification occurs before translation verification.

Run from `Mindspore_inhand_HarmonyOS`:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\test-build-ai-runtime-acceptance-wiring.ps1
```

Expected RED: the test reports that the native verifier calls are missing.

## Task 2: Wire the native contracts

Files:

- Modify: `Mindspore_inhand_HarmonyOS/scripts/build-ai-runtime-acceptance.ps1`

Immediately after `build-hap.ps1`, invoke:

```powershell
& (Join-Path $PSScriptRoot 'verify-gesture-native-contract.ps1')
& (Join-Path $PSScriptRoot 'test-translation-xz-native-contract.ps1')
```

Do not duplicate verifier logic or add new parameters. Re-run the focused test
and require GREEN.

## Task 3: Verify the real contracts and project

Run from `Mindspore_inhand_HarmonyOS`:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\verify-gesture-native-contract.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\test-translation-xz-native-contract.ps1
```

Then run:

```powershell
& 'C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat' test --no-daemon
powershell -ExecutionPolicy Bypass -File .\scripts\build-ai-runtime-acceptance.ps1
```

Read `entry/.test/default/intermediates/test/coverage_data/test_result.txt` and
require the exact zero-failure Hypium summary; do not trust hvigor exit code
alone. Unified acceptance must report both native contracts and verify both HAPs.

## Task 4: Review and integrate

- Commit only the wiring test and acceptance-script change.
- Produce an SDD task report with RED/GREEN and verification evidence.
- Run spec-compliance review, then whole-branch review.
- Fast-forward merge to `master` only after approval.
- Re-run the focused test and unified acceptance on merged `master`.
- Remove the feature worktree and branch; retain the old gesture translation
  worktree only as a read-only reference.
