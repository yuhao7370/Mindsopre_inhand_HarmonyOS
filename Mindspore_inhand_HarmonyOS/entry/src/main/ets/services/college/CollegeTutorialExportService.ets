import { collegeTutorialExportFileName } from '../../common/data/CollegeLocalQuickStart';

export type CollegeTutorialExportStatus = 'idle' | 'exporting' | 'done' | 'failed';

export interface CollegeTutorialExportResult {
  readonly ok: boolean;
  readonly cancelled: boolean;
}

export type CollegeDestinationPicker = (defaultName: string) => Promise<string>;
export type CollegePackageReader = () => Promise<Uint8Array>;
export type CollegePackageWriter = (uri: string, bytes: Uint8Array) => Promise<number>;

export class CollegeTutorialExportService {
  private readonly pickDestination: CollegeDestinationPicker;
  private readonly readPackage: CollegePackageReader;
  private readonly writePackage: CollegePackageWriter;

  constructor(
    pickDestination: CollegeDestinationPicker,
    readPackage: CollegePackageReader,
    writePackage: CollegePackageWriter
  ) {
    this.pickDestination = pickDestination;
    this.readPackage = readPackage;
    this.writePackage = writePackage;
  }

  async exportPackage(): Promise<CollegeTutorialExportResult> {
    const destination = await this.pickDestination(collegeTutorialExportFileName);
    if (destination.length === 0) {
      return { ok: false, cancelled: true };
    }
    try {
      const bytes = await this.readPackage();
      const written = await this.writePackage(destination, bytes);
      return { ok: written === bytes.length, cancelled: false };
    } catch (_) {
      return { ok: false, cancelled: false };
    }
  }
}
