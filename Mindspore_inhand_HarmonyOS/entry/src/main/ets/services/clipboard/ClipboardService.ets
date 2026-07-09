import { pasteboard } from '@kit.BasicServicesKit';

export interface CopyTextResult {
  readonly ok: boolean;
  readonly copiedTextLength: number;
}

export interface TextClipboardWriter {
  copyText(text: string): Promise<void>;
}

export class HarmonyPasteboardTextWriter implements TextClipboardWriter {
  async copyText(text: string): Promise<void> {
    const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, text);
    await pasteboard.getSystemPasteboard().setData(data);
  }
}

export class ClipboardService {
  private readonly writer: TextClipboardWriter;

  constructor(writer?: TextClipboardWriter) {
    this.writer = writer ?? new HarmonyPasteboardTextWriter();
  }

  async copyText(text: string): Promise<CopyTextResult> {
    if (text.length === 0) {
      return {
        ok: false,
        copiedTextLength: 0
      };
    }
    try {
      await this.writer.copyText(text);
      return {
        ok: true,
        copiedTextLength: text.length
      };
    } catch (_) {
      return {
        ok: false,
        copiedTextLength: 0
      };
    }
  }
}
