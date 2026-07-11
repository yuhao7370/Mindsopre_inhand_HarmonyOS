import { FeatureWorkflow } from '../../features/runtime/FeatureWorkflowCatalog';
import { AppStringKey } from '../../common/i18n/AppStrings';
import {
  ImageClassificationResult,
  ImageClassificationRunResult,
  ImageClassificationService
} from './ImageClassificationService';
import { customModelDefaultModelUri, CustomModelRunResult, CustomModelService } from './CustomModelService';
import {
  ObjectDetection,
  ObjectDetectionRunResult,
  ObjectDetectionService
} from './ObjectDetectionService';
import {
  StyleTransferModelUris,
  StyleTransferResult,
  StyleTransferService
} from './StyleTransferService';
import {
  SegmentationRectangle,
  SegmentationResult,
  SegmentationService
} from './SegmentationService';
import {
  PosePoint,
  PoseResult,
  PoseService,
  poseSimilarityPercent
} from './PoseService';
import {
  GestureDetection,
  GestureResult,
  GestureService,
  gestureDetectionLabel,
  gestureDetectionLabelKey
} from './GestureService';
import {
  SceneDetection,
  SceneDetectionResult,
  SceneDetectionService
} from './SceneDetectionService';
import {
  LocalTextTranslationRunner,
  TextRecognitionResult,
  TextRecognitionService,
  TextTranslationResult,
  TextTranslationService
} from './TextRecognitionService';

export type AiRunCode =
  'NATIVE_ADAPTER_PENDING' |
  'MISSING_INPUT' |
  'CUSTOM_MODEL_DONE' |
  'CUSTOM_MODEL_FAILED' |
  'CLASSIFICATION_MODEL_PENDING' |
  'CLASSIFICATION_DONE' |
  'CLASSIFICATION_FAILED' |
  'OBJECT_DETECTION_DONE' |
  'OBJECT_DETECTION_FAILED' |
  'STYLE_TRANSFER_DONE' |
  'STYLE_TRANSFER_FAILED' |
  'TEXT_RECOGNITION_DONE' |
  'TEXT_RECOGNITION_FAILED' |
  'TEXT_TRANSLATION_DONE' |
  'TEXT_TRANSLATION_FAILED' |
  'SEGMENTATION_DONE' |
  'SEGMENTATION_FAILED' |
  'POSE_DETECTION_DONE' |
  'POSE_DETECTION_FAILED' |
  'GESTURE_DETECTION_DONE' |
  'GESTURE_DETECTION_FAILED' |
  'SCENE_DETECTION_DONE' |
  'SCENE_DETECTION_FAILED';

export interface AiRunInputs {
  readonly imageUri?: string;
  readonly contentImageUri?: string;
  readonly styleImageUri?: string;
  readonly backgroundImageUri?: string;
  readonly stylePredictModelUri?: string;
  readonly styleTransferModelUri?: string;
  readonly modelUri?: string;
  readonly text?: string;
}

export type AiRunData =
  AiClassificationData |
  AiObjectDetectionsData |
  AiStyleTransferData |
  AiTextRecognitionData |
  AiTextTranslationData |
  AiSegmentationData |
  AiPoseData |
  AiGestureData |
  AiSceneData |
  AiCustomModelData;

export interface AiClassificationData {
  readonly kind: 'classification';
  readonly imageUri: string;
  readonly classification: ImageClassificationResult;
}

export interface AiObjectDetectionsData {
  readonly kind: 'objectDetections';
  readonly imageUri: string;
  readonly modelUri: string;
  readonly detections: Array<ObjectDetection>;
}

export interface AiStyleTransferData {
  readonly kind: 'styleTransfer';
  readonly contentImageUri: string;
  readonly styleImageUri: string;
  readonly result: StyleTransferResult;
}

export interface AiTextRecognitionData {
  readonly kind: 'textRecognition';
  readonly imageUri: string;
  readonly result: TextRecognitionResult;
}

export interface AiTextTranslationData {
  readonly kind: 'textTranslation';
  readonly result: TextTranslationResult;
}

export interface AiSegmentationData {
  readonly kind: 'segmentation';
  readonly imageUri: string;
  readonly backgroundImageUri: string;
  readonly result: SegmentationResult;
}

export interface AiPoseData {
  readonly kind: 'pose';
  readonly imageUri: string;
  readonly result: PoseResult;
}

export interface AiGestureData {
  readonly kind: 'gesture';
  readonly imageUri: string;
  readonly result: GestureResult;
}

export interface AiSceneData {
  readonly kind: 'scenes';
  readonly imageUri: string;
  readonly result: SceneDetectionResult;
}

export interface AiCustomModelData {
  readonly kind: 'customModel';
  readonly imageUri: string;
  readonly modelUri: string;
  readonly outputCount: number;
  readonly executionMs: number;
}

export interface AiRunResultRow {
  readonly labelKey: AppStringKey;
  readonly value: string;
  readonly valueKey?: AppStringKey;
}

export interface AiRunResult {
  readonly ok: boolean;
  readonly code: AiRunCode;
  readonly aiMethod: string;
  readonly messageKey: AppStringKey;
  readonly detailText: string;
  readonly data?: AiRunData;
}

export interface AiServiceOptions {
  readonly imageClassificationService?: ImageClassificationService;
  readonly customModelService?: CustomModelService;
  readonly objectDetectionService?: ObjectDetectionService;
  readonly styleTransferService?: StyleTransferService;
  readonly textRecognitionService?: TextRecognitionService;
  readonly textTranslationService?: TextTranslationService;
  readonly segmentationService?: SegmentationService;
  readonly poseService?: PoseService;
  readonly gestureService?: GestureService;
  readonly sceneDetectionService?: SceneDetectionService;
}

export class DefaultAiService {
  private readonly imageClassificationService: ImageClassificationService;
  private readonly customModelService?: CustomModelService;
  private readonly objectDetectionService?: ObjectDetectionService;
  private readonly styleTransferService?: StyleTransferService;
  private readonly textRecognitionService?: TextRecognitionService;
  private readonly textTranslationService: TextTranslationService;
  private readonly segmentationService?: SegmentationService;
  private readonly poseService?: PoseService;
  private readonly gestureService?: GestureService;
  private readonly sceneDetectionService?: SceneDetectionService;

  constructor(options?: AiServiceOptions) {
    this.imageClassificationService = options?.imageClassificationService ?? new ImageClassificationService({
      labels: []
    });
    this.customModelService = options?.customModelService;
    this.objectDetectionService = options?.objectDetectionService;
    this.styleTransferService = options?.styleTransferService;
    this.textRecognitionService = options?.textRecognitionService;
    this.textTranslationService = options?.textTranslationService ?? new TextTranslationService({
      runner: new LocalTextTranslationRunner()
    });
    this.segmentationService = options?.segmentationService;
    this.poseService = options?.poseService;
    this.gestureService = options?.gestureService;
    this.sceneDetectionService = options?.sceneDetectionService;
  }

  async run(workflow: FeatureWorkflow, inputs: AiRunInputs = {}): Promise<AiRunResult> {
    if (workflow.aiMethod === 'classifyImage') {
      return this.classifyImage(inputs);
    }
    if (workflow.aiMethod === 'detectObjects') {
      return this.detectObjects(inputs);
    }
    if (workflow.aiMethod === 'runStyleTransfer') {
      return this.runStyleTransfer(inputs);
    }
    if (workflow.aiMethod === 'recognizeText') {
      return this.recognizeText(inputs);
    }
    if (workflow.aiMethod === 'translateText') {
      return this.translateText(inputs);
    }
    if (workflow.aiMethod === 'segmentPerson') {
      return this.segmentPerson(inputs);
    }
    if (workflow.aiMethod === 'detectPose') {
      return this.detectPose(inputs);
    }
    if (workflow.aiMethod === 'detectGesture') {
      return this.detectGesture(inputs);
    }
    if (workflow.aiMethod === 'detectScene') {
      return this.detectScene(inputs);
    }
    if (workflow.aiMethod === 'runCustomModel') {
      return this.runCustomModel(inputs);
    }
    return {
      ok: false,
      code: 'NATIVE_ADAPTER_PENDING',
      aiMethod: workflow.aiMethod,
      messageKey: 'feature_runtime_pending_adapter',
      detailText: ''
    };
  }

  private async detectGesture(inputs: AiRunInputs): Promise<AiRunResult> {
    if (this.gestureService === undefined) {
      return this.runnerUnavailableResult('detectGesture', 'feature_runtime_gesture_runner_unavailable');
    }

    const imageUri = inputs.imageUri ?? '';
    if (imageUri.length === 0) {
      return {
        ok: false,
        code: 'MISSING_INPUT',
        aiMethod: 'detectGesture',
        messageKey: 'feature_runtime_missing_input',
        detailText: ''
      };
    }

    const result: GestureResult = await this.gestureService.detectGesture(imageUri);
    if (!result.ok || result.gestures.length === 0) {
      return {
        ok: false,
        code: 'GESTURE_DETECTION_FAILED',
        aiMethod: 'detectGesture',
        messageKey: 'feature_runtime_gesture_failed',
        detailText: this.gestureSummary(result, imageUri)
      };
    }
    return {
      ok: true,
      code: 'GESTURE_DETECTION_DONE',
      aiMethod: 'detectGesture',
      messageKey: 'feature_runtime_gesture_done',
      detailText: this.gestureSummary(result, imageUri),
      data: {
        kind: 'gesture',
        imageUri: imageUri,
        result: result
      }
    };
  }

  private async detectScene(inputs: AiRunInputs): Promise<AiRunResult> {
    if (this.sceneDetectionService === undefined) {
      return this.runnerUnavailableResult('detectScene', 'feature_runtime_scene_runner_unavailable');
    }

    const imageUri = inputs.imageUri ?? '';
    if (imageUri.length === 0) {
      return {
        ok: false,
        code: 'MISSING_INPUT',
        aiMethod: 'detectScene',
        messageKey: 'feature_runtime_missing_input',
        detailText: ''
      };
    }

    const result: SceneDetectionResult = await this.sceneDetectionService.detectScenes(imageUri);
    if (!result.ok || result.scenes.length === 0) {
      return {
        ok: false,
        code: 'SCENE_DETECTION_FAILED',
        aiMethod: 'detectScene',
        messageKey: 'feature_runtime_scene_failed',
        detailText: this.sceneDetectionSummary(result, imageUri)
      };
    }
    return {
      ok: true,
      code: 'SCENE_DETECTION_DONE',
      aiMethod: 'detectScene',
      messageKey: 'feature_runtime_scene_done',
      detailText: this.sceneDetectionSummary(result, imageUri),
      data: {
        kind: 'scenes',
        imageUri: imageUri,
        result: result
      }
    };
  }

  private async detectPose(inputs: AiRunInputs): Promise<AiRunResult> {
    if (this.poseService === undefined) {
      return {
        ok: false,
        code: 'NATIVE_ADAPTER_PENDING',
        aiMethod: 'detectPose',
        messageKey: 'feature_runtime_pending_adapter',
        detailText: ''
      };
    }

    const imageUri = inputs.imageUri ?? '';
    if (imageUri.length === 0) {
      return {
        ok: false,
        code: 'MISSING_INPUT',
        aiMethod: 'detectPose',
        messageKey: 'feature_runtime_missing_input',
        detailText: ''
      };
    }

    const result: PoseResult = await this.poseService.detectPose(imageUri);
    if (!result.ok) {
      return {
        ok: false,
        code: 'POSE_DETECTION_FAILED',
        aiMethod: 'detectPose',
        messageKey: 'feature_runtime_pose_failed',
        detailText: this.poseSummary(result, imageUri)
      };
    }
    return {
      ok: true,
      code: 'POSE_DETECTION_DONE',
      aiMethod: 'detectPose',
      messageKey: 'feature_runtime_pose_done',
      detailText: this.poseSummary(result, imageUri),
      data: {
        kind: 'pose',
        imageUri: imageUri,
        result: result
      }
    };
  }

  private async segmentPerson(inputs: AiRunInputs): Promise<AiRunResult> {
    if (this.segmentationService === undefined) {
      return {
        ok: false,
        code: 'NATIVE_ADAPTER_PENDING',
        aiMethod: 'segmentPerson',
        messageKey: 'feature_runtime_pending_adapter',
        detailText: ''
      };
    }

    const imageUri = inputs.imageUri ?? '';
    if (imageUri.length === 0) {
      return {
        ok: false,
        code: 'MISSING_INPUT',
        aiMethod: 'segmentPerson',
        messageKey: 'feature_runtime_missing_input',
        detailText: ''
      };
    }

    const result: SegmentationResult = await this.segmentationService.segmentPerson(imageUri);
    const backgroundImageUri = inputs.backgroundImageUri ?? '';
    if (!result.ok) {
      return {
        ok: false,
        code: 'SEGMENTATION_FAILED',
        aiMethod: 'segmentPerson',
        messageKey: 'feature_runtime_segmentation_failed',
        detailText: this.segmentationSummary(result, imageUri, backgroundImageUri)
      };
    }
    return {
      ok: true,
      code: 'SEGMENTATION_DONE',
      aiMethod: 'segmentPerson',
      messageKey: 'feature_runtime_segmentation_done',
      detailText: this.segmentationSummary(result, imageUri, backgroundImageUri),
      data: {
        kind: 'segmentation',
        imageUri: imageUri,
        backgroundImageUri: backgroundImageUri,
        result: result
      }
    };
  }

  private async recognizeText(inputs: AiRunInputs): Promise<AiRunResult> {
    if (this.textRecognitionService === undefined) {
      return {
        ok: false,
        code: 'NATIVE_ADAPTER_PENDING',
        aiMethod: 'recognizeText',
        messageKey: 'feature_runtime_pending_adapter',
        detailText: ''
      };
    }

    const imageUri = inputs.imageUri ?? '';
    if (imageUri.length === 0) {
      return {
        ok: false,
        code: 'MISSING_INPUT',
        aiMethod: 'recognizeText',
        messageKey: 'feature_runtime_missing_input',
        detailText: ''
      };
    }

    const result: TextRecognitionResult = await this.textRecognitionService.recognizeText(imageUri);
    if (!result.ok) {
      return {
        ok: false,
        code: 'TEXT_RECOGNITION_FAILED',
        aiMethod: 'recognizeText',
        messageKey: 'feature_runtime_text_recognition_failed',
        detailText: this.textRecognitionSummary(result, imageUri)
      };
    }
    return {
      ok: true,
      code: 'TEXT_RECOGNITION_DONE',
      aiMethod: 'recognizeText',
      messageKey: 'feature_runtime_text_recognition_done',
      detailText: this.textRecognitionSummary(result, imageUri),
      data: {
        kind: 'textRecognition',
        imageUri: imageUri,
        result: result
      }
    };
  }

  private async translateText(inputs: AiRunInputs): Promise<AiRunResult> {
    let text = inputs.text ?? '';
    const imageUri = inputs.imageUri ?? '';
    if (text.length === 0 && imageUri.length > 0) {
      if (this.textRecognitionService === undefined) {
        return this.pendingAdapterResult('translateText');
      }
      const recognitionResult: TextRecognitionResult = await this.textRecognitionService.recognizeText(imageUri);
      if (!recognitionResult.ok || recognitionResult.text.length === 0) {
        return {
          ok: false,
          code: 'TEXT_RECOGNITION_FAILED',
          aiMethod: 'translateText',
          messageKey: 'feature_runtime_text_recognition_failed',
          detailText: this.textRecognitionSummary(recognitionResult, imageUri)
        };
      }
      text = recognitionResult.text;
    }

    if (text.length === 0) {
      return {
        ok: false,
        code: 'MISSING_INPUT',
        aiMethod: 'translateText',
        messageKey: 'feature_runtime_missing_input',
        detailText: ''
      };
    }

    const result: TextTranslationResult = await this.textTranslationService.translateText(text);
    if (!result.ok) {
      return {
        ok: false,
        code: 'TEXT_TRANSLATION_FAILED',
        aiMethod: 'translateText',
        messageKey: 'feature_runtime_text_translation_failed',
        detailText: this.textTranslationSummary(result),
        data: {
          kind: 'textTranslation',
          result: result
        }
      };
    }
    return {
      ok: true,
      code: 'TEXT_TRANSLATION_DONE',
      aiMethod: 'translateText',
      messageKey: 'feature_runtime_text_translation_done',
      detailText: this.textTranslationSummary(result),
      data: {
        kind: 'textTranslation',
        result: result
      }
    };
  }

  private pendingAdapterResult(aiMethod: string): AiRunResult {
    return {
      ok: false,
      code: 'NATIVE_ADAPTER_PENDING',
      aiMethod: aiMethod,
      messageKey: 'feature_runtime_pending_adapter',
      detailText: ''
    };
  }

  private runnerUnavailableResult(aiMethod: string, messageKey: AppStringKey): AiRunResult {
    return {
      ok: false,
      code: 'NATIVE_ADAPTER_PENDING',
      aiMethod: aiMethod,
      messageKey: messageKey,
      detailText: ''
    };
  }

  private async runStyleTransfer(inputs: AiRunInputs): Promise<AiRunResult> {
    if (this.styleTransferService === undefined) {
      return {
        ok: false,
        code: 'NATIVE_ADAPTER_PENDING',
        aiMethod: 'runStyleTransfer',
        messageKey: 'feature_runtime_pending_adapter',
        detailText: ''
      };
    }

    const contentImageUri = inputs.contentImageUri ?? '';
    const styleImageUri = inputs.styleImageUri ?? '';
    if (contentImageUri.length === 0 || styleImageUri.length === 0) {
      return {
        ok: false,
        code: 'MISSING_INPUT',
        aiMethod: 'runStyleTransfer',
        messageKey: 'feature_runtime_missing_input',
        detailText: ''
      };
    }

    const modelUris: StyleTransferModelUris = {
      predictModelUri: inputs.stylePredictModelUri ?? '',
      transferModelUri: inputs.styleTransferModelUri ?? ''
    };
    const result = await this.styleTransferService.run(contentImageUri, styleImageUri, modelUris);
    if (!result.ok) {
      return {
        ok: false,
        code: 'STYLE_TRANSFER_FAILED',
        aiMethod: 'runStyleTransfer',
        messageKey: 'feature_runtime_style_transfer_failed',
        detailText: this.styleTransferSummary(result, contentImageUri, styleImageUri)
      };
    }
    return {
      ok: true,
      code: 'STYLE_TRANSFER_DONE',
      aiMethod: 'runStyleTransfer',
      messageKey: 'feature_runtime_style_transfer_done',
      detailText: this.styleTransferSummary(result, contentImageUri, styleImageUri),
      data: {
        kind: 'styleTransfer',
        contentImageUri: contentImageUri,
        styleImageUri: styleImageUri,
        result: result
      }
    };
  }

  private async detectObjects(inputs: AiRunInputs): Promise<AiRunResult> {
    if (this.objectDetectionService === undefined) {
      return {
        ok: false,
        code: 'NATIVE_ADAPTER_PENDING',
        aiMethod: 'detectObjects',
        messageKey: 'feature_runtime_pending_adapter',
        detailText: ''
      };
    }

    const imageUri = inputs.imageUri ?? '';
    if (imageUri.length === 0) {
      return {
        ok: false,
        code: 'MISSING_INPUT',
        aiMethod: 'detectObjects',
        messageKey: 'feature_runtime_missing_input',
        detailText: ''
      };
    }

    const result: ObjectDetectionRunResult =
      await this.objectDetectionService.detectObjects(imageUri, inputs.modelUri);
    if (result.ok) {
      return {
        ok: true,
        code: 'OBJECT_DETECTION_DONE',
        aiMethod: 'detectObjects',
        messageKey: 'feature_runtime_object_detection_done',
        detailText: this.objectDetectionSummary(result.detections, imageUri, inputs.modelUri ?? ''),
        data: {
          kind: 'objectDetections',
          imageUri: imageUri,
          modelUri: inputs.modelUri ?? '',
          detections: result.detections
        }
      };
    }
    return {
      ok: false,
      code: 'OBJECT_DETECTION_FAILED',
      aiMethod: 'detectObjects',
      messageKey: 'feature_runtime_object_detection_failed',
      detailText: this.objectDetectionFailureSummary(result, imageUri, inputs.modelUri ?? '')
    };
  }

  private async classifyImage(inputs: AiRunInputs): Promise<AiRunResult> {
    const imageUri = inputs.imageUri ?? '';
    if (imageUri.length === 0) {
      return {
        ok: false,
        code: 'MISSING_INPUT',
        aiMethod: 'classifyImage',
        messageKey: 'feature_runtime_missing_input',
        detailText: ''
      };
    }

    const result: ImageClassificationRunResult = await this.imageClassificationService.classifyImage(imageUri);
    if (result.code === 'MODEL_PENDING') {
      return {
        ok: false,
        code: 'CLASSIFICATION_MODEL_PENDING',
        aiMethod: 'classifyImage',
        messageKey: 'feature_runtime_classification_runner_unavailable',
        detailText: ''
      };
    }
    if (result.ok) {
      return {
        ok: true,
        code: 'CLASSIFICATION_DONE',
        aiMethod: 'classifyImage',
        messageKey: 'feature_runtime_classification_done',
        detailText: this.imageClassificationSummary(result.classification, imageUri),
        data: {
          kind: 'classification',
          imageUri: imageUri,
          classification: result.classification
        }
      };
    }
    return {
      ok: false,
      code: 'CLASSIFICATION_FAILED',
      aiMethod: 'classifyImage',
      messageKey: 'feature_runtime_classification_failed',
      detailText: this.imageClassificationFailureSummary(result, imageUri)
    };
  }

  private async runCustomModel(inputs: AiRunInputs): Promise<AiRunResult> {
    const selectedModelUri = inputs.modelUri ?? '';
    const modelUri = selectedModelUri.length > 0 ? selectedModelUri : customModelDefaultModelUri;
    const imageUri = inputs.imageUri ?? '';
    if (imageUri.length === 0) {
      return {
        ok: false,
        code: 'MISSING_INPUT',
        aiMethod: 'runCustomModel',
        messageKey: 'feature_runtime_missing_input',
        detailText: ''
      };
    }
    if (this.customModelService !== undefined) {
      return this.runCustomModelWithService(this.customModelService, modelUri, imageUri);
    }
    return this.pendingAdapterResult('runCustomModel');
  }

  private async runCustomModelWithService(
    service: CustomModelService,
    modelUri: string,
    imageUri: string
  ): Promise<AiRunResult> {
    try {
      const result = await service.run(modelUri, imageUri);
      if (!result.ok) {
        return this.customModelFailedResult(modelUri, imageUri);
      }
      return {
        ok: true,
        code: 'CUSTOM_MODEL_DONE',
        aiMethod: 'runCustomModel',
        messageKey: 'feature_runtime_custom_model_done',
        detailText: this.customModelExecutionSummary(result),
        data: {
          kind: 'customModel',
          imageUri: imageUri,
          modelUri: modelUri,
          outputCount: result.output.length,
          executionMs: result.executionMs
        }
      };
    } catch (_) {
      return this.customModelFailedResult(modelUri, imageUri);
    }
  }

  private customModelFailedResult(modelUri: string, imageUri: string): AiRunResult {
    return {
      ok: false,
      code: 'CUSTOM_MODEL_FAILED',
      aiMethod: 'runCustomModel',
      messageKey: 'feature_runtime_custom_model_failed',
      detailText: `model=${this.lastPathSegment(modelUri)}\nimage=${this.lastPathSegment(imageUri)}`
    };
  }

  private customModelExecutionSummary(result: CustomModelRunResult): string {
    const lines: Array<string> = [
      'Model execution completed!',
      '',
      `Execution time: ${result.executionMs}ms`,
      '',
      'Output data (first 10 values):'
    ];
    const displayCount = Math.min(10, result.output.length);
    for (let index = 0; index < displayCount; index++) {
      lines.push(`Value[${index}]: ${result.output[index].toFixed(6)}`);
    }
    if (result.output.length > 10) {
      lines.push('... (showing first 10 values)');
    }
    return lines.join('\n');
  }

  private imageClassificationSummary(classification: ImageClassificationResult, imageUri: string): string {
    const lines: Array<string> = [
      `label=${classification.label}`,
      `score=${classification.score.toFixed(6)}`,
      `index=${classification.index}`,
      `image=${this.lastPathSegment(imageUri)}`
    ];
    return lines.join('\n');
  }

  private imageClassificationFailureSummary(result: ImageClassificationRunResult, imageUri: string): string {
    const lines: Array<string> = [
      `image=${this.lastPathSegment(imageUri)}`,
      `reason=${result.code}`,
      `index=${result.classification.index}`,
      `score=${result.classification.score.toFixed(6)}`
    ];
    return lines.join('\n');
  }

  private objectDetectionSummary(detections: Array<ObjectDetection>, imageUri: string, modelUri: string): string {
    const lines: Array<string> = [
      `image=${this.lastPathSegment(imageUri)}`
    ];
    if (modelUri.length > 0) {
      lines.push(`model=${this.lastPathSegment(modelUri)}`);
    }
    lines.push(`detections=${detections.length}`);
    detections.forEach((detection: ObjectDetection, index: number) => {
      const label = detection.label.length > 0 ? detection.label : `${detection.labelId}`;
      lines.push(`${index + 1}. ${label} ${(detection.score * 100).toFixed(2)}% ` +
        `[${detection.left.toFixed(0)},${detection.top.toFixed(0)},` +
        `${detection.right.toFixed(0)},${detection.bottom.toFixed(0)}]`);
    });
    return lines.join('\n');
  }

  private objectDetectionFailureSummary(
    result: ObjectDetectionRunResult,
    imageUri: string,
    modelUri: string
  ): string {
    const lines: Array<string> = [
      `image=${this.lastPathSegment(imageUri)}`,
      `reason=${result.code}`
    ];
    if (modelUri.length > 0) {
      lines.push(`model=${this.lastPathSegment(modelUri)}`);
    }
    return lines.join('\n');
  }

  private poseSummary(result: PoseResult, imageUri: string): string {
    const lines: Array<string> = [
      `image=${this.lastPathSegment(imageUri)}`,
      `skeletonCount=${result.skeletonCount}`,
      `pointCount=${result.pointCount}`,
      `executionMs=${result.executionMs}`
    ];
    if (result.similarity !== undefined) {
      lines.push(`similarity=${poseSimilarityPercent(result.similarity)}`);
    }
    result.points.forEach((point: PosePoint, index: number) => {
      lines.push(`${index + 1}. ${point.type} ${(point.score * 100).toFixed(2)}% ` +
        `[${point.x.toFixed(0)},${point.y.toFixed(0)}]`);
    });
    return lines.join('\n');
  }

  private segmentationSummary(result: SegmentationResult, imageUri: string, backgroundImageUri: string): string {
    const lines: Array<string> = [
      `image=${this.lastPathSegment(imageUri)}`,
      `subjectCount=${result.subjectCount}`,
      `detailCount=${result.detailCount}`,
      `foregroundAvailable=${result.foregroundAvailable}`,
      `executionMs=${result.executionMs}`
    ];
    if (backgroundImageUri.length > 0) {
      lines.push(`background=${this.lastPathSegment(backgroundImageUri)}`);
    }
    result.rectangles.forEach((rectangle: SegmentationRectangle, index: number) => {
      lines.push(`${index + 1}. [` +
        `${rectangle.left.toFixed(0)},${rectangle.top.toFixed(0)},` +
        `${rectangle.width.toFixed(0)},${rectangle.height.toFixed(0)}]`);
    });
    return lines.join('\n');
  }

  private textRecognitionSummary(result: TextRecognitionResult, imageUri: string): string {
    const lines: Array<string> = [
      `image=${this.lastPathSegment(imageUri)}`,
      `lineCount=${result.lineCount}`,
      `blockCount=${result.blockCount}`,
      `executionMs=${result.executionMs}`
    ];
    if (result.text.length > 0) {
      lines.push('text=');
      lines.push(result.text);
    }
    return lines.join('\n');
  }

  private gestureSummary(result: GestureResult, imageUri: string): string {
    const lines: Array<string> = [
      `image=${this.lastPathSegment(imageUri)}`,
      `count=${result.gestures.length}`,
      `executionMs=${result.executionMs}`
    ];
    const displayCount = Math.min(5, result.gestures.length);
    for (let index = 0; index < displayCount; index++) {
      const gesture = result.gestures[index];
      lines.push(`${index + 1}. ${this.gestureLine(gesture)}`);
    }
    return lines.join('\n');
  }

  private sceneDetectionSummary(result: SceneDetectionResult, imageUri: string): string {
    const lines: Array<string> = [
      `image=${this.lastPathSegment(imageUri)}`,
      `count=${result.scenes.length}`,
      `executionMs=${result.executionMs}`
    ];
    result.scenes.forEach((scene: SceneDetection, index: number) => {
      lines.push(`${index + 1}. ${scene.label} ${(scene.score * 100).toFixed(2)}%`);
    });
    return lines.join('\n');
  }

  private gestureLine(gesture: GestureDetection): string {
    const label = gestureDetectionLabel(gesture);
    let line = `${label} ${(gesture.score * 100).toFixed(2)}%`;
    if (gesture.rect !== undefined) {
      line += ` [` +
        `${gesture.rect.left.toFixed(0)},${gesture.rect.top.toFixed(0)},` +
        `${gesture.rect.width.toFixed(0)},${gesture.rect.height.toFixed(0)}]`;
    }
    return line;
  }

  private textTranslationSummary(result: TextTranslationResult): string {
    const lines: Array<string> = [
      `targetLanguage=${result.targetLanguage}`,
      `source=${result.sourceText}`,
      `translated=${result.translatedText}`
    ];
    return lines.join('\n');
  }

  private styleTransferSummary(
    result: StyleTransferResult,
    contentImageUri: string,
    styleImageUri: string
  ): string {
    const lines: Array<string> = [
      `content=${this.lastPathSegment(contentImageUri)}`,
      `style=${this.lastPathSegment(styleImageUri)}`,
      `outputFloats=${result.outputFloatCount}`,
      `predictMs=${result.predictMs}`,
      `transferMs=${result.transferMs}`,
      `executionMs=${result.executionMs}`
    ];
    return lines.join('\n');
  }

  private lastPathSegment(uri: string): string {
    return runtimePathSegment(uri);
  }

}

export function aiRunResultRows(result: AiRunResult): Array<AiRunResultRow> {
  const data = result.data;
  if (data === undefined) {
    return [];
  }

  switch (data.kind) {
    case 'classification':
      return [
        resultRow('feature_runtime_result_label', data.classification.label),
        resultRow('feature_runtime_result_score', `${(data.classification.score * 100).toFixed(2)}%`),
        resultRow('feature_runtime_result_image', runtimePathSegment(data.imageUri))
      ];
    case 'objectDetections':
      return objectDetectionResultRows(data);
    case 'styleTransfer':
      return [
        resultRow('feature_runtime_result_content_image', runtimePathSegment(data.contentImageUri)),
        resultRow('feature_runtime_result_style_image', runtimePathSegment(data.styleImageUri)),
        resultRow('feature_runtime_result_output', `${data.result.outputFloatCount}`),
        resultRow('feature_runtime_result_execution_time', `${data.result.executionMs}ms`)
      ];
    case 'textRecognition':
      return [
        resultRow('feature_runtime_result_lines', `${data.result.lineCount}`),
        resultRow('feature_runtime_result_image', runtimePathSegment(data.imageUri)),
        resultRow('feature_runtime_result_text', data.result.text)
      ];
    case 'textTranslation':
      const translationRows: Array<AiRunResultRow> = [
        resultRow('feature_runtime_result_target_language', data.result.targetLanguage),
        resultRow('feature_runtime_result_text', data.result.sourceText)
      ];
      if (data.result.translatedText.length > 0) {
        translationRows.push(resultRow('feature_runtime_result_translated_text', data.result.translatedText));
      }
      return translationRows;
    case 'segmentation':
      const segmentationRows: Array<AiRunResultRow> = [
        resultRow('feature_runtime_result_subjects', `${data.result.subjectCount}`),
        resultRow('feature_runtime_result_details', `${data.result.detailCount}`),
        resultRow('feature_runtime_result_foreground', `${data.result.foregroundAvailable}`),
        resultRow('feature_runtime_result_execution_time', `${data.result.executionMs}ms`)
      ];
      if (data.backgroundImageUri.length > 0) {
        segmentationRows.push(resultRow(
          'feature_runtime_result_background',
          runtimePathSegment(data.backgroundImageUri)
        ));
      }
      return segmentationRows;
    case 'pose':
      const poseRows: Array<AiRunResultRow> = [
        resultRow('feature_runtime_result_skeletons', `${data.result.skeletonCount}`),
        resultRow('feature_runtime_result_points', `${data.result.pointCount}`)
      ];
      if (data.result.similarity !== undefined) {
        poseRows.push(resultRow('feature_runtime_result_similarity', poseSimilarityPercent(data.result.similarity)));
      }
      poseRows.push(resultRow('feature_runtime_result_execution_time', `${data.result.executionMs}ms`));
      return poseRows;
    case 'gesture':
      return gestureResultRows(data);
    case 'scenes':
      return sceneDetectionResultRows(data);
    case 'customModel':
      return [
        resultRow('feature_runtime_result_model', runtimePathSegment(data.modelUri)),
        resultRow('feature_runtime_result_output', `${data.outputCount}`),
        resultRow('feature_runtime_result_execution_time', `${data.executionMs}ms`)
      ];
  }
}

function objectDetectionResultRows(data: AiObjectDetectionsData): Array<AiRunResultRow> {
  const rows: Array<AiRunResultRow> = [
    resultRow('feature_runtime_result_count', `${data.detections.length}`)
  ];
  if (data.detections.length > 0) {
    const top = data.detections[0];
    const label = top.label.length > 0 ? top.label : `${top.labelId}`;
    rows.push(resultRow('feature_runtime_result_top_detection', `${label} ${(top.score * 100).toFixed(2)}%`));
  }
  rows.push(resultRow('feature_runtime_result_image', runtimePathSegment(data.imageUri)));
  if (data.modelUri.length > 0) {
    rows.push(resultRow('feature_runtime_result_model', runtimePathSegment(data.modelUri)));
  }
  return rows;
}

function gestureResultRows(data: AiGestureData): Array<AiRunResultRow> {
  const rows: Array<AiRunResultRow> = [
    resultRow('feature_runtime_result_count', `${data.result.gestures.length}`)
  ];
  if (data.result.gestures.length > 0) {
    const top = data.result.gestures[0];
    rows.unshift(resultRow('feature_runtime_result_label', gestureDetectionLabel(top), gestureDetectionLabelKey(top)));
    rows.push(resultRow('feature_runtime_result_score', `${(top.score * 100).toFixed(2)}%`));
  }
  rows.push(resultRow('feature_runtime_result_image', runtimePathSegment(data.imageUri)));
  rows.push(resultRow('feature_runtime_result_execution_time', `${data.result.executionMs}ms`));
  return rows;
}

function sceneDetectionResultRows(data: AiSceneData): Array<AiRunResultRow> {
  const rows: Array<AiRunResultRow> = [
    resultRow('feature_runtime_result_count', `${data.result.scenes.length}`)
  ];
  if (data.result.scenes.length > 0) {
    rows.push(resultRow('feature_runtime_result_scenes', sceneDetectionListText(data.result.scenes)));
  }
  rows.push(resultRow('feature_runtime_result_image', runtimePathSegment(data.imageUri)));
  rows.push(resultRow('feature_runtime_result_execution_time', `${data.result.executionMs}ms`));
  return rows;
}

function sceneDetectionListText(scenes: Array<SceneDetection>): string {
  const lines: Array<string> = [];
  scenes.forEach((scene: SceneDetection, index: number) => {
    lines.push(`${index + 1}. ${scene.label} ${(scene.score * 100).toFixed(2)}%`);
  });
  return lines.join('\n');
}

function resultRow(labelKey: AppStringKey, value: string, valueKey?: AppStringKey): AiRunResultRow {
  return {
    labelKey: labelKey,
    value: value,
    valueKey: valueKey
  };
}

export function copyableTextForAiResult(aiMethod: string, rows: Array<AiRunResultRow>): string {
  if (aiMethod === 'recognizeText') {
    return resultRowValue(rows, 'feature_runtime_result_text');
  }
  if (aiMethod === 'translateText') {
    const translatedText = resultRowValue(rows, 'feature_runtime_result_translated_text');
    return translatedText.length > 0 ? translatedText : resultRowValue(rows, 'feature_runtime_result_text');
  }
  return '';
}

function resultRowValue(rows: Array<AiRunResultRow>, labelKey: AppStringKey): string {
  for (let index = 0; index < rows.length; index++) {
    const row = rows[index];
    if (row.labelKey === labelKey) {
      return row.value;
    }
  }
  return '';
}

function runtimePathSegment(uri: string): string {
  const normalized = uri.split('\\').join('/');
  const parts = normalized.split('/');
  if (parts.length === 0) {
    return uri;
  }
  return parts[parts.length - 1];
}
