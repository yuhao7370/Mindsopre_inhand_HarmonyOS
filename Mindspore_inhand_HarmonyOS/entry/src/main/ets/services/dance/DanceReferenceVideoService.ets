import { common } from '@kit.AbilityKit';
import { fileIo, fileUri } from '@kit.CoreFileKit';
import request from '@ohos.request';
import { AppStringKey } from '../../common/i18n/AppStrings';
import {
  danceReferenceVideoLengthBytes,
  danceReferenceVideoUrl
} from './DancePageService';

export const danceReferenceVideoCacheFileName: string = 'danceVideo2.mp4';
export const danceReferenceVideoDownloadStatusSuccessful: number = 0;
export const danceReferenceVideoDownloadStatusRunning: number = 1;
export const danceReferenceVideoDownloadStatusPaused: number = 3;
export const danceReferenceVideoDownloadStatusFailed: number = 4;

export interface DanceReferenceVideoPrepareResult {
  readonly ok: boolean;
  readonly uri: string;
  readonly messageKey: AppStringKey;
  readonly downloaded: boolean;
}

export interface DanceReferenceVideoProgress {
  readonly receivedBytes: number;
  readonly totalBytes: number;
}

export type DanceReferenceVideoProgressCallback = (progress: DanceReferenceVideoProgress) => void;

export interface DanceReferenceVideoFileStore {
  fileSize(path: string): Promise<number>;
  remove(path: string): Promise<void>;
  replace(sourcePath: string, destinationPath: string): Promise<void>;
}

export interface DanceReferenceVideoDownloader {
  download(
    url: string,
    destinationPath: string,
    context?: common.BaseContext,
    onProgress?: DanceReferenceVideoProgressCallback
  ): Promise<void>;
}

export type DanceReferenceVideoDownloadEvent = 'progress' | 'complete' | 'pause' | 'remove' | 'fail';
export type DanceReferenceVideoProgressListener = (receivedBytes: number, totalBytes: number) => void;
export type DanceReferenceVideoEmptyListener = () => void;
export type DanceReferenceVideoFailureListener = (errorCode: number) => void;
export type DanceReferenceVideoDownloadListener =
  DanceReferenceVideoProgressListener | DanceReferenceVideoEmptyListener | DanceReferenceVideoFailureListener;

export interface DanceReferenceVideoDownloadTask {
  on(event: DanceReferenceVideoDownloadEvent, callback: DanceReferenceVideoDownloadListener): void;
  off(event: DanceReferenceVideoDownloadEvent, callback?: DanceReferenceVideoDownloadListener): void;
  getTaskInfo(): Promise<request.DownloadInfo>;
}

let danceReferenceVideoTempSequence: number = 0;

export class DanceReferenceVideoCacheService {
  private readonly fileStore: DanceReferenceVideoFileStore;
  private readonly downloader: DanceReferenceVideoDownloader;

  constructor(
    fileStore: DanceReferenceVideoFileStore = new HarmonyDanceReferenceVideoFileStore(),
    downloader: DanceReferenceVideoDownloader = new HarmonyDanceReferenceVideoDownloader()
  ) {
    this.fileStore = fileStore;
    this.downloader = downloader;
  }

  async prepare(
    cacheDir: string,
    context?: common.BaseContext,
    onProgress?: DanceReferenceVideoProgressCallback
  ): Promise<DanceReferenceVideoPrepareResult> {
    if (cacheDir.length === 0) {
      return danceReferenceVideoFailedResult();
    }

    const destinationPath = danceReferenceVideoCachePath(cacheDir);
    const currentFileSize = await this.fileStore.fileSize(destinationPath);
    if (isCompleteDanceReferenceVideo(currentFileSize)) {
      return danceReferenceVideoReadyResult(danceReferenceVideoPlaybackUri(destinationPath), false);
    }

    if (currentFileSize >= 0) {
      await this.fileStore.remove(destinationPath);
    }
    const tempPath = danceReferenceVideoTempPath(destinationPath);
    try {
      await this.downloader.download(danceReferenceVideoUrl, tempPath, context, onProgress);
      if (!isCompleteDanceReferenceVideo(await this.fileStore.fileSize(tempPath))) {
        await this.fileStore.remove(tempPath);
        return danceReferenceVideoFailedResult();
      }
      await this.fileStore.replace(tempPath, destinationPath);
      return danceReferenceVideoReadyResult(danceReferenceVideoPlaybackUri(destinationPath), true);
    } catch (_) {
      await this.fileStore.remove(tempPath);
      return danceReferenceVideoFailedResult();
    }
  }
}

export class HarmonyDanceReferenceVideoFileStore implements DanceReferenceVideoFileStore {
  async fileSize(path: string): Promise<number> {
    try {
      const stat = await fileIo.stat(path);
      return stat.size;
    } catch (_) {
      return -1;
    }
  }

  async remove(path: string): Promise<void> {
    try {
      await fileIo.unlink(path);
    } catch (_) {
    }
  }

  async replace(sourcePath: string, destinationPath: string): Promise<void> {
    await this.remove(destinationPath);
    try {
      await fileIo.rename(sourcePath, destinationPath);
    } catch (_) {
      throw new Error('Failed to replace dance reference video.');
    }
  }
}

export class HarmonyDanceReferenceVideoDownloader implements DanceReferenceVideoDownloader {
  async download(
    url: string,
    destinationPath: string,
    context?: common.BaseContext,
    onProgress?: DanceReferenceVideoProgressCallback
  ): Promise<void> {
    if (context === undefined) {
      throw new Error('Missing download context.');
    }
    try {
      const task = await request.downloadFile(context, {
        url: url,
        filePath: destinationPath,
        title: danceReferenceVideoCacheFileName,
        enableMetered: true,
        enableRoaming: true,
        background: false
      });
      await waitForDanceReferenceVideoDownload(
        new HarmonyDanceReferenceVideoDownloadTask(task),
        onProgress
      );
    } catch (_) {
      throw new Error('Dance reference video download failed.');
    }
  }
}

export class HarmonyDanceReferenceVideoDownloadTask implements DanceReferenceVideoDownloadTask {
  private readonly task: request.DownloadTask;

  constructor(task: request.DownloadTask) {
    this.task = task;
  }

  on(event: DanceReferenceVideoDownloadEvent, callback: DanceReferenceVideoDownloadListener): void {
    if (event === 'progress') {
      this.task.on(event, callback as DanceReferenceVideoProgressListener);
      return;
    }
    if (event === 'fail') {
      this.task.on(event, callback as DanceReferenceVideoFailureListener);
      return;
    }
    this.task.on(event, callback as DanceReferenceVideoEmptyListener);
  }

  off(event: DanceReferenceVideoDownloadEvent, callback?: DanceReferenceVideoDownloadListener): void {
    if (event === 'progress') {
      this.task.off(event, callback as DanceReferenceVideoProgressListener);
      return;
    }
    if (event === 'fail') {
      this.task.off(event, callback as DanceReferenceVideoFailureListener);
      return;
    }
    this.task.off(event, callback as DanceReferenceVideoEmptyListener);
  }

  async getTaskInfo(): Promise<request.DownloadInfo> {
    try {
      return await this.task.getTaskInfo();
    } catch (_) {
      throw new Error('Failed to query dance reference video download.');
    }
  }
}

export function danceReferenceVideoCachePath(cacheDir: string): string {
  const normalizedCacheDir = cacheDir.endsWith('/') || cacheDir.endsWith('\\') ?
    cacheDir.substring(0, cacheDir.length - 1) :
    cacheDir;
  return `${normalizedCacheDir}/${danceReferenceVideoCacheFileName}`;
}

export function danceReferenceVideoPlaybackUri(path: string): string {
  const uri = fileUri.getUriFromPath(path);
  return uri.length > 0 ? uri : `file://${path}`;
}

export function danceReferenceVideoTempPath(destinationPath: string): string {
  danceReferenceVideoTempSequence++;
  return `${destinationPath}.download.${Date.now()}.${danceReferenceVideoTempSequence}`;
}

export function isCompleteDanceReferenceVideo(fileSize: number): boolean {
  return fileSize === danceReferenceVideoLengthBytes;
}

export function danceReferenceVideoProgressPercent(progress: DanceReferenceVideoProgress): number {
  if (progress.totalBytes <= 0 || progress.receivedBytes <= 0) {
    return 0;
  }
  const percent = Math.floor(progress.receivedBytes * 100 / progress.totalBytes);
  return Math.min(100, Math.max(0, percent));
}

function danceReferenceVideoReadyResult(uri: string, downloaded: boolean): DanceReferenceVideoPrepareResult {
  return {
    ok: true,
    uri: uri,
    messageKey: 'dance_reference_video_ready',
    downloaded: downloaded
  };
}

function danceReferenceVideoFailedResult(): DanceReferenceVideoPrepareResult {
  return {
    ok: false,
    uri: '',
    messageKey: 'dance_reference_video_failed',
    downloaded: false
  };
}

export function waitForDanceReferenceVideoDownload(
  task: DanceReferenceVideoDownloadTask,
  onProgress?: DanceReferenceVideoProgressCallback
): Promise<void> {
  return new Promise<void>((resolve: () => void, reject: (reason: Error) => void) => {
    let settled = false;
    const progress = (receivedBytes: number, totalBytes: number): void => {
      if (onProgress !== undefined) {
        onProgress({
          receivedBytes: receivedBytes,
          totalBytes: totalBytes
        });
      }
    };
    const cleanup = (): void => {
      task.off('progress', progress);
      task.off('complete');
      task.off('pause');
      task.off('remove');
      task.off('fail');
    };
    const complete = (): void => {
      if (settled) {
        return;
      }
      settled = true;
      cleanup();
      resolve();
    };
    const fail = (errorCode: number): void => {
      if (settled) {
        return;
      }
      settled = true;
      cleanup();
      reject(new Error(`Dance reference video download failed: ${errorCode}`));
    };
    const pause = (): void => {
      fail(danceReferenceVideoDownloadStatusPaused);
    };
    const remove = (): void => {
      fail(danceReferenceVideoDownloadStatusFailed);
    };
    task.on('progress', progress);
    task.on('complete', complete);
    task.on('pause', pause);
    task.on('remove', remove);
    task.on('fail', fail);
    task.getTaskInfo()
      .then((info: request.DownloadInfo) => {
        if (info.status === danceReferenceVideoDownloadStatusSuccessful) {
          complete();
          return;
        }
        if (info.status === danceReferenceVideoDownloadStatusFailed) {
          fail(info.failedReason);
          return;
        }
        if (info.status === danceReferenceVideoDownloadStatusPaused) {
          fail(info.status);
        }
      })
      .catch(() => {
        fail(danceReferenceVideoDownloadStatusFailed);
      });
  });
}
