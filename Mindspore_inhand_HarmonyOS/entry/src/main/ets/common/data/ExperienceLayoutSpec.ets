export const experienceGridColumnCount: number = 2;
export const experienceGridCardHeightVp: number = 50;
export const experienceGridRowGapVp: number = 17;
export const experienceGridSideInsetVp: number = 18;
export const experienceGridColumnGapVp: number = 8;

export function experienceGridHeightVp(itemCount: number): number {
  const rowCount = Math.ceil(Math.max(0, itemCount) / experienceGridColumnCount);
  if (rowCount === 0) {
    return 0;
  }
  return rowCount * experienceGridCardHeightVp + (rowCount - 1) * experienceGridRowGapVp;
}
