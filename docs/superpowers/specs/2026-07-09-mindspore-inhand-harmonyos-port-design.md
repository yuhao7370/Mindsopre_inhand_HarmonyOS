# MindSpore Inhand HarmonyOS Port Design

## Goal

Port the local Android project `Mindspore_inhand/` into the HarmonyOS project
`Mindspore_inhand_HarmonyOS/` as a buildable and runnable HarmonyOS app while
preserving the Android app's current user-facing behavior as closely as the
HarmonyOS platform allows.

The target app must build with the locally installed DevEco Studio toolchain at
`C:\Program Files\Huawei\DevEco Studio`.

## Source Baseline

The Android source has these Gradle modules:

- `app`
- `common`
- `customView`
- `imageObject`
- `styletransfer`
- `hms`
- `dance`
- `custommodel`
- `mindsporelibrary`

The HarmonyOS project currently has one `entry` module with a default
Hello World page.

The Android source contains 21 ARouter route annotations and more than 30
Activity/Fragment classes. The resource set includes XML layouts, drawable
selectors, PNG/JPG assets, string resources, menus, navigation XML, and local
assets such as `privacy.html` and `Country_pair_new.txt`.

## Definition Of 1:1

1:1 means matching the current Android source behavior, not only the README
screenshots. For example, `VisionFragment.java` currently hides
`Dance Factory` and `Intelligent poetry` from the Experience page; the
HarmonyOS app must keep those feature pages available in code but hidden from
the default Experience grid unless product requirements change.

The final port must preserve:

- Splash and permission onboarding flow.
- Main bottom navigation with Experience, College, and Me.
- Experience feature grouping and feature entry cards.
- College list, local summary dialog, checked-state persistence, and web links.
- Me page version display and retained hidden actions from the Android source.
- Privacy policy display from the local HTML asset.
- Camera, album/file picker, web, sharing, storage, and permission behavior.
- MindSpore Lite based image classification, object detection, style transfer,
  and custom model flows.
- HMS ML inspired feature entries: PoseNet, body segmentation, hand gesture,
  OCR/text extraction, translation, and related still/live camera modes.

## Recommended Approach

Use a phased full port. Each phase must leave the HarmonyOS project buildable.
The final state must implement the full 1:1 target; intermediate phases may
ship limited behavior only while the migration is actively in progress.

Rejected approaches:

- A single all-at-once rewrite is too risky because UI, resources, camera,
  MindSpore Lite, HMS ML, and signing would fail together.
- A UI-only shell is useful as an intermediate checkpoint but is not the final
  target.

## HarmonyOS Architecture

Keep a single `entry` module and organize ArkTS code by feature and capability:

```text
entry/src/main/ets/
  app/
    AppRoutes.ets
    AppState.ets
  common/
    components/
    constants/
    theme/
    utils/
  pages/
    SplashPage.ets
    MainPage.ets
    ExperiencePage.ets
    CollegePage.ets
    MePage.ets
    PrivacyPolicyPage.ets
    WebPage.ets
  features/
    objectDetection/
    imageClassification/
    styleTransfer/
    customModel/
    hmsLike/
    dance/
    poetry/
  services/
    ai/
    camera/
    picker/
    permissions/
    share/
    storage/
    web/
```

Use `entry/src/main/resources/base/media` for migrated raster assets and
`entry/src/main/resources/base/element/string.json` for strings. Keep code,
resources, and service adapters separated so UI pages can remain stable while
native AI and platform services are implemented.

## Routing

Replace Android ARouter paths with a typed route registry in
`app/AppRoutes.ets`.

Android routes to preserve as HarmonyOS route names include:

- `/imageobject/ObjectPhotoActivity`
- `/imageobject/ObjectCameraActivity`
- `/imageobject/ImageCameraActivity`
- `/styletransfer/StyleMainActivity`
- `/custommodel/CustomModelMainActivity`
- `/hms/PosenetMainActivitys`
- `/posenet/LiveSkeletonAnalyseActivity`
- `/hms/ImageSegmentationActivity`
- `/hms/ImageSegmentationLiveAnalyseActivity`
- `/hms/PortraitSegmentationActivity`
- `/hms/StillHandGestureAnalyseActivity`
- `/hms/LiveHandGestureAnalyseActivity`
- `/hms/TextRecognitionActivity`
- `/hms/TextTranslationActivity`
- `/dance/DanceMainActivity`
- `/app/IntelligentPoetryWritingActivity`
- `/app/MyQRCodeActivity`
- `/app/PrivacyPolicyActivity`

The registry must contain only route names and page URLs. Feature pages call
the registry instead of hardcoding page paths in multiple places.

## UI And Resource Migration

Android XML layout logic must be rewritten as ArkTS components. Existing image
assets should be reused directly where possible. XML selectors and shapes must
be converted to ArkTS style constants or resource JSON where appropriate.

Core reusable components:

- `GradientTitleBar`
- `BottomTabBar`
- `FeatureCard`
- `SectionTitle`
- `CollegeTimelineItem`
- `NoticeDialog`
- `UpdateDialog`
- `ResultOverlay`
- `CameraPreviewPanel`
- `ImagePickerPanel`

The UI should preserve the Android visual hierarchy and spacing but use
HarmonyOS-native controls and responsive layout rather than a literal XML
translation. Mobile phone is the primary device type.

## Platform Services

Create service adapters under `services/` so pages do not directly depend on
low-level HarmonyOS APIs.

Required adapters:

- `PermissionService`: camera, photo/media, file access, network permissions.
- `PickerService`: image selection and `.ms` model file selection.
- `CameraService`: still capture and live preview frames for AI processing.
- `StorageService`: temporary images, model copies, and user preferences.
- `ShareService`: text/image sharing where HarmonyOS supports it.
- `WebService`: internal Web component page and external URL launching.

These adapters must return explicit success and failure results. Pages must
show user-readable failure messages instead of silently doing nothing.

## AI And Native Inference

The Android project uses Android AAR/JNI libraries and HMS ML Kit. These cannot
be copied directly as a HarmonyOS implementation.

Final HarmonyOS implementation must use HarmonyOS-compatible APIs:

- Prefer HarmonyOS MindSpore Lite Kit APIs for MindSpore model inference.
- Use HarmonyOS Native C/C++ only when ArkTS APIs are insufficient.
- Do not depend on Android AARs, Android `.so` files, AppCompat, ARouter,
  Glide, Retrofit, RxJava, or HMS Android SDKs.

Create `services/ai/AiService.ets` as the UI-facing boundary. It should expose
feature-level operations, not raw tensor APIs:

- `classifyImage(image): Promise<ImageClassificationResult>`
- `detectObjects(image, model?): Promise<ObjectDetectionResult>`
- `runStyleTransfer(contentImage, styleImage, models?): Promise<StyleTransferResult>`
- `runCustomModel(modelFile, inputImage): Promise<CustomModelResult>`
- `segmentPerson(imageOrFrame): Promise<SegmentationResult>`
- `detectPose(imageOrFrame): Promise<PoseResult>`
- `detectGesture(imageOrFrame): Promise<GestureResult>`
- `recognizeText(image): Promise<TextRecognitionResult>`
- `translateText(text, sourceLanguage, targetLanguage): Promise<TranslationResult>`

The service boundary allows UI work, model integration, and native adapters to
be verified independently.

## Feature Mapping

### App Shell

Map Android `SplashActivity`, `MainActivity`, `ExperienceFragment`,
`CollegeFragment`, and `MeFragment` to HarmonyOS pages and shared components.

### Computer Vision

Map Android feature entries to HarmonyOS feature pages:

- Object Detection Photo: image picker plus model selection and object boxes.
- Object Detection Real-time: camera preview plus live detection overlay.
- Image Classification: camera preview plus top classification result.
- Style Transfer: content image, style image/model selection, result image,
  and execution timing details.
- Custom Model: model file selection, image input, output summary, timing.
- PoseNet: still and live pose detection modes.
- Portrait Segmentation: still/live segmentation preview.
- Gesture Recognition: still/live gesture recognition modes.

### Speech Semantic Technology

Map Android text features:

- Text Extraction: pick/capture image, show recognized text.
- Text Translation: input or recognized text, source/target language choices,
  show translated output.
- Intelligent Poetry: keep page and route available but hidden by default,
  matching current Android source behavior.

### College

Port the timeline-style list, local MindSpore summary dialog, checked-state
preferences, quick-start child items, and web navigation.

### Me

Port the version row and hidden actions. Keep hidden Android actions hidden
unless the source explicitly shows them in a later change.

## Build And Local Toolchain

The project must build with DevEco Studio 6.1.1 SDK/API 24 detected at:

```powershell
C:\Program Files\Huawei\DevEco Studio
```

Command-line builds must set:

```powershell
$env:DEVECO_SDK_HOME='C:\Program Files\Huawei\DevEco Studio\sdk'
$env:PATH='C:\Program Files\Huawei\DevEco Studio\jbr\bin;' + $env:PATH
```

The primary verification command is:

```powershell
& 'C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat' assembleHap --no-daemon
```

The existing baseline Hello World project builds with this command. Final
implementation must keep this command green.

Debug signing must be configured through DevEco-supported local signing. The
repository must not commit private signing keys or local machine secrets.

## Implementation Phases

### Phase 1: Project Foundation

- Replace Hello World with app shell, route registry, shared theme, and build
  helper documentation.
- Migrate app icon and core strings.
- Verify `assembleHap`.

### Phase 2: Main UI And Navigation

- Implement Splash, Main, Experience, College, Me, Privacy, and Web pages.
- Migrate assets needed by those pages.
- Preserve hidden feature visibility from current Android source.
- Verify navigation manually and with build checks.

### Phase 3: Platform Services

- Add permission, picker, storage, camera, web, and share service adapters.
- Wire pages to adapters with explicit error states.
- Verify still-image picker, model picker, and camera preview on device or
  emulator.

### Phase 4: MindSpore Features

- Implement MindSpore Lite compatible adapters for classification, object
  detection, style transfer, and custom model execution.
- Package or download model assets in a HarmonyOS-safe way.
- Verify each result path with a known image/model pair.

### Phase 5: HMS-like AI Features

- Implement or adapt pose, segmentation, gesture, OCR, and translation using
  HarmonyOS-compatible kits or MindSpore models.
- Keep feature pages and result formats aligned with Android behavior.
- Verify still and live modes separately.

### Phase 6: Polish And Release Readiness

- Remove dead Android assumptions.
- Ensure build output is clean and ignored generated files stay ignored.
- Verify installation/run from DevEco Studio.
- Document unsupported platform differences only if HarmonyOS lacks a direct
  equivalent.

## Verification Requirements

Completion requires evidence for every item:

- `ohpm install` succeeds or reports no missing dependencies.
- `assembleHap --no-daemon` succeeds from the local DevEco toolchain.
- DevEco Studio can open the HarmonyOS project without missing SDK errors.
- App starts on a HarmonyOS phone target.
- Main navigation works across Experience, College, and Me.
- Every preserved Android route has a HarmonyOS page or explicit feature entry.
- Every visible feature entry opens and completes its original flow. A
  documented platform difference is acceptable only after verifying that
  HarmonyOS has no usable native, kit, or MindSpore-model equivalent and the
  user approves the difference.
- MindSpore model flows run with packaged or selected `.ms` models.
- Camera and picker flows handle permission denial and success.
- Generated folders, local properties, cloned Android source, and build outputs
  remain ignored by Git.

## External References

- MindSpore Lite downloads: https://www.mindspore.cn/lite/docs/en/master/use/downloads.html
- HarmonyOS MindSpore Lite ArkTS guide: https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/mindspore-guidelines-based-js
- HarmonyOS MindSpore Lite C/C++ guide: https://developer.huawei.com/consumer/cn/doc/HarmonyOS-Guides/mindspore-lite-guidelines
