import { Injectable, Logger } from "@nestjs/common";
import { randomUUID } from "crypto";

export interface SignalingSession {
  sessionId: string;
  deviceId: string;
  userId?: string;
}

@Injectable()
export class SessionAuthService {
  private readonly logger = new Logger(SessionAuthService.name);

  authenticate(headers: Record<string, string | string[] | undefined>): SignalingSession {
    const deviceIdHeader = headers["x-beamdrop-device-id"];
    const deviceId = Array.isArray(deviceIdHeader) ? deviceIdHeader[0] : deviceIdHeader;
    if (!deviceId) {
      this.logger.debug("Using anonymous signaling placeholder session");
    }
    return {
      sessionId: randomUUID(),
      deviceId: deviceId ?? `anonymous-${randomUUID()}`
    };
  }
}
