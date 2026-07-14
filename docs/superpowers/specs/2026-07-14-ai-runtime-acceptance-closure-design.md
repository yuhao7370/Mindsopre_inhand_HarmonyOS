# AI Runtime Acceptance Closure Design

## Context

The HarmonyOS port now builds the main HAP and includes real local execution
paths for the HMS gesture model and the Chinese-English translation model. Host
tests cover their pure ArkTS contracts, and the gesture `ohosTest` loads the
real MNN model, but the device-test suite still contains the generated
`Ability.test.ets` placeholder. Translation has no equivalent packaged-model
smoke test. This leaves a gap between "the files are in the repository" and
"the application package can initialize the actual runtime chain."

Real-device execution remains explicitly deferred. This phase improves the
testable migration boundary without claiming accuracy, latency, or device
compatibility that has not been measured.

## Chosen Approach

Use the existing models and runtime code and add the smallest missing
acceptance layer:

1. replace the placeholder device test with a packaged translation smoke test;
2. add a license-clean hand-image fixture for deterministic gesture
   preprocessing checks while retaining synthetic decoder contract tests;
3. verify the main HAP contains the required model and native-library assets,
   and verify the separate `ohosTest` feature HAP is correctly paired with the
   main module;
4. keep translation quality gates and device validation status unchanged.

Continuing training is excluded from this phase. The current tiny model is
already integrated, and another unbounded training continuation has uncertain
benefit. Replacing it with larger direction-specific models would increase the
package and require another converter/runtime qualification cycle. Neither is
required to close the current code-migration acceptance gap.

## Test Boundaries

### Translation Device Smoke Test

Add `TranslationNative.test.ets` under `entry/src/ohosTest/ets/test/` and
register it from `List.test.ets`. The test uses the application
`ResourceManager`, `productionTranslationModelBundleFactory`, and the same
runner used by the feature page. It must:

- load the packaged translation manifest, tokenizer, vocabulary, and archive;
- extract and initialize the encoder, prefill, and step models through the
  production native archive bridge and MindSpore Lite runner;
- translate one fixed Chinese input to English and one fixed English input to
  Chinese;
- require non-empty output, the expected target-language direction, finite
  inference completion, and deterministic output across two runs;
- reset the production translation cache in a `finally` block so every loaded
  MindSpore session is closed even after a failed assertion.

The smoke test must not assert a preferred wording or mark the model
production-ready. Exact sentence quality remains the responsibility of the
existing host evaluation gate, which currently does not pass.

Delete `Ability.test.ets`; no template assertion remains in the device suite.

### Gesture Fixture Contract

Add one small test image generated specifically for this repository and record
its generation note and SHA-256 beside the fixture. It depicts a clearly
visible hand and is a preprocessing fixture, not a recognition gold label.
A checked-in RGBA fixture derived from that image lets host tests exercise the
same normalization and resize function used by the feature. They verify tensor
shape, channel order, finite values, value bounds, and determinism. The
`ohosTest` suite separately decodes the PNG with ImageKit and checks that the
decoded dimensions and production preprocessing contract remain valid.
Decoder tests continue to use controlled synthetic tensors so class,
confidence, coordinate, and non-max-suppression assertions remain exact.

The existing `GestureNative.test.ets` continues to load `GestureDetector.ms`
and verify real MNN output names, shapes, finiteness, and repeatability. It may
consume the fixture later on a device, but this phase does not assert that the
model detects a particular gesture in the image.

## Package Acceptance Guard

Add one PowerShell guard that accepts explicit main-HAP and optional
`ohosTest`-HAP paths. The main HAP must contain:

- `models/gesture/GestureDetector.ms`;
- `models/translation/translation-models.tar.xz` and its runtime metadata;
- `libgesture_mnn.so`, `libMNN.so`, and `libtranslation_archive.so` for
  `arm64-v8a`.

The `ohosTest` HAP is a small feature module and must not duplicate the main
HAP's model assets. Its `module.json` must identify module `entry_test` with
`TestAbility`, and `pack.info` must pair `entry_test` with the main `entry`
module for the same bundle.

The guard reuses Windows `tar` and PowerShell JSON parsing. It must not
introduce a package parser dependency. `build-hap.ps1` calls it for the main HAP
after assembly; the verification workflow calls it with both paths after the
`ohosTest` HAP is assembled. The main build continues to verify source asset
hashes before assembly; the new guard verifies final package structure after
assembly.

## Data Flow

For translation, the test obtains `ResourceManager`, calls the production
translation factory, and exercises the same tokenizer to archive extraction to
MindSpore Lite decode path used by the UI. Results return through the existing
`TextTranslationResult` contract.

For gesture, the fixture flows through the production image preprocessor into
the existing tensor contract. Native-session and decoder responsibilities stay
separate so host tests remain deterministic and device-only behavior is not
mocked as successful inference.

## Error Handling And Cleanup

- The smoke test initializes the production bundle before checking translated
  output, so missing or corrupt packaged assets fail at their existing
  manifest/archive boundary rather than being replaced by a fake result.
- Model initialization and prediction failures are test failures; there is no
  dictionary, cloud, or fake-model fallback.
- `resetTranslationModelCacheForTests()` runs in `finally`, including after
  assertion or inference failure.
- Generated extracted-model directories remain application-private and are
  reused or cleaned according to the production cache implementation.
- Package inspection reports every missing required entry in one run.

## Verification

Completion requires fresh evidence for all of the following:

- focused host tests for the gesture fixture and package guard;
- all ArkTS/Hypium host tests;
- all Python translation tests;
- successful main HAP assembly and post-package inspection;
- successful `ohosTest` HAP assembly and verification that it is paired with
  the main entry HAP without duplicating the main model assets;
- clean Git status.

If no device or emulator is available, the translation and gesture device
tests are compile-and-package verified only. Their execution remains an
explicit follow-up and is not counted as passed.

## Non-Goals

- No new translation model, training continuation, service, or network
  fallback.
- No claim that the current translation model passes its production quality
  gate.
- No real-device accuracy, FPS, memory, or long-running stability claim.
- No broad refactor of `FeatureRuntimePage` or unrelated hidden features.
- No new package-inspection dependency.

## Success Criteria

This phase is complete when the placeholder device test is gone, both AI
runtime chains have meaningful packaged-runtime acceptance coverage, the main
HAP contains the required model/native assets, the `ohosTest` HAP is correctly
paired with it, all runnable host checks pass, both HAP variants build, and the
remaining real-device gap is documented without being presented as completed
verification.
