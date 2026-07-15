# Local Translation Runtime Input Policy V1

## Result

The pinned 100-row Chinese-English manual set passed the automatic corruption
gate with the runtime input policy enabled. The total flag count decreased from
14 to 9, and neither translation direction regressed:

| Direction | V5 baseline | Runtime policy | Change |
| --- | ---: | ---: | ---: |
| Chinese to English | 6 | 4 | -2 |
| English to Chinese | 8 | 5 | -3 |
| Total | 14 | 9 | -5 |

Changed row IDs: `15, 20, 21, 22, 33, 37, 38, 39, 40, 63, 64, 69, 70, 71, 75, 82, 84, 85, 86, 87, 88, 89`.

The policy collapses OCR-spaced runs of at least three single ASCII letters,
preserves URLs, email addresses, and code-like identifiers byte-for-byte, and
does not send punctuation-only separators to the model. Plain numbers, dates,
names, and ordinary hyphenated words remain in model context.

## Bound Identity

The model was not changed by this evaluation:

- Checkpoint SHA-256: `3b8b9a61910ae1b147947eef0168d6b0c5b8033d0a9059e82ef79cc468ce705f`
- Tokenizer SHA-256: `e5528a5c3685d08f8868902d31febeb763eea8519f9997f43b05964b02554640`
- V5 terminal SHA-256: `61f9554923cbc617d813d3c0b7128d44456e703bd3e1806978810cd1fa5ebd13`
- V5 budget terminal SHA-256: `96d4c9baca530799b1c1a6ce026efdca320c28ff9b6f7873fce05eeab7ed1a7d`
- Manual set SHA-256: `0b8d0393eb46128065a05d6fdb38fa660828c85ca435980f74e59a91efea2ca1`
- Baseline results SHA-256: `f05ffa227aab96196b6bc8ae170d99631ffc6c8d644fcc8effd6008ef2ad79eb`
- Policy code SHA-256: `7c2a1c4caf3ceb897872520e71e7bc18571c68c0568fc92e3e46351d7654c462`
- Evaluator code SHA-256: `b116e61e06638cb4f97e4d9afe7e2bc09f98e78cad801f67759578e471eba826`

The canonical external evidence was written under
`%LOCALAPPDATA%\Temp\translation-t3-marian\runtime-input-policy-eval-v3`:

- Evaluation report: 1,492 bytes, SHA-256 `e678b11d7a92996c1eb1e7eb511bd23f68b3e798e99aad1d3a53dc053a4509c4`
- Policy results: 23,224 bytes, SHA-256 `4db64a59756b4c781efd26b0f7849cd7203b20193e6c84a6e55c6a0c5185d630`

## Limits

This gate detects preservation corruption; it does not establish general
semantic translation quality. The existing manual-quality limitation remains,
the application is for local learning rather than production approval, and no
real-device functionality or performance was validated.
