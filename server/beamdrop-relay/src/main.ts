import "reflect-metadata";
import { Logger, ValidationPipe } from "@nestjs/common";
import { NestFactory } from "@nestjs/core";
import { raw } from "express";
import { AppModule } from "./app.module";

async function bootstrap() {
  const app = await NestFactory.create(AppModule, { bufferLogs: true });
  app.use("/relay/blobs", raw({ type: "*/*", limit: process.env.RELAY_MAX_FILE_BYTES ?? "512mb" }));
  app.useGlobalPipes(new ValidationPipe({ whitelist: true, transform: true }));
  const port = Number(process.env.PORT ?? 4020);
  await app.listen(port);
  Logger.log(`BeamDrop relay listening on ${port}`, "Bootstrap");
}

void bootstrap();
