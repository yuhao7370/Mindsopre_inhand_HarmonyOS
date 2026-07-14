# AI Runtime HAP Payload Integrity Design

## Context

The current acceptance guard proves that the main HAP contains every gesture
and translation entry, but it does not prove that those entries contain the
same bytes as the verified source assets. The native contract checks also read
the unstripped build libraries while the HAP contains the stripped libraries.
The current package was audited and its bytes are correct; the remaining risk
is that a future packaging regression could keep the same entry names and pass
acceptance with altered content.

Real-device execution remains deferred. This increment verifies the packaged
artifact without claiming device compatibility or model quality.

## Chosen Approach

Extend the existing HAP guard instead of adding another acceptance script.
After the existing entry and module checks, it will stream each required ZIP
entry through SHA-256 and compare it with the canonical file:

- 3 gesture model/metadata files and 7 translation model/metadata files under
  `entry/src/main/resources/rawfile`;
- `libgesture_mnn.so`, `libMNN.so`, and `libtranslation_archive.so` under the
  generated `stripped_native_libs/default/arm64-v8a` directory.

The guard receives optional expected-payload roots. Production calls use
project-relative defaults, while contract tests supply small temporary roots.
This keeps the tests fast and avoids copying the real translation archive.

The unified acceptance script will pass the stripped gesture and translation
library paths to the existing native contract verifiers. ELF exports and
`DT_NEEDED` checks will therefore cover the exact native bytes later compared
with the HAP.

## Hashing And Failure Behavior

Use .NET ZIP streams and SHA-256 so large model entries are never converted to
PowerShell text or fully buffered in memory. Compare normalized lowercase hex
digests and include the package entry and expected source path in failures.
Missing expected files, missing package entries, unreadable archives, or hash
mismatches all fail the build.

The existing `tar`-based entry listing and JSON checks remain unchanged. The
new hashing code is additive and does not introduce a package dependency.

## Verification

Contract tests must prove that a valid paired-HAP fixture passes and that the
guard rejects:

- a model entry whose name is unchanged but whose content differs by one byte;
- a native-library entry whose name is unchanged but whose content differs by
  one byte;
- all previously covered structural and pairing failures.

The acceptance wiring test must lock the explicit stripped library paths. A
fresh unified acceptance run must build the main and `ohosTest` HAPs, verify
native contracts on stripped libraries, and verify all packaged payload hashes.
Host tests remain part of the post-merge regression run.

## Non-Goals

- No model replacement, retraining, online service, or new runtime.
- No extraction or modification of HMS proprietary model assets.
- No device execution or accuracy claim.
- No general-purpose signing or whole-HAP reproducibility check.

## Success Criteria

The increment is complete when all 10 AI resource entries and 3 native
libraries are byte-matched against their canonical inputs, both tamper tests
fail for the intended reason, native contracts inspect stripped libraries,
the unified acceptance completes successfully, and `master` remains clean.
