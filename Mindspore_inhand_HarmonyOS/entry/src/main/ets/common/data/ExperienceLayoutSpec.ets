export const experienceGridColumnCount: number = 2;
export const experienceGridCardHeightVp: number = 72;
export const experienceGridRowGapVp: number = 12;
export const experienceGridSideInsetVp: number = 16;
export const experienceGridColumnGapVp: number = 12;
export const experienceCardRadiusVp: number = 16;
export const experienceCardBorderWidthVp: number = 1;
export const experienceCardBorderColor: string = '#E8EDF5';
export const experienceCardPressedScale: number = 0.98;
export const experienceContentTopRadiusVp: number = 28;
export const experienceContentOverlapVp: number = 24;
export const experienceContentBottomPaddingVp: number = 28;

export function experienceGridHeightVp(itemCount: number): number {
  const rowCount = Math.ceil(Math.max(0, itemCount) / experienceGridColumnCount);
  if (rowCount === 0) {
    return 0;
  }
  return rowCount * experienceGridCardHeightVp + (rowCount - 1) * experienceGridRowGapVp;
}
