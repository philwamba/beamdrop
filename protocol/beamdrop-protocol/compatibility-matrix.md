# BeamDrop Protocol Compatibility Matrix

## Current Version

| Protocol version | Status | Notes |
| --- | --- | --- |
| `1.0` | Initial | First BeamDrop schema contract for discovery, pairing, transfer envelopes, progress, results, and errors. |

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
| `FOLDER_ARCHIVE` | Yes | Sent as an archive envelope with file metadata and final SHA-256. |
| `IMAGE` | Yes | Requires file-style metadata and may include dimensions. |
| `SCREENSHOT` | Yes | Requires file-style metadata and may include dimensions. |
| `CLIPBOARD_TEXT` | Yes | Must respect platform clipboard restrictions. |
| `CLIPBOARD_IMAGE` | Yes | Requires file-style metadata and must respect platform clipboard restrictions. |
| `PAIRING_REQUEST` | Yes | Used for pairing control messages. |
| `PAIRING_ACCEPTED` | Yes | Used for pairing control messages. |
| `TRANSFER_CANCEL` | Yes | Used to cancel in-progress transfer. |
| `TRANSFER_RESUME` | Yes | Required for large files. |
| `DEVICE_PING` | Yes | Used for reachability checks. |

## Security Compatibility

| Requirement | `1.0` behavior |
| --- | --- |
| Unknown peers | Reject unless pairing is active or receiver explicitly approves the incoming request. |
| Revoked peers | Reject before accepting transfer envelopes or content chunks. |
| Envelope validation | Validate against schema before accepting content. |
| Large file chunks | Default chunk size is 4 MB. |
| Resume | Required for large files and represented with `resumeSupported` and `resumeToken`. |
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
