export type RelayRecordStatus = "issued" | "uploaded" | "downloaded" | "expired" | "deleted";

export interface RelayRecord {
  transferId: string;
  token: string;
  objectKey: string;
  encryptedSizeBytes: number;
  contentType: string;
  senderDeviceId?: string;
  receiverDeviceId?: string;
  expiresAt: Date;
  createdAt: Date;
  status: RelayRecordStatus;
}
