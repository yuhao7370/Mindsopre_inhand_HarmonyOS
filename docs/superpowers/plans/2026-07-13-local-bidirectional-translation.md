# Local Bidirectional Translation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the finite offline phrase dictionary with one compact, fully local Chinese↔English translation model that handles arbitrary new text and OCR output on HarmonyOS.

**Architecture:** Train one direction-token-conditioned tiny Marian checkpoint, export fixed-shape encoder/prefill/decode graphs, weight-quantize them for MindSpore Lite, and drive SentencePiece plus greedy KV-cache decoding from ArkTS. The existing `TextTranslationRunner`, Android target-language rule, OCR chaining, copy behavior, and request-generation protection remain intact. Full training and production wiring are gated on all three ONNX→MindSpore prototype graphs passing converter, benchmark, finite-value, multi-token cache, and 35 MiB package-size checks.

**Tech Stack:** Python 3.9, PyTorch, Transformers, ONNX opset 17, MindSpore Lite 2.8 converter/benchmark, SentencePiece Unigram, BiST, FLORES+, ArkTS, `@kit.MindSporeLiteKit`, Hypium, DevEco/Hvigor.

## Global Constraints

- Scope is only Chinese↔English; there is no network or server fallback.
- Base checkpoint is `Helsinki-NLP/opus-mt_tiny_zho-eng@4ee3a9342aae4ca6fbae82c930b5dccff5dd68dd`.
- BiST revision is `aca6be897afc319f779009379c8b849c1eb8d63e`; FLORES+ revision is `b3a5298db5721c8a682e7ef00a37fcc9ab522757`.
- Token IDs: `EOS=0`, `UNK=1`, `PAD/decoder_start=32000`, `<2en>=32001`, `<2zh>=32002`; vocab size `32003`.
- Tokenizer is SentencePiece Unigram with `nmt_nfkc`, dummy prefix, whitespace removal, and escaped whitespace.
- Input/output maximum is 128 tokens; fixed shapes only; 2 decoder layers, 8 heads, head dimension 32.
- Greedy decoding and argmax stay in ArkTS; no beam search.
- Total packaged translation model assets must be ≤35 MiB.
- Never treat `LocalTextTranslationRunner` output as production model inference.
- Preserve unrelated user changes, especially `docs/harmonyos-platform-differences.md`.

---

## File Structure

- `tools/translation/requirements.lock.txt`: pinned host ML dependencies.
- `tools/translation/export_marian_smoke.py`: fixed encoder/prefill/decode wrappers and ONNX export.
- `tools/translation/convert_mindspore.ps1`: converter, quantization, benchmark, tensor contract, and size gate.
- `tools/translation/prepare_bist.py`: deterministic dataset filtering/splitting.
- `tools/translation/train_bidirectional.py`: bounded bidirectional fine-tuning.
- `tools/translation/evaluate_translation.py`: FLORES+/manual metrics and report.
- `Mindspore_inhand_HarmonyOS/entry/src/main/resources/rawfile/models/translation/`: three models, tokenizer, manifest, hashes, and notices.
- `Mindspore_inhand_HarmonyOS/entry/src/main/ets/services/ai/TinyTranslationTokenizer.ets`: normalization, segmentation, IDs, and decode.
- `Mindspore_inhand_HarmonyOS/entry/src/main/ets/services/ai/TranslationModelManifest.ets`: asset paths, token/tensor contract, and manifest validation.
- `Mindspore_inhand_HarmonyOS/entry/src/main/ets/services/ai/MindSporeLiteTranslationRunner.ets`: model cache and autoregressive state machine.
- `Mindspore_inhand_HarmonyOS/entry/src/test/TranslationModelUnit.test.ets`: focused host tests.

### Task 1: Pass the Three-Graph ONNX→MindSpore Prototype Gate

**Files:**
- Create: `tools/translation/requirements.lock.txt`
- Create: `tools/translation/export_marian_smoke.py`
- Create: `tools/translation/convert_mindspore.ps1`
- Create: `tools/translation/contracts/translation-v1.json`
- Create: `tools/translation/fixtures/smoke.zh.txt`
- Create: `tools/translation/fixtures/smoke.en.txt`

**Interfaces:**
- Produces: fixed ONNX and `.ms` prototype graphs with the exact names/shapes from the design spec.
- Gate: all graphs convert, benchmark, remain finite, decode multiple tokens, and estimate ≤35 MiB packaged quantized size.

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

Use a fixed wrapper that constructs additive mask shape `[1,1,1,128]` directly instead of the Transformers dynamic mask helper. Replace attention Softmax with stable `ReduceMax → Sub → Exp → ReduceSum → Div`. Export opset 17, run ONNX Runtime, and require finite outputs plus `max_abs <= 1e-5` against PyTorch before conversion.

- [ ] **Step 3: Convert and benchmark encoder**

```powershell
converter_lite --fmk=ONNX --modelFile=encoder.onnx `
  --outputFile=encoder --saveType=MINDIR_LITE --optimize=general
benchmark --modelFile=encoder.ms --inDataFile=encoder_inputs.bin `
  --inputShapes=input_ids:1,128`;attention_mask:1,128
```

Expected: converter exit 0; benchmark exit 0; output `FLOAT32 [1,128,256]` with no NaN/Inf; against ONNX Runtime require `max_abs <= 0.02` and `mean_abs <= 0.002` for all-valid and half-padding masks.

- [ ] **Step 4: Export and convert prefill/step**

Use fixed full-size cache tensors `[1,8,128,32]` and an explicit integer `decoder_position` update. Run `decoder_step` for at least five tokens with one retained cross cache and evolving self caches. Assert every logits/cache output is finite and matches PyTorch/ONNX Runtime within `1e-4` before quantization.

- [ ] **Step 5: Run weight quantization and the package-size gate**

Use the exact 8-bit config from the design spec. Require ≥99% token argmax agreement over 100 fixture steps and total `encoder.ms + decoder_prefill.ms + decoder_step.ms <= 35 MiB`. If either gate fails, stop this plan before Task 2 and revise the graph/package design in the approved spec.

- [ ] **Step 6: Commit the reproducible smoke harness**

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
- Create: `Mindspore_inhand_HarmonyOS/entry/src/main/resources/rawfile/models/translation/encoder.ms`
- Create: `Mindspore_inhand_HarmonyOS/entry/src/main/resources/rawfile/models/translation/decoder_prefill.ms`
- Create: `Mindspore_inhand_HarmonyOS/entry/src/main/resources/rawfile/models/translation/decoder_step.ms`
- Create: `Mindspore_inhand_HarmonyOS/entry/src/main/resources/rawfile/models/translation/tokenizer.model`
- Create: `Mindspore_inhand_HarmonyOS/entry/src/main/resources/rawfile/models/translation/vocab.json`
- Create: `Mindspore_inhand_HarmonyOS/entry/src/main/resources/rawfile/models/translation/tokenizer_runtime.json`
- Create: `Mindspore_inhand_HarmonyOS/entry/src/main/resources/rawfile/models/translation/manifest.json`
- Create: `Mindspore_inhand_HarmonyOS/entry/src/main/resources/rawfile/models/translation/SHA256SUMS`
- Create: `Mindspore_inhand_HarmonyOS/entry/src/main/resources/rawfile/models/translation/LICENSES.md`
- Create: `Mindspore_inhand_HarmonyOS/scripts/verify-translation-model.ps1`

**Interfaces:**
- Produces: complete local runtime assets and a build-stopping integrity guard.

- [ ] **Step 1: Run Task 1 export/conversion against the trained checkpoint**

Require float ONNX/PyTorch agreement, float `.ms` benchmark success, quantized ≥99% token agreement, exact tensor contract, and ≤35 MiB final graph total.

- [ ] **Step 2: Write and run the failing project asset guard**

Before copying assets, add a PowerShell guard that reads `manifest.json`, hashes every file, checks vocab/token IDs/tensor names/shapes, and exits nonzero. Expected first run: missing asset failure.

- [ ] **Step 3: Copy only runtime assets and rerun the guard**

Include identical `source.spm`/`target.spm` once as `tokenizer.model`, the extended vocab, a generated `tokenizer_runtime.json` with every piece ID/score/type plus the compiled `nmt_nfkc` normalization map, all three quantized graphs, fixed revisions/licenses, quality metrics, and file hashes.

- [ ] **Step 4: Commit**

```powershell
git add Mindspore_inhand_HarmonyOS/entry/src/main/resources/rawfile/models/translation `
  Mindspore_inhand_HarmonyOS/scripts/verify-translation-model.ps1
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

Validate `manifest.json` through `TranslationModelManifest.ets`. Load three rawfiles once with a module-level promise and `mindSporeLite.loadModelFromBuffer`, find tensors by manifest name, set typed buffers, execute encoder→prefill→step, perform ArkTS argmax, decode each chunk, and join separators. Return `ok:false` for empty output, model/tensor errors, NaN/Inf, or unsupported target. Export `resetTranslationModelCacheForTests()` and call it from the existing runtime cache reset hook.

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

Test image/camera OCR auto-translation, empty OCR, OCR failure versus translation failure, copy, repeated clicks, old-generation suppression, page exit, exact newline preservation, and operation with network disabled. Add target-side tests that load all three real `.ms` files, decode at least five tokens in both directions, and assert contract/finite outputs.

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

With Wi-Fi and cellular disabled, translate at least 20 new sentences in each direction plus gallery/camera OCR. On Mate 60 Pro require cold load ≤3 seconds, 32 output tokens ≤5 seconds, peak RSS delta ≤250 MiB, and total translation assets ≤35 MiB.

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
