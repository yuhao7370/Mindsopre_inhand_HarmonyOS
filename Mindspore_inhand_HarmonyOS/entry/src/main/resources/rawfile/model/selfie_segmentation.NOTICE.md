# Selfie Segmentation model notice

- Upstream project: MediaPipe, Apache License 2.0.
- Upstream repository revision used to audit the graph contract: `0ad5a71bcdff3d756dc5b07f93765aaeb4152538`.
- Source model URL: `https://storage.googleapis.com/mediapipe-assets/selfie_segmentation.tflite`.
- Source model size: `249505` bytes.
- Source model SHA-256: `9EE168EC7C8F2A16C56FE8E1CFBC514974CBBB7E434051B455635F1BD1462F5C`.
- Converter: MNN 3.6.0 (`mnn-3.6.0-cp311-cp311-win_amd64.whl`).
- Converter wheel SHA-256: `B36778F25DA5E27646B5449FB0399D0518ABC22977D4E339FA320A12E5A432FD`.
- Conversion command: `python -m MNN.tools.mnnconvert -f TFLITE --modelFile selfie_segmentation.tflite --MNNModel selfie_segmentation.mnn --bizCode MNN`.
- Converted model size: `446064` bytes.
- Converted model SHA-256: `2EC8CB8940B42DE3F453EDFEBC0945905C81F2DD6C8A751128AAF6F98B8DB128`.
- Input tensor: `input_1`, float32 NHWC `[1, 256, 256, 3]`, RGB channels normalized to `[0, 1]` by division by 255.
- Output tensor: `activation_10`, float32 NHWC `[1, 256, 256, 1]`; the application thresholds foreground confidence at `0.1` and rejects masks below a 1% foreground ratio.

The Apache License 2.0 text distributed with this model is
`LICENSE-Apache-2.0.txt` in the same directory.
