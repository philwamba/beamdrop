import { Injectable } from "@nestjs/common";

@Injectable()
export class RelayConfig {
  readonly maxFileBytes = Number(process.env.RELAY_MAX_FILE_BYTES ?? 512 * 1024 * 1024);
  readonly tokenTtlSeconds = Number(process.env.RELAY_TOKEN_TTL_SECONDS ?? 900);
  readonly cleanupIntervalSeconds = Number(process.env.RELAY_CLEANUP_INTERVAL_SECONDS ?? 60);
}
