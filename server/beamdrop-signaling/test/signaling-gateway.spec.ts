import { Socket } from "socket.io";
import { SessionAuthService } from "../src/common/session-auth.service";
import { PresenceService } from "../src/presence/presence.service";
import { SignalingGateway } from "../src/signaling/signaling.gateway";

interface FakeSocket {
  id: string;
  handshake: { auth: Record<string, unknown>; headers: Record<string, string> };
  join: jest.Mock;
  emit: jest.Mock;
  disconnect: jest.Mock;
}

function fakeSocket(id: string, sessionToken?: string, headers: Record<string, string> = {}): FakeSocket {
  return {
    id,
    handshake: { auth: sessionToken ? { sessionToken } : {}, headers },
    join: jest.fn(),
    emit: jest.fn(),
    disconnect: jest.fn()
  };
}

function asSocket(socket: FakeSocket): Socket {
  return socket as unknown as Socket;
}

describe("SignalingGateway", () => {
  let auth: SessionAuthService;
  let presence: PresenceService;
  let gateway: SignalingGateway;
  let roomEmit: jest.Mock;
  let toMock: jest.Mock;

  function createGateway(): SignalingGateway {
    const created = new SignalingGateway(presence, auth);
    roomEmit = jest.fn();
    toMock = jest.fn().mockReturnValue({ emit: roomEmit });
    created.server = { to: toMock } as never;
    return created;
  }

  function connectAuthenticated(id: string, deviceId: string): FakeSocket {
    const session = auth.issue(deviceId);
    const socket = fakeSocket(id, session.sessionToken);
    gateway.handleConnection(asSocket(socket));
    return socket;
  }

  beforeEach(() => {
    delete process.env.BEAMDROP_ALLOW_ANONYMOUS_SIGNALING;
    delete process.env.SIGNALING_WS_RATE_LIMIT_MAX;
    delete process.env.SIGNALING_WS_RATE_LIMIT_WINDOW_SECONDS;
    auth = new SessionAuthService();
    presence = new PresenceService();
    gateway = createGateway();
  });

  it("accepts a connection with a valid session token and binds the token's device id", () => {
    const session = auth.issue("device-a");
    const socket = fakeSocket("conn-1", session.sessionToken, { "x-beamdrop-device-id": "spoofed-device" });

    gateway.handleConnection(asSocket(socket));

    expect(socket.disconnect).not.toHaveBeenCalled();
    expect(socket.join).toHaveBeenCalledWith("device-a");
    expect(socket.emit).toHaveBeenCalledWith("presence:ready", { deviceId: "device-a" });
    expect(presence.list().map((entry) => entry.deviceId)).toEqual(["device-a"]);
  });

  it("rejects a connection without a session token", () => {
    const socket = fakeSocket("conn-1", undefined, { "x-beamdrop-device-id": "device-a" });

    gateway.handleConnection(asSocket(socket));

    expect(socket.disconnect).toHaveBeenCalledWith(true);
    expect(socket.emit).toHaveBeenCalledWith("session:error", expect.objectContaining({ message: expect.any(String) }));
    expect(socket.join).not.toHaveBeenCalled();
    expect(presence.list()).toEqual([]);
  });

  it("rejects a connection with an unknown session token", () => {
    const socket = fakeSocket("conn-1", "forged-token");

    gateway.handleConnection(asSocket(socket));

    expect(socket.disconnect).toHaveBeenCalledWith(true);
    expect(presence.list()).toEqual([]);
  });

  it("rejects a connection with an expired session token", () => {
    const issuedAt = new Date(Date.now() - 100 * 60 * 60 * 1000);
    const session = auth.issue("device-a", issuedAt);
    const socket = fakeSocket("conn-1", session.sessionToken);

    gateway.handleConnection(asSocket(socket));

    expect(socket.disconnect).toHaveBeenCalledWith(true);
    expect(presence.list()).toEqual([]);
  });

  it("accepts a session token supplied via handshake header", () => {
    const session = auth.issue("device-a");
    const socket = fakeSocket("conn-1", undefined, { "x-beamdrop-session-token": session.sessionToken });

    gateway.handleConnection(asSocket(socket));

    expect(socket.disconnect).not.toHaveBeenCalled();
    expect(socket.join).toHaveBeenCalledWith("device-a");
  });

  it("allows anonymous connections only when BEAMDROP_ALLOW_ANONYMOUS_SIGNALING=true", () => {
    process.env.BEAMDROP_ALLOW_ANONYMOUS_SIGNALING = "true";
    const socket = fakeSocket("conn-1", undefined, { "x-beamdrop-device-id": "legacy-device" });

    gateway.handleConnection(asSocket(socket));

    expect(socket.disconnect).not.toHaveBeenCalled();
    expect(socket.join).toHaveBeenCalledWith("legacy-device");
  });

  it("forwards pairing signals with the authenticated sender device id", () => {
    const sender = connectAuthenticated("conn-1", "device-a");

    const result = gateway.pairingSignal(asSocket(sender), {
      targetDeviceId: "device-b",
      pairingSessionId: "pair-1",
      payload: { code: "123456" }
    });

    expect(result).toEqual({ accepted: true });
    expect(toMock).toHaveBeenCalledWith("device-b");
    expect(roomEmit).toHaveBeenCalledWith("pairing:signal", {
      fromDeviceId: "device-a",
      pairingSessionId: "pair-1",
      payload: { code: "123456" }
    });
  });

  it("forwards transfer signals with the authenticated sender device id", () => {
    const sender = connectAuthenticated("conn-1", "device-a");

    const result = gateway.transferSignal(asSocket(sender), {
      targetDeviceId: "device-b",
      transferId: "transfer-1",
      kind: "offer",
      payload: { sdp: "..." }
    });

    expect(result).toEqual({ accepted: true });
    expect(toMock).toHaveBeenCalledWith("device-b");
    expect(roomEmit).toHaveBeenCalledWith("transfer:signal", {
      fromDeviceId: "device-a",
      transferId: "transfer-1",
      kind: "offer",
      payload: { sdp: "..." }
    });
  });

  it("refuses to forward signals from an unauthenticated connection", () => {
    const socket = fakeSocket("conn-unbound");

    const result = gateway.transferSignal(asSocket(socket), {
      targetDeviceId: "device-b",
      transferId: "transfer-1",
      kind: "offer",
      payload: {}
    });

    expect(result).toEqual({ accepted: false, reason: "unauthenticated" });
    expect(toMock).not.toHaveBeenCalled();
    expect(socket.disconnect).toHaveBeenCalledWith(true);
  });

  it("disconnects a socket that exceeds the per-connection message rate limit", () => {
    process.env.SIGNALING_WS_RATE_LIMIT_MAX = "3";
    process.env.SIGNALING_WS_RATE_LIMIT_WINDOW_SECONDS = "10";
    gateway = createGateway();
    const sender = connectAuthenticated("conn-1", "device-a");
    const signal = {
      targetDeviceId: "device-b",
      pairingSessionId: "pair-1",
      payload: {}
    };

    for (let i = 0; i < 3; i++) {
      expect(gateway.pairingSignal(asSocket(sender), signal)).toEqual({ accepted: true });
    }
    const result = gateway.pairingSignal(asSocket(sender), signal);

    expect(result).toEqual({ accepted: false, reason: "rate-limited" });
    expect(sender.disconnect).toHaveBeenCalledWith(true);
    expect(sender.emit).toHaveBeenCalledWith("session:error", { message: "Message rate limit exceeded." });
  });

  it("clears presence and rate-limit state on disconnect", () => {
    const sender = connectAuthenticated("conn-1", "device-a");

    gateway.handleDisconnect(asSocket(sender));

    expect(presence.list()).toEqual([]);
    const result = gateway.pairingSignal(asSocket(sender), {
      targetDeviceId: "device-b",
      pairingSessionId: "pair-1",
      payload: {}
    });
    expect(result).toEqual({ accepted: false, reason: "unauthenticated" });
  });
});
