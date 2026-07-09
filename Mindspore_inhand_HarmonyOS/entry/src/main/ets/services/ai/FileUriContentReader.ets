import { fileIo } from '@kit.CoreFileKit';

export class FileUriDescriptor {
  readonly fd: number;

  constructor(fd: number) {
    this.fd = fd;
  }
}

export abstract class FileUriContentBackend {
  abstract open(uri: string): Promise<FileUriDescriptor>;

  abstract size(file: FileUriDescriptor): Promise<number>;

  abstract read(file: FileUriDescriptor, buffer: ArrayBuffer): Promise<number>;

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

  async read(file: FileUriDescriptor, buffer: ArrayBuffer): Promise<number> {
    return fileIo.read(file.fd, buffer);
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
      const buffer = new ArrayBuffer(size);
      const bytesRead = await this.backend.read(file, buffer);
      return arrayBufferPrefixToUint8Array(buffer, bytesRead);
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
