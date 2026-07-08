import { InMemoryBlobStorage } from "../src/blobs/blob-storage";
import { CleanupService } from "../src/cleanup/cleanup.service";
import { RelayConfig } from "../src/common/relay.config";
import { RelayRecordRepository } from "../src/tokens/relay-record.repository";

describe("CleanupService", () => {
  it("deletes expired records and encrypted blobs", async () => {
    const records = new RelayRecordRepository();
    const storage = new InMemoryBlobStorage();
    records.upsert({
      transferId: "relay-1",
      token: "expired",
      objectKey: "relay-1.bin",
      encryptedSizeBytes: 4,
      contentType: "application/octet-stream",
      expiresAt: new Date("2026-07-06T12:00:00Z"),
      createdAt: new Date("2026-07-06T11:59:00Z"),
      status: "uploaded"
    });
    await storage.put("relay-1.bin", Buffer.from("abcd"), "application/octet-stream");

    const deleted = await new CleanupService(records, storage, new RelayConfig()).cleanupExpired(
      new Date("2026-07-06T12:00:01Z")
    );

    expect(deleted).toBe(1);
    expect(records.findByToken("expired")).toBeUndefined();
    await expect(storage.get("relay-1.bin")).resolves.toBeUndefined();
  });
});
