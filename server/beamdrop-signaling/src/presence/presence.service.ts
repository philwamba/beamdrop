import { Injectable } from "@nestjs/common";

export interface DevicePresence {
  deviceId: string;
  connectionId: string;
  platform?: string;
  lastSeenAt: Date;
}

@Injectable()
export class PresenceService {
  private readonly devices = new Map<string, DevicePresence>();

  upsert(presence: DevicePresence): DevicePresence {
    this.devices.set(presence.deviceId, presence);
    return presence;
  }

  removeByConnection(connectionId: string): void {
    for (const [deviceId, presence] of this.devices.entries()) {
      if (presence.connectionId === connectionId) {
        this.devices.delete(deviceId);
      }
    }
  }

  list(): DevicePresence[] {
    return [...this.devices.values()].sort((a, b) => a.deviceId.localeCompare(b.deviceId));
  }
}
