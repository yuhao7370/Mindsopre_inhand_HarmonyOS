# Task 11: API24 Custom Model

## Result

The production Custom Model route now accepts only the documented single-input MindSpore Lite contract, probes a candidate through the real runtime before publishing it to the stable cache, reloads same-path replacements, and rejects malformed or non-finite first outputs. The API24 x86_64 emulator passed the native recovery oracle and the production DocumentPicker, PhotoPicker, inference, and output-rendering flow. The tracked ABI is restored to `arm64-v8a`; arm64 main and ohosTest HAPs pass exact payload and isolation checks.

## Baseline and root cause

The original cache was keyed by the fixed `/cache/custom_model.ms` URI. Replacing that file could therefore reuse a stale `mindSporeLite.Model`. Candidate publication checked only that the model loaded and exposed a superficially compatible input; it did not run the model or validate the first output. Production output decoding accepted any non-empty float32 result, including misaligned, oversized, or non-finite data. The selected-file reader also attempted one large read, so a valid DocumentPicker file could be truncated by a short read.

## Controlled fixture and provenance

The Task 11 graphs are project-authored calculation fixtures and contain no trained weights or third-party data. They are separately licensed under Apache-2.0; this does not claim that the entire repository is Apache-2.0. The bundled model notice and Apache-2.0 text record the fixture license and reproduction details.

| Fixture | TFLite source bytes / SHA-256 | MindSpore Lite bytes / SHA-256 | Purpose |
|---|---|---|---|
| channel mean | 948 / `99A725E615C3B6B64C015DCE2EFE5796DCA65DDA22DD6B5B1753F500447A9B7A` | 600 / `DB1A0A273DA0658155473FB391E95D027D0D5606C72FB2FFB18BFAE0FDC85409` | returns RGB channel means |
| inverted channel mean | 1,180 / `AFC464560DFE364E68B7D83544FB45E141B5A471813166FA7FCEEC37166D47AD` | 800 / `7EB540E46CE1437FB3004CAB1AF80BBAEBE2D83355923DA4432006482EA336D9` | same-path replacement oracle; returns `1 - mean` |
| non-finite output | 1,184 / `C722CA178EBBAB5AD6ECDF4327B46FFD72E009EE62FC46E858C4D41DA03DA52D` | 800 / `C8087D8D7C94CD3BB92F872BC0665CABC0BB343A6C0D16B276FC4659C4AE0957` | loads and predicts but returns NaN values |

`scripts/generate-custom-model-fixtures.py` records the exact TensorFlow 2.15 graph definitions and its Python/package environment. `scripts/convert-custom-model-fixtures.sh` pins the official MindSpore Lite 2.6.0 Linux x64 converter archive:

```text
https://ms-release.obs.cn-north-4.myhuaweicloud.com/2.6.0/MindSpore/lite/release/linux/x86_64/mindspore-lite-2.6.0-linux-x64.tar.gz
SHA-256 DC70D965C440ECAB9692FD2DD7362E967D79E92CCB0FF632AC021D25D2AF9C9E
converter_lite --fmk=TFLITE --modelFile=<source> --outputFile=<output> --saveType=MINDIR_LITE --optimize=general --fp16=off
```

An independent generator run reproduced all three exact source hashes. The conversion script verifies every source and output hash before copying the stable artifacts. Reproducibility is pinned to the recorded tool versions rather than claimed across arbitrary TensorFlow or converter releases.

## Runtime and cache contract

- A candidate must expose exactly one float32 NHWC input shaped `[1,224,224,3]`, with `elementNum=150528` and `dataSize=602112`. Production inference also requires exactly 602,112 preprocessed bytes before calling the runtime.
- Before stable-cache publication, the native loader builds the candidate from its bytes and runs a deterministic bounded non-uniform probe through the same runtime path used by inference.
- The first consumed output must exist, be float32, have coherent element/data-size/shape metadata, be four-byte aligned, and contain between 1 and 262,144 floats (at most 1 MiB). Every decoded value must be finite.
- The same checks are repeated during production inference before any success output is returned. An invalid result becomes a terminal failure rather than partial or stale success.
- The selected runner reads the current file bytes and builds a fresh model on every queued run, so replacing the fixed `custom_model.ms` path cannot pin the previous model. A process-global Promise tail serializes users of the shared native runtime and recovers after rejection.
- Candidate validation happens before the atomic stable-cache write. Rejected non-finite content leaves the last-good file and inference result usable.
- DocumentPicker files are read in bounded 1 MiB chunks from the descriptor's advancing current pointer. Every CoreFileKit read uses relative offset zero; the reader's accumulated byte count is used only to place each chunk in the destination. Explicit short-read/overshoot checks and a 64 MiB file limit remain enforced.

## RED/GREEN evidence

Tests were added before implementation for malformed two-byte, NaN, oversized, and metadata-incoherent outputs; wrong input byte counts; pre-publication non-finite rejection; real validator wiring; same-URI reload; overlapping-run serialization; and exact chunked file reads. The extended RED run failed to compile because the new runtime/validator abstractions and constructor dependencies did not exist. Earlier RED assertions also demonstrated that malformed and non-finite outputs were accepted.

The review follow-up added direct count/data-size/shape metadata mismatch cases through a lazy output decoder. All three are rejected before its `readData` callback runs (`readDataCalls=0`). It also changed the file-reader fake to model CoreFileKit's advancing descriptor position and relative offset semantics. Before the production fix, both the existing five-byte short-read test and a `1,048,613`-byte exact-read oracle failed with `Selected file ended before its declared size`; Hvigor still returned 0, so complete output scanning remains mandatory. After the fix, the large oracle passes with `65,537`-byte backend short reads and byte-for-byte equality.

The fresh follow-up `hvigorw test --no-daemon` run returned 0 and printed `BUILD SUCCESSFUL in 36 s 503 ms`. An explicit scan of the complete output found zero `AssertException`, `ERROR`, or `FAILED` lines; Hvigor's exit code alone was not treated as sufficient evidence.

The permanent API24 test uses production cache, preprocessing, selected-file runner, service, and the three controlled main-module assets. It programmatically creates solid red and blue PNGs, checks UI event-loop progress during native work, rejects the non-finite replacement without losing the last-good model, publishes the inverted model to the same cache URI, and then restores the primary model.

The API24 x86_64 suite passed 2/2 in 643 ms. Its real CoreFileKit exact-read case crossed the 1 MiB boundary at `1,048,613` bytes with zero byte mismatches. The source and returned-copy SHA-256 values both matched `DED6BC08234E6A4AECE8FF14FFC2AC1F662602EAED4472146A5A9AC1A738A4A8`. The original production-runtime case also passed with:

- exact input floats: `150528`
- primary red output: `[1,0,0]`
- primary blue output: `[0,0,1]`
- red-vs-blue MAE: `0.6666666667`; maximum absolute difference: `1`
- UI timer ticks during work: `9`
- inverted model at the same URI, red output: `[0,1,1]`
- non-finite candidate rejected before publication: `true`
- primary model recovery and output equality: passed

## Production API24 UI evidence

The controlled 600-byte primary `.ms` file was sent to:

```text
/storage/media/100/local/files/Docs/Download/custom_channel_mean.ms
```

Host and device SHA-256 both matched `DB1A0A273DA0658155473FB391E95D027D0D5606C72FB2FFB18BFAE0FDC85409`. From the production Custom Model page, the system DocumentPicker path `浏览 -> 我的手机 -> Download` displayed `custom_channel_mean.ms` as 600 B. Selecting it returned to the application with `MindSpore 模型文件已就绪。`

The production PhotoPicker selected two existing Gallery images. Both requests returned to the page, used the cached selected model, and rendered the actual first-output values:

- image 1: 78 ms, `[0.331564, 0.582547, 0.633139]`
- image 2: 62 ms, `[0.050326, 0.043221, 0.044181]`

Both output panels reported `Model execution completed!`, and the two real Gallery inputs produced measurably different results. This UI evidence complements the controlled red/blue device oracle; it is not inferred from a mocked runner.

## Final arm64 gates and boundary

`scripts/build-ai-runtime-acceptance.ps1` returned 0 in 61.8 seconds with the tracked `arm64-v8a` profile. Fixture/source hashes, license and notice markers, layout/cache mutation guards, core assets, native ABI contracts, main HAP, ohosTest HAP, exact payload bytes, and main/test model isolation all pass. The main HAP contains the three controlled `.ms` assets; the ohosTest HAP contains no duplicated model assets.

The first final arm64 resource build stopped at `CompileResource` because Windows ReadOnly attributes copied from the newly created fixture files prevented deletion of a generated resource copy. A review follow-up encountered the same attribute only in the verified worktree's generated `entry/.test` directory. Clearing the attributes only on those scoped generated copies resolved the environment-only failure; no source-code or product-build workaround was added.

No arm64 physical-device inference is claimed. Runtime, DocumentPicker, PhotoPicker, UI responsiveness, same-path replacement, rejection, and recovery evidence is from the API24 x86_64 emulator; arm64 evidence is build, native-contract, and exact HAP verification.
