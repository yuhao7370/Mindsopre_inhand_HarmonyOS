# Tiny Marian bidirectional translation report

Status: `T3_QUALITY_BLOCKED`

## Outcome

The single direction-token-conditioned Marian checkpoint completed the bounded 12-epoch run and remained stable and improving on BiST validation. It is not promoted: the exact FLORES+ test is access-gated, both 50-row manual directions are below 45 passes, and both contain fatal numeric, URL, or identifier corruption. No FLORES substitute, threshold change, cloud fallback, dictionary, extra model, or unapproved training amendment was used.

The optimizer-independent selected checkpoint, exact resumable state, logs, generated outputs, and audit artifacts remain under `%TEMP%/translation-t3-marian`. Bulk weights, optimizer state, caches, datasets, and generated evaluation JSONL are intentionally not committed.

## Reproducible contract

- Base: `Helsinki-NLP/opus-mt_tiny_zho-eng@4ee3a9342aae4ca6fbae82c930b5dccff5dd68dd`.
- Data: `Mxode/BiST@aca6be897afc319f779009379c8b849c1eb8d63e`, exact six T2 artifacts verified before every run.
- One shared 6-encoder/2-decoder Marian model; d_model 256, FFN 1536, 8 heads, vocabulary 32003, max 128.
- Token IDs: EOS 0, UNK 1, PAD/decoder start 32000, `<2en>` 32001, `<2zh>` 32002.
- Seed 20260713; FP16 CUDA; AdamW 3e-5, weight decay 0.01, label smoothing 0.1, warmup 1000.
- Logical batch 32 per direction, 1:1 deterministic alternation, accumulation 4, effective batch 128. The RTX 2070 fit physical batch 32 without subdivision.
- Validation every absolute 1000 optimizer steps, two non-improving evaluations for early stop, strict lower-loss checkpoint replacement.
- The evidence amendments changed only total epoch limit: 4, then 8, then 12. The original 12-GPU-hour ceiling and every quality threshold remained unchanged.
- A stopped v3 launch reached and durably saved step 11300 under the former 100-step resume cadence. The resume cadence was then TDD-changed to 500 steps to reduce I/O, and the exact step-11300 model/optimizer/scaler/RNG cursor continued. No optimizer state was fabricated or rolled back. The final training report records 13924.157 seconds; smoke plus the discarded unsaved diagnostic launch keep observed GPU work below four hours, well inside the unchanged 12-hour ceiling.

## Smoke and training evidence

The real 20-step smoke used exactly 64 examples per direction. Both direction prefixes produced finite values. Its first-five mean loss was 10.977557468414307 and final-five mean was 9.40162913799286, so the material-drop gate passed. Peak allocated CUDA memory was 2,909,094,912 bytes.

The full run stopped at the 12-epoch limit:

- Optimizer steps: 16878; logical batches: 67512.
- Best and final validation loss: 3.7039039318084717 at step 16878.
- Training elapsed: 13924.157 seconds.
- Peak allocated CUDA memory: 2,384,856,064 bytes.
- GPU: NVIDIA GeForce RTX 2070, 8,589,475,840 bytes; torch 2.5.1+cu121; CUDA 12.1.
- Nondeterministic exceptions: none recorded.

Validation loss continued to fall at every v3 evaluation: 3.843734888839722 at 12000, 3.8089170692443846 at 13000, 3.780145908355713 at 14000, 3.750305261039734 at 15000, 3.7268042890548707 at 16000, and 3.7039039318084717 at 16878. Direction-specific final validation losses were 3.2650395484924317 for zh-en and 4.142768315124512 for en-zh; their exact mean is 3.7039039318084717.

The selected model is 68,702,684 bytes with SHA-256 `a7603325361de12f35ebc660c861c648a1f7293b31174280b32bbea34d9f491a`. The portable file inventory and all selected-file hashes are in `manifests/marian-checkpoint-v1.json`.

## Evaluation evidence

FLORES+ is pinned to `openlanguagedata/flores_plus@b3a5298db5721c8a682e7ef00a37fcc9ab522757`, exact paths `devtest/cmn_Hans.jsonl` and `devtest/eng_Latn.jsonl`. An unauthenticated exact-revision request returned HTTP 401 `GatedRepoError`: access is restricted and authentication is required. The files were not available locally, so FLORES metrics remain absent and the gate fails closed.

The BiST test split is reported only as a diagnostic, never as FLORES or checkpoint selection evidence. With 5000 rows per direction, greedy max-128 decoding, deterministic smallest-ID ties, and sacreBLEU 2.4.3:

| Direction | BLEU | chrF2 |
| --- | ---: | ---: |
| zh-en | 24.88509876073252 | 51.8995801970156 |
| en-zh | 30.993262133451687 | 28.374817170642853 |

BLEU signatures use `tok:13a` for zh-en and `tok:zh` for en-zh; both chrF2 signatures use `nc:6|nw:0|space:no|version:2.4.3`.

All 100 manual rows have source, reference, generated output, explicit pass/fail, reason, and audited fatal-corruption list in the retained `manual-audited-step16878-v1.jsonl` artifact.

| Direction | Passed | Required | Fatal rows | Failed IDs |
| --- | ---: | ---: | ---: | --- |
| zh-en | 34/50 | 45/50 | 5 | 1, 5, 16, 17, 20, 21, 22, 27, 29, 30, 33, 34, 35, 36, 42, 43 |
| en-zh | 25/50 | 45/50 | 7 | 53, 57, 61, 63, 64, 65, 67, 69, 70, 71, 73, 74, 75, 80, 82, 83, 84, 85, 88, 89, 91, 94, 97, 99, 100 |

The recurring failures are OCR-like spacing, incomplete target-language conversion, wrong lexical sense, missing dates/frequency, URL destruction, numeric role changes, and brand or identifier alteration. These results independently block promotion even if FLORES access is later granted.

## Promotion decision

`T3_QUALITY_BLOCKED`. Preserve the selected checkpoint and evidence for an evidence-based rescue assessment. Do not convert or ship this checkpoint as the production translation asset and do not start another training amendment without an approved quality-rescue definition.

Final verification passed 31 T3 unit tests, Python AST parsing, six JSON files, the exact 100-row JSONL contract, `git diff --check`, and scans for secrets, machine paths, forbidden model/data extensions, trailing whitespace, and changed files over 1 MiB. The verification does not override the failed model-quality gates.
