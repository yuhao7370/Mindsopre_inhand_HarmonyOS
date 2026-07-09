import { common } from '@kit.AbilityKit';
import { fileIo } from '@kit.CoreFileKit';
import { image } from '@kit.ImageKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { AppStringKey } from '../../common/i18n/AppStrings';

export const resultImageTitlePrefix = 'MindSpore_Result';
export const resultImagePackingOption: image.PackingOption = {
  format: 'image/jpeg',
  quality: 100
};

export interface ResultImageSaveResult {
  readonly ok: boolean;
  readonly uri: string;
  readonly messageKey: AppStringKey;
}

export interface ResultImagePixelMapEncoder {
  encodeJpeg(pixelMap: image.PixelMap): Promise<ArrayBuffer>;
}

export interface ResultImageAssetWriter {
  writeJpeg(bytes: ArrayBuffer): Promise<string>;
}

export function isFullResultImageWrite(bytes: ArrayBuffer, writtenByteCount: number): boolean {
  return writtenByteCount === bytes.byteLength;
}

export class ResultImageSaveService {
  private readonly encoder: ResultImagePixelMapEncoder;
  private readonly writer: ResultImageAssetWriter;

  constructor(encoder: ResultImagePixelMapEncoder, writer: ResultImageAssetWriter) {
    this.encoder = encoder;
    this.writer = writer;
  }

  async save(pixelMap: image.PixelMap | undefined): Promise<ResultImageSaveResult> {
    if (pixelMap === undefined) {
      return { ok: false, uri: '', messageKey: 'feature_runtime_save_image_missing' };
    }
    try {
      const bytes = await this.encoder.encodeJpeg(pixelMap);
      if (bytes.byteLength === 0) {
        return { ok: false, uri: '', messageKey: 'feature_runtime_save_image_failed' };
      }
      const uri = await this.writer.writeJpeg(bytes);
      if (uri.length === 0) {
        return { ok: false, uri: '', messageKey: 'feature_runtime_save_image_failed' };
      }
      return { ok: true, uri: uri, messageKey: 'feature_runtime_save_image_done' };
    } catch (_) {
      return { ok: false, uri: '', messageKey: 'feature_runtime_save_image_failed' };
    }
  }
}

export class HarmonyResultImagePixelMapEncoder implements ResultImagePixelMapEncoder {
  async encodeJpeg(pixelMap: image.PixelMap): Promise<ArrayBuffer> {
    const packer = image.createImagePacker();
    try {
      return await packer.packToData(pixelMap, resultImagePackingOption);
    } finally {
      await packer.release();
    }
  }
}

export class HarmonyResultImageAssetWriter implements ResultImageAssetWriter {
  private readonly context: common.UIAbilityContext;

  constructor(context: common.UIAbilityContext) {
    this.context = context;
  }

  async writeJpeg(bytes: ArrayBuffer): Promise<string> {
    const helper = photoAccessHelper.getPhotoAccessHelper(this.context);
    const uri = await helper.createAssetWithShortTermPermission({
      title: `${resultImageTitlePrefix}_${Date.now()}`,
      fileNameExtension: 'jpg',
      photoType: photoAccessHelper.PhotoType.IMAGE,
      subtype: photoAccessHelper.PhotoSubtype.DEFAULT
    });
    const file = await fileIo.open(uri, fileIo.OpenMode.READ_WRITE);
    try {
      const writtenByteCount = await fileIo.write(file.fd, bytes);
      if (!isFullResultImageWrite(bytes, writtenByteCount)) {
        throw new Error('result image write incomplete');
      }
      return uri;
    } finally {
      await fileIo.close(file);
    }
  }
}
