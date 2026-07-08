import { Inject, Injectable, Logger, OnModuleDestroy, OnModuleInit } from "@nestjs/common";
import { BlobStorage } from "../blobs/blob-storage";
import { RelayConfig } from "../common/relay.config";
import { RelayRecordRepository } from "../tokens/relay-record.repository";

@Injectable()
export class CleanupService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(CleanupService.name);
  private timer?: NodeJS.Timeout;

  constructor(
    private readonly records: RelayRecordRepository,
    @Inject("BlobStorage") private readonly storage: BlobStorage,
    private readonly config: RelayConfig
  ) {}

  onModuleInit(): void {
    const intervalMs = this.config.cleanupIntervalSeconds * 1000;
    this.timer = setInterval(() => {
      void this.cleanupExpired().catch((error) => {
        this.logger.error(`Relay cleanup failed: ${error instanceof Error ? error.message : error}`);
      });
    }, intervalMs);
    this.timer.unref?.();
    this.logger.log(`Scheduled relay blob cleanup every ${this.config.cleanupIntervalSeconds}s`);
  }

  onModuleDestroy(): void {
    if (this.timer) {
      clearInterval(this.timer);
      this.timer = undefined;
    }
  }

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
