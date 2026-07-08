import { BadRequestException, Injectable, Logger, UnauthorizedException } from "@nestjs/common";
import { randomBytes, randomUUID } from "crypto";

export interface SignalingSession {
  sessionToken: string;
  deviceId: string;
  issuedAt: Date;
  expiresAt: Date;
}

const MAX_DEVICE_ID_LENGTH = 128;

@Injectable()
export class SessionAuthService {
  private readonly logger = new Logger(SessionAuthService.name);
  private readonly sessions = new Map<string, SignalingSession>();
  private readonly sessionTtlSeconds = Number(process.env.SIGNALING_SESSION_TTL_SECONDS ?? 3600);

  get allowAnonymous(): boolean {
    return process.env.BEAMDROP_ALLOW_ANONYMOUS_SIGNALING === "true";
  }

  issue(deviceId: unknown, now = new Date()): SignalingSession {
    if (typeof deviceId !== "string" || deviceId.trim().length === 0) {
      throw new BadRequestException("deviceId is required.");
    }
    if (deviceId.trim().length > MAX_DEVICE_ID_LENGTH) {
      throw new BadRequestException(`deviceId must be at most ${MAX_DEVICE_ID_LENGTH} characters.`);
    }
    const session: SignalingSession = {
      sessionToken: randomBytes(32).toString("base64url"),
      deviceId: deviceId.trim(),
      issuedAt: now,
      expiresAt: new Date(now.getTime() + this.sessionTtlSeconds * 1000)
    };
    this.sessions.set(session.sessionToken, session);
    this.logger.log(`Issued signaling session for device ${session.deviceId}`);
    return session;
  }

  requireValid(sessionToken: string | undefined, now = new Date()): SignalingSession {
    if (!sessionToken) {
      throw new UnauthorizedException("Session token is required.");
    }
    const session = this.sessions.get(sessionToken);
    if (!session) {
      throw new UnauthorizedException("Session token not found.");
    }
    if (session.expiresAt.getTime() <= now.getTime()) {
      this.sessions.delete(sessionToken);
      throw new UnauthorizedException("Session token expired.");
    }
    return session;
  }

  revoke(sessionToken: string): void {
    this.sessions.delete(sessionToken);
  }

  /**
   * Legacy placeholder behavior, only reachable when
   * BEAMDROP_ALLOW_ANONYMOUS_SIGNALING=true (local development only).
   */
  anonymousSession(headers: Record<string, string | string[] | undefined>, now = new Date()): SignalingSession {
    const deviceIdHeader = headers["x-beamdrop-device-id"];
    const deviceId = Array.isArray(deviceIdHeader) ? deviceIdHeader[0] : deviceIdHeader;
    if (!deviceId) {
      this.logger.debug("Using anonymous signaling placeholder session");
    }
    return {
      sessionToken: `anonymous-${randomUUID()}`,
      deviceId: deviceId ?? `anonymous-${randomUUID()}`,
      issuedAt: now,
      expiresAt: new Date(now.getTime() + this.sessionTtlSeconds * 1000)
    };
  }
}
