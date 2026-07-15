# Self-Contained Core MindSpore Model Assets Implementation Plan

> Execute in an isolated worktree using TDD, subagent implementation, an
> independent review, and verification-before-completion.

## Goal

Commit the five core MindSpore Lite models, remove normal-build networking,
pin every source asset by exact bytes/SHA-256, and extend main-HAP payload
verification to cover them.

## Task 1: Add the failing repository asset contract

Files:

- Create: `Mindspore_inhand_HarmonyOS/scripts/check-core-model-assets.ps1`

Create a dependency-free core-model guard that requires:

- `.gitignore` ignores `.ms.download` but not stable `.ms` files;
- `Mindspore_inhand_HarmonyOS/.gitattributes` marks the five model binaries
  `-text -diff` with project-relative paths;
- all five assets exist with the exact approved bytes and SHA-256;
- normal `ensure-mindspore-models.ps1` contains every model/label verifier and
  no downloader call;
- each non-scene verifier and downloader contains its exact byte/hash contract;
- every downloader uses a request-private same-directory temp, `File.Replace`
  for an existing stable file, `File.Move` for an absent stable file, and never
  removes/truncates the stable path on failure;
- the full Apache-2.0 license and model NOTICE/provenance files exist beside the
  models.

Run the guard and record RED against current source. Do not wire the failing
guard into `build-hap.ps1` until Task 2 is green.

## Task 2: Make source assets deterministic and offline

Files:

- Modify: `Mindspore_inhand_HarmonyOS/.gitignore`
- Modify: `Mindspore_inhand_HarmonyOS/.gitattributes`
- Modify: `Mindspore_inhand_HarmonyOS/scripts/ensure-mindspore-models.ps1`
- Modify: `Mindspore_inhand_HarmonyOS/scripts/verify-image-classification-model.ps1`
- Modify: `Mindspore_inhand_HarmonyOS/scripts/verify-object-detection-model.ps1`
- Modify: `Mindspore_inhand_HarmonyOS/scripts/verify-style-transfer-models.ps1`
- Modify: `Mindspore_inhand_HarmonyOS/scripts/download-image-classification-model.ps1`
- Modify: `Mindspore_inhand_HarmonyOS/scripts/download-object-detection-model.ps1`
- Modify: `Mindspore_inhand_HarmonyOS/scripts/download-style-transfer-models.ps1`
- Modify: `Mindspore_inhand_HarmonyOS/scripts/download-scene-detection-model.ps1`
- Modify: `Mindspore_inhand_HarmonyOS/scripts/build-hap.ps1`
- Add: `Mindspore_inhand_HarmonyOS/entry/src/main/resources/rawfile/model/mobilenetv2.ms`
- Add: `Mindspore_inhand_HarmonyOS/entry/src/main/resources/rawfile/model/resnet18-place365.ms`
- Add: `Mindspore_inhand_HarmonyOS/entry/src/main/resources/rawfile/model/ssd.ms`
- Add: `Mindspore_inhand_HarmonyOS/entry/src/main/resources/rawfile/model/style_predict_quant.ms`
- Add: `Mindspore_inhand_HarmonyOS/entry/src/main/resources/rawfile/model/style_transfer_quant.ms`
- Add: `Mindspore_inhand_HarmonyOS/entry/src/main/resources/rawfile/model/LICENSE-Apache-2.0.txt`
- Add: `Mindspore_inhand_HarmonyOS/entry/src/main/resources/rawfile/model/NOTICE.md`

Remove only the stable `.ms` ignore rule, add the project-local binary
attribute, and stage the exact existing files. Turn
`ensure-mindspore-models.ps1` into verifier-only wiring. Replace minimum-size
checks with exact byte and SHA-256 checks.

For all four manual downloaders, use a unique same-directory partial path.
Validate it completely, then call `File.Replace(temp, stable, backup)` when a
stable file exists or same-directory `File.Move(temp, stable)` when it does not.
Any download, validation, or publication failure must preserve the previous
stable file and clean only request-private temp/backup files. Existing files may
still short-circuit unless `-Force` is supplied.

Copy the complete Apache-2.0 text from the already tracked third-party license
and add the reviewed model NOTICE with official source URLs, pinned scene
commit/copyright, exact contracts, no-extra-NOTICE finding, and the Model Zoo
non-commercial research/education restriction.

Wire `check-core-model-assets.ps1` into `build-hap.ps1`, run it and every
model/label verifier to GREEN, then commit:

```text
build: make core models self contained
```

## Task 3: Bind the five models into HAP integrity verification

Files:

- Modify: `Mindspore_inhand_HarmonyOS/scripts/verify-ai-runtime-haps.ps1`
- Modify: `Mindspore_inhand_HarmonyOS/scripts/test-verify-ai-runtime-haps.ps1`
- Modify: `Mindspore_inhand_HarmonyOS/scripts/check-core-model-assets.ps1`

First extend the fixture's valid main entries with the five model paths plus the
license/NOTICE paths. Add a tampered `ssd.ms` fixture and require a payload
mismatch; run it and record RED because the current verifier does not bind that
entry. Then add the same exact entries to the main HAP verifier and to the core
source guard. Reuse existing `Assert-HapPayloadHashes`; do not create a second
ZIP/hash implementation.
Run the fixture test and require valid/fresh-process acceptance, missing-entry,
duplicate-entry, tampered app-model, gesture/native tamper, copied-test-model,
and pairing rejections to pass. Commit:

```text
build: verify core model hap payloads
```

## Task 4: Record build boundary

Files:

- Create: `docs/model-provenance/mindspore-lite-core-models.md`
- Modify: `docs/harmonyos-platform-differences.md`

Mirror the reviewed NOTICE facts in the developer-facing provenance document.
State that clean normal builds now verify repository assets without networking
and that downloaders are manual recovery tools only. Do not claim model quality
or device behavior.

Run `git diff --check`, the core guard, model verifiers, HAP fixture test,
i18n guard, and fresh Hypium. Commit:

```text
docs: record core model provenance
```

## Task 5: Review, acceptance, merge, and cleanup

Request independent review of all commits. The reviewer must confirm no normal
build path invokes networking, every model is tracked/binary, constants match
the actual bytes, partial/failing downloads never replace stable assets, and the
main HAP binds all five payloads while `ohosTest` still excludes copied models.
Resolve every Critical/Important finding.

Run fresh unified acceptance and `git diff --check` in the feature worktree.
After whole-branch approval, fast-forward `master`, rerun the core guard, HAP
fixture test, exact model verifiers, fresh Hypium, and unified acceptance on
merged `master`. Remove the worktree and branch safely. Do not claim device
execution.
