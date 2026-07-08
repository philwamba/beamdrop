import { INestApplication } from "@nestjs/common";
import { Test } from "@nestjs/testing";
import { raw } from "express";
import request = require("supertest");
import { AppModule } from "../src/app.module";

describe("BlobController", () => {
  let app: INestApplication;

  beforeEach(async () => {
    const moduleRef = await Test.createTestingModule({
      imports: [AppModule]
    }).compile();
    app = moduleRef.createNestApplication();
    app.use("/relay/blobs", raw({ type: "*/*", limit: "16mb" }));
    await app.init();
  });

  afterEach(async () => {
    await app.close();
  });

  async function issueToken(encryptedSizeBytes: number): Promise<{ token: string; transferId: string }> {
    const response = await request(app.getHttpServer())
      .post("/relay/tokens")
      .send({ encryptedSizeBytes, senderDeviceId: "device-a", receiverDeviceId: "device-b" })
      .expect(201);
    expect(typeof response.body.token).toBe("string");
    expect(response.body.maxBytes).toBe(encryptedSizeBytes);
    return response.body;
  }

  it("round-trips an encrypted blob through upload and download", async () => {
    const payload = Buffer.from("encrypted-bytes-0123456789");
    const { token, transferId } = await issueToken(payload.length);

    await request(app.getHttpServer())
      .post(`/relay/blobs/${token}`)
      .set("Content-Type", "application/octet-stream")
      .send(payload)
      .expect(201)
      .expect(({ body }) => {
        expect(body).toEqual({ transferId, status: "uploaded" });
      });

    const download = await request(app.getHttpServer())
      .get(`/relay/blobs/${token}`)
      .buffer(true)
      .parse((res, callback) => {
        const chunks: Buffer[] = [];
        res.on("data", (chunk) => chunks.push(chunk));
        res.on("end", () => callback(null, Buffer.concat(chunks)));
      })
      .expect(200)
      .expect("Content-Type", /application\/octet-stream/);

    expect(Buffer.compare(download.body as Buffer, payload)).toBe(0);
  });

  it("rejects an upload whose size does not match the token metadata", async () => {
    const { token } = await issueToken(10);

    await request(app.getHttpServer())
      .post(`/relay/blobs/${token}`)
      .set("Content-Type", "application/octet-stream")
      .send(Buffer.from("way-more-than-ten-bytes"))
      .expect(400)
      .expect(({ body }) => {
        expect(body.message).toMatch(/size does not match/i);
      });
  });

  it("rejects an upload with an empty body", async () => {
    const { token } = await issueToken(10);

    await request(app.getHttpServer())
      .post(`/relay/blobs/${token}`)
      .set("Content-Type", "application/octet-stream")
      .expect(400);
  });

  it("rejects uploads and downloads with an unknown token", async () => {
    await request(app.getHttpServer())
      .post("/relay/blobs/unknown-token")
      .set("Content-Type", "application/octet-stream")
      .send(Buffer.from("abcd"))
      .expect(401);

    await request(app.getHttpServer()).get("/relay/blobs/unknown-token").expect(401);
  });

  it("rejects a download before the blob was uploaded", async () => {
    const { token } = await issueToken(10);

    await request(app.getHttpServer())
      .get(`/relay/blobs/${token}`)
      .expect(400)
      .expect(({ body }) => {
        expect(body.message).toMatch(/not uploaded/i);
      });
  });

  it("rejects token issuance for a non-positive size", async () => {
    await request(app.getHttpServer()).post("/relay/tokens").send({ encryptedSizeBytes: 0 }).expect(400);
  });
});
