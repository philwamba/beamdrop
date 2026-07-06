import { Inject, Injectable, Logger } from "@nestjs/common";
import { BlobStorage } from "../blobs/blob-storage";
import { RelayRecordRepository } from "../tokens/relay-record.repository";

@Injectable()
export class CleanupService {
  private readonly logger = new Logger(CleanupService.name);

  constructor(
    private readonly records: RelayRecordRepository,
    @Inject("BlobStorage") private readonly storage: BlobStorage
  ) {}

  async cleanupExpired(now = new Date()): Promise<number> {
    let deleted = 0;
    for (const record of this.records.list()) {
      if (record.expiresAt.getTime() <= now.getTime()) {
        await this.storage.delete(record.objectKey);
        record.status = "deleted";
        this.records.delete(record.token);
        deleted++;
      }
    }
    if (deleted > 0) {
      this.logger.log(`Deleted ${deleted} expired relay blobs.`);
    }
    return deleted;
  }
}
