import { experienceHeaderHeightVp } from './ExperienceHeaderBranding';

export const experienceGridColumnCount: number = 2;
export const experienceGridCardHeightVp: number = 72;
export const experienceGridRowGapVp: number = 12;
export const experienceGridSideInsetVp: number = 16;
export const experienceGridColumnGapVp: number = 12;
export const experienceCardRadiusVp: number = 16;
export const experienceCardBorderWidthVp: number = 1;
export const experienceCardBorderColor: string = '#E8EDF5';
export const experienceCardPressedScale: number = 0.98;
export const experienceContentBottomPaddingVp: number = 28;
export const experienceStickyTitleHeightVp: number = 56;
export const experienceStickyTitleThresholdVp: number =
  experienceHeaderHeightVp - experienceStickyTitleHeightVp;

export function experienceStickyTitleVisible(scrollOffsetVp: number): boolean {
  return scrollOffsetVp >= experienceStickyTitleThresholdVp;
}

export function experienceGridHeightVp(itemCount: number): number {
  const rowCount = Math.ceil(Math.max(0, itemCount) / experienceGridColumnCount);
  if (rowCount === 0) {
    return 0;
  }
  return rowCount * experienceGridCardHeightVp + (rowCount - 1) * experienceGridRowGapVp;
}
