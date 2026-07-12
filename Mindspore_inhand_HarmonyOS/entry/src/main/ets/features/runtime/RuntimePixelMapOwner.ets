export interface RuntimeReleasablePixelMap {
  release(): Promise<void>;
}

export function clearRuntimePixelMapState<T extends RuntimeReleasablePixelMap>(
  owner: RuntimePixelMapOwner<T>
): T | undefined {
  owner.clear();
  return owner.current();
}

export class RuntimePixelMapOwner<T extends RuntimeReleasablePixelMap> {
  private generation: number = 0;
  private value: T | undefined = undefined;

  beginReplacement(): number {
    return ++this.generation;
  }

  isCurrent(requestId: number): boolean {
    return requestId === this.generation;
  }

  accept(requestId: number, next: T): boolean {
    if (!this.isCurrent(requestId)) {
      if (this.value !== next) {
        this.release(next);
      }
      return false;
    }
    const previous = this.value;
    this.value = next;
    if (previous !== undefined && previous !== next) {
      this.release(previous);
    }
    return true;
  }

  current(): T | undefined {
    return this.value;
  }

  clear(): void {
    this.generation++;
    const previous = this.value;
    this.value = undefined;
    if (previous !== undefined) {
      this.release(previous);
    }
  }

  private release(value: T): void {
    value.release().catch(() => {});
  }
}
