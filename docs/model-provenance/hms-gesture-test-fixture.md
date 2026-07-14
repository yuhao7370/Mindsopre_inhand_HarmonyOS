# HMS Gesture Test Fixture

## Source

- Generation date: `2026-07-14`
- Source dimensions: `1254 x 1254` pixels
- Repository path: `Mindspore_inhand_HarmonyOS/entry/src/ohosTest/resources/rawfile/fixtures/gesture/open_palm.png`
- PNG SHA-256: `9F6453C75E62630868D63D720A9C66B1B7301AD5997E788121FB5A857F8C4EB5`
- Prompt: `Square documentary test photograph, one adult human hand showing an open palm with five separated fingers, hand centered and fully inside frame, plain medium-gray background, even diffuse light, no text, no jewelry, no extra hands, no cropped fingers, natural skin texture, front-facing camera, high contrast between hand and background.`

## Derived host fixture

`tools/gesture/generate-hms-gesture-fixture.ps1` decodes the PNG with `System.Drawing.Bitmap`, scales it to `32 x 32`, and writes `32 * 32 * 4` row-major RGBA bytes to `GestureImageFixture.ets` as UTF-8 without a BOM.

## Limitation

This generated image is preprocessing and runtime input only. It is not a recognition gold label and does not define an expected gesture class, score, or bounding box. Tests may use it to check deterministic finite preprocessing and runtime outputs, but not recognition accuracy.
