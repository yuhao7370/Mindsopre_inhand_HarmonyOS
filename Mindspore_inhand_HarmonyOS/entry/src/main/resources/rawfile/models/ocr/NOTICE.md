# PP-OCRv3 local OCR assets

This feature bundles the official PaddleOCR PP-OCRv3 Chinese mobile detector
and recognizer. PaddleOCR is Apache-2.0 licensed. The Chinese recognizer
contains Chinese and English printed-text characters.

| Asset | Original URL | Original SHA-256 | Bundled SHA-256 | Contract |
| --- | --- | --- | --- | --- |
| `ppocrv3_det.mnn` | https://paddleocr.bj.bcebos.com/PP-OCRv3/chinese/ch_PP-OCRv3_det_infer.tar | `8682B39D9B9EDB03CB91CF0B0FA8BC2DABF87BF941A88049EFC97E62328F1892` | `4C49C41D6675BDCC25718E976D0EB3A9560BF030FAA79E20B51378CA98480FB2` | float32 NCHW `x [1,3,960,960]` -> `sigmoid_0.tmp_0 [1,1,960,960]`; RGB `/255`, ImageNet mean/std |
| `ppocrv3_rec.mnn` | https://paddleocr.bj.bcebos.com/PP-OCRv3/chinese/ch_PP-OCRv3_rec_infer.tar | `F92B13DC91C92E0F220D095412695C429F7E70907467D2F780F339EEB83BB7B1` | `2B67F7CA600FFFAE2CB3243B1661458109060BC9BCFD978E25CE39A22170FA3B` | float32 NCHW `x [1,3,48,320]` -> `softmax_5.tmp_0 [1,40,6625]`; RGB `/127.5 - 1`, CTC blank index 0 |
| `ppocr_keys_v1.txt` | https://raw.githubusercontent.com/PaddlePaddle/PaddleOCR/release/2.7/ppocr/utils/ppocr_keys_v1.txt | `28B2362AD4AB2DC38769AA72FEB535E3A9DDB3FD2A7585A05920E6393B1DC7F7` | `28B2362AD4AB2DC38769AA72FEB535E3A9DDB3FD2A7585A05920E6393B1DC7F7` | CTC dictionary indexes 1..6623, terminal space index 6624 |

Conversion was performed with Paddle2ONNX 1.3.1 and MNN 3.6.0:

```text
python -m paddle2onnx.command --model_dir <model> --model_filename inference.pdmodel --params_filename inference.pdiparams --save_file <model>.onnx --opset_version 11
python -m MNN.tools.mnnconvert -f ONNX --modelFile <model>.onnx --MNNModel <model>.mnn --bizCode MNN
```

The resulting detector and recognizer contracts were loaded by MNN before
being bundled. The repository includes the Apache-2.0 text at
`rawfile/model/LICENSE-Apache-2.0.txt`.
