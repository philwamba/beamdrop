import {
  BadRequestException,
  Body,
  Controller,
  Get,
  Header,
  Inject,
  Param,
  Post,
  RawBodyRequest,
  Req
} from "@nestjs/common";
import { Request } from "express";
import { BlobStorage } from "./blob-storage";
import { TransferTokenService } from "../tokens/transfer-token.service";
import { RelayRecordRepository } from "../tokens/relay-record.repository";

@Controller("relay")
export class BlobController {
  constructor(
    private readonly tokens: TransferTokenService,
    private readonly records: RelayRecordRepository,
    @Inject("BlobStorage") private readonly storage: BlobStorage
  ) {}

  @Post("tokens")
  issue(@Body() body: { encryptedSizeBytes: number; contentType?: string; senderDeviceId?: string; receiverDeviceId?: string }) {
    const record = this.tokens.issue(body);
    return {
      transferId: record.transferId,
      token: record.token,
      expiresAt: record.expiresAt.toISOString(),
      maxBytes: record.encryptedSizeBytes
    };
  }

  @Post("blobs/:token")
  async upload(@Param("token") token: string, @Req() request: RawBodyRequest<Request>) {
    const record = this.tokens.requireValid(token);
    const rawBody = request.rawBody ?? (Buffer.isBuffer(request.body) ? request.body : undefined);
    if (!rawBody || rawBody.length === 0) {
      throw new BadRequestException("Encrypted blob body is required.");
    }
    if (rawBody.length !== record.encryptedSizeBytes) {
      throw new BadRequestException("Encrypted blob size does not match token metadata.");
    }
    await this.storage.put(record.objectKey, rawBody, record.contentType);
    record.status = "uploaded";
    this.records.upsert(record);
    return { transferId: record.transferId, status: record.status };
  }

  @Get("blobs/:token")
  @Header("Content-Type", "application/octet-stream")
  async download(@Param("token") token: string) {
    const record = this.tokens.requireValid(token);
    const blob = await this.storage.get(record.objectKey);
    if (!blob) {
      throw new BadRequestException("Encrypted blob not uploaded.");
    }
    record.status = "downloaded";
    this.records.upsert(record);
    return blob.bytes;
  }
}
