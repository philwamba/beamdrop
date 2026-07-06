# BeamDrop Signaling

Optional BeamDrop signaling service for future remote transfer coordination.
The local MVP must work without this service.

## Capabilities

- Health endpoint: `GET /health`.
- WebSocket gateway namespace: `/signaling`.
- Device presence tracking.
- Auth/session placeholder using `x-beamdrop-device-id`.
- Pairing signaling placeholder event: `pairing:signal`.
- Transfer signaling placeholder event: `transfer:signal`.
- Rate limiting structure through `@nestjs/throttler`.
- Structured Nest logger usage.

## Privacy

The signaling service handles presence and coordination metadata only. It must
not transport file bytes or clipboard contents. Future signaling payloads should
contain only encrypted session setup data or metadata needed to connect peers.

## Run

```sh
pnpm install
pnpm test
pnpm build
pnpm start
```

From `server/`:

```sh
docker compose up signaling
```
