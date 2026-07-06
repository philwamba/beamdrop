# BeamDrop Technical Architecture

## Architecture Overview

BeamDrop is a native local-first transfer system with platform apps, a shared
core where practical, and optional server components for future relay or
signaling. The local MVP must work without login and without cloud upload.

```text
Native App UI
  -> Platform Integration Layer
  -> Shared Core Boundary
  -> BeamDrop Protocol
  -> Local Discovery / Direct Transport
  -> Optional Relay or Signaling
```

## Repository Boundaries

- `apps/android`: Kotlin and Jetpack Compose Android app.
- `apps/ios`: Swift and SwiftUI iPhone app.
- `apps/macos`: Swift, SwiftUI, and AppKit macOS app.
- `apps/windows`: C#, WinUI 3, and Windows App SDK app.
- `core/beamdrop-core`: shared Rust logic where it reduces duplicate
  correctness work.
- `protocol/beamdrop-protocol`: protocol definitions, message schemas, test
  vectors, and compatibility rules.
- `server/beamdrop-relay`: optional relay service, not required for local MVP.
- `server/beamdrop-signaling`: optional signaling service, not required for
  local MVP.

## Native-Only Requirement

BeamDrop UI and platform integration must be native. The project must not use
Electron, Tauri, Flutter, React Native, Ionic, Cordova, web wrappers, or a
browser-only architecture.

The native-only requirement matters because BeamDrop depends on platform-specific
file pickers, share sheets, clipboard permissions, background execution limits,
local network permissions, secure storage, notifications, desktop tray/menu bar
behavior, and OS-specific receive locations.

## Shared Core Responsibilities

Shared Rust code is appropriate for:

- Protocol encoding and decoding.
- Transfer manifest validation.
- Chunk state machine.
- Hashing and integrity verification.
- Resume metadata validation.
- Trust model primitives.
- Cross-platform test vectors.

Shared Rust code should not own:

- Native UI.
- Platform file picker behavior.
- iOS Share Sheet integration.
- Android intent handling.
- macOS menu bar or Finder integration.
- Windows shell integration.
- Platform permission prompts.

## Local-First Network Model

The local MVP must support transfer on a usable local network without login.
Recommended local path:

1. Discover nearby BeamDrop devices using local discovery.
2. Pair with QR code.
3. Establish authenticated encrypted session.
4. Exchange transfer manifest.
5. Ask receiver for approval when required.
6. Transfer chunked content directly.
7. Verify file hash.
8. Commit received files to the selected destination.

Public and corporate Wi-Fi may block multicast, peer discovery, client-to-client
traffic, or firewall ports. BeamDrop must include manual IP and QR fallback so a
user can connect even when automatic nearby discovery fails.

## Optional Server Model

Optional server components may help with:

- Signaling between paired devices.
- NAT traversal coordination.
- Relay when direct local transfer is impossible.
- Device presence hints for already trusted devices.

Server components must not be required for MVP local transfer. They must not be
designed as mandatory cloud storage. If a relay is used in the future, content
must remain end-to-end protected and the UI must clearly show that the transfer
is relayed.

Current optional server scaffolds:

- `server/beamdrop-signaling`: NestJS WebSocket gateway for device presence,
  pairing signaling placeholders, transfer signaling placeholders, rate limiting
  structure, logging, and `GET /health`.
- `server/beamdrop-relay`: NestJS HTTP service for expiring transfer tokens and
  temporary encrypted blob upload/download. The relay stores metadata-only
  records and opaque encrypted bytes in future S3/R2-compatible storage.
- `server/docker-compose.yml`: local PostgreSQL, Redis, MinIO, signaling, and
  relay wiring for future integration work.

Relay storage rules:

- Clients encrypt before upload.
- Server stores encrypted temporary blobs only.
- Server does not inspect plaintext or decrypt content.
- Tokens and blobs expire.
- Cleanup deletes expired relay objects.
- Logs must not include file contents, clipboard contents, keys, or decrypted
  metadata.

## Device Identity

Each BeamDrop install should have a stable device identity:

- Device ID: random, non-guessable identifier.
- Display name: user-visible local name.
- Platform: Android, iPhone, macOS, or Windows.
- Public key: used for authentication and trust.
- Trust state: unknown, pending, trusted, revoked.

Device private keys must be stored in platform secure storage where available:

- Android Keystore.
- iOS Keychain / Secure Enclave where appropriate.
- macOS Keychain.
- Windows Credential Locker, DPAPI, or platform-supported secure storage.

## Transfer Pipeline

Every transfer should be represented by a manifest:

- Transfer ID.
- Sender device ID.
- Receiver device ID.
- Creation time.
- Item list.
- Total bytes.
- Chunk size.
- Per-file hash.
- Optional per-chunk hashes for resume and verification.
- Relative paths for folders.

Large files must be chunked. Resume metadata must record completed chunks and
verify that resumed content still matches the original manifest.

## Persistence

Apps need local persistence for:

- Trusted devices.
- Revoked devices.
- Transfer history.
- Incomplete transfer state.
- Receive destination preferences.
- Clipboard feature preferences.
- Permission education state.

Sensitive data should be minimized. BeamDrop should not persist raw clipboard
content longer than needed for a user-triggered send.

## Permission Architecture

BeamDrop must explain permissions before invoking OS prompts:

- Local network access.
- Notifications.
- File picker or storage access.
- Photos/media access where required.
- Clipboard access or clipboard automation.
- Camera access for QR pairing.

Permission screens must state what the permission enables in BeamDrop and what
happens if the user declines.

## Failure Handling

Expected production failures:

- Discovery blocked by network.
- Device changed IP.
- Firewall blocks inbound connection.
- User revokes trust during transfer.
- Receiver rejects transfer.
- File destination unavailable.
- Disk space insufficient.
- Hash verification fails.
- App is backgrounded by mobile OS.

Each failure must map to a user-readable error state and, where possible, a
retry, resume, manual IP fallback, or diagnostics action.
