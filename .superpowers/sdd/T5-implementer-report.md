# T5 Implementer Report: ArkTS SentencePiece Tokenizer

## Scope

- Added the pure ArkTS tokenizer, focused host tests, generated test fixture, and
  the small Python fixture generator/tests required by Task 5.
- Did not modify training/evaluation code, XZ/native code, the final model
  archive/manifest, UI, or the unrelated dirty documentation files.
- The generated 16.7 KiB test fixture is deliberately a lossless subset of the
  pinned model's table. The production `TTOK1` parser accepts the eventual full
  32,000-piece/exact-normalization table; this task does not fabricate the final
  HAP tokenizer asset owned by the packaging task.

## RED evidence

The Python generator test first failed before implementation with:

```text
ModuleNotFoundError: No module named 'tools.translation.tokenizer_generate_fixture'
```

The first Hvigor invocation was blocked before compilation by an unset/invalid
`DEVECO_SDK_HOME` and was not counted as RED. With the DevEco SDK/JBR command
environment restored, `hvigorw test --no-daemon` reached
`:entry:default@UnitTestArkTS`, exited 1, and reported the expected production
gap:

```text
Could not resolve "../main/ets/services/ai/TinyTranslationTokenizer"
Cannot find module '../main/ets/services/ai/TinyTranslationTokenizer'
```

No production tokenizer module existed at that point.

## Implemented behavior

- Strictly parses a pinned, versioned `TTOK1` text table: source-model SHA-256,
  vocabulary/UNK contract, normalizer flags, codepoint-encoded normalization
  rules, and piece ID/score/type rows.
- Applies exact longest-match generated `nmt_nfkc` rules, dummy `▁`, ASCII-space
  collapse/removal, and escaped whitespace without relying on platform locale
  normalization.
- Implements SentencePiece Unigram Viterbi with prefix-length ordering, strict
  score ties, one-Unicode-symbol unknown fallback using `min_score - 10`, and
  the pinned `UNK=1` behavior.
- Emits fixed 128-element IDs/masks with direction first, at most 126 model
  pieces, EOS immediately before PAD, and exact `<2en>/<2zh>` IDs.
- Splits long input safely and retains original `LF`, `CRLF`, and repeated
  newline sequences as per-chunk separators.
- Decoding stops at EOS, skips PAD/direction/control IDs, removes the dummy
  whitespace marker, and emits the SentencePiece unknown replacement `⁇`.
- Reproduces the existing Android broad Unicode direction rule for Chinese,
  full-width forms, CJK radicals/punctuation, and CJK strokes.

## Golden coverage

The generator validates the exact pinned `source.spm`:

- revision input SHA-256:
  `E5528A5C3685D08F8868902D31FEBEB763EEA8519F9997F43B05964B02554640`
- exact size: `755175` bytes
- SentencePiece Unigram, vocabulary 32,000, `nmt_nfkc`, dummy prefix,
  whitespace removal, and whitespace escaping

Its immutable ArkTS goldens cover Chinese, English, mixed text, full-width
forms/punctuation, ASCII punctuation, repeated whitespace, unknown supplementary
Unicode, total-token boundaries 127/128/129, multiple `LF`/`CRLF` separators,
combining-character NFKC, and both translation directions. Generator tests also
fail on changed model bytes and on a stale checked-in fixture.

## GREEN verification

- `python -m unittest tools.translation.tokenizer_test_generator -v`: 2 tests,
  exit 0, `OK`.
- Full host `hvigorw test --no-daemon`: exit 0,
  `BUILD SUCCESSFUL in 42 s 859 ms`; six focused `TranslationModelUnit` cases
  are registered in `List.test.ets` alongside the existing suites.
- `entry@ohosTest` HAP compile/package:
  `assembleHap --mode module -p product=default -p module=entry@ohosTest
  --no-daemon`: exit 0, `BUILD SUCCESSFUL in 18 s 119 ms`.
- Full default HAP: `assembleHap --no-daemon`: exit 0,
  `BUILD SUCCESSFUL in 35 s 286 ms`.
- Existing repository ArkTS warnings, CMake path-length warnings, and the
  unsigned-HAP notice remain; no tokenizer compiler warning or error was added.

## Residual boundary

Task 5 proves tokenizer behavior against Python SentencePiece goldens and proves
host/target compilation. Final full-table asset loading, trained graph quality,
greedy decoder integration, and on-device inference remain the explicitly later
tasks; no device-runtime or translation-quality claim is made here.

DONE

## Fresh-review remediation

The fresh review identified three P1 gaps in `df7e64e`; the remediation uses
new failing generator/Hypium tests before production changes:

- The fixture now declares `TTOK1_TEST` and can only be configured through the
  explicit test-profile API. Production `TTOK1` requires the pinned declared
  count of 32,000, every unique contiguous source ID `0..31999`, PAD `32000`
  outside the piece table, exact EOS/UNK text and types, NORMAL type for all
  other source pieces, unique piece text, finite scores, valid codepoints, and
  a non-empty/unique-source normalization table. A generated synthetic 32K
  smoke and declared-count/missing/duplicate/out-of-range/non-finite/type/map
  corruption negatives exercise the production path.
- Adjacent Viterbi unknown nodes are coalesced into the single unknown run
  emitted by pinned SentencePiece. Unknown decoding emits ` ⁇ ` before dummy
  whitespace removal, reproducing both `A ⁇ B` and doubled spaces where an
  explicit `▁` also surrounds UNK. Supplementary, adjacency/whitespace, BMP
  private-use, and boundary-sensitive unknown goldens are generated from the
  pinned model.
- Long non-newline runs select the last fitting boundary by strict category
  priority: Chinese `。！？；`, English `.?!;`, ASCII space/tab, then a
  Unicode-safe hard cut. The delimiter remains in the previous chunk. Each
  chunk retains its exact `sourceText`, allowing tests to prove byte-for-string
  reconstruction together with the original `LF`/`CRLF` separator fields.

RED evidence includes generator failures for absent `TTOK1_TEST` and absent
unknown/priority cases, plus `UnitTestArkTS` failures for the absent explicit
test API/source-text contract. An intermediate Hypium execution also exposed
that Hvigor may exit zero while logging a failed assertion; final verification
therefore checks the generated Hypium result/error output rather than treating
`BUILD SUCCESSFUL` alone as a pass.

### Fresh-review verification

- `python -m unittest tools.translation.tokenizer_test_generator -v`: 3 tests,
  exit 0, `OK`.
- Host `hvigorw test --no-daemon`: exit 0, `BUILD SUCCESSFUL in 52 s 297 ms`.
  The complete output contains no `ERROR: Error in ...` Hypium failure line.
  The Windows Hvigor adapter suppresses Hypium's `console.info` summary, so an
  exact numeric pass/failure/error count is not claimed here.
- `entry@ohosTest` HAP compile/package: exit 0,
  `BUILD SUCCESSFUL in 1 min 2 s 529 ms`.
- The final default-HAP build was attempted twice but produced no output before
  the 120 s and 180 s command timeouts (exit 124). It is therefore not claimed
  as verified for this remediation; the pre-remediation Task 5 commit's default
  HAP build remains the successful result recorded above.
- Scoped `git diff --check` for the Task 5 files: exit 0.
