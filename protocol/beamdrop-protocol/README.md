# BeamDrop Protocol Package

This package defines the BeamDrop wire contract for local discovery, pairing,
transfer envelopes, progress updates, results, and protocol errors.

BeamDrop protocol versioning starts at `1.0`. The local discovery service name is:

```text
_beamdrop._tcp
```

## Protocol Principles

- Local network transfer must work without login.
- Unknown peers must be rejected unless pairing is active.
- Revoked peers must be rejected.
- Devices pair through an explicit QR-based pairing flow.
- Transfer envelopes must be validated before accepting content.
- Large file transfers must be chunked and resumable.
- File transfers must include a final SHA-256 hash and receivers must verify it.
- Default chunk size is 4 MB, represented as `4194304` bytes.

## Required Device Advertisement Fields

Every device advertisement must include:

- `protocolVersion`
- `deviceId`
- `deviceName`
- `platform`
- `publicKey`
- `features`
- `port`

Supported platforms:

- `android`
- `ios`
- `macos`
- `windows`

## Supported Transfer Types

- `TEXT`
- `URL`
- `FILE`
- `FOLDER_ARCHIVE`
- `IMAGE`
- `SCREENSHOT`
- `CLIPBOARD_TEXT`
- `CLIPBOARD_IMAGE`
- `PAIRING_REQUEST`
- `PAIRING_ACCEPTED`
- `TRANSFER_CANCEL`
- `TRANSFER_RESUME`
- `DEVICE_PING`

## Schemas

- `schemas/device-advertisement.schema.json`
- `schemas/pairing-request.schema.json`
- `schemas/pairing-response.schema.json`
- `schemas/transfer-envelope.schema.json`
- `schemas/transfer-progress.schema.json`
- `schemas/transfer-result.schema.json`
- `schemas/error.schema.json`

## Examples

- `examples/device-advertisement.example.json`
- `examples/pairing-request.example.json`
- `examples/pairing-response.example.json`
- `examples/text-transfer.example.json`
- `examples/file-transfer.example.json`
- `examples/transfer-progress.example.json`
- `examples/transfer-result.example.json`

## Validation Rules

Implementations must validate JSON messages against the corresponding schema
before acting on the message. A receiver must reject malformed messages,
unsupported platforms, unsupported transfer types, revoked peers, unknown peers
outside an active pairing flow, and file transfer envelopes missing chunk or hash
metadata.

The protocol package currently defines schemas and examples only. Runtime
encoding, signing, encryption, transport, and compatibility tests should be added
in the shared protocol/core implementation phase.
