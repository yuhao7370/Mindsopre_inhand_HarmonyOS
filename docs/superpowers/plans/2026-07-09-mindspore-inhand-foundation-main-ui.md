# MindSpore Inhand Foundation Main UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the default HarmonyOS Hello World with a buildable MindSpore Inhand app shell that contains typed routes, feature metadata, shared theme, and the main Experience/College/Me UI.

**Architecture:** This plan implements the first executable slice of the approved full-port spec. It keeps the HarmonyOS project as a single `entry` module, moves reusable non-UI logic into focused ArkTS files, and makes all pages consume typed data rather than hardcoded route strings. AI, camera, picker, and native MindSpore execution are represented by route-ready feature pages in this slice and implemented in subsequent slices.

**Tech Stack:** HarmonyOS 6.1.1 API 24, ArkTS, ArkUI, Hypium unit tests, DevEco Studio local Hvigor.

## Global Constraints

- Target HarmonyOS project path: `Mindspore_inhand_HarmonyOS/`.
- Source Android project path: `Mindspore_inhand/`; it is ignored by Git and must remain ignored.
- DevEco Studio path: `C:\Program Files\Huawei\DevEco Studio`.
- Command-line builds must set `$env:DEVECO_SDK_HOME='C:\Program Files\Huawei\DevEco Studio\sdk'`.
- Command-line builds must prepend `C:\Program Files\Huawei\DevEco Studio\jbr\bin` to `$env:PATH`.
- Primary build command: `& 'C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat' assembleHap --no-daemon`.
- Do not depend on Android AARs, Android `.so` files, AppCompat, ARouter, Glide, Retrofit, RxJava, or HMS Android SDKs.
- Preserve current Android source behavior: `Dance Factory` and `Intelligent poetry` are route-ready but hidden from the default Experience grid.
- Every phase must leave the HarmonyOS project buildable.
- Private signing keys, local SDK paths in committed local config, generated folders, and build outputs must not be committed.

---

## File Structure

This plan creates or modifies these files:

- Create `Mindspore_inhand_HarmonyOS/entry/src/main/ets/app/AppRoutes.ets`: typed route constants and route lookup helpers.
- Create `Mindspore_inhand_HarmonyOS/entry/src/main/ets/app/AppState.ets`: tab and app state types.
- Create `Mindspore_inhand_HarmonyOS/entry/src/main/ets/common/theme/AppTheme.ets`: color, spacing, and typography constants.
- Create `Mindspore_inhand_HarmonyOS/entry/src/main/ets/common/data/FeatureCatalog.ets`: Experience feature metadata and visibility rules.
- Create `Mindspore_inhand_HarmonyOS/entry/src/main/ets/common/data/CollegeCatalog.ets`: College timeline data.
- Create `Mindspore_inhand_HarmonyOS/entry/src/main/ets/common/data/MeCatalog.ets`: Me page row data and visibility rules.
- Create `Mindspore_inhand_HarmonyOS/entry/src/main/ets/common/components/BottomTabBar.ets`: bottom navigation component.
- Create `Mindspore_inhand_HarmonyOS/entry/src/main/ets/common/components/FeatureCard.ets`: Experience feature card component.
- Create `Mindspore_inhand_HarmonyOS/entry/src/main/ets/common/components/SectionTitle.ets`: compact section title component.
- Create `Mindspore_inhand_HarmonyOS/entry/src/main/ets/common/components/GradientTitleBar.ets`: title/header component.
- Create `Mindspore_inhand_HarmonyOS/entry/src/main/ets/pages/MainPage.ets`: main tab container.
- Create `Mindspore_inhand_HarmonyOS/entry/src/main/ets/pages/ExperiencePage.ets`: migrated Experience grid.
- Create `Mindspore_inhand_HarmonyOS/entry/src/main/ets/pages/CollegePage.ets`: migrated College list.
- Create `Mindspore_inhand_HarmonyOS/entry/src/main/ets/pages/MePage.ets`: migrated Me page.
- Create `Mindspore_inhand_HarmonyOS/entry/src/main/ets/pages/FeatureStubPage.ets`: route-ready feature page for feature entries not implemented in this slice.
- Modify `Mindspore_inhand_HarmonyOS/entry/src/main/ets/pages/Index.ets`: replace Hello World with `MainPage`.
- Modify `Mindspore_inhand_HarmonyOS/entry/src/main/resources/base/profile/main_pages.json`: add `pages/FeatureStubPage`.
- Modify `Mindspore_inhand_HarmonyOS/entry/src/main/resources/base/element/string.json`: app label and visible strings.
- Modify `Mindspore_inhand_HarmonyOS/entry/src/main/resources/base/element/color.json`: start background and app colors.
- Modify `Mindspore_inhand_HarmonyOS/entry/src/test/LocalUnit.test.ets`: add data and route tests.
- Create `Mindspore_inhand_HarmonyOS/scripts/build-hap.ps1`: local DevEco build helper.

## Task 1: Route And Catalog Foundation

**Files:**
- Create: `Mindspore_inhand_HarmonyOS/entry/src/main/ets/app/AppRoutes.ets`
- Create: `Mindspore_inhand_HarmonyOS/entry/src/main/ets/app/AppState.ets`
- Create: `Mindspore_inhand_HarmonyOS/entry/src/main/ets/common/data/FeatureCatalog.ets`
- Create: `Mindspore_inhand_HarmonyOS/entry/src/main/ets/common/data/CollegeCatalog.ets`
- Create: `Mindspore_inhand_HarmonyOS/entry/src/main/ets/common/data/MeCatalog.ets`
- Modify: `Mindspore_inhand_HarmonyOS/entry/src/test/LocalUnit.test.ets`

**Interfaces:**
- Produces `AppRoute` enum-like constants with route names matching Android ARouter paths.
- Produces `FeatureItem`, `FeatureSection`, `visibleExperienceSections`, `allExperienceFeatures`, and `findFeatureByRoute(routeName: string): FeatureItem | undefined`.
- Produces `CollegeItem`, `collegeItems`, `MeItem`, and `visibleMeItems`.
- Consumed by Tasks 2 and 3.

- [ ] **Step 1: Write failing catalog tests**

Replace the sample test body in `Mindspore_inhand_HarmonyOS/entry/src/test/LocalUnit.test.ets` with tests that import the wished-for APIs:

```typescript
import { describe, it, expect } from '@ohos/hypium';
import { AppRoute } from '../main/ets/app/AppRoutes';
import { allExperienceFeatures, findFeatureByRoute, visibleExperienceSections } from '../main/ets/common/data/FeatureCatalog';
import { collegeItems } from '../main/ets/common/data/CollegeCatalog';
import { visibleMeItems } from '../main/ets/common/data/MeCatalog';

export default function localUnitTest() {
  describe('mindsporePortFoundation', () => {
    it('preservesAndroidRouteNames', 0, () => {
      expect(AppRoute.OBJECT_PHOTO.name).assertEqual('/imageobject/ObjectPhotoActivity');
      expect(AppRoute.STYLE_TRANSFER.name).assertEqual('/styletransfer/StyleMainActivity');
      expect(AppRoute.TEXT_TRANSLATION.name).assertEqual('/hms/TextTranslationActivity');
    });

    it('keepsHiddenAndroidFeaturesRouteReady', 0, () => {
      const dance = findFeatureByRoute('/dance/DanceMainActivity');
      const poetry = findFeatureByRoute('/app/IntelligentPoetryWritingActivity');
      expect(dance?.visibleByDefault).assertFalse();
      expect(poetry?.visibleByDefault).assertFalse();
    });

    it('showsExpectedVisibleExperienceFeatures', 0, () => {
      const visibleCount = visibleExperienceSections
        .map((section) => section.items.length)
        .reduce((sum, count) => sum + count, 0);
      expect(visibleCount).assertEqual(10);
      expect(allExperienceFeatures.length).assertEqual(12);
    });

    it('definesCollegeAndMeRows', 0, () => {
      expect(collegeItems.length).assertEqual(6);
      expect(visibleMeItems.length).assertEqual(1);
      expect(visibleMeItems[0].title).assertEqual('Version');
    });
  });
}
```

- [ ] **Step 2: Run test/build to verify RED**

Run:

```powershell
cd Mindspore_inhand_HarmonyOS
$env:DEVECO_SDK_HOME='C:\Program Files\Huawei\DevEco Studio\sdk'
$env:PATH='C:\Program Files\Huawei\DevEco Studio\jbr\bin;' + $env:PATH
& 'C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat' assembleHap --no-daemon
```

Expected: FAIL during ArkTS compile because the imported `AppRoutes` and catalog files do not exist.

- [ ] **Step 3: Implement route and catalog files**

Create `Mindspore_inhand_HarmonyOS/entry/src/main/ets/app/AppRoutes.ets`:

```typescript
export interface AppRouteInfo {
  readonly name: string;
  readonly page: string;
}

export const AppRoute = {
  MAIN: { name: '/app/MainActivity', page: 'pages/Index' },
  OBJECT_PHOTO: { name: '/imageobject/ObjectPhotoActivity', page: 'pages/FeatureStubPage' },
  OBJECT_CAMERA: { name: '/imageobject/ObjectCameraActivity', page: 'pages/FeatureStubPage' },
  IMAGE_CAMERA: { name: '/imageobject/ImageCameraActivity', page: 'pages/FeatureStubPage' },
  STYLE_TRANSFER: { name: '/styletransfer/StyleMainActivity', page: 'pages/FeatureStubPage' },
  CUSTOM_MODEL: { name: '/custommodel/CustomModelMainActivity', page: 'pages/FeatureStubPage' },
  POSENET: { name: '/hms/PosenetMainActivitys', page: 'pages/FeatureStubPage' },
  LIVE_SKELETON: { name: '/posenet/LiveSkeletonAnalyseActivity', page: 'pages/FeatureStubPage' },
  SEGMENTATION_STILL: { name: '/hms/ImageSegmentationActivity', page: 'pages/FeatureStubPage' },
  SEGMENTATION_LIVE: { name: '/hms/ImageSegmentationLiveAnalyseActivity', page: 'pages/FeatureStubPage' },
  PORTRAIT_SEGMENTATION: { name: '/hms/PortraitSegmentationActivity', page: 'pages/FeatureStubPage' },
  GESTURE_STILL: { name: '/hms/StillHandGestureAnalyseActivity', page: 'pages/FeatureStubPage' },
  GESTURE_LIVE: { name: '/hms/LiveHandGestureAnalyseActivity', page: 'pages/FeatureStubPage' },
  TEXT_RECOGNITION: { name: '/hms/TextRecognitionActivity', page: 'pages/FeatureStubPage' },
  TEXT_TRANSLATION: { name: '/hms/TextTranslationActivity', page: 'pages/FeatureStubPage' },
  DANCE: { name: '/dance/DanceMainActivity', page: 'pages/FeatureStubPage' },
  POETRY: { name: '/app/IntelligentPoetryWritingActivity', page: 'pages/FeatureStubPage' },
  MY_QR_CODE: { name: '/app/MyQRCodeActivity', page: 'pages/FeatureStubPage' },
  PRIVACY: { name: '/app/PrivacyPolicyActivity', page: 'pages/FeatureStubPage' }
} as const;

export const appRoutes: AppRouteInfo[] = Object.keys(AppRoute)
  .map((key: string) => AppRoute[key] as AppRouteInfo);

export function findRouteByName(name: string): AppRouteInfo | undefined {
  return appRoutes.find((route: AppRouteInfo) => route.name === name);
}
```

Create `Mindspore_inhand_HarmonyOS/entry/src/main/ets/app/AppState.ets`:

```typescript
export enum MainTab {
  EXPERIENCE = 0,
  COLLEGE = 1,
  ME = 2
}

export interface TabItem {
  readonly id: MainTab;
  readonly title: string;
  readonly icon: string;
}

export const mainTabs: TabItem[] = [
  { id: MainTab.EXPERIENCE, title: 'Experience', icon: 'rocket' },
  { id: MainTab.COLLEGE, title: 'College', icon: 'college' },
  { id: MainTab.ME, title: 'Me', icon: 'me' }
];
```

Create `Mindspore_inhand_HarmonyOS/entry/src/main/ets/common/data/FeatureCatalog.ets`:

```typescript
import { AppRoute } from '../../app/AppRoutes';

export type FeatureCategory = 'experience-vision' | 'experience-speech' | 'advanced-vision' | 'advanced-speech';

export interface FeatureItem {
  readonly id: string;
  readonly title: string;
  readonly badge?: string;
  readonly icon: string;
  readonly routeName: string;
  readonly visibleByDefault: boolean;
}

export interface FeatureSection {
  readonly id: FeatureCategory;
  readonly title: string;
  readonly items: FeatureItem[];
}

export const experienceSections: FeatureSection[] = [
  {
    id: 'experience-vision',
    title: 'Computer Vision',
    items: [
      { id: 'posenet', title: 'PoseNet', icon: 'people', routeName: AppRoute.POSENET.name, visibleByDefault: true },
      { id: 'segmentation', title: 'Portrait Segmentation', icon: 'image', routeName: AppRoute.SEGMENTATION_LIVE.name, visibleByDefault: true },
      { id: 'image', title: 'Image Classification', icon: 'grid', routeName: AppRoute.IMAGE_CAMERA.name, visibleByDefault: true },
      { id: 'gesture', title: 'Gesture Recognition', icon: 'hand', routeName: AppRoute.GESTURE_STILL.name, visibleByDefault: true },
      { id: 'dance', title: 'Dance Factory', badge: 'HOT', icon: 'dance', routeName: AppRoute.DANCE.name, visibleByDefault: false }
    ]
  },
  {
    id: 'experience-speech',
    title: 'Speech Semantic Technology',
    items: [
      { id: 'poetry', title: 'Intelligent poetry', badge: 'HOT', icon: 'poetry', routeName: AppRoute.POETRY.name, visibleByDefault: false },
      { id: 'text', title: 'Text Extraction', icon: 'text', routeName: AppRoute.TEXT_RECOGNITION.name, visibleByDefault: true },
      { id: 'translation', title: 'Text Translation', icon: 'translate', routeName: AppRoute.TEXT_TRANSLATION.name, visibleByDefault: true }
    ]
  },
  {
    id: 'advanced-vision',
    title: 'Computer Vision',
    items: [
      { id: 'objectPhoto', title: 'Object Detection(Photo)', icon: 'photo', routeName: AppRoute.OBJECT_PHOTO.name, visibleByDefault: true },
      { id: 'objectCamera', title: 'Object Detection(Real-time)', icon: 'camera', routeName: AppRoute.OBJECT_CAMERA.name, visibleByDefault: true },
      { id: 'style', title: 'Style Transfer', icon: 'style', routeName: AppRoute.STYLE_TRANSFER.name, visibleByDefault: true },
      { id: 'custom', title: 'Custom Model', icon: 'model', routeName: AppRoute.CUSTOM_MODEL.name, visibleByDefault: true }
    ]
  },
  {
    id: 'advanced-speech',
    title: 'Speech Semantic Technology',
    items: []
  }
];

export const allExperienceFeatures: FeatureItem[] = experienceSections.reduce((items: FeatureItem[], section: FeatureSection) => {
  items.push(...section.items);
  return items;
}, []);

export const visibleExperienceSections: FeatureSection[] = experienceSections
  .map((section: FeatureSection) => ({
    id: section.id,
    title: section.title,
    items: section.items.filter((item: FeatureItem) => item.visibleByDefault)
  }))
  .filter((section: FeatureSection) => section.items.length > 0);

export function findFeatureByRoute(routeName: string): FeatureItem | undefined {
  return allExperienceFeatures.find((item: FeatureItem) => item.routeName === routeName);
}
```

Create `Mindspore_inhand_HarmonyOS/entry/src/main/ets/common/data/CollegeCatalog.ets`:

```typescript
export type CollegeItemType = 'link' | 'quickStart' | 'summary' | 'footer';

export interface CollegeQuickAction {
  readonly id: string;
  readonly title: string;
  readonly icon: string;
  readonly url: string;
}

export interface CollegeItem {
  readonly id: string;
  readonly type: CollegeItemType;
  readonly title: string;
  readonly icon: string;
  readonly url?: string;
  readonly quickActions?: CollegeQuickAction[];
}

export const mindSporeSummary =
  'MindSpore is a full-scenario AI computing framework. This HarmonyOS port keeps the learning entry local and opens external resources through the web page flow.';

export const collegeItems: CollegeItem[] = [
  { id: 'summary', type: 'summary', title: 'MindSpore Summary', icon: 'summary' },
  { id: 'cloud', type: 'link', title: 'A One-Hour Trip to MindSpore', icon: 'cloud', url: 'https://www.mindspore.cn/' },
  {
    id: 'quick',
    type: 'quickStart',
    title: 'Quick Start',
    icon: 'new',
    quickActions: [
      { id: 'train', title: 'Train', icon: 'train', url: 'https://www.mindspore.cn/tutorials' },
      { id: 'inference', title: 'Inference', icon: 'inference', url: 'https://www.mindspore.cn/lite' },
      { id: 'applications', title: 'Applications', icon: 'app', url: 'https://www.mindspore.cn/ecosystem' },
      { id: 'video', title: 'Video', icon: 'video', url: 'https://www.mindspore.cn/resources' }
    ]
  },
  { id: 'faq', type: 'link', title: 'FAQ', icon: 'faq', url: 'https://www.mindspore.cn/docs' },
  { id: 'forum', type: 'link', title: 'Ask on forum', icon: 'forum', url: 'https://discuss.mindspore.cn/' },
  { id: 'footer', type: 'footer', title: '~Illuminate your learning trip~', icon: 'footer' }
];
```

Create `Mindspore_inhand_HarmonyOS/entry/src/main/ets/common/data/MeCatalog.ets`:

```typescript
export interface MeItem {
  readonly id: string;
  readonly title: string;
  readonly icon: string;
  readonly visibleByDefault: boolean;
}

export const meItems: MeItem[] = [
  { id: 'share', title: 'Share', icon: 'share', visibleByDefault: false },
  { id: 'qr', title: 'My QR Code', icon: 'qr', visibleByDefault: false },
  { id: 'star', title: 'Star', icon: 'star', visibleByDefault: false },
  { id: 'official', title: 'Official Website', icon: 'official', visibleByDefault: false },
  { id: 'code', title: 'Code', icon: 'code', visibleByDefault: false },
  { id: 'feedback', title: 'FeedBack', icon: 'feedback', visibleByDefault: false },
  { id: 'version', title: 'Version', icon: 'version', visibleByDefault: true }
];

export const visibleMeItems: MeItem[] = meItems.filter((item: MeItem) => item.visibleByDefault);
```

- [ ] **Step 4: Run GREEN verification**

Run the same `assembleHap --no-daemon` command. Expected: PASS or move to the first compile error caused by strict ArkTS import syntax and fix only that error.

- [ ] **Step 5: Commit Task 1**

```powershell
git add Mindspore_inhand_HarmonyOS/entry/src/main/ets/app Mindspore_inhand_HarmonyOS/entry/src/main/ets/common/data Mindspore_inhand_HarmonyOS/entry/src/test/LocalUnit.test.ets
git commit -m "feat: add HarmonyOS route and catalog foundation"
```

## Task 2: Shared UI Components And Main Tab Shell

**Files:**
- Create: `Mindspore_inhand_HarmonyOS/entry/src/main/ets/common/theme/AppTheme.ets`
- Create: `Mindspore_inhand_HarmonyOS/entry/src/main/ets/common/components/BottomTabBar.ets`
- Create: `Mindspore_inhand_HarmonyOS/entry/src/main/ets/common/components/FeatureCard.ets`
- Create: `Mindspore_inhand_HarmonyOS/entry/src/main/ets/common/components/SectionTitle.ets`
- Create: `Mindspore_inhand_HarmonyOS/entry/src/main/ets/common/components/GradientTitleBar.ets`
- Create: `Mindspore_inhand_HarmonyOS/entry/src/main/ets/pages/MainPage.ets`
- Modify: `Mindspore_inhand_HarmonyOS/entry/src/main/ets/pages/Index.ets`

**Interfaces:**
- Consumes `mainTabs` and `MainTab` from Task 1.
- Produces `MainPage` with internal selected tab state.
- Later pages are consumed by `MainPage`.

- [ ] **Step 1: Write a failing tab data assertion**

Append to `LocalUnit.test.ets`:

```typescript
import { MainTab, mainTabs } from '../main/ets/app/AppState';

it('definesThreeMainTabsInAndroidOrder', 0, () => {
  expect(mainTabs.length).assertEqual(3);
  expect(mainTabs[0].id).assertEqual(MainTab.EXPERIENCE);
  expect(mainTabs[1].title).assertEqual('College');
  expect(mainTabs[2].title).assertEqual('Me');
});
```

Run build. Expected: FAIL if Task 1 has not produced `mainTabs`, otherwise PASS and proceed because this assertion covers the shell's data contract.

- [ ] **Step 2: Implement theme constants**

Create `Mindspore_inhand_HarmonyOS/entry/src/main/ets/common/theme/AppTheme.ets`:

```typescript
export const AppColor = {
  primary: '#5E82FF',
  primaryStart: '#57C4DE',
  primaryEnd: '#6681FF',
  pageBackground: '#F7F8FA',
  cardBackground: '#FFFFFF',
  textPrimary: '#303133',
  textSecondary: '#606266',
  textMuted: '#A0A3AA',
  divider: '#E5E6EB',
  accent: '#6681FF',
  danger: '#F53F3F'
} as const;

export const AppSpacing = {
  xs: 4,
  sm: 8,
  md: 12,
  lg: 16,
  xl: 24,
  page: 20
} as const;

export const AppRadius = {
  card: 6,
  button: 6,
  sheet: 8
} as const;
```

- [ ] **Step 3: Implement shared components**

Create the listed components as small ArkTS components:

```typescript
// BottomTabBar.ets
import { MainTab, TabItem } from '../../app/AppState';
import { AppColor } from '../theme/AppTheme';

@Component
export struct BottomTabBar {
  @Prop selected: MainTab;
  tabs: TabItem[] = [];
  onChange: (tab: MainTab) => void = () => {};

  build() {
    Row() {
      ForEach(this.tabs, (tab: TabItem) => {
        Column() {
          Text(tab.icon).fontSize(22)
          Text(tab.title).fontSize(13)
        }
        .layoutWeight(1)
        .height(56)
        .justifyContent(FlexAlign.Center)
        .fontColor(this.selected === tab.id ? AppColor.accent : AppColor.textSecondary)
        .onClick(() => this.onChange(tab.id))
      }, (tab: TabItem) => `${tab.id}`)
    }
    .width('100%')
    .height(56)
    .backgroundColor(AppColor.cardBackground)
  }
}
```

```typescript
// FeatureCard.ets
import { FeatureItem } from '../data/FeatureCatalog';
import { AppColor, AppRadius } from '../theme/AppTheme';

@Component
export struct FeatureCard {
  item: FeatureItem;
  onClick: (item: FeatureItem) => void = () => {};

  build() {
    Row() {
      Text(this.item.icon).fontSize(24).width(34)
      Text(this.item.title).fontSize(14).fontColor(AppColor.textPrimary).fontWeight(FontWeight.Medium).layoutWeight(1)
      if (this.item.badge) {
        Text(this.item.badge).fontSize(10).fontColor(AppColor.danger).fontStyle(FontStyle.Italic)
      }
    }
    .height(58)
    .padding({ left: 10, right: 10 })
    .backgroundColor(AppColor.cardBackground)
    .border({ width: 1, color: AppColor.divider, radius: AppRadius.card })
    .onClick(() => this.onClick(this.item))
  }
}
```

```typescript
// SectionTitle.ets
import { AppColor } from '../theme/AppTheme';

@Component
export struct SectionTitle {
  title: string;

  build() {
    Row() {
      Rect().width(4).height(18).fill(AppColor.accent)
      Text(this.title).fontSize(18).fontWeight(FontWeight.Bold).fontColor(AppColor.textPrimary).margin({ left: 10 })
    }
    .height(30)
    .alignItems(VerticalAlign.Center)
  }
}
```

```typescript
// GradientTitleBar.ets
import { AppColor } from '../theme/AppTheme';

@Component
export struct GradientTitleBar {
  title: string;
  subtitle: string = '';

  build() {
    Column() {
      Text(this.title).fontSize(28).fontWeight(FontWeight.Bold).fontColor(Color.White)
      if (this.subtitle.length > 0) {
        Text(this.subtitle).fontSize(16).fontColor(Color.White).textAlign(TextAlign.Center).margin({ top: 16 })
      }
    }
    .width('100%')
    .height(210)
    .justifyContent(FlexAlign.Center)
    .linearGradient({
      angle: 120,
      colors: [[AppColor.primaryStart, 0], [AppColor.primaryEnd, 1]]
    })
  }
}
```

- [ ] **Step 4: Implement MainPage and Index delegation**

Create `MainPage.ets` that switches among `ExperiencePage`, `CollegePage`, and `MePage`; if those files are not present yet, create minimal temporary local builders inside `MainPage` with the exact page names as text, then Task 3 replaces them.

Modify `Index.ets`:

```typescript
import { MainPage } from './MainPage';

@Entry
@Component
struct Index {
  build() {
    MainPage()
  }
}
```

- [ ] **Step 5: Run build and commit**

Run `assembleHap --no-daemon`. Expected: PASS.

```powershell
git add Mindspore_inhand_HarmonyOS/entry/src/main/ets/common/theme Mindspore_inhand_HarmonyOS/entry/src/main/ets/common/components Mindspore_inhand_HarmonyOS/entry/src/main/ets/pages/MainPage.ets Mindspore_inhand_HarmonyOS/entry/src/main/ets/pages/Index.ets Mindspore_inhand_HarmonyOS/entry/src/test/LocalUnit.test.ets
git commit -m "feat: add HarmonyOS main tab shell"
```

## Task 3: Experience, College, Me, And Feature Stub Pages

**Files:**
- Create: `Mindspore_inhand_HarmonyOS/entry/src/main/ets/pages/ExperiencePage.ets`
- Create: `Mindspore_inhand_HarmonyOS/entry/src/main/ets/pages/CollegePage.ets`
- Create: `Mindspore_inhand_HarmonyOS/entry/src/main/ets/pages/MePage.ets`
- Create: `Mindspore_inhand_HarmonyOS/entry/src/main/ets/pages/FeatureStubPage.ets`
- Modify: `Mindspore_inhand_HarmonyOS/entry/src/main/ets/pages/MainPage.ets`
- Modify: `Mindspore_inhand_HarmonyOS/entry/src/main/resources/base/profile/main_pages.json`

**Interfaces:**
- Consumes Task 1 catalog data and Task 2 components.
- Produces visible UI that matches the Android app's current shell and feature visibility.

- [ ] **Step 1: Add route page registration first**

Modify `main_pages.json`:

```json
{
  "src": [
    "pages/Index",
    "pages/FeatureStubPage"
  ]
}
```

Run build. Expected: FAIL because `FeatureStubPage.ets` is missing.

- [ ] **Step 2: Implement FeatureStubPage**

Create a route-aware page that reads router params when present and shows the feature title plus a message that the feature service is being ported in the next slices:

```typescript
import router from '@ohos.router';
import { allExperienceFeatures, FeatureItem } from '../common/data/FeatureCatalog';
import { AppColor } from '../common/theme/AppTheme';

@Entry
@Component
struct FeatureStubPage {
  @State title: string = 'MindSpore Feature';
  @State routeName: string = '';

  aboutToAppear() {
    const params = router.getParams() as Record<string, string>;
    this.routeName = params?.routeName ?? '';
    const feature = allExperienceFeatures.find((item: FeatureItem) => item.routeName === this.routeName);
    this.title = params?.title ?? feature?.title ?? this.title;
  }

  build() {
    Column() {
      Text(this.title).fontSize(22).fontWeight(FontWeight.Bold).fontColor(AppColor.textPrimary)
      Text('Feature service migration is queued for the next implementation slice.')
        .fontSize(15)
        .fontColor(AppColor.textSecondary)
        .textAlign(TextAlign.Center)
        .margin({ top: 16 })
      Button('Back').margin({ top: 28 }).onClick(() => router.back())
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .padding(24)
    .backgroundColor(AppColor.pageBackground)
  }
}
```

- [ ] **Step 3: Implement ExperiencePage**

Use `GradientTitleBar`, `SectionTitle`, `FeatureCard`, and `visibleExperienceSections`. Card clicks call `router.pushUrl({ url: route.page, params: { routeName: item.routeName, title: item.title } })` using `findRouteByName`.

Expected visible cards: PoseNet, Portrait Segmentation, Image Classification, Gesture Recognition, Text Extraction, Text Translation, Object Detection(Photo), Object Detection(Real-time), Style Transfer, Custom Model.

- [ ] **Step 4: Implement CollegePage**

Use `collegeItems`. Summary shows a local dialog with `mindSporeSummary`; link and quick-start items navigate to `FeatureStubPage` with the URL/title as params for this slice. The full Web component arrives in a later platform-services slice.

- [ ] **Step 5: Implement MePage**

Use `visibleMeItems`. Show the version row with `V1.0.0`. Hidden Android rows remain present in `MeCatalog` but not rendered.

- [ ] **Step 6: Wire MainPage to real pages**

Import and render `ExperiencePage`, `CollegePage`, and `MePage` in `MainPage`.

- [ ] **Step 7: Run build and commit**

Run `assembleHap --no-daemon`. Expected: PASS.

```powershell
git add Mindspore_inhand_HarmonyOS/entry/src/main/ets/pages Mindspore_inhand_HarmonyOS/entry/src/main/resources/base/profile/main_pages.json
git commit -m "feat: port main HarmonyOS pages"
```

## Task 4: Resources, Build Helper, And Baseline Verification

**Files:**
- Modify: `Mindspore_inhand_HarmonyOS/entry/src/main/resources/base/element/string.json`
- Modify: `Mindspore_inhand_HarmonyOS/entry/src/main/resources/base/element/color.json`
- Create: `Mindspore_inhand_HarmonyOS/scripts/build-hap.ps1`
- Modify: `Mindspore_inhand_HarmonyOS/.gitignore` if a new generated path appears during verification.

**Interfaces:**
- Produces reusable local build helper.
- Keeps generated files ignored.

- [ ] **Step 1: Update app strings and colors**

Set `EntryAbility_label` to `MindSpore Inhand`, add visible shell strings, and set `start_window_background` to `#FFFFFF`. Keep JSON5/JSON syntax valid for HarmonyOS resource compilation.

- [ ] **Step 2: Create local build helper**

Create `scripts/build-hap.ps1`:

```powershell
$ErrorActionPreference = 'Stop'
$env:DEVECO_SDK_HOME = 'C:\Program Files\Huawei\DevEco Studio\sdk'
$env:PATH = 'C:\Program Files\Huawei\DevEco Studio\jbr\bin;' + $env:PATH
& 'C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat' assembleHap --no-daemon
```

- [ ] **Step 3: Run final slice verification**

Run:

```powershell
cd Mindspore_inhand_HarmonyOS
& .\scripts\build-hap.ps1
```

Expected: `BUILD SUCCESSFUL`.

Run:

```powershell
git status --short --ignored
```

Expected: only source changes and ignored generated directories; no generated build output is untracked.

- [ ] **Step 4: Commit Task 4**

```powershell
git add Mindspore_inhand_HarmonyOS/entry/src/main/resources/base/element/string.json Mindspore_inhand_HarmonyOS/entry/src/main/resources/base/element/color.json Mindspore_inhand_HarmonyOS/scripts/build-hap.ps1 Mindspore_inhand_HarmonyOS/.gitignore
git commit -m "chore: add HarmonyOS build helper and resource baseline"
```

## Slice Completion Verification

After Task 4:

```powershell
cd Mindspore_inhand_HarmonyOS
& .\scripts\build-hap.ps1
git log --oneline -5
git status --short --ignored
```

The slice is complete only if:

- The build reports `BUILD SUCCESSFUL`.
- `Index.ets` no longer contains the Hello World text.
- The main UI renders Experience, College, and Me tabs.
- Hidden Android source features are still route-ready but excluded from the default Experience grid.
- The latest commits are task-scoped.
- The only ignored entries are generated/local paths such as `Mindspore_inhand/`, `.hvigor/`, `.idea/`, `entry/build/`, `local.properties`, and `oh_modules/`.
