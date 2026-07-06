import { BadRequestException, Injectable, UnauthorizedException } from "@nestjs/common";
import { randomBytes, randomUUID } from "crypto";
import { RelayConfig } from "../common/relay.config";
import { RelayRecordRepository } from "./relay-record.repository";
import { RelayRecord } from "./relay-record";

export interface IssueTokenRequest {
  encryptedSizeBytes: number;
  contentType?: string;
  senderDeviceId?: string;
  receiverDeviceId?: string;
}

@Injectable()
export class TransferTokenService {
  constructor(
    private readonly config: RelayConfig,
    private readonly records: RelayRecordRepository
  ) {}

  issue(request: IssueTokenRequest, now = new Date()): RelayRecord {
    if (!Number.isFinite(request.encryptedSizeBytes) || request.encryptedSizeBytes <= 0) {
      throw new BadRequestException("Encrypted size must be positive.");
    }
    if (request.encryptedSizeBytes > this.config.maxFileBytes) {
      throw new BadRequestException(`Encrypted blob exceeds max file size of ${this.config.maxFileBytes} bytes.`);
    }

    const token = randomBytes(32).toString("base64url");
    const transferId = `relay-${randomUUID()}`;
    return this.records.upsert({
      transferId,
      token,
      objectKey: `${transferId}.bin`,
      encryptedSizeBytes: request.encryptedSizeBytes,
      contentType: request.contentType ?? "application/octet-stream",
      senderDeviceId: request.senderDeviceId,
      receiverDeviceId: request.receiverDeviceId,
      expiresAt: new Date(now.getTime() + this.config.tokenTtlSeconds * 1000),
      createdAt: now,
      status: "issued"
    });
  }

  requireValid(token: string, now = new Date()): RelayRecord {
    const record = this.records.findByToken(token);
    if (!record) {
      throw new UnauthorizedException("Relay token not found.");
    }
    if (record.expiresAt.getTime() <= now.getTime()) {
      record.status = "expired";
      this.records.upsert(record);
      throw new UnauthorizedException("Relay token expired.");
    }
    return record;
  }
}
