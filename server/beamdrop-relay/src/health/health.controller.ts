import { Controller, Get } from "@nestjs/common";

@Controller("health")
export class HealthController {
  @Get()
  health() {
    return {
      status: "ok",
      service: "beamdrop-relay",
      localMvpRequired: false,
      contentHandling: "encrypted-temporary-blobs-only"
    };
  }
}
