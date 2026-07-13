# Translation runtime licenses and notices

## Bidirectional student model

The shipped MindSpore Lite translation graphs are the project-produced
Chinese-English bidirectional student and are distributed under Apache-2.0.
They derive from `Helsinki-NLP/opus-mt_tiny_zho-eng` revision
`4ee3a9342aae4ca6fbae82c930b5dccff5dd68dd`, whose model card declares
Apache-2.0: https://huggingface.co/Helsinki-NLP/opus-mt_tiny_zho-eng

The English-Chinese distillation teacher was
`Helsinki-NLP/opus-mt-en-zh` revision
`408d9bc410a388e1d9aef112a2daba955b945255`, whose model card declares
Apache-2.0. Teacher weights are not shipped.

The BiST parallel training data is CC-BY-SA-4.0. Dataset rows are not shipped;
the pinned dataset identity and attribution are recorded in
`tools/translation/manifests/bist-v1.json`.

## SentencePiece tokenizer

`tokenizer.model` is `source.spm` from the pinned tiny OPUS-MT revision above.
SentencePiece is Copyright 2018 Google Inc. and licensed under Apache-2.0:
https://github.com/google/sentencepiece

## XZ decompressor

`libtranslation_archive.so` uses the decoder-only XZ Utils 5.8.3 build pinned
by `Mindspore_inhand_HarmonyOS/entry/src/main/cpp/translation_xz/XZ_BUILD_MANIFEST.json`.
XZ Utils files use the licenses described by the imported upstream `COPYING`
file at `Mindspore_inhand_HarmonyOS/entry/src/main/cpp/translation_xz/third_party/xz/COPYING`.

