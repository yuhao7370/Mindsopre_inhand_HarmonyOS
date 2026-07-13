const hmsGestureInputSize: number = 224;

export function gestureInputFromRgba(rgba: Uint8Array, width: number, height: number): Float32Array {
  if (!Number.isInteger(width) || !Number.isInteger(height) || width <= 0 || height <= 0 ||
    rgba.length !== width * height * 4) {
    throw new Error('Invalid RGBA gesture input.');
  }

  const planeSize = hmsGestureInputSize * hmsGestureInputSize;
  const input = new Float32Array(planeSize * 3);
  for (let targetY = 0; targetY < hmsGestureInputSize; targetY++) {
    const sourceY = Math.min(height - 1, Math.round(targetY * height / hmsGestureInputSize));
    for (let targetX = 0; targetX < hmsGestureInputSize; targetX++) {
      const sourceX = Math.min(width - 1, Math.round(targetX * width / hmsGestureInputSize));
      const sourceOffset = (sourceY * width + sourceX) * 4;
      const targetOffset = targetY * hmsGestureInputSize + targetX;
      input[targetOffset] = rgba[sourceOffset + 2] / 255;
      input[planeSize + targetOffset] = rgba[sourceOffset + 1] / 255;
      input[planeSize * 2 + targetOffset] = rgba[sourceOffset] / 255;
    }
  }
  return input;
}
