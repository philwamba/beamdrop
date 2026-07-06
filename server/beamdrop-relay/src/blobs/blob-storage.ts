export interface StoredBlob {
  objectKey: string;
  bytes: Buffer;
  contentType: string;
}

export interface BlobStorage {
  put(objectKey: string, bytes: Buffer, contentType: string): Promise<void>;
  get(objectKey: string): Promise<StoredBlob | undefined>;
  delete(objectKey: string): Promise<void>;
}

export class InMemoryBlobStorage implements BlobStorage {
  private readonly blobs = new Map<string, StoredBlob>();

  async put(objectKey: string, bytes: Buffer, contentType: string): Promise<void> {
    this.blobs.set(objectKey, { objectKey, bytes, contentType });
  }

  async get(objectKey: string): Promise<StoredBlob | undefined> {
    return this.blobs.get(objectKey);
  }

  async delete(objectKey: string): Promise<void> {
    this.blobs.delete(objectKey);
  }
}

export class S3CompatibleBlobStorage implements BlobStorage {
  async put(): Promise<void> {
    throw new Error("S3/R2 storage adapter placeholder: wire AWS SDK client here.");
  }

  async get(): Promise<StoredBlob | undefined> {
    throw new Error("S3/R2 storage adapter placeholder: wire AWS SDK client here.");
  }

  async delete(): Promise<void> {
    throw new Error("S3/R2 storage adapter placeholder: wire AWS SDK client here.");
  }
}
