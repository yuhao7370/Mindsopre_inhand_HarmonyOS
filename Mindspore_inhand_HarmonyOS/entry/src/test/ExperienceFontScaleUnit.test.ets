import { describe, expect, it } from '@ohos/hypium';
import {
  bottomTabBarMinHeightVp,
  bottomTabItemMinHeightVp
} from '../main/ets/common/data/BottomTabBarLayoutSpec';
import { experienceHeaderMinHeightVp } from '../main/ets/common/data/ExperienceHeaderBranding';
import {
  experienceGroupTitleMinHeightVp,
  experienceSectionTitleMinHeightVp,
  experienceStickyTitleMinHeightVp,
  experienceStickyTitleThresholdForMeasuredHeightsVp,
  experienceStickyTitleThresholdVp,
  experienceStickyTitleVisible
} from '../main/ets/common/data/ExperienceLayoutSpec';

export default function experienceFontScaleUnitTest(): void {
  describe('ExperienceFontScaleUnitTest', () => {
    it('keepsDefaultGeometryAsContentAdaptiveMinimums', 0, () => {
      expect(experienceHeaderMinHeightVp).assertEqual(132);
      expect(experienceGroupTitleMinHeightVp).assertEqual(30);
      expect(experienceSectionTitleMinHeightVp).assertEqual(20);
      expect(experienceStickyTitleMinHeightVp).assertEqual(56);
      expect(experienceStickyTitleThresholdVp).assertEqual(76);
      expect(bottomTabItemMinHeightVp).assertEqual(50);
      expect(bottomTabBarMinHeightVp).assertEqual(62);
    });

    it('derivesStickyTransitionFromMeasuredHeaderAndStickyHeights', 0, () => {
      expect(experienceStickyTitleThresholdForMeasuredHeightsVp(132, 56)).assertEqual(76);
      expect(experienceStickyTitleThresholdForMeasuredHeightsVp(470, 63)).assertEqual(407);
      expect(experienceStickyTitleVisible(406, 407)).assertFalse();
      expect(experienceStickyTitleVisible(407, 407)).assertTrue();
    });
  });
}
