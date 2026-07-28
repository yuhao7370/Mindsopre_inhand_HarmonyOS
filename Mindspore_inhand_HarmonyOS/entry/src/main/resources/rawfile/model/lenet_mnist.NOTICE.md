# LeNet MNIST MindSpore Lite model

Source: `docs/tutorials/college-hap/college-hap.zip!/artifacts/lenet_mnist.mindir`.
The tutorial archive is the project-local college tutorial source; the MindIR was
extracted only into an operating-system temporary directory for conversion.
Source length: 189495 bytes.
Source SHA-256: `180A5ADAD63856AA6C79397AA319BBA82E919755B6D89B65E447851AF96EE115`.

Converted artifact: `lenet_mnist.ms`, 182520 bytes, SHA-256 `4CBF1D2E07C9D2BAD1B742C18AFA55996EA6CC0D335875C5D8E66C9447FD23C3`.
Converter: official MindSpore Lite 2.6.0 Linux x64 package, `converter_lite`.
The official package URL is
`https://ms-release.obs.cn-north-4.myhuaweicloud.com/2.6.0/MindSpore/lite/release/linux/x86_64/mindspore-lite-2.6.0-linux-x64.tar.gz`;
its SHA-256 is `DC70D965C440ECAB9692FD2DD7362E967D79E92CCB0FF632AC021D25D2AF9C9E`.
The exact conversion flags are `--fmk=MINDIR --saveType=MINDIR_LITE
--optimize=general --fp16=off --inputDataFormat=NCHW`.

Input: FLOAT32 NCHW `[1, 1, 28, 28]`.
Output: FLOAT32 `[1, 10]`; indices 0 through 9 represent digits 0 through 9.
The input is grayscale MNIST content normalized consistently with the tutorial
training procedure (mean `0.1307`, standard deviation `0.3081`).

License: project-private local learning use; the tutorial archive contains no separate trained-model license.
MindSpore Lite is an Apache-2.0 tool and is not redistributed by this artifact.
