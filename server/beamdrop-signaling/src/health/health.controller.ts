import { Controller, Get } from "@nestjs/common";

@Controller("health")
export class HealthController {
  @Get()
  health() {
    return {
      status: "ok",
      service: "beamdrop-signaling",
      localMvpRequired: false,
      contentHandling: "metadata-and-signaling-only"
    };
  }
}
