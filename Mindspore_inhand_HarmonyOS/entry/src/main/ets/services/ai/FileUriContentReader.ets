import { fileIo } from '@kit.CoreFileKit';

export const fileUriContentMaxBytes: number = 64 * 1024 * 1024;
const fileUriContentReadChunkBytes: number = 1024 * 1024;

export class FileUriDescriptor {
  readonly fd: number;

  constructor(fd: number) {
    this.fd = fd;
  }
}

export abstract class FileUriContentBackend {
  abstract open(uri: string): Promise<FileUriDescriptor>;

  abstract size(file: FileUriDescriptor): Promise<number>;

  abstract read(file: FileUriDescriptor, buffer: ArrayBuffer, offset: number): Promise<number>;

  abstract close(file: FileUriDescriptor): Promise<void>;
}

export class CoreFileKitContentBackend extends FileUriContentBackend {
  async open(uri: string): Promise<FileUriDescriptor> {
    const file = await fileIo.open(uri, fileIo.OpenMode.READ_ONLY);
    return new FileUriDescriptor(file.fd);
  }

  async size(file: FileUriDescriptor): Promise<number> {
    const stat = await fileIo.stat(file.fd);
    return stat.size;
  }

  async read(file: FileUriDescriptor, buffer: ArrayBuffer, offset: number): Promise<number> {
    return fileIo.read(file.fd, buffer, {
      offset: offset,
      length: buffer.byteLength
    });
  }

  async close(file: FileUriDescriptor): Promise<void> {
    await fileIo.close(file.fd);
  }
}

export class FileUriContentReader {
  private readonly backend: FileUriContentBackend;

  constructor(backend: FileUriContentBackend = new CoreFileKitContentBackend()) {
    this.backend = backend;
  }

  async readFileContent(uri: string): Promise<Uint8Array> {
    let file: FileUriDescriptor | undefined = undefined;
    try {
      file = await this.backend.open(uri);
      const size = await this.backend.size(file);
      if (!Number.isInteger(size) || size < 0 || size > fileUriContentMaxBytes) {
        throw new Error('Selected file size is outside the supported range.');
      }
      const buffer = new ArrayBuffer(size);
      const destination = new Uint8Array(buffer);
      let offset = 0;
      while (offset < size) {
        const chunkByteCount = Math.min(fileUriContentReadChunkBytes, size - offset);
        const chunk = new ArrayBuffer(chunkByteCount);
        const bytesRead = await this.backend.read(file, chunk, offset);
        if (bytesRead <= 0 || bytesRead > size - offset) {
          throw new Error('Selected file ended before its declared size.');
        }
        if (bytesRead > chunkByteCount) {
          throw new Error('Selected file read exceeded the requested chunk.');
        }
        destination.set(new Uint8Array(chunk, 0, bytesRead), offset);
        offset += bytesRead;
      }
      return arrayBufferPrefixToUint8Array(buffer, offset);
    } finally {
      if (file !== undefined) {
        await this.backend.close(file);
      }
    }
  }
}

export function arrayBufferPrefixToUint8Array(buffer: ArrayBuffer, byteCount: number): Uint8Array {
  const source = new Uint8Array(buffer);
  const length = Math.min(Math.max(byteCount, 0), source.length);
  const output = new Uint8Array(length);
  output.set(source.subarray(0, length));
  return output;
}
