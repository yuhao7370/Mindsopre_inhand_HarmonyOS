export class RuntimeRequestGeneration {
  private generation: number = 0;

  begin(): number {
    return ++this.generation;
  }

  isCurrent(requestId: number): boolean {
    return requestId === this.generation;
  }

  invalidate(): void {
    this.generation++;
  }
}
