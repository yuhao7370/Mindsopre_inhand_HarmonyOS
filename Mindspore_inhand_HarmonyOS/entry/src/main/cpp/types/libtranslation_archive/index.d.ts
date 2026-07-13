export interface TranslationArchiveMember {
  readonly name: 'encoder.ms' | 'decoder_prefill.ms' | 'decoder_step.ms';
  readonly size: number;
  readonly sha256: string;
}

export interface TranslationArchiveRequest {
  readonly archiveFd: number;
  readonly archiveOffset: number;
  readonly archiveLength: number;
  readonly cacheRoot: string;
  readonly archiveSha256: string;
  readonly members: TranslationArchiveMember[];
}

export interface TranslationArchiveResult {
  readonly directory: string;
  readonly reused: boolean;
}

export const extractArchive: (request: TranslationArchiveRequest) => Promise<TranslationArchiveResult>;
