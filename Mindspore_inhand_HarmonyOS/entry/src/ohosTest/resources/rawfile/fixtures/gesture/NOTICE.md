# Gesture-recognition device fixtures

`four.jpg` is the unchanged MediaPipe Model Maker Gesture Recognizer test image
`06aa70cc-a12a-4b1e-85cf-e54d44c19a3a.jpg` at commit
`0ad5a71bcdff3d756dc5b07f93765aaeb4152538`.

- Source: https://github.com/google-ai-edge/mediapipe/blob/0ad5a71bcdff3d756dc5b07f93765aaeb4152538/mediapipe/model_maker/python/vision/gesture_recognizer/testdata/raw_data/four/06aa70cc-a12a-4b1e-85cf-e54d44c19a3a.jpg
- License: Apache License 2.0 (repository `LICENSE` at the pinned commit).
- Size: 22,147 bytes; dimensions: 384x512.
- SHA-256: `197F8A11CB74A2ECFF8AA106271E5D3088A64C8FEA691DC081385FB8BA4A6AA0`.
- Expected production result: category 3 (`Four`), score at least 0.85, box IoU at least 0.90 against `(242.214, 182.637, 41.648, 59.506)`.

`solid_gray.png` is a project-authored 384x512 `#808080` negative fixture,
generated with ImageMagick `magick -size 384x512 xc:'#808080' -strip`.
Its SHA-256 is
`69A6B38DBE20F182F658D7DE3C545F6BECCF892C951BC008532543517D2C8DFE`;
the expected production result is zero detections.
