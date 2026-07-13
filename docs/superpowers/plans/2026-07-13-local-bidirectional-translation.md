# Local Bidirectional Translation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the finite offline phrase dictionary with one compact, fully local Chinese↔English translation model that handles arbitrary new text and OCR output on HarmonyOS.

**Architecture:** Train one direction-token-conditioned tiny Marian checkpoint, export fixed-shape encoder/prefill/decode graphs, weight-quantize them for MindSpore Lite, ship the three W8 graphs as one verified solid `translation-models.tar.xz`, and drive SentencePiece plus greedy KV-cache decoding from ArkTS. A narrow pinned `liblzma` utility extracts the archive to app-private storage; it is not a second ML runtime. The existing `TextTranslationRunner`, Android target-language rule, OCR chaining, copy behavior, and request-generation protection remain intact. The three-graph prototype has passed converter, per-graph benchmark, finite-value execution and the reproducible W8 cache loop; full training and production wiring remain gated on bilingual quality, archive integrity, HAP asset size and target-device checks.

**Tech Stack:** Python 3.9, PyTorch, Transformers, ONNX opset 17, MindSpore Lite 2.8 converter/benchmark, SentencePiece Unigram, BiST, FLORES+, ArkTS, `@kit.MindSporeLiteKit`, pinned XZ Utils 5.8.3/minimal static `liblzma`, NAPI, Hypium, DevEco/Hvigor.

## Global Constraints

- Scope is only Chinese↔English; there is no network or server fallback.
- Base checkpoint is `Helsinki-NLP/opus-mt_tiny_zho-eng@4ee3a9342aae4ca6fbae82c930b5dccff5dd68dd`.
- BiST revision is `aca6be897afc319f779009379c8b849c1eb8d63e`; FLORES+ revision is `b3a5298db5721c8a682e7ef00a37fcc9ab522757`.
- Token IDs: `EOS=0`, `UNK=1`, `PAD/decoder_start=32000`, `<2en>=32001`, `<2zh>=32002`; vocab size `32003`.
- Tokenizer is SentencePiece Unigram with `nmt_nfkc`, dummy prefix, whitespace removal, and escaped whitespace.
- Input/output maximum is 128 tokens; fixed shapes only; 2 decoder layers, 8 heads, head dimension 32.
- Greedy decoding and argmax stay in ArkTS; no beam search.
- The complete shipped translation asset set in the HAP—one W8 archive, tokenizer/runtime assets, manifest/licenses/hashes, and the small decompressor—must be ≤35 MiB. The three raw `.ms` files, float/ONNX/checkpoint artifacts are not shipped.
- App-private extracted graphs may total about 55.5 MiB; track private-cache disk and runtime RSS separately from the shipped-asset gate.
- Never treat `LocalTextTranslationRunner` output as production model inference.
- Preserve unrelated user changes, especially `docs/harmonyos-platform-differences.md`.

---

## File Structure

- `tools/translation/requirements.lock.txt`: pinned host ML dependencies.
- `tools/translation/export_marian_smoke.py`: fixed encoder/prefill/decode wrappers and ONNX export.
- `tools/translation/convert_mindspore.ps1`: converter, quantization, benchmark, tensor contract, and W8 quality gate.
- `tools/translation/build_translation_archive.py`: reproducible solid TAR/XZ archive builder and strict member manifest.
- `tools/translation/build_xz_ohos.ps1`: pinned XZ source download/hash/build/import verification.
- `tools/translation/prepare_bist.py`: deterministic dataset filtering/splitting.
- `tools/translation/train_bidirectional.py`: bounded bidirectional fine-tuning.
- `tools/translation/evaluate_translation.py`: FLORES+/manual metrics and report.
- `Mindspore_inhand_HarmonyOS/entry/src/main/resources/rawfile/models/translation/`: one W8 `translation-models.tar.xz`, tokenizer/runtime assets, manifest, hashes, and notices; never the three raw graphs.
- `Mindspore_inhand_HarmonyOS/entry/src/main/cpp/translation_xz/`: narrow bounded streaming decompressor and NAPI wrapper.
- `Mindspore_inhand_HarmonyOS/entry/src/main/ets/services/ai/TinyTranslationTokenizer.ets`: normalization, segmentation, IDs, and decode.
- `Mindspore_inhand_HarmonyOS/entry/src/main/ets/services/ai/TranslationModelManifest.ets`: asset paths, token/tensor contract, and manifest validation.
- `Mindspore_inhand_HarmonyOS/entry/src/main/ets/services/ai/MindSporeLiteTranslationRunner.ets`: model cache and autoregressive state machine.
- `Mindspore_inhand_HarmonyOS/entry/src/test/TranslationModelUnit.test.ets`: focused host tests.

### Task 1: Pass the Three-Graph ONNX→MindSpore Prototype Gate

**Files:**
- Create: `tools/translation/requirements.lock.txt`
- Create: `tools/translation/export_marian_smoke.py`
- Create: `tools/translation/convert_mindspore.ps1`
- Create: `tools/translation/build_translation_archive.py`
- Create: `tools/translation/test_build_translation_archive.py`
- Create: `tools/translation/verify_translation_package.py`
- Create: `tools/translation/test_verify_translation_package.py`
- Create: `tools/translation/manifests/prototype-package-v1.json`
- Create: `tools/translation/contracts/translation-v1.json`
- Create: `tools/translation/fixtures/smoke.zh.txt`
- Create: `tools/translation/fixtures/smoke.en.txt`

**Interfaces:**
- Produces: fixed ONNX and `.ms` prototype graphs with the exact names/shapes from the design spec.
- Gate: all graphs convert, benchmark, remain finite, decode multiple tokens, and prove that the complete compressed shipped asset set can remain ≤35 MiB without degrading below W8.

- [ ] **Step 1: Lock the tensor contract before exporting**

`translation-v1.json` must list every input/output name, dtype, and shape. The encoder contract begins:

```json
{
  "version": 1,
  "vocabSize": 32003,
  "maxTokens": 128,
  "encoder": {
    "inputs": {
      "input_ids": [1, 128],
      "attention_mask": [1, 128]
    },
    "outputs": {
      "encoder_hidden_states": [1, 128, 256]
    }
  }
}
```

Add all prefill/step cache names exactly as the design spec; reject any generated graph that differs.

- [ ] **Step 2: Export encoder and verify numerical equality**

Use a fixed wrapper that constructs additive mask shape `[1,1,1,128]` directly instead of the Transformers dynamic mask helper. Replace attention Softmax with stable `ReduceMax → Sub → Exp → ReduceSum → Div`. Export opset 17 and require finite outputs. The retained FP16 prototype shows that a `1e-5` PyTorch↔ONNX CPU bound is not reproducible (`max_abs=0.0231934`); record that comparison diagnostically and keep the conversion gate on float MindSpore↔ONNX (`max_abs <= 0.02`, `mean_abs <= 0.002`) instead of silently changing graph precision.

- [ ] **Step 3: Convert and benchmark encoder**

```powershell
converter_lite --fmk=ONNX --modelFile=encoder.onnx `
  --outputFile=encoder --saveType=MINDIR_LITE --optimize=general
benchmark --modelFile=encoder.ms --inDataFile=encoder_inputs.bin `
  --inputShapes=input_ids:1,128`;attention_mask:1,128
```

Expected: converter exit 0; benchmark exit 0; output `FLOAT32 [1,128,256]` with no NaN/Inf; against ONNX Runtime require `max_abs <= 0.02` and `mean_abs <= 0.002` for all-valid and half-padding masks.

- [ ] **Step 4: Export and convert prefill/step**

Use host-managed self history `[1,8,127,32]`, one new self slot/output `[1,8,1,32]`, retained cross caches `[1,8,128,32]`, and an explicit integer `position_id`. Masks are INT32 in ONNX; ONNX floating tensors are FP16 while converted MindSpore runtime tensors are FP32. The final converter command for prefill/step must set NCHW input and output flags. Run `decoder_step` for at least five tokens with one retained cross cache and evolving self history. PyTorch↔ONNX FP16 comparison is diagnostic (the retained host stack reaches `max_abs=0.015625`); the technical numerical gate remains float MindSpore↔ONNX `max_abs <= 0.02`, `mean_abs <= 0.002`, plus finite tensors and exact W8 token agreement.

Measured prototype evidence: stable-softmax encoder, prefill, and fixed-cache step all convert and execute. Encoder all-mask error is `max/mean 0.0071133/0.0007997`; half-padding is `0.0146904/0.0010149`. The reproducible harness now makes ONNX Runtime, float MindSpore and W8 MindSpore agree on the prefill-plus-five-step sequence `[422,21,23,22,80,5]`; it binds tensors by exact names and fails closed on divergence. This is graph/runtime feasibility evidence only, not final bilingual quality.

- [ ] **Step 5: Run weight quantization and the package-size gate**

Use the exact fixed-bit W8 config from the design spec. Prototype measurements are: float `100.169 MiB`; fixed W8 `58,161,928 B / 55.468 MiB`, finite, per-graph benchmarkable and exact on the reproducible cache-loop fixture; dynamic W8 `56,629,192 B / 54.006 MiB`; W4 `32,877,504 B / 31.354 MiB`; mixed `30,739,720 B / 29.316 MiB`. W4 and mixed diverge tokens badly and are quality NO; there is no 4-bit/mixed production fallback. W8 remains the only quality candidate; final promotion still requires the trained-model quality gates below.

For the final trained checkpoint, require ≥99% token argmax agreement over 100 fixture steps. Build one solid W8 `translation-models.tar.xz`, then require the complete shipped HAP translation asset set—including archive, tokenizer/runtime, manifest/licenses/hashes, and decompressor—to be ≤35 MiB. Do not ship the three raw `.ms` files or float/ONNX/checkpoint artifacts.

- [ ] **Step 6: Reproduce and guard the archive**

Implement and test `build_translation_archive.py` here, before any task consumes it. It must create a deterministic TAR containing exactly canonical `encoder.ms`, `decoder_prefill.ms`, and `decoder_step.ms`, normalize member order/metadata, invoke an explicitly supplied host XZ Utils 5.8.3 executable as one solid CRC64 stream, and verify the resulting stream plus exact member names/sizes/SHA values. Reject other XZ versions, concatenated/trailing streams, links, paths, duplicates, and extras. Build twice in separate temporary directories and require byte-identical TAR and `.tar.xz` hashes.

Implement `verify_translation_package.py` and its tests in the same task. `prototype-package-v1.json` records the measured archive and actual prototype tokenizer/runtime/manifest/license/hash assets plus the reserved decompressor allowance; the verifier must sum the complete staged HAP translation asset set and fail above 35 MiB. Task 4 must rerun the same verifier over actual final assets with no allowance substituted for a real file. Pin XZ Utils 5.8.3 source SHA-256 `FFF1FFCF2B0DA84D308A14DE513A1AA23D4E9AA3464D17E64B9714BFDD0BBFB6` and tag commit `4b73f2ec19a99ef465282fbce633e8deb33691b3`; explicitly reject compromised 5.6.0/5.6.1. Task 1 may invoke a verified host XZ binary; the OHOS static `liblzma` build/import belongs to Task 4.

The legacy source-evidence archive is `25,073,516 B`, SHA-256 `1DBB6BA66FC7F5FBA777F38960E1D56FBC0AAB793C30B068020D1DCD0773BC7F`; its non-canonical TAR is `58,173,440 B`, SHA-256 `D305ED7D1FE5DF6E1019078646D3D8D9F43D4514345D166011BF2A70F95FBB84`. It is verified as immutable input evidence, not reproduced byte-for-byte. Rebuilding the same members with canonical names and normalized metadata produces deterministic TAR SHA-256 `23A3DD41E006A6A3E1A7C844E6E66B3F99A49A54ACCEED02B7EAF38D0108F3E5` and XZ SHA-256 `A942697ADA0EC6EC8C102AB898B43D931C31EE132112B2A11B95F2673C8B30EE`. Its W8 members are:

- `encoder_fixed_stable_w8.ms`: `16,109,400 B`, SHA-256 `317DB84237D67206AEC036CF4A5B6F8212E5F116C3682C1B3E1ED7916460B558`.
- `decoder_prefill1_stable_w8_nchw.ms`: `21,138,552 B`, SHA-256 `FBCBCBC50C89740EE4851BBE0DC397973F1A2905473237F0934E12497BF4084C`.
- `decoder_step_fixedcache_stable_w8_nchw.ms`: `20,913,976 B`, SHA-256 `333704F597B2C28CEB37DE7E61CBAA3B503D45FA84EA2D81F0A328408D8B4C33`.

This archive proves packaging only; generate the final archive only after bidirectional training and quality gates pass.

- [ ] **Step 7: Commit the reproducible smoke harness**

```powershell
git add tools/translation
git commit -m "build: validate tiny translation export pipeline"
```

### Task 2: Prepare the Deterministic Bidirectional Training Set

**Files:**
- Create: `tools/translation/prepare_bist.py`
- Create: `tools/translation/test_prepare_bist.py`
- Create: `tools/translation/config/training-v1.json`
- Create: `tools/translation/manifests/bist-v1.json`

**Interfaces:**
- Produces: 90k/5k/5k train/validation/test records per direction with immutable hashes.

- [ ] **Step 1: Write failing split and normalization tests**

```python
def test_split_bucket_is_big_endian_sha_prefix():
    digest = hashlib.sha256('你好\0hello'.encode('utf-8')).hexdigest()
    assert split_bucket('你好', 'hello') == int(digest[:8], 16) % 20

def test_direction_rows_are_not_swapped():
    assert training_row({'text_zh': '你好', 'text_en': 'hello'}, 'zh-en') == {
        'source': '你好', 'target': 'hello', 'direction_id': 32001
    }
```

- [ ] **Step 2: Run RED**

```powershell
python -m unittest tools.translation.test_prepare_bist -v
```

Expected: FAIL because `prepare_bist` is absent.

- [ ] **Step 3: Implement exact filtering and quotas**

Stream pinned shards in lexical order, apply SentencePiece `nmt_nfkc`, reject empty and lengths outside 3–120, deduplicate normalized pairs, compute the exact SHA bucket, and stop only after each direction reaches 90,000 train, 5,000 validation, and 5,000 test rows. Write JSONL plus SHA-256 for every output.

- [ ] **Step 4: Verify counts, hashes, and rerun determinism**

Run the preparer twice into separate temporary directories. Expected: identical file hashes and exact per-direction quotas.

- [ ] **Step 5: Commit scripts and manifests, not bulk data**

```powershell
git add tools/translation/prepare_bist.py tools/translation/test_prepare_bist.py `
  tools/translation/config/training-v1.json tools/translation/manifests/bist-v1.json
git commit -m "build: define bidirectional translation dataset"
```

### Task 3: Train and Evaluate the One Bidirectional Checkpoint

**Files:**
- Create: `tools/translation/train_bidirectional.py`
- Create: `tools/translation/test_train_contract.py`
- Create: `tools/translation/evaluate_translation.py`
- Create: `tools/translation/manual-eval-v1.jsonl`
- Create: `tools/translation/reports/translation-v1.md`

**Interfaces:**
- Consumes: Task 2 JSONL and the fixed base checkpoint.
- Produces: one checkpoint with vocab 32003 and a signed training/evaluation report.

- [ ] **Step 1: Write contract tests before training**

Assert config has seed `20260713`, batch 32, accumulation 4, learning rate `3e-5`, warmup 1000, weight decay 0.01, label smoothing 0.1, max 4 epochs, max 12 GPU hours, and new embedding rows initialized with `normal(0,0.02)`.

- [ ] **Step 2: Run a 20-step overfit smoke**

Train on 64 examples per direction and require training loss to decrease and both direction prefixes to generate finite logits. This catches swapped fields and token-ID mistakes before the bounded full run.

- [ ] **Step 3: Run the bounded training job**

Train FP16 with 1:1 direction batch alternation. Evaluate every 1000 steps, stop after two non-improving evaluations, four epochs, or 12 RTX 2070 GPU hours. Save only the lowest-validation-loss checkpoint plus optimizer-independent manifest.

- [ ] **Step 4: Evaluate exact quality gates**

Run sacreBLEU 2.4.3 on pinned FLORES+ devtest. Require zh→en BLEU ≥19.0 and chrF2 ≥49.0; en→zh BLEU ≥17.0 and chrF2 ≥40.0. Score the 50-item manual set per direction and require ≥45/50 with no fatal numeric/URL/proper-name corruption.

- [ ] **Step 5: Commit model report and checkpoint provenance**

Do not commit bulk training data. Commit the selected checkpoint only after Task 4 converts it successfully; at this step commit scripts, manual set, report, config, revision, and checkpoint SHA manifest.

```powershell
git add tools/translation
git commit -m "feat: train tiny bidirectional translator"
```

### Task 4: Export, Quantize, and Commit the Final Model Package

**Files:**
- Create: `Mindspore_inhand_HarmonyOS/entry/src/main/resources/rawfile/models/translation/translation-models.tar.xz`
- Create: `Mindspore_inhand_HarmonyOS/entry/src/main/resources/rawfile/models/translation/tokenizer.model`
- Create: `Mindspore_inhand_HarmonyOS/entry/src/main/resources/rawfile/models/translation/vocab.json`
- Create: `Mindspore_inhand_HarmonyOS/entry/src/main/resources/rawfile/models/translation/tokenizer_runtime.json`
- Create: `Mindspore_inhand_HarmonyOS/entry/src/main/resources/rawfile/models/translation/manifest.json`
- Create: `Mindspore_inhand_HarmonyOS/entry/src/main/resources/rawfile/models/translation/SHA256SUMS`
- Create: `Mindspore_inhand_HarmonyOS/entry/src/main/resources/rawfile/models/translation/LICENSES.md`
- Create: `Mindspore_inhand_HarmonyOS/scripts/verify-translation-model.ps1`
- Create: `tools/translation/build_xz_ohos.ps1`
- Create: `Mindspore_inhand_HarmonyOS/entry/src/main/cpp/translation_xz/CMakeLists.txt`
- Create: `Mindspore_inhand_HarmonyOS/entry/src/main/cpp/translation_xz/translation_xz_extract.cpp`
- Create: `Mindspore_inhand_HarmonyOS/entry/src/main/cpp/translation_xz/translation_xz_napi.cpp`
- Create: `Mindspore_inhand_HarmonyOS/entry/src/main/ets/native/translation_xz/index.d.ts`

**Interfaces:**
- Produces: complete local runtime assets and a build-stopping integrity guard.

- [ ] **Step 1: Run Task 1 export/conversion against the trained checkpoint**

Require float ONNX/PyTorch agreement, float `.ms` benchmark success, W8 ≥99% token agreement over 100 steps, exact tensor contract, and the approved FLORES+/manual bilingual quality gates. Use NCHW input/output converter flags for both cache graphs. Do not generate the final archive before these gates pass.

- [ ] **Step 2: Write and run the failing project asset guard**

Before copying assets, add a thin project PowerShell guard that invokes Task 1's `verify_translation_package.py` for archive/member/package integrity and then checks the Harmony manifest's vocab/token IDs and tensor names/shapes. Do not reimplement archive construction or package-size accounting in Task 4. The manifest must still describe the three extracted graph names, exact tensor contracts, sizes, and SHA-256 values. Expected first run: missing asset failure.

- [ ] **Step 3: Build and verify the bounded native extractor**

Build only minimal static `liblzma` with encoders, tools, and threads disabled; the arm64 API24 compile/link probe is GO. Stream rawfile FD/range into an app-private temp directory/file with compressed cap 32 MiB, output cap 60 MiB, liblzma memory cap 68 MiB, required CRC64, and no concatenated stream or trailing data. Strictly allow exactly regular `encoder.ms`, `decoder_prefill.ms`, and `decoder_step.ms`; reject links, paths, duplicates, extras, or any size/SHA mismatch. Atomically rename only after complete verification, clean partials, and key the cache by archive SHA.

- [ ] **Step 4: Copy only final runtime assets and rerun the guard**

Reuse Task 1's `build_translation_archive.py` against the final trained W8 graphs; do not create a second builder or packaging path. Copy identical `source.spm`/`target.spm` once as `tokenizer.model`, the extended vocab, a generated `tokenizer_runtime.json` with every piece ID/score/type plus the compiled `nmt_nfkc` normalization map, the resulting solid W8 archive, fixed revisions/licenses, quality metrics, and file hashes. Rerun Task 1's package verifier over the actual final archive, tokenizer/runtime, manifest/licenses/hashes, and built decompressor; no prototype size reservation is accepted at this gate. Exclude the three raw `.ms`, float/ONNX/checkpoint artifacts, and every W4/mixed candidate.

- [ ] **Step 5: Commit**

```powershell
git add Mindspore_inhand_HarmonyOS/entry/src/main/resources/rawfile/models/translation `
  Mindspore_inhand_HarmonyOS/scripts/verify-translation-model.ps1 `
  Mindspore_inhand_HarmonyOS/entry/src/main/cpp/translation_xz `
  Mindspore_inhand_HarmonyOS/entry/src/main/ets/native/translation_xz `
  tools/translation/build_xz_ohos.ps1
git commit -m "feat: add tiny bidirectional translation model"
```

### Task 5: Implement the ArkTS SentencePiece-Compatible Tokenizer

**Files:**
- Create: `Mindspore_inhand_HarmonyOS/entry/src/main/ets/services/ai/TinyTranslationTokenizer.ets`
- Create: `Mindspore_inhand_HarmonyOS/entry/src/test/TranslationModelUnit.test.ets`
- Modify: `Mindspore_inhand_HarmonyOS/entry/src/test/List.test.ets`

**Interfaces:**
- Produces: `encodeTranslationText(text,target): TranslationChunk[]`, `decodeTranslationTokens(ids): string`, and exact direction routing.

- [ ] **Step 1: Generate immutable Python SentencePiece golden fixtures**

Fixtures must cover Chinese, English, mixed text, full-width punctuation, ASCII punctuation, repeated whitespace, unknown Unicode, 127/128/129-token boundaries, multiple newlines, and both directions.

- [ ] **Step 2: Write failing Hypium tests**

Assert normalized pieces/IDs equal Python goldens; `<2en>/<2zh>` is the first ID; EOS precedes PAD; chunks never exceed 128; original newline count/order is restored; decode skips PAD/direction/EOS and replaces unknowns consistently.

- [ ] **Step 3: Run RED**

Run Hvigor tests. Expected: missing tokenizer module.

- [ ] **Step 4: Implement Unigram Viterbi encoding, normalization, and chunking**

Parse a text-exported piece table generated during Task 4 rather than implementing protobuf parsing in ArkTS. Implement `nmt_nfkc` with the exact generated normalization map, dummy `▁`, whitespace collapse, Unigram dynamic programming, unknown fallback ID 1, Android Unicode direction rule, and separator-preserving chunking.

- [ ] **Step 5: Run GREEN and commit**

```powershell
& 'C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat' test --no-daemon
git add Mindspore_inhand_HarmonyOS/entry/src/main/ets/services/ai/TinyTranslationTokenizer.ets `
  Mindspore_inhand_HarmonyOS/entry/src/test/TranslationModelUnit.test.ets `
  Mindspore_inhand_HarmonyOS/entry/src/test/List.test.ets
git commit -m "feat: add tiny translation tokenizer"
```

### Task 6: Implement the Multi-Graph MindSpore Greedy Decoder

**Files:**
- Create: `Mindspore_inhand_HarmonyOS/entry/src/main/ets/services/ai/TranslationModelManifest.ets`
- Create: `Mindspore_inhand_HarmonyOS/entry/src/main/ets/services/ai/MindSporeLiteTranslationRunner.ets`
- Modify: `Mindspore_inhand_HarmonyOS/entry/src/main/ets/services/ai/TextRecognitionService.ets`
- Modify: `Mindspore_inhand_HarmonyOS/entry/src/test/TranslationModelUnit.test.ets`

**Interfaces:**
- Implements: `TextTranslationRunner.translate(text,targetLanguage): Promise<TextTranslationResult>`.
- Produces: `runtimeSource: 'localModel'` on real model success, plus `resetTranslationModelCacheForTests()`.

- [ ] **Step 1: Extend the result contract and write fake-model tests**

Change `TextTranslationRuntimeSource` to `'offlineDictionary' | 'localModel'`. Define a small injectable `TranslationTensorSession` used by host tests. Test manifest parsing, one encoder call per chunk, one prefill, evolving positions/self caches, retained cross caches, stable argmax, EOS stop, 128-token stop, malformed tensor rejection, finite-value rejection, module-level model caching, and cache reset.

- [ ] **Step 2: Run RED**

Expected: missing runner/session and `localModel` type failure.

- [ ] **Step 3: Implement exact model loading and decode loop**

Validate `manifest.json` through `TranslationModelManifest.ets`. Ask the narrow native utility to stream, verify, and atomically cache the archive, then load the three verified app-private model files once with a module-level promise. Find tensors by manifest name, set typed buffers, execute encoder→prefill→step, perform ArkTS argmax, decode each chunk, and join separators. ArkTS remains responsible for tokenizer and greedy decoding; `liblzma` does decompression only. Return `ok:false` for archive/extraction, empty output, model/tensor, NaN/Inf, or unsupported-target errors. Export `resetTranslationModelCacheForTests()` and call it from the existing runtime cache reset hook.

- [ ] **Step 4: Run GREEN and commit**

```powershell
& 'C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat' test --no-daemon
git add Mindspore_inhand_HarmonyOS/entry/src/main/ets/services/ai/MindSporeLiteTranslationRunner.ets `
  Mindspore_inhand_HarmonyOS/entry/src/main/ets/services/ai/TranslationModelManifest.ets `
  Mindspore_inhand_HarmonyOS/entry/src/main/ets/services/ai/TextRecognitionService.ets `
  Mindspore_inhand_HarmonyOS/entry/src/test/TranslationModelUnit.test.ets
git commit -m "feat: run local bidirectional translation model"
```

### Task 7: Wire Production Translation, OCR, Offline UX, and Final Verification

**Files:**
- Modify: `Mindspore_inhand_HarmonyOS/entry/src/main/ets/services/ai/ImageClassificationRuntimeFactory.ets`
- Modify: `Mindspore_inhand_HarmonyOS/entry/src/main/ets/services/ai/AiService.ets`
- Modify: `Mindspore_inhand_HarmonyOS/entry/src/main/ets/features/runtime/FeatureWorkflowCatalog.ets`
- Modify: `Mindspore_inhand_HarmonyOS/scripts/build-hap.ps1`
- Modify: `Mindspore_inhand_HarmonyOS/entry/src/test/LocalUnit.test.ets`
- Modify: `Mindspore_inhand_HarmonyOS/entry/src/test/TranslationModelUnit.test.ets`
- Create: `Mindspore_inhand_HarmonyOS/entry/src/ohosTest/ets/test/TranslationModel.test.ets`
- Modify: `Mindspore_inhand_HarmonyOS/entry/src/ohosTest/ets/test/List.test.ets`
- Modify: `docs/harmonyos-platform-differences.md` only after preserving the existing user delta

**Interfaces:**
- Produces: production `translateText` backed by `localModel`, for direct text and OCR, with no network dependency.

- [ ] **Step 1: Write failing factory and workflow tests**

Assert default translation uses an injected local-model session, arbitrary unmapped sentences return `TEXT_TRANSLATION_DONE`, runtime source is `localModel`, text and OCR share the runner, copy returns translated text, and translation workflow does not report an Internet requirement.

- [ ] **Step 2: Replace dictionary production wiring**

`createHarmonyTextTranslationService()` must instantiate `MindSporeLiteTranslationRunner` by default and retain `LocalTextTranslationRunner` only for explicitly injected legacy/demo tests. `AiService` must label `localModel` success as normal completion, not dictionary fallback. Remove `internet` from only the translation workflow permissions; keep the app-level Internet permission for unrelated Web/resource features. Make `build-hap.ps1` call `verify-translation-model.ps1` before Hvigor.

- [ ] **Step 3: Verify OCR and page lifecycle**

Test image/camera OCR auto-translation, empty OCR, OCR failure versus translation failure, copy, repeated clicks, old-generation suppression, page exit, exact newline preservation, and operation with network disabled. Add target-side tests that extract the real archive, validate all three `.ms` files, decode at least five tokens in both directions, and assert contract/finite outputs. Also test archive SHA cache reuse, interrupted extraction cleanup, CRC/member/path/duplicate/trailing-data rejection, and size/memory caps.

- [ ] **Step 4: Run complete verification**

```powershell
& .\Mindspore_inhand_HarmonyOS\scripts\verify-translation-model.ps1
Push-Location .\Mindspore_inhand_HarmonyOS
& 'C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat' test --no-daemon
& .\scripts\build-hap.ps1
Pop-Location
git diff --check
```

Expected: model guard PASS, `Failure: 0, Error: 0`, HAP build PASS, no whitespace errors.

- [ ] **Step 5: Install and verify on target**

With Wi-Fi and cellular disabled, translate at least 20 new sentences in each direction plus gallery/camera OCR. On Mate 60 Pro measure real archive extraction and require cold load ≤3 seconds, 32 output tokens ≤5 seconds, and peak RSS delta ≤250 MiB. Require the complete HAP translation asset set ≤35 MiB; record the separate app-private extracted-cache disk usage (about 55.5 MiB). Until this arm64 target run exists, cold load, latency, RSS, extraction and private-cache measurements remain pending; host numbers are not device proof.

- [ ] **Step 6: Commit**

```powershell
git add Mindspore_inhand_HarmonyOS/entry/src/main/ets/services/ai `
  Mindspore_inhand_HarmonyOS/entry/src/main/ets/features/runtime/FeatureWorkflowCatalog.ets `
  Mindspore_inhand_HarmonyOS/scripts/build-hap.ps1 `
  Mindspore_inhand_HarmonyOS/entry/src/test `
  Mindspore_inhand_HarmonyOS/entry/src/ohosTest `
  docs/harmonyos-platform-differences.md
git commit -m "feat: enable offline Chinese English translation"
```
