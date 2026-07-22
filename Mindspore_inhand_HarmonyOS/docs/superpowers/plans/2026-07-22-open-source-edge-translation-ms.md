# Open-Source Edge Translation Model Replacement Plan

> **Execution rule:** use test-first changes, one implementation owner, then a fresh independent review. Do not train a model, call a cloud translator, or add phrase-specific post-processing.

**Goal:** Replace the unapproved locally trained translation checkpoint with pinned open-source edge models, convert them to weight-quantized MindSpore Lite `.ms` graphs, and make both English-to-Chinese and Chinese-to-English work in the production Worker on the API 24 emulator.

**Selected conversion candidates:**

- English to Chinese: `Helsinki-NLP/opus-mt-en-zh@408d9bc410a388e1d9aef112a2daba955b945255`, Apache-2.0, Marian 6/6 layers, `d_model=512`, vocab 65001, upstream Tatoeba BLEU 31.4.
- Chinese to English: `Helsinki-NLP/opus-mt_tiny_zho-eng@4ee3a9342aae4ca6fbae82c930b5dccff5dd68dd`, Apache-2.0, Marian 6/2 layers, `d_model=256`, vocab 32001.

`DDDSSS/translation_en-zh` was rejected: its training dataset has no license metadata or exact generator provenance and contains visibly incorrect training pairs. Both selected candidates instead come from the Helsinki-NLP OPUS/Tatoeba model family with pinned upstream benchmark and license evidence. A successful conversion is still not by itself production approval.

## Acceptance contract

1. No locally trained weight, online service, phrase dictionary, or output rewrite is used.
2. Every upstream repository, revision, file size, SHA-256, architecture value, license, and notice is pinned and verified before export.
3. PyTorch, ONNX, and `.ms` decoding agree on the fixed bilingual sentence corpus. English-to-Chinese uses the upstream `num_beams=4` generation contract; Chinese-to-English remains greedy. The corpus includes:
   - `hello world` preserves the greeting and world meaning in Chinese without adjacent repetition;
   - report/confidential/Monday remains complete;
   - door/window remains complete;
   - weather remains complete;
   - the corresponding Chinese sentences produce meaningful English.
4. Conversion uses W8 weight quantization and records graph sizes, tensor contracts, parity, and 100-step finite cache evidence.
5. Translation stays inside the persistent Worker. The UI thread exchanges only transferable request/result data.
6. The Worker routes by target language and lazily loads only one direction at a time. Switching direction deterministically replaces the Worker so the larger model is not retained beside the other direction.
7. The final dual-ABI HAP builds, installs, runs both directions on the x86_64 API 24 emulator, and does not regress the other nine routes.
8. Documentation must distinguish technical pass, model-quality pass, and release-license approval. `productionPromotionAllowed` cannot become true without all three.

## Task 1: Pin candidates and add failing source/quality guards

**Files:** `tools/translation/manifests/`, `tools/translation/verify_translation_package.py`, a focused new guard under `scripts/`, translation reports.

1. Add RED tests that reject an unpinned revision, wrong checkpoint/tokenizer hashes, missing Apache notices, missing direction metadata, and any local-learning approval record.
2. Add a reference-inference fixture containing source sentences, target language, raw expected semantic tokens, and captured upstream outputs. It must test completeness and language purity without requiring one arbitrary Chinese wording.
3. Pin the two candidate revisions and artifacts. Record the rejected DDDSSS provenance/quality evidence so it cannot silently replace the approved source later.

## Task 2: Parameterize the Marian exporter

**Files:** `tools/translation/export_marian_smoke.py` and focused exporter tests.

1. Add RED profiles for 2- and 6-layer decoders and assert exact input/output names and shapes.
2. Replace fixed layer counts, hidden size, head dimension, vocab size, pad/start IDs, and maximum length with validated immutable profile values.
3. Keep the existing encoder/prefill/fixed-cache-step architecture. Generate cache tensors and names by the validated decoder layer count.
4. Export both candidates to isolated external build directories. Verify PyTorch-to-ONNX encoder, prefill, multi-step cache, and greedy sentence parity.

**Stop condition:** if the standard Marian wrappers cannot export either pinned checkpoint without unsupported custom logic or sentence parity, reject the candidate before changing application code.

## Task 3: Convert ONNX graphs to W8 `.ms`

**Files:** reproducible conversion script/config, conversion manifest/report, package verifier.

1. Pin a MindSpore Lite converter version outside the repository and verify its archive hash.
2. Convert all six graphs with `WEIGHT_QUANT`, 8 bits, `minWeightSize=0`, `minWeightChannel=0`.
3. Run `.ms` tensor-contract inspection, PyTorch/ONNX/`.ms` numerical parity, 100-step finite-cache checks, greedy Chinese-to-English parity, and four-beam English-to-Chinese parity.
4. Measure actual graph, archive, and peak host inference memory. Replace legacy single-model 32/60 MiB limits only with measured, explicit global and per-direction limits.

**Stop condition:** reject the pair if the converter fails, token parity falls below the existing 99% cache-loop contract, the archive exceeds the measured HAP budget, or emulator RSS cannot safely hold one active direction.

## Task 4: Package two independent tokenizer/model directions

**Files:** translation rawfiles, tokenizer generator/runtime, `TranslationModelManifest.ets`, archive/package scripts and guards.

1. Add manifest schema v2 with exact `en` and `zh` target records. Each record owns its vocabulary, source tokenizer, target tokenizer, three graphs, checksums, architecture, and upstream approval evidence.
2. Generate independent tokenizer runtimes from each candidate's source/target SentencePiece files. Add the upstream-required `>>cmn_Hans<<` source prefix only for English-to-Chinese.
3. Package the six `.ms` files and two tokenizer pairs into one verified archive. Preserve both arm64-v8a and x86_64 decompressor libraries.
4. Add corruption, swapped-direction, wrong-vocab, wrong-layer-count, archive traversal, and size-budget tests.

## Task 5: Route and lazily load in the Worker

**Files:** `TranslationWorkerRuntime.ets`, `MindSporeLiteTranslationRunner.ets`, tokenizer/session code, Worker client/service tests.

1. Add RED tests for target-to-direction routing, dynamic 2/6-layer cache binding, repeated requests reusing a direction, and direction switches replacing the Worker.
2. Make the tensor runner derive cache arrays and bindings from the validated direction manifest. Implement four-beam search only for the manifest direction that requests it; keep the existing greedy path for the tiny model.
3. Initialize only metadata in the Worker; load the requested direction on first use. On a target-direction switch, terminate and recreate the Worker so model buffers and native models are released together.
4. Keep FIFO ordering, timeouts, stable errors, and UI-thread isolation unchanged.

## Task 6: Device and full-product verification

1. Run focused LocalUnit and package guards, scanning logs because Hvigor can return zero after assertion failures.
2. Run a fresh dual-ABI acceptance build and verify exact native payloads.
3. Install the produced unsigned main/test HAPs on the API 24 x86_64 emulator.
4. Run TranslationNative with an explicit timeout, both directions, repeated requests, direction switches, OCR input, and record latency/RSS.
5. Use the production page to verify the bilingual fixed sentences and capture screenshots/layout evidence.
6. Run all ten routes again. Required result: 10 PASS, 0 FAIL, 0 crash/white screen.
7. Commit the functional repair as `fix(text-translation): use open-source edge models`, then request an independent spec/quality review. Apply any Critical/Important findings in a separate follow-up commit.
