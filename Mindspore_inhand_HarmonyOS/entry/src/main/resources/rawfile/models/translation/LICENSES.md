# Translation runtime licenses and notices

## Open-source OPUS-MT model pair

The shipped English-to-Chinese MindSpore Lite graphs are converted from
`Helsinki-NLP/opus-mt-en-zh` revision
`408d9bc410a388e1d9aef112a2daba955b945255`. The upstream model card declares
Apache-2.0: https://huggingface.co/Helsinki-NLP/opus-mt-en-zh

The shipped Chinese-to-English MindSpore Lite graphs are converted from
`Helsinki-NLP/opus-mt_tiny_zho-eng` revision
`4ee3a9342aae4ca6fbae82c930b5dccff5dd68dd`. The upstream model card declares
Apache-2.0: https://huggingface.co/Helsinki-NLP/opus-mt_tiny_zho-eng

Exact upstream file hashes, revisions, notices, and conversion evidence are
recorded under `tools/translation/manifests/`. No locally trained weights,
distillation dataset, or phrase-specific rewrite is shipped.

## Tokenizer data

The archive's TTOK2 tables are deterministic runtime encodings of the pinned
`source.spm`, `target.spm`, and `vocab.json` files from the two model revisions
above. SentencePiece is Copyright 2018 Google Inc. and licensed under
Apache-2.0: https://github.com/google/sentencepiece

## XZ decompressor

`libtranslation_archive.so` uses the decoder-only XZ Utils 5.8.3 build pinned
by `Mindspore_inhand_HarmonyOS/entry/src/main/cpp/translation_xz/XZ_BUILD_MANIFEST.json`.
XZ Utils files use the licenses described by the imported upstream `COPYING`
file at `Mindspore_inhand_HarmonyOS/entry/src/main/cpp/translation_xz/third_party/xz/COPYING`.
