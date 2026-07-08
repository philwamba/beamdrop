import { Logger } from "@nestjs/common";
import { SkipThrottle } from "@nestjs/throttler";
import {
  ConnectedSocket,
  MessageBody,
  OnGatewayConnection,
  OnGatewayDisconnect,
  SubscribeMessage,
  WebSocketGateway,
  WebSocketServer
} from "@nestjs/websockets";
import { Server, Socket } from "socket.io";
import { PresenceService } from "../presence/presence.service";
import { SessionAuthService, SignalingSession } from "../common/session-auth.service";

interface PairingSignal {
  targetDeviceId: string;
  pairingSessionId: string;
  payload: unknown;
}

interface TransferSignal {
  targetDeviceId: string;
  transferId: string;
  kind: "offer" | "answer" | "candidate" | "cancel";
  payload: unknown;
}

@SkipThrottle()
@WebSocketGateway({
  namespace: "/signaling",
  cors: {
    origin: false
  }
})
export class SignalingGateway implements OnGatewayConnection, OnGatewayDisconnect {
  @WebSocketServer()
  server!: Server;

  private readonly logger = new Logger(SignalingGateway.name);
  private readonly connectionToDevice = new Map<string, string>();
  private readonly messageTimestamps = new Map<string, number[]>();
  private readonly messageRateLimit = Number(process.env.SIGNALING_WS_RATE_LIMIT_MAX ?? 60);
  private readonly messageRateWindowMs = Number(process.env.SIGNALING_WS_RATE_LIMIT_WINDOW_SECONDS ?? 10) * 1000;

  constructor(
    private readonly presence: PresenceService,
    private readonly auth: SessionAuthService
  ) {}

  handleConnection(client: Socket) {
    let session: SignalingSession;
    try {
      session = this.resolveSession(client);
    } catch (error) {
      this.logger.warn(`Rejected unauthenticated signaling connection ${client.id}`);
      client.emit("session:error", {
        message: error instanceof Error ? error.message : "Unauthorized"
      });
      client.disconnect(true);
      return;
    }

    this.connectionToDevice.set(client.id, session.deviceId);
    this.presence.upsert({
      deviceId: session.deviceId,
      connectionId: client.id,
      platform: String(client.handshake.headers["x-beamdrop-platform"] ?? ""),
      lastSeenAt: new Date()
    });
    client.join(session.deviceId);
    this.logger.log(`Device connected: ${session.deviceId}`);
    client.emit("presence:ready", { deviceId: session.deviceId });
  }

  handleDisconnect(client: Socket) {
    this.presence.removeByConnection(client.id);
    const deviceId = this.connectionToDevice.get(client.id);
    this.connectionToDevice.delete(client.id);
    this.messageTimestamps.delete(client.id);
    this.logger.log(`Device disconnected: ${deviceId ?? client.id}`);
  }

  @SubscribeMessage("presence:list")
  listPresence(@ConnectedSocket() client: Socket) {
    if (!this.requireAuthenticated(client) || !this.consumeMessageBudget(client)) {
      return { devices: [] };
    }
    return { devices: this.presence.list() };
  }

  @SubscribeMessage("pairing:signal")
  pairingSignal(@ConnectedSocket() client: Socket, @MessageBody() signal: PairingSignal) {
    const fromDeviceId = this.requireAuthenticated(client);
    if (!fromDeviceId) {
      return { accepted: false, reason: "unauthenticated" };
    }
    if (!this.consumeMessageBudget(client)) {
      return { accepted: false, reason: "rate-limited" };
    }
    this.logger.debug(`Pairing signal ${signal.pairingSessionId} to ${signal.targetDeviceId}`);
    this.server.to(signal.targetDeviceId).emit("pairing:signal", {
      fromDeviceId,
      pairingSessionId: signal.pairingSessionId,
      payload: signal.payload
    });
    return { accepted: true };
  }

  @SubscribeMessage("transfer:signal")
  transferSignal(@ConnectedSocket() client: Socket, @MessageBody() signal: TransferSignal) {
    const fromDeviceId = this.requireAuthenticated(client);
    if (!fromDeviceId) {
      return { accepted: false, reason: "unauthenticated" };
    }
    if (!this.consumeMessageBudget(client)) {
      return { accepted: false, reason: "rate-limited" };
    }
    this.logger.debug(`Transfer signal ${signal.kind} ${signal.transferId} to ${signal.targetDeviceId}`);
    this.server.to(signal.targetDeviceId).emit("transfer:signal", {
      fromDeviceId,
      transferId: signal.transferId,
      kind: signal.kind,
      payload: signal.payload
    });
    return { accepted: true };
  }

  private resolveSession(client: Socket): SignalingSession {
    const token = this.extractSessionToken(client);
    if (!token && this.auth.allowAnonymous) {
      return this.auth.anonymousSession(client.handshake.headers);
    }
    return this.auth.requireValid(token);
  }

  private extractSessionToken(client: Socket): string | undefined {
    const auth = client.handshake.auth as Record<string, unknown> | undefined;
    if (typeof auth?.sessionToken === "string" && auth.sessionToken.length > 0) {
      return auth.sessionToken;
    }
    const headerToken = client.handshake.headers["x-beamdrop-session-token"];
    const token = Array.isArray(headerToken) ? headerToken[0] : headerToken;
    return token && token.length > 0 ? token : undefined;
  }

  private requireAuthenticated(client: Socket): string | undefined {
    const deviceId = this.connectionToDevice.get(client.id);
    if (!deviceId) {
      this.logger.warn(`Dropping message from unauthenticated connection ${client.id}`);
      client.disconnect(true);
      return undefined;
    }
    return deviceId;
  }

  private consumeMessageBudget(client: Socket): boolean {
    const now = Date.now();
    const cutoff = now - this.messageRateWindowMs;
    const timestamps = (this.messageTimestamps.get(client.id) ?? []).filter((at) => at > cutoff);
    timestamps.push(now);
    this.messageTimestamps.set(client.id, timestamps);
    if (timestamps.length > this.messageRateLimit) {
      const deviceId = this.connectionToDevice.get(client.id);
      this.logger.warn(`Message rate limit exceeded, disconnecting ${deviceId ?? client.id}`);
      client.emit("session:error", { message: "Message rate limit exceeded." });
      client.disconnect(true);
      return false;
    }
    return true;
  }
}
