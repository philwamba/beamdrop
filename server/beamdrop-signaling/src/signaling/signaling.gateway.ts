import { Logger, UseGuards } from "@nestjs/common";
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
import { SessionAuthService } from "../common/session-auth.service";

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

  constructor(
    private readonly presence: PresenceService,
    private readonly auth: SessionAuthService
  ) {}

  handleConnection(client: Socket) {
    const session = this.auth.authenticate(client.handshake.headers);
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
    this.logger.log(`Device disconnected: ${deviceId ?? client.id}`);
  }

  @SubscribeMessage("presence:list")
  listPresence() {
    return { devices: this.presence.list() };
  }

  @SubscribeMessage("pairing:signal")
  pairingSignal(@ConnectedSocket() client: Socket, @MessageBody() signal: PairingSignal) {
    this.logger.debug(`Pairing signal ${signal.pairingSessionId} to ${signal.targetDeviceId}`);
    this.server.to(signal.targetDeviceId).emit("pairing:signal", {
      fromDeviceId: this.connectionToDevice.get(client.id),
      pairingSessionId: signal.pairingSessionId,
      payload: signal.payload
    });
    return { accepted: true };
  }

  @SubscribeMessage("transfer:signal")
  transferSignal(@ConnectedSocket() client: Socket, @MessageBody() signal: TransferSignal) {
    this.logger.debug(`Transfer signal ${signal.kind} ${signal.transferId} to ${signal.targetDeviceId}`);
    this.server.to(signal.targetDeviceId).emit("transfer:signal", {
      fromDeviceId: this.connectionToDevice.get(client.id),
      transferId: signal.transferId,
      kind: signal.kind,
      payload: signal.payload
    });
    return { accepted: true };
  }
}
