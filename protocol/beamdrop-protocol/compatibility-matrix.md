# BeamDrop Protocol Compatibility Matrix

## Current Version

| Protocol version | Status | Notes |
| --- | --- | --- |
| `1.0` | Initial | First BeamDrop schema contract for discovery, pairing, transfer envelopes, progress, results, and errors. |

## Android-Windows-macOS MVP Compatibility

| Area | Android | Windows | macOS | Required MVP behavior |
| --- | --- | --- | --- | --- |
| Protocol version | `1.0` | `1.0` | `1.0` | Reject unsupported versions. |
| Pairing QR JSON | camelCase, accepts legacy snake_case | camelCase | camelCase | New QR payloads use `type`, `protocolVersion`, `serviceName`, `pairingSessionId`, `deviceId`, `deviceName`, `platform`, `publicKey`, optional `endpoint`, and `expiresAtEpochMillis`. |
| Discovery service | `_beamdrop._tcp` | `_beamdrop._tcp` | `_beamdrop._tcp` | No hardcoded IPs; use discovery, QR endpoint hints, or manual fallback. |
| Transfer frame | JSON envelope + newline + bytes | JSON envelope + newline + bytes | JSON envelope + newline + bytes | Same envelope field names and chunk/hash metadata. |
| Transfer type names | `TEXT`, `URL`, `FILE`, `CLIPBOARD_TEXT` | `TEXT`, `URL`, `FILE`, `CLIPBOARD_TEXT` | `TEXT`, `URL`, `FILE`, `CLIPBOARD_TEXT` | Reject unsupported transfer types. |
| Chunk size | 4 MB | 4 MB | 4 MB | Never load large files fully into memory. |
| Final hash | SHA-256 | SHA-256 | SHA-256 | Verify before marking complete. |
| Unknown peer | Rejected | Rejected | Rejected | Pairing or explicit approval required. |
| Revoked peer | Rejected | Rejected | Rejected | Re-pairing required before trust is restored. |
| Transfer status names | Android enum names | Windows enum names | Swift enum raw values | `Queued`, `WaitingForApproval`, `Transferring`, `Verifying`, `Completed`, `Failed`, `Cancelled`, `Rejected`, `Corrupted`, `Incomplete`. |
| Cancellation | `Cancelled` history | `Cancelled` history | `Cancelled` history | User-visible cancellation state. |
| Resume | Planned metadata | Planned metadata | Planned metadata | Persisted cross-restart resume not complete yet. |

## macOS MVP Implementation Notes

| Area | macOS behavior |
| --- | --- |
| Native stack | Swift, SwiftUI, AppKit, Network.framework, Bonjour, NSPasteboard, Keychain. |
| Menu bar | Status item exposes open app, send clipboard, pairing, clipboard pause, diagnostics, and quit actions. |
| Pairing import | Paste/import pairing JSON is implemented; camera QR scanning is future work. |
| Receive path | Local TCP listener accepts `JSON envelope + newline + payload bytes`, checks trusted peer state, requires approval unless auto-accept is enabled, writes files to Downloads, and verifies SHA-256. |
| Clipboard | Manual send only. Clipboard sharing can be paused, disabled, and sensitive-looking text is blocked from clipboard-send action. |
| Security | Device identity is generated with CryptoKit and persisted through a Keychain abstraction. |

## Platform Compatibility

| Platform | Supported in `1.0` | Notes |
| --- | --- | --- |
| Android | Yes | Clipboard sending must be user-triggered where required by Android restrictions. |
| iOS | Yes | Clipboard sending must be manual through Share Sheet, Shortcuts, or Paste. |
| macOS | Yes | Desktop clipboard workflows may be stronger with explicit user permission. |
| Windows | Yes | Desktop clipboard workflows may be stronger with explicit user permission. |

## Discovery Compatibility

| Version | Local service name | Required fields |
| --- | --- | --- |
| `1.0` | `_beamdrop._tcp` | `deviceId`, `deviceName`, `platform`, `publicKey`, `features`, `port` |

## Transfer Type Compatibility

| Transfer type | Supported in `1.0` | Notes |
| --- | --- | --- |
| `TEXT` | Yes | Requires text metadata. |
| `URL` | Yes | Requires URL metadata. |
| `FILE` | Yes | Requires file name, MIME type, size, chunk size, chunk count, and SHA-256. |
| `FOLDER_ARCHIVE` | Future | Not part of Android-Windows MVP wire contract. |
| `IMAGE` | Future | Send as `FILE` for MVP if image transfer is needed. |
| `SCREENSHOT` | Future | Send as `FILE` for MVP if screenshot transfer is needed. |
| `CLIPBOARD_TEXT` | Yes | Must respect platform clipboard restrictions. |
| `CLIPBOARD_IMAGE` | Future | Not part of Android-Windows MVP wire contract. |
| `PAIRING_REQUEST` | Future | MVP pairing is QR payload plus explicit local trust approval. |
| `PAIRING_ACCEPTED` | Future | MVP pairing is QR payload plus explicit local trust approval. |
| `TRANSFER_CANCEL` | Future | MVP cancellation is local cancellation of the active stream. |
| `TRANSFER_RESUME` | Future | Resume metadata exists; cross-restart resume is not complete. |
| `DEVICE_PING` | Future | Not required for Android-Windows MVP. |

## Security Compatibility

| Requirement | `1.0` behavior |
| --- | --- |
| Unknown peers | Reject unless pairing is active or receiver explicitly approves the incoming request. |
| Revoked peers | Reject before accepting transfer envelopes or content chunks. |
| Envelope validation | Validate against schema before accepting content. |
| Large file chunks | Default chunk size is 4 MB. |
| Resume | Planned metadata exists; persisted cross-restart resume is not complete in Android-Windows MVP. |
| File hash | Final SHA-256 must be present and verified before completion. |

## Version Negotiation

BeamDrop `1.0` implementations must reject unsupported major versions. Future
minor versions may add optional fields, but must not remove required `1.0` fields
without a major version change.

## Compatibility Test Expectations

- Validate every example file against its schema.
- Reject unsupported platforms.
- Reject unsupported transfer types.
- Reject file transfers missing chunk metadata.
- Reject file transfers missing `sha256`.
- Reject unknown peers unless pairing is active.
- Reject revoked peers.
- Verify final file hash before reporting success.
