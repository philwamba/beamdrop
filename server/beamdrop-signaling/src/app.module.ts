import { Module } from "@nestjs/common";
import { ThrottlerModule } from "@nestjs/throttler";
import { HealthController } from "./health/health.controller";
import { PresenceService } from "./presence/presence.service";
import { SignalingGateway } from "./signaling/signaling.gateway";
import { SessionAuthService } from "./common/session-auth.service";

@Module({
  imports: [
    ThrottlerModule.forRoot([
      {
        ttl: Number(process.env.SIGNALING_RATE_LIMIT_TTL_SECONDS ?? 60) * 1000,
        limit: Number(process.env.SIGNALING_RATE_LIMIT_MAX ?? 120)
      }
    ])
  ],
  controllers: [HealthController],
  providers: [PresenceService, SignalingGateway, SessionAuthService]
})
export class AppModule {}
