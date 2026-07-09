import { common } from '@kit.AbilityKit';
import { fileIo } from '@kit.CoreFileKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { resourceManager } from '@kit.LocalizationKit';
import { AppStringKey } from '../../common/i18n/AppStrings';

export const qrCodeImageTitlePrefix = 'MindSpore_QR';

export interface QrCodeSaveResult {
  readonly ok: boolean;
  readonly uri: string;
  readonly messageKey: AppStringKey;
}

export interface QrCodeMediaReader {
  readQrCodeImage(): ArrayBuffer;
}

export interface QrCodeAssetWriter {
  writeJpeg(bytes: ArrayBuffer): Promise<string>;
}

export function isFullQrCodeWrite(bytes: ArrayBuffer, writtenByteCount: number): boolean {
  return writtenByteCount === bytes.byteLength;
}

export class QrCodeSaveService {
  private readonly reader: QrCodeMediaReader;
  private readonly writer: QrCodeAssetWriter;

  constructor(reader: QrCodeMediaReader, writer: QrCodeAssetWriter) {
    this.reader = reader;
    this.writer = writer;
  }

  async save(): Promise<QrCodeSaveResult> {
    try {
      const bytes = this.reader.readQrCodeImage();
      const uri = await this.writer.writeJpeg(bytes);
      if (uri.length === 0) {
        return { ok: false, uri: '', messageKey: 'qr_code_save_failed' };
      }
      return { ok: true, uri: uri, messageKey: 'qr_code_save_done' };
    } catch (_) {
      return { ok: false, uri: '', messageKey: 'qr_code_save_failed' };
    }
  }
}

export class HarmonyQrCodeMediaReader implements QrCodeMediaReader {
  private readonly manager: resourceManager.ResourceManager;
  private readonly mediaResource: Resource;

  constructor(manager: resourceManager.ResourceManager, mediaResource: Resource) {
    this.manager = manager;
    this.mediaResource = mediaResource;
  }

  readQrCodeImage(): ArrayBuffer {
    return arrayBufferFromUint8Array(this.manager.getMediaContentSync(this.mediaResource.id));
  }
}

export class HarmonyQrCodeAssetWriter implements QrCodeAssetWriter {
  private readonly context: common.UIAbilityContext;

  constructor(context: common.UIAbilityContext) {
    this.context = context;
  }

  async writeJpeg(bytes: ArrayBuffer): Promise<string> {
    const helper = photoAccessHelper.getPhotoAccessHelper(this.context);
    const uri = await helper.createAssetWithShortTermPermission({
      title: `${qrCodeImageTitlePrefix}_${Date.now()}`,
      fileNameExtension: 'jpg',
      photoType: photoAccessHelper.PhotoType.IMAGE,
      subtype: photoAccessHelper.PhotoSubtype.DEFAULT
    });
    const file = await fileIo.open(uri, fileIo.OpenMode.READ_WRITE);
    try {
      const writtenByteCount = await fileIo.write(file.fd, bytes);
      if (!isFullQrCodeWrite(bytes, writtenByteCount)) {
        throw new Error('qr code image write incomplete');
      }
      return uri;
    } finally {
      await fileIo.close(file);
    }
  }
}

function arrayBufferFromUint8Array(content: Uint8Array): ArrayBuffer {
  const copy = new Uint8Array(content.length);
  copy.set(content);
  return copy.buffer as ArrayBuffer;
}
