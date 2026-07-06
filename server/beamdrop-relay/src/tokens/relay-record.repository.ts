import { Injectable } from "@nestjs/common";
import { RelayRecord } from "./relay-record";

@Injectable()
export class RelayRecordRepository {
  private readonly records = new Map<string, RelayRecord>();

  upsert(record: RelayRecord): RelayRecord {
    this.records.set(record.token, record);
    return record;
  }

  findByToken(token: string): RelayRecord | undefined {
    return this.records.get(token);
  }

  list(): RelayRecord[] {
    return [...this.records.values()];
  }

  delete(token: string): void {
    this.records.delete(token);
  }
}
