# Image-classification device fixtures

These immutable test inputs are the TensorFlow-hosted example images used only
by `ImageClassificationNativeTest` to verify the on-device production model
decoder. They are not application assets.

| File | Source | Expected ImageNet label | SHA-256 |
| --- | --- | --- | --- |
| `grace_hopper.jpg` | https://storage.googleapis.com/download.tensorflow.org/example_images/grace_hopper.jpg | `military_uniform` | `A8CA6D734765703B09728AB47FE59F473D93AE3967FC24C7C0288C3C7ADB7130` |
| `yellow_labrador.jpg` | https://storage.googleapis.com/download.tensorflow.org/example_images/YellowLabradorLooking_new.jpg | `Labrador_retriever` | `D4CB12EA8A768582562E1F1C0C930EA6FC4757F5B66551B986B41498EFD75CA1` |
