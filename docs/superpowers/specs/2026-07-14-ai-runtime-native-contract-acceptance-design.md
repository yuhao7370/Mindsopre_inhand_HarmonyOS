# AI Runtime Native Contract Acceptance Design

## Context

The unified AI acceptance command builds the main HAP and the `ohosTest` HAP,
then checks that the expected models and native libraries are packaged. The
repository also has stronger source-and-ELF contract guards for the HMS gesture
NAPI/MNN bridge and the local-translation XZ NAPI bridge, but the unified entry
point does not invoke them. A package can therefore contain both libraries while
their ABI, dependency, architecture, or safety contracts have drifted.

Device execution remains outside this migration increment. The goal is to make
the existing host-side acceptance command fail closed on the native contracts
that can be checked after a local build.

## Decision

After `build-hap.ps1` completes the main HAP build, the unified acceptance script
will invoke, in this order:

1. `verify-gesture-native-contract.ps1`, against the freshly built
   `libgesture_mnn.so` and the gesture NAPI/MNN sources.
2. `test-translation-xz-native-contract.ps1`, against the committed
   `libtranslation_archive.so` and the translation XZ NAPI sources.

Only after both contracts pass will acceptance assemble the `ohosTest` HAP and
run the existing dual-HAP structure guard. The script already uses
`$ErrorActionPreference = 'Stop'`, so either verifier terminates acceptance on
failure without custom error handling.

## Regression Contract

A dependency-free PowerShell wiring test will read the acceptance script and
require exactly one call to each native verifier. It will also require both calls
to occur after `build-hap.ps1` and before the `entry@ohosTest` assemble command.
This guards the useful ordering: gesture verification needs the freshly built
library, while native failure should avoid an unnecessary test-HAP build.

## Scope

In scope:

- Wire both existing native contract scripts into the unified acceptance entry.
- Add a focused static wiring regression test.
- Document the expanded host-side acceptance boundary.

Out of scope:

- Changing gesture or translation models, native code, or ABI expectations.
- Changing HAP contents or the existing HAP structure guard.
- Device/emulator execution, recognition accuracy, or translation quality.

## Acceptance

- The focused wiring test passes and rejects the pre-change script during RED.
- Both native contract scripts pass against the current artifacts.
- Hypium remains fully green.
- Unified acceptance builds both HAPs and ends with the HAP structure guard.
- No device validation is claimed.
