# Translation runtime licenses and notices

## Open-source OPUS-MT model pair

The shipped English-to-Chinese MindSpore Lite graphs are converted from
`Helsinki-NLP/opus-mt-en-zh` revision
`408d9bc410a388e1d9aef112a2daba955b945255` under Apache-2.0.

The shipped Chinese-to-English MindSpore Lite graphs are converted from
`Helsinki-NLP/opus-mt_tiny_zho-eng` revision
`4ee3a9342aae4ca6fbae82c930b5dccff5dd68dd` under Apache-2.0.

Exact source hashes, notices, and conversion evidence are pinned under
`tools/translation/manifests/`. No locally trained weights or training dataset
is included.

## Tokenizer data

TTOK2 tables are deterministic runtime encodings of the pinned upstream
SentencePiece and vocabulary files. SentencePiece is Copyright 2018 Google
Inc. and licensed under Apache-2.0.

## XZ decompressor

The decoder-only native wrapper uses XZ Utils 5.8.3 under the licenses in the
imported upstream `COPYING` file.
