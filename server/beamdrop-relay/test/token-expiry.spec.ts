import { UnauthorizedException } from "@nestjs/common";
import { RelayConfig } from "../src/common/relay.config";
import { RelayRecordRepository } from "../src/tokens/relay-record.repository";
import { TransferTokenService } from "../src/tokens/transfer-token.service";

describe("TransferTokenService", () => {
  it("rejects expired tokens", () => {
    const config = new RelayConfig();
    Object.defineProperty(config, "tokenTtlSeconds", { value: 1 });
    const records = new RelayRecordRepository();
    const service = new TransferTokenService(config, records);
    const issuedAt = new Date("2026-07-06T12:00:00Z");
    const record = service.issue({ encryptedSizeBytes: 10 }, issuedAt);

    expect(() => service.requireValid(record.token, new Date("2026-07-06T12:00:02Z"))).toThrow(UnauthorizedException);
    expect(records.findByToken(record.token)?.status).toBe("expired");
  });
});
