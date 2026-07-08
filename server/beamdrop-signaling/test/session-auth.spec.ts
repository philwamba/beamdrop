import { BadRequestException, INestApplication, UnauthorizedException } from "@nestjs/common";
import { Test } from "@nestjs/testing";
import request = require("supertest");
import { AppModule } from "../src/app.module";
import { SessionAuthService } from "../src/common/session-auth.service";

describe("SessionAuthService", () => {
  let service: SessionAuthService;

  beforeEach(() => {
    delete process.env.BEAMDROP_ALLOW_ANONYMOUS_SIGNALING;
    service = new SessionAuthService();
  });

  it("issues opaque tokens bound to a device id", () => {
    const issuedAt = new Date("2026-07-08T12:00:00Z");
    const session = service.issue("device-a", issuedAt);

    expect(session.deviceId).toBe("device-a");
    expect(session.sessionToken).toMatch(/^[A-Za-z0-9_-]{43}$/);
    expect(session.expiresAt.getTime()).toBeGreaterThan(issuedAt.getTime());
    expect(service.requireValid(session.sessionToken, issuedAt)).toEqual(session);
  });

  it("issues distinct tokens per registration", () => {
    const first = service.issue("device-a");
    const second = service.issue("device-a");
    expect(first.sessionToken).not.toBe(second.sessionToken);
  });

  it("rejects a missing or unknown token", () => {
    expect(() => service.requireValid(undefined)).toThrow(UnauthorizedException);
    expect(() => service.requireValid("not-a-real-token")).toThrow(UnauthorizedException);
  });

  it("rejects and forgets expired tokens", () => {
    const issuedAt = new Date("2026-07-08T12:00:00Z");
    const session = service.issue("device-a", issuedAt);
    const afterExpiry = new Date(session.expiresAt.getTime() + 1);

    expect(() => service.requireValid(session.sessionToken, afterExpiry)).toThrow(UnauthorizedException);
    expect(() => service.requireValid(session.sessionToken, issuedAt)).toThrow(UnauthorizedException);
  });

  it("rejects blank device ids", () => {
    expect(() => service.issue("")).toThrow(BadRequestException);
    expect(() => service.issue("   ")).toThrow(BadRequestException);
    expect(() => service.issue(undefined)).toThrow(BadRequestException);
    expect(() => service.issue("x".repeat(129))).toThrow(BadRequestException);
  });

  it("defaults anonymous signaling to off", () => {
    expect(service.allowAnonymous).toBe(false);
  });
});

describe("POST /sessions", () => {
  let app: INestApplication;

  beforeEach(async () => {
    const moduleRef = await Test.createTestingModule({
      imports: [AppModule]
    }).compile();
    app = moduleRef.createNestApplication();
    await app.init();
  });

  afterEach(async () => {
    await app.close();
  });

  it("issues a session token for a device", async () => {
    await request(app.getHttpServer())
      .post("/sessions")
      .send({ deviceId: "device-a" })
      .expect(201)
      .expect(({ body }) => {
        expect(body.deviceId).toBe("device-a");
        expect(typeof body.sessionToken).toBe("string");
        expect(body.sessionToken.length).toBeGreaterThanOrEqual(43);
        expect(new Date(body.expiresAt).getTime()).toBeGreaterThan(Date.now());
      });
  });

  it("rejects registration without a device id", async () => {
    await request(app.getHttpServer()).post("/sessions").send({}).expect(400);
  });
});
