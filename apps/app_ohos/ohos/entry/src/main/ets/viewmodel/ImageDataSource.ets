import { ImageSizeCache } from './ImageSizeCache';

export class ImageDataSource implements IDataSource {
  private images: string[] = [];
  private listeners: DataChangeListener[] = [];
  private sizeCache: ImageSizeCache;

  constructor(images: string[], sizeCache: ImageSizeCache) {
    this.images = images;
    this.sizeCache = sizeCache;
  }

  totalCount(): number {
    return this.images.length;
  }

  getData(index: number): string {
    return this.images[index];
  }

  getEstimatedHeight(index: number, containerWidth: number): number {
    const url: string = this.images[index];
    return this.sizeCache.getEstimatedHeight(url, containerWidth);
  }

  registerDataChangeListener(listener: DataChangeListener): void {
    if (this.listeners.indexOf(listener) < 0) {
      this.listeners.push(listener);
    }
  }

  unregisterDataChangeListener(listener: DataChangeListener): void {
    const index: number = this.listeners.indexOf(listener);
    if (index >= 0) {
      this.listeners.splice(index, 1);
    }
  }

  notifyDataReload(): void {
    this.listeners.forEach((listener: DataChangeListener) => {
      listener.onDataReloaded();
    });
  }

  notifyDataAdd(index: number): void {
    this.listeners.forEach((listener: DataChangeListener) => {
      listener.onDataAdded(index);
    });
  }

  notifyDataChange(index: number): void {
    this.listeners.forEach((listener: DataChangeListener) => {
      listener.onDataChanged(index);
    });
  }

  notifyDataDelete(index: number): void {
    this.listeners.forEach((listener: DataChangeListener) => {
      listener.onDataDeleted(index);
    });
  }
}
