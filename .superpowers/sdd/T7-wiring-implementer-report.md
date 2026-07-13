# T7 Wiring Implementer Report

## Outcome

Production text translation is now wired to `MindSporeLiteTranslationRunner` instead of the finite demo dictionary. The runtime factory supplies the Harmony raw-file descriptor adapter and app-private translation cache path, while host tests can inject a model bundle factory or an explicit runner. Direct text and OCR translation continue through the same `TextTranslationService` and runner instance.

`DefaultAiService` no longer silently creates `LocalTextTranslationRunner`; that runner remains available only when a legacy/demo test explicitly injects it. A missing final model package returns `TEXT_TRANSLATION_FAILED` with the normal model failure message and preserved source text. There is no cloud, network, or dictionary fallback.

The translation workflow no longer lists Internet as a feature requirement. The application-level Internet permission remains unchanged for unrelated web/help and resource behavior.

## TDD evidence

- Pure behavior RED after correcting the fixture: `Tests run: 453, Failure: 7, Error: 0, Pass: 446, Ignore: 0`.
- The failures proved the old production behavior: translation still required Internet, bare `DefaultAiService` still created the dictionary, and the runtime factory still returned dictionary success/unsupported messaging when model assets were absent.
- Final fresh GREEN after all assertions: `Tests run: 455, Failure: 0, Error: 0, Pass: 455, Ignore: 0`.
- Focused class counts: `mindsporePortFoundation` 416/416 and `TranslationModelUnit` 24/24.

Coverage includes arbitrary unmapped direct text succeeding through an injected `localModel` runner, OCR sharing that runner, exact source and translated newlines, copy output, empty input, OCR and model failure separation, repeated clicks, stale-generation suppression, page-exit invalidation, missing-model fail-closed behavior, explicit host bundle-factory injection, and removal of only the translation workflow's Internet requirement.

## Build and package evidence

- Default HAP: `assembleHap --no-daemon` exited 0.
- ohosTest HAP: `BUILD SUCCESSFUL in 40 s 502 ms`.
- Both HAPs contain `libs/arm64-v8a/libtranslation_archive.so`, but no translation archive, runtime manifest, encoder, or decoder model asset.
- `scripts/build-hap.ps1` remains unchanged and does not invoke `verify-translation-model.ps1`. Enabling that gate before the verified final assets exist would correctly fail the asset-incomplete package, so the gate remains deferred.
- `git diff --check` passed with only Git line-ending conversion notices.

## Deferred final-package work

This checkpoint does not claim real offline translation inference, bilingual quality, latency, memory, extraction, or phone behavior. The verified final archive/manifest/tokenizer assets, build-HAP verifier gate, target-side extraction/inference tests, signed installation, and device measurements remain final-package follow-up work.
