import { Module } from "@nestjs/common";
import { APP_GUARD } from "@nestjs/core";
import { ThrottlerGuard, ThrottlerModule } from "@nestjs/throttler";
import { HealthController } from "./health/health.controller";
import { PresenceService } from "./presence/presence.service";
import { SignalingGateway } from "./signaling/signaling.gateway";
import { SessionAuthService } from "./common/session-auth.service";
import { SessionController } from "./sessions/session.controller";

@Module({
  imports: [
    ThrottlerModule.forRoot([
      {
        ttl: Number(process.env.SIGNALING_RATE_LIMIT_TTL_SECONDS ?? 60) * 1000,
        limit: Number(process.env.SIGNALING_RATE_LIMIT_MAX ?? 120)
      }
    ])
  ],
  controllers: [HealthController, SessionController],
  providers: [
    PresenceService,
    SignalingGateway,
    SessionAuthService,
    {
      provide: APP_GUARD,
      useClass: ThrottlerGuard
    }
  ]
})
export class AppModule {}
