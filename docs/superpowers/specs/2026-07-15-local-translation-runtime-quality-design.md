# Local Translation Runtime Quality Design

## Context

The app already ships one offline Chinese-English model and runs it through
the production MindSpore Lite encoder, prefill, and cached decoder-step path.
The retained V5 continuation improved the fixed BiST diagnostic slightly, but
its audited practical-text score regressed from 34 to 29 passes for Chinese to
English and from 24 to 22 passes for English to Chinese. Fatal URL, identifier,
number, OCR-spacing, and proper-name corruption remains. Another undirected
training continuation is therefore not justified by the current evidence.

This increment optimizes the observable quality of the existing model without
adding a server, network fallback, second model, dictionary fallback, or larger
package. Real-device latency and memory validation remain deferred.

## Chosen Approach

Add a narrow production input policy around the existing model:

1. normalize OCR-style runs of separated ASCII letters before tokenization;
2. split exact protected spans from surrounding natural language;
3. translate only natural-language spans with the existing model;
4. concatenate protected spans byte-for-byte with translated spans and the
   existing newline separators.

Protected spans are deliberately limited to values whose translation would be
data corruption rather than localization:

- `http://` and `https://` URLs;
- email addresses;
- code-like identifiers that contain an underscore, or contain both an ASCII
  letter and digit with an internal `-`, `_`, `.`, `/`, or `:` separator.

Plain numbers, dates, natural-language names, and ordinary hyphenated words are
not protected in this increment. Their placement and grammar require model
context, and broad heuristics would silently change valid translations.

OCR normalization collapses a run only when it contains at least three
single-letter ASCII tokens. One normal space between letters is removed, while
two or more spaces retain a word boundary. For example,
`P L E A S E   K E E P` becomes `PLEASE KEEP`. Normal prose such as
`A B test` and non-ASCII text is unchanged.

## Alternatives Rejected

### Continue V5 BiST Training

The exact V5 continuation reduced validation loss and slightly improved BiST
BLEU/chrF2, but worsened the audited practical set in both directions and added
one fatal corruption. More of the same objective is not the smallest
evidence-backed next step.

### Replace The Model Or Add Direction-Specific Models

Larger or direction-specific models may improve quality but would change the
package-size, conversion, runtime, and acceptance boundaries. That conflicts
with the current small local-learning model constraint.

### Beam Search

Beam search keeps the same weights but multiplies decoder work and KV-cache
state. The current exported graphs are batch-one and the app has no device
latency evidence, so beam search is deferred until the lower-cost corruption
policy has been measured.

## Components And Data Flow

`TranslationInputPolicy.ets` owns pure normalization and segmentation. It
returns ordered segments tagged as `model` or `protected`. It has no model,
resource, or platform dependency.

`MindSporeLiteTranslationRunner` applies the policy after the production bundle
and tokenizer are loaded. Every `model` segment is encoded with the existing
`encodeTranslationText()` function and decoded through the existing serialized
session. Every `protected` segment is appended unchanged. Failure of any model
segment fails the whole request exactly as it does today.

The original source text remains `TextTranslationResult.sourceText`; only the
text passed into the model is normalized. Existing newline ownership and
request cancellation behavior remain unchanged.

## Host A/B Gate

Before production integration, a host-only evaluator runs the retained exact
V5 checkpoint against the fixed manual sources with the proposed policy. The
experiment is diagnostic and may not relabel the model as production-approved.

The policy is eligible for ArkTS integration only when all of the following are
true:

- URL, email, and code-identifier protected spans are reproduced exactly;
- automatic fatal corruptions do not increase in either direction;
- total automatic fatal corruptions decrease by at least one;
- unchanged ordinary-text controls produce the same model input as the greedy
  baseline;
- the model, tokenizer, conversion, and packaged archive hashes are unchanged.

If the host checkpoint or pinned environment is unavailable, implementation
stops at the pure policy tests and is not wired into production.

## Error Handling

- Empty or whitespace-only input keeps the existing failure behavior.
- A protected-only input succeeds by returning the exact protected content;
  this avoids corrupting a pasted URL or identifier.
- Invalid or incomplete URL-like text is treated as model text.
- Segment order is stable and concatenation is lossless apart from the explicit
  OCR-letter normalization.
- Model load, tensor, decode, or empty-output failures remain fail-closed; no
  protected-span path can turn a failed natural-language translation into a
  success.

## Testing

- Python unit tests define the host policy and prove OCR/protected-span edge
  cases before the A/B evaluator is run.
- The A/B report records the exact checkpoint, tokenizer, evaluator code,
  inputs, baseline outputs, policy outputs, metrics, and hashes.
- ArkTS Hypium tests mirror the approved policy fixture and cover mixed leading,
  trailing, adjacent, protected-only, newline, and unchanged-prose cases.
- Existing 473 host tests, translation package verification, UI parity guards,
  and HAP acceptance remain required after integration.

## Non-Goals

- No new training run in this increment.
- No manual-set examples are added to training data.
- No production-quality promotion claim.
- No network service, dictionary fallback, second model, beam search, or model
  architecture change.
- No real-device performance or accuracy claim.

## Success Criteria

The increment is complete when the pinned host A/B gate passes, the identical
policy is integrated into the ArkTS production runner, all focused and full
host checks pass, the translation package hashes remain unchanged, and the
remaining semantic/model limitations are documented honestly.
