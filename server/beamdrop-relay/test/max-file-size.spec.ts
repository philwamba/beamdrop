import { BadRequestException } from "@nestjs/common";
import { RelayConfig } from "../src/common/relay.config";
import { RelayRecordRepository } from "../src/tokens/relay-record.repository";
import { TransferTokenService } from "../src/tokens/transfer-token.service";

describe("max file size enforcement", () => {
  it("rejects token issuance above configured encrypted size", () => {
    const config = new RelayConfig();
    Object.defineProperty(config, "maxFileBytes", { value: 1024 });
    const service = new TransferTokenService(config, new RelayRecordRepository());

    expect(() => service.issue({ encryptedSizeBytes: 1025 })).toThrow(BadRequestException);
  });
});
