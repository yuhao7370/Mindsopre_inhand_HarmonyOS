# Image-classification device fixtures

These immutable test inputs are the TensorFlow-hosted example images used only
by `ImageClassificationNativeTest` to verify the on-device production model
decoder. They are not application assets.

| File | Source | Expected ImageNet label | SHA-256 |
| --- | --- | --- | --- |
| `grace_hopper.jpg` | https://storage.googleapis.com/download.tensorflow.org/example_images/grace_hopper.jpg | `military_uniform` | `A8CA6D734765703B09728AB47FE59F473D93AE3967FC24C7C0288C3C7ADB7130` |
| `yellow_labrador.jpg` | https://commons.wikimedia.org/wiki/File:YellowLabradorLooking_new.jpg | `Labrador_retriever`; object-detection manual box `[58,37,650,552]` | `D4CB12EA8A768582562E1F1C0C930EA6FC4757F5B66551B986B41498EFD75CA1` |

`yellow_labrador.jpg` is the 700x577, 83,281-byte Wikimedia Commons original
(SHA-1 `F1D042827C2F2154A6D8043B8E8F07C1BE612941`). The original photograph is
credited to Elf, with derivative work by Djmirko and later retouching by FT2.
It is available under CC BY-SA 3.0 and GFDL. The detection box above is a
project-authored test annotation, not upstream metadata.
