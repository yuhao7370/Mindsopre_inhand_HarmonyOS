# Official Helsinki-NLP translation checkpoints

This conversion uses only the following pinned Hugging Face repositories:

- `Helsinki-NLP/opus-mt-en-zh@408d9bc410a388e1d9aef112a2daba955b945255`
- `Helsinki-NLP/opus-mt_tiny_zho-eng@4ee3a9342aae4ca6fbae82c930b5dccff5dd68dd`

Both repository model cards declare `Apache-2.0`. The original model-card
bytes and SHA-256 values are pinned in `open-source-edge-models-v1.json`.
English-to-Chinese follows the upstream `>>cmn_Hans<<` target prefix and
four-beam generation settings. Chinese-to-English uses deterministic greedy
generation.

`DDDSSS/translation_en-zh` is not an approved source because its training
dataset lacks license metadata and exact generator provenance, and inspected
training pairs contain incorrect translations.
