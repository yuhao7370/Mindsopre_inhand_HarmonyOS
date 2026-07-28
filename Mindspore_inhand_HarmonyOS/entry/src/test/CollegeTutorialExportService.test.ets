import { describe, expect, it } from '@ohos/hypium';
import { CollegeTutorialExportService } from '../main/ets/services/college/CollegeTutorialExportService';

export default function collegeTutorialExportServiceUnitTest(): void {
  describe('CollegeTutorialExportServiceUnitTest', () => {
    it('exportsEveryPackageByteAfterDestinationSelection', 0, async () => {
      const bytes = new Uint8Array([1, 2, 3, 4]);
      let written = 0;
      const service = new CollegeTutorialExportService(
        async (name: string): Promise<string> => name.endsWith('.zip') ? 'file://target' : '',
        async (): Promise<Uint8Array> => bytes,
        async (_uri: string, value: Uint8Array): Promise<number> => {
          written = value.length;
          return value.length;
        }
      );
      expect((await service.exportPackage()).ok).assertTrue();
      expect(written).assertEqual(4);
    });

    it('reportsCancellationWithoutReadingPackage', 0, async () => {
      let read = false;
      const service = new CollegeTutorialExportService(
        async (): Promise<string> => '',
        async (): Promise<Uint8Array> => {
          read = true;
          return new Uint8Array();
        },
        async (): Promise<number> => 0
      );
      const result = await service.exportPackage();
      expect(result.ok).assertFalse();
      expect(result.cancelled).assertTrue();
      expect(read).assertFalse();
    });

    it('reportsPickerFailuresAsFailures', 0, async () => {
      const service = new CollegeTutorialExportService(
        async (): Promise<string> => { throw new Error('picker failed'); },
        async (): Promise<Uint8Array> => new Uint8Array(),
        async (): Promise<number> => 0
      );
      const result = await service.exportPackage();
      expect(result.ok).assertFalse();
      expect(result.cancelled).assertFalse();
    });

    it('reportsReaderFailuresWithoutDestination', 0, async () => {
      const readerFailure = new CollegeTutorialExportService(
        async (): Promise<string> => 'file://secret-target',
        async (): Promise<Uint8Array> => { throw new Error('read failed'); },
        async (): Promise<number> => 0
      );
      const result = await readerFailure.exportPackage();
      expect(result.ok).assertFalse();
      expect(result.cancelled).assertFalse();
    });

    it('reportsWriterFailuresWithoutDestination', 0, async () => {
      const writerFailure = new CollegeTutorialExportService(
        async (): Promise<string> => 'file://secret-target',
        async (): Promise<Uint8Array> => new Uint8Array([1]),
        async (): Promise<number> => { throw new Error('write failed'); }
      );
      const result = await writerFailure.exportPackage();
      expect(result.ok).assertFalse();
      expect(result.cancelled).assertFalse();
    });

    it('reportsShortWritesAsFailures', 0, async () => {
      const service = new CollegeTutorialExportService(
        async (): Promise<string> => 'file://secret-target',
        async (): Promise<Uint8Array> => new Uint8Array([1, 2]),
        async (): Promise<number> => 1
      );
      const result = await service.exportPackage();
      expect(result.ok).assertFalse();
      expect(result.cancelled).assertFalse();
    });
  });
}
