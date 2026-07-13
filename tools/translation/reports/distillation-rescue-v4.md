# English-to-Chinese distillation rescue v4

Status: `GENERATION_IN_PROGRESS_DO_NOT_PROMOTE`

## Immutable inputs

- Teacher: `Helsinki-NLP/opus-mt-en-zh@408d9bc410a388e1d9aef112a2daba955b945255`, Apache-2.0.
- Teacher weights: 312,087,009 bytes, SHA-256 `69a1d6ec829cee349360b3b677ac0aa99a7d88822d1a6578370029efffdca3f5`.
- Exact language prefix: `>>cmn_Hans<<`, token ID `[5]`.
- Student baseline: optimizer step 16,878, model SHA-256 `a7603325361de12f35ebc660c861c648a1f7293b31174280b32bbea34d9f491a`.
- Source: the approved T2 `en-zh.train.jsonl` only, 90,000 rows, 36,670,761 bytes, SHA-256 `20b908acd71a734f8252c383c5cd2f0bf476214809d0f64cfcc50c1cb5e5670e`.
- No validation, test, manual-audit, or FLORES row is used for distillation or training.

## Deterministic generation contract

Generation uses FP16, four beams, no sampling, renormalized logits, and a maximum of 128 output tokens. Each fixed 512-row chunk is sorted by teacher source-token length and original row ID for inference, then restored to original ID order before its canonical JSONL is atomically persisted. Batch size is fixed to 64 for the initial run and every resume; the runner rejects a different batch because batch 64 and 128 produced different token rows during the probe.

The 512-row throughput probe measured:

| Batch | Rows/s | Peak CUDA memory | Teacher | Original fallback | Hard fail |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 64 | 6.9262 | 1.848 GB | 456 | 56 | 0 |
| 128 | 6.1169 | 3.546 GB | 456 | 56 | 0 |

Batch 64 was 13.23% faster and is the immutable selected batch. FP16 and FP32 returned identical token rows for 118/128 precision-probe inputs; this is diagnostic evidence rather than a claim of cross-precision identity.

The eight retained probe timers total 390.515 seconds exactly: initial FP32 batch 64, two FP16/FP32 precision runs, FP16 capacity batch 256, the corrected FP16/FP32 precision pair, and sorted FP16 batches 64/128. Retained teacher loading, warmup, and failed-retry process wall adds 287.385 observed seconds. The immutable actual probe/load ledger is therefore 677.9 seconds; no throughput estimate replaces this actual value in the budget gate.

## Target provenance policy

Teacher targets must pass the student structural/length contract and the conservative source-target number and URL gate. A rejected teacher target falls back to the exact original approved T2 target only if that original target passes the structural/length contract. The original fallback is intentionally not rejected by the source-target regex gate: the strict regex can falsely reject valid dates and Chinese-number translations.

Every fallback receives a canonical sidecar entry containing its row ID, source hash, and `originalPreservationWarnings`. Number and URL differences are audit-only warnings. They do not alter the source, target, target origin, or row order. The final manifest pins the sidecar hash and records `fallbackWithPreservationWarnings`, `number`, and `url` totals. Offline verification recomputes every warning and requires byte-identical sidecar and manifest statistics.

A hard failure means both the generated teacher target failed its applicable validation and the exact original target failed the structural/length target contract. Hard failures stop generation and are never silently omitted.

## Bounded rescue contract

The rescue starts from the exact step-16,878 student weights with a reset AdamW optimizer. It keeps the original 90,000-row Chinese-to-English view and replaces only the English-to-Chinese training targets with the distilled/fallback view, preserving deterministic 1:1 alternation. Training uses FP16, logical and physical batch 32, accumulation 4, learning rate `1e-5`, weight decay `0.01`, label smoothing `0.1`, and 100 warmup optimizer steps. Rescue validation occurs at steps 500, 1,000, and the epoch-one final step. A rescue checkpoint replaces the baseline only on strictly lower combined validation loss.

The cumulative ceiling is 43,200 GPU seconds and includes the prior 13,924.157-second baseline, the 677.9-second actual probe/load ledger, actual teacher generation, and rescue training/evaluation. Before every generation chunk, the runner requires baseline + probe/load actual + generation actual + the 2,400-second rescue reserve to remain at or below the ceiling. Epoch two is permitted only if epoch-one manual evaluation reaches at least 33/50 English-to-Chinese passes with at most two fatal rows and retains at least 32/50 Chinese-to-English passes. Promotion thresholds remain unchanged.

Final generation counts, hashes, elapsed time, rescue metrics, and the promotion decision must come from verified retained artifacts; this report does not claim them while generation is running.
