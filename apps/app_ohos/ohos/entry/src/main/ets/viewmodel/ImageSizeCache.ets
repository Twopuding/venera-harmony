export interface ImageSize {
  width: number;
  height: number;
}

export class ImageSizeCache {
  private cache: Map<string, ImageSize> = new Map();
  private defaultAspectRatio: number = 1.4;

  getSize(url: string): ImageSize | null {
    const size = this.cache.get(url);
    return size !== undefined ? size : null;
  }

  cacheSize(url: string, width: number, height: number): void {
    this.cache.set(url, { width: width, height: height });
  }

  getEstimatedHeight(url: string, containerWidth: number): number {
    const size = this.cache.get(url);
    if (size !== undefined) {
      return containerWidth * size.height / size.width;
    }
    return containerWidth * this.defaultAspectRatio;
  }

  hasSize(url: string): boolean {
    return this.cache.has(url);
  }

  clear(): void {
    this.cache.clear();
  }
}
