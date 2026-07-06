# BeamDrop Protocol Specification

## Scope

This document defines the expected BeamDrop protocol behavior for pairing,
trusted device sessions, transfer manifests, chunked file transfer, verification,
and resume. It is implementation guidance for `protocol/beamdrop-protocol` and
`core/beamdrop-core`.

## Protocol Goals

- Work locally without login.
- Authenticate trusted devices.
- Prevent unknown devices from silently sending files.
- Support files, folders, text, links, screenshots, and clipboard content.
- Require chunking for large files.
- Require file hash verification.
- Require resume for large files.
- Allow future optional relay without changing content security assumptions.

## Device Record

Each device advertises or exchanges:

- `device_id`: stable random identifier.
- `display_name`: user-editable display name.
- `platform`: `android`, `iphone`, `macos`, or `windows`.
- `public_key`: device identity public key.
- `protocol_version`: supported protocol version.
- `capabilities`: transfer types and optional features.

The private key must never leave the device.

## Android-Windows MVP Wire Contract

Android and Windows MVP builds use the same local TCP framing:

1. Connect to the paired peer endpoint.
2. Write one UTF-8 JSON transfer envelope.
3. Terminate the envelope with a single newline byte.
4. Stream raw payload bytes in 4 MB chunks by default.
5. Close the payload stream when complete.

The transfer envelope is camelCase JSON:

```json
{
  "protocolVersion": "1.0",
  "transferId": "tx-01J2M8X0E11Y0Y9QVT38A0BHR5",
  "transferType": "FILE",
  "senderDeviceId": "bd-android-abc",
  "senderPublicKey": "base64-public-key",
  "receiverDeviceId": "bd-windows-def",
  "createdAt": "2026-07-06T14:27:18Z",
  "payloadMetadata": {
    "fileName": "demo.mov",
    "mimeType": "video/quicktime",
    "sizeBytes": 187904819,
    "chunkSize": 4194304,
    "totalChunks": 45,
    "sha256": "6f1d2d9a8b0f73643d20e6f8bdbbcf46c2cf4bfb2f8b2c4ed4db70d49c9b3b2a"
  }
}
```

Receivers must validate `protocolVersion`, `transferType`, sender trust state,
chunk metadata, size, and final `sha256` before marking the transfer complete.

## Trust States

- `unknown`: no saved trust relationship.
- `pairing`: temporary QR-code pairing session.
- `trusted`: user-approved device.
- `revoked`: previously trusted device blocked from automatic trust.

Unknown devices cannot send files without approval. Revoked devices must be
treated as untrusted and should show a warning if they attempt to connect.

## Pairing by QR Code

QR pairing is mandatory for MVP. A QR code should contain a short-lived pairing
payload:

- Pairing session ID.
- Device ID.
- Display name.
- Platform.
- Public key or key agreement material.
- Local endpoint hint when available.
- Expiration timestamp.
- Protocol version.

The QR payload must not contain a permanent shared secret. Pairing must complete
with an authenticated handshake and visible confirmation on both devices.

Android and Windows MVP QR payloads use camelCase JSON with:

- `type`: `beamdrop_pairing`.
- `protocolVersion`: `1.0`.
- `pairingSessionId`.
- `deviceId`.
- `deviceName`.
- `platform`: `android`, `ios`, `macos`, or `windows`.
- `publicKey`.
- `serviceName`: `_beamdrop._tcp`.
- `endpoint`: optional `host`, `port`, and `route`.
- `expiresAtEpochMillis`.

Implementations may accept the older Android snake_case QR shape for migration,
but new QR payloads must use the shared camelCase shape.

## Session Establishment

After discovery, manual IP entry, or QR connection:

1. Devices exchange protocol versions.
2. Devices authenticate identity keys or pairing keys.
3. Devices derive session keys.
4. Devices confirm trust state.
5. Receiver enforces approval requirements.

All transfer sessions must use authenticated encryption.

## Transfer Manifest

Before sending content, the sender transmits a manifest:

```json
{
  "transfer_id": "random-transfer-id",
  "sender_device_id": "sender-id",
  "receiver_device_id": "receiver-id",
  "created_at": "2026-07-06T00:00:00Z",
  "kind": "files",
  "total_bytes": 1048576,
  "chunk_size": 1048576,
  "items": []
}
```

Each item includes:

- `item_id`.
- `kind`: file, folder, text, link, screenshot, or clipboard.
- `display_name`.
- `relative_path` for folders.
- `byte_length`.
- `mime_type` where known.
- `file_hash` for file-like content.
- `metadata_hash` when metadata integrity matters.

## Chunking

All large file transfers must be chunked. The implementation should define a
large-file threshold, but the protocol must support chunking for any file.

Chunk message fields:

- `transfer_id`.
- `item_id`.
- `chunk_index`.
- `offset`.
- `length`.
- `chunk_hash` when enabled.
- `payload`.

Chunks must be written to a staging area until the full file hash is verified.

## Hash Verification

File hash verification is required. A received file is complete only when:

1. All expected bytes are received.
2. The computed file hash matches the manifest.
3. The final file is moved from staging to destination.
4. Transfer history records success.

If hash verification fails, BeamDrop must not expose the staged file as a
successful received item.

## Resume

Transfer resume is required for large files. Resume negotiation must include:

- Transfer ID.
- Manifest hash.
- Item IDs.
- Completed chunk ranges.
- Destination staging state.
- Current file hash state or chunk verification state.

Resume must fail safely if:

- The manifest changed.
- The sender device identity changed.
- The receiver no longer trusts the sender.
- Staged content does not match recorded chunk hashes.
- The user revoked the device.

## Receive Approval

For unknown devices, BeamDrop must ask for approval before accepting content.
For trusted devices, product settings may allow automatic receive for selected
content types, but the default should remain understandable and revocable.

The approval request must show:

- Sender display name and platform.
- Trust state.
- Transfer type.
- Item count.
- Total size.
- Destination.
- Accept and reject actions.

## Manual IP and QR Fallback

When local discovery fails, BeamDrop must support:

- Manual IP or hostname entry.
- QR code containing endpoint hints.
- Network diagnostics explaining likely causes.

Fallback flows still require authentication, trust checks, and receive approval
where applicable.

## Versioning

Protocol messages must include a version. Apps should reject unsupported major
versions and gracefully degrade unsupported optional capabilities.

Compatibility tests must cover:

- Current protocol version.
- Previous supported versions.
- Unknown optional fields.
- Unsupported transfer kinds.
- Resume across app restart.
