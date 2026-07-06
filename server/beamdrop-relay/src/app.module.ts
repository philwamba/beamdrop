import { Module } from "@nestjs/common";
import { ThrottlerModule } from "@nestjs/throttler";
import { BlobController } from "./blobs/blob.controller";
import { CleanupService } from "./cleanup/cleanup.service";
import { HealthController } from "./health/health.controller";
import { InMemoryBlobStorage } from "./blobs/blob-storage";
import { TransferTokenService } from "./tokens/transfer-token.service";
import { RelayRecordRepository } from "./tokens/relay-record.repository";
import { RelayConfig } from "./common/relay.config";

@Module({
  imports: [
    ThrottlerModule.forRoot([
      {
        ttl: Number(process.env.RELAY_RATE_LIMIT_TTL_SECONDS ?? 60) * 1000,
        limit: Number(process.env.RELAY_RATE_LIMIT_MAX ?? 60)
      }
    ])
  ],
  controllers: [HealthController, BlobController],
  providers: [
    RelayConfig,
    TransferTokenService,
    RelayRecordRepository,
    CleanupService,
    {
      provide: "BlobStorage",
      useClass: InMemoryBlobStorage
    }
  ]
})
export class AppModule {}
