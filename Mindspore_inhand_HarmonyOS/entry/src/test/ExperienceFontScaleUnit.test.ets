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
  experienceStickyTitleThresholdVp
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
  });
}
