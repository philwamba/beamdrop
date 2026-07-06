# BeamDrop Relay

Optional BeamDrop relay service for future remote transfers when direct local
paths are unavailable. The local MVP must work without this service.

## Capabilities

- Health endpoint: `GET /health`.
- Expiring relay token issuance: `POST /relay/tokens`.
- Encrypted temporary blob upload: `POST /relay/blobs/:token`.
- Encrypted temporary blob download: `GET /relay/blobs/:token`.
- Max encrypted file size enforcement.
- Cleanup service for expired tokens/blobs.
- Metadata-only relay records.
- S3/R2-compatible storage adapter placeholder.
- Rate limiting structure through `@nestjs/throttler`.

## Security and Privacy

The relay must never receive or inspect plaintext files. Clients encrypt before
upload and decrypt after download. The relay stores only opaque encrypted bytes
and metadata such as transfer ID, size, content type, device IDs, object key,
status, and expiry time.

Transfers expire. Expired blobs are deleted by cleanup. Logs must never contain
file contents, clipboard contents, encryption keys, or decrypted metadata.

## Run

```sh
pnpm install
pnpm test
pnpm build
pnpm start
```

From `server/`:

```sh
docker compose up relay
```
