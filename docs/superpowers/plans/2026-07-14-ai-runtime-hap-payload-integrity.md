# AI Runtime HAP Payload Integrity Implementation Plan

**Goal:** Make the build reject a main HAP whose AI payload names are correct
but whose model, metadata, or native-library bytes differ from the verified
inputs.

**Architecture:** Extend the existing HAP guard with streaming ZIP-entry
SHA-256 checks. Production defaults point at rawfile sources and stripped
native outputs; tests inject tiny temporary expected roots. Point the existing
native verifiers at the stripped libraries packaged into the HAP.

## Task 1: Add failing payload-tamper contracts

**Files:**

- Modify: `Mindspore_inhand_HarmonyOS/scripts/test-verify-ai-runtime-haps.ps1`

Create temporary canonical resource/native roots and a matching valid HAP.
Add same-name, one-byte-different fixtures for one model and one `.so`, and
require both to be rejected. Run the test and confirm it fails because the
current guard accepts altered content.

## Task 2: Verify packaged payload bytes

**Files:**

- Modify: `Mindspore_inhand_HarmonyOS/scripts/verify-ai-runtime-haps.ps1`
- Modify: `Mindspore_inhand_HarmonyOS/scripts/test-verify-ai-runtime-haps.ps1`

Add optional expected rawfile and stripped-library roots with project-relative
defaults. Open the HAP as a ZIP archive, stream SHA-256 for the 10 resource
entries and 3 native entries, and compare each with its expected file. Keep all
existing structural checks. Run the guard contract test to green.

## Task 3: Inspect the packaged native libraries

**Files:**

- Modify: `Mindspore_inhand_HarmonyOS/scripts/build-ai-runtime-acceptance.ps1`
- Modify: `Mindspore_inhand_HarmonyOS/scripts/test-build-ai-runtime-acceptance-wiring.ps1`

Pass explicit stripped `libgesture_mnn.so` and
`libtranslation_archive.so` paths to their existing contract verifiers. Update
the AST wiring expectations and negative cases so removing or weakening those
arguments fails. Run both focused PowerShell contract tests.

## Task 4: Regression and integration

Run the full Hypium suite and confirm the exact result file reports no
failures. Run `build-ai-runtime-acceptance.ps1` and confirm main HAP assembly,
both stripped-native contracts, `ohosTest` assembly, payload hashes, and paired
HAP checks all pass. Request an independent diff review, fix any findings,
fast-forward the reviewed branch into `master`, repeat the required checks on
`master`, and remove the temporary worktree/branch.
