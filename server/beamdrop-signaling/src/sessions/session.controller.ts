import { Body, Controller, Post } from "@nestjs/common";
import { SessionAuthService } from "../common/session-auth.service";

@Controller("sessions")
export class SessionController {
  constructor(private readonly sessions: SessionAuthService) {}

  @Post()
  create(@Body() body: { deviceId: string }) {
    const session = this.sessions.issue(body?.deviceId);
    return {
      sessionToken: session.sessionToken,
      deviceId: session.deviceId,
      expiresAt: session.expiresAt.toISOString()
    };
  }
}
