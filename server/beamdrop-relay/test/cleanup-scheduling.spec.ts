import { InMemoryBlobStorage } from "../src/blobs/blob-storage";
import { CleanupService } from "../src/cleanup/cleanup.service";
import { RelayConfig } from "../src/common/relay.config";
import { RelayRecordRepository } from "../src/tokens/relay-record.repository";

describe("CleanupService scheduling", () => {
  let records: RelayRecordRepository;
  let storage: InMemoryBlobStorage;
  let config: RelayConfig;
  let service: CleanupService;

  beforeEach(() => {
    jest.useFakeTimers();
    records = new RelayRecordRepository();
    storage = new InMemoryBlobStorage();
    config = new RelayConfig();
    Object.defineProperty(config, "cleanupIntervalSeconds", { value: 5 });
    service = new CleanupService(records, storage, config);
  });

  afterEach(() => {
    service.onModuleDestroy();
    jest.useRealTimers();
  });

  it("runs cleanupExpired on the configured interval after module init", async () => {
    const spy = jest.spyOn(service, "cleanupExpired");
    service.onModuleInit();

    expect(spy).not.toHaveBeenCalled();
    await jest.advanceTimersByTimeAsync(5000);
    expect(spy).toHaveBeenCalledTimes(1);
    await jest.advanceTimersByTimeAsync(10000);
    expect(spy).toHaveBeenCalledTimes(3);
  });

  it("removes expired blobs when the scheduled cleanup fires", async () => {
    records.upsert({
      transferId: "relay-1",
      token: "expired",
      objectKey: "relay-1.bin",
      encryptedSizeBytes: 4,
      contentType: "application/octet-stream",
      expiresAt: new Date(Date.now() - 1000),
      createdAt: new Date(Date.now() - 2000),
      status: "uploaded"
    });
    await storage.put("relay-1.bin", Buffer.from("abcd"), "application/octet-stream");
    service.onModuleInit();

    await jest.advanceTimersByTimeAsync(5000);

    expect(records.findByToken("expired")).toBeUndefined();
    await expect(storage.get("relay-1.bin")).resolves.toBeUndefined();
  });

  it("stops the interval on module destroy", async () => {
    const spy = jest.spyOn(service, "cleanupExpired");
    service.onModuleInit();
    await jest.advanceTimersByTimeAsync(5000);
    expect(spy).toHaveBeenCalledTimes(1);

    service.onModuleDestroy();
    await jest.advanceTimersByTimeAsync(20000);

    expect(spy).toHaveBeenCalledTimes(1);
  });
});
