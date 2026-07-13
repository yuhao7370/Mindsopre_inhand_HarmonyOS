# T6 Implementer Report

## Outcome

Implemented the ArkTS multi-graph greedy decoder for the local Chinese-English translation model. The production loader now parses the same strict runtime manifest enforced by `verify-translation-model.ps1`, verifies and extracts the single XZ archive through the narrow native module, loads the encoder/prefill/step MindSpore Lite graphs once, validates every tensor contract, and fails closed without the legacy dictionary fallback.

The real bilingual model archive is intentionally not present yet. Production inference on a device remains pending the final promoted assets; missing assets return `ok: false` honestly.

## TDD evidence

- RED: `hvigorw test --no-daemon` failed because `TranslationModelManifest` and `MindSporeLiteTranslationRunner` did not exist.
- Intermediate RED: the expanded fake-session tests exposed a test syntax error; it was fixed before production adapter work continued.
- Final GREEN: `Tests run: 449, Failure: 0, Error: 0, Pass: 449, Ignore: 0`.
- `TranslationModelUnit`: 20 successful tests.

The focused tests cover strict manifest fields/tokens/tensors, encoder/prefill/step calls, position and masks, NCHW self-cache scatter, retained cross-cache identity, stable finite argmax, EOS and 128-token stops, multi-chunk separator joining, malformed/extra/missing/non-finite tensors, unsupported targets, empty output, concurrent singleton load, reset cleanup, failed-load retry, and stale in-flight generation isolation.

## Production wiring

- Registered the verified prebuilt `libtranslation_archive.so` as a typed local OHPM dependency.
- Confirmed both generated HAPs contain `libs/arm64-v8a/libtranslation_archive.so`.
- Added the model cache reset to `resetHarmonyRuntimeAiServiceCachesForTests()`.
- Kept Task 7 production factory/UI selection unchanged.

## Build evidence

- Host test: `BUILD SUCCESSFUL in 1 min 52 s 839 ms`.
- Default HAP: `BUILD SUCCESSFUL in 52 s 598 ms`.
- ohosTest HAP: `BUILD SUCCESSFUL in 42 s 479 ms`.
- `git diff --check`: pass.
- No translation model/archive asset larger than 1 MiB was introduced by T6.

The initial default HAP packaging attempt reached successful ArkTS compilation but failed with `spawn java ENOENT`; adding the DevEco JBR `bin` directory to `PATH` fixed the environment-only packaging failure.
