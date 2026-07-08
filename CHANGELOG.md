# Changelog

All notable BeamDrop changes are tracked here.

## 0.1.0-internal.3 - 2026-07-08

### Fixed

- Android internal APK artifacts are now signed so sideload installs are not
  rejected as invalid packages.
- macOS internal DMG packaging now includes a real app icon generated from the
  BeamDrop logo asset.
- macOS app resources are packaged inside `Contents/Resources` so the `.app`
  bundle can be signed as a conventional app bundle.

### Release Status

- Private QA only. macOS artifacts still require Developer ID signing and Apple
  notarization before public distribution.

## 0.1.0-internal.2 - 2026-07-08

### Added

- Transfer-session encryption foundations for Android, macOS, and Windows,
  including sealed chunk streams and encrypted transfer envelope metadata.
- iPhone local transfer transport primitives for TCP connection framing and
  bounded frame reads.
- Public-safe QA/readiness documentation pass that removes implementation-
  sensitive details from Markdown while keeping release gates visible.

### Changed

- Transfer envelope handling now carries encryption metadata where supported and
  keeps final hash verification as the completion gate.
- macOS keychain, validation, transfer, and protocol models were tightened for
  release-readiness work.
- Windows transfer handling now tracks encryption-related audit state and
  encrypted payload metadata.
- Relay blob upload handling was tightened for safer temporary encrypted blob
  processing.
- Release, QA, architecture, store-submission, and security docs were reworded
  to avoid exposing sensitive implementation detail or business readiness notes.

### Release Status

- Private QA only. This is not a public beta or production release.

## 0.1.0-internal.1 - 2026-07-07

### Added

- Release-readiness checklists for Android, iPhone, macOS, Windows, shared Rust
  core, protocol JSON, and optional server scaffolding.
- Store submission notes with per-platform signing, permission, policy, manual
  QA, and known-limitation requirements.
- CI coverage for centralized platform build scripts plus Rust, protocol JSON,
  signaling service, and relay service checks.

### Changed

- iOS build script now runs both Swift package tests and build.
- Windows build script now runs both the active core test suite and the scaffold
  persistence/settings/clipboard-policy tests.
- Transfer envelope protocol schema and examples now require `senderPublicKey`
  and final SHA-256 integrity metadata for every transfer envelope.
- Rust protocol validation now rejects missing cross-transfer integrity metadata
  and path-shaped file names.

### Release Status

- Private QA only. Do not ship as production until signed platform releases,
  security signoff, and real-device cross-platform QA are complete.

## 0.1.0-internal.0 - 2026-07-06

### Added

- Native app foundations for Android, iOS, macOS, and Windows.
- Shared protocol schema package and Rust core foundation.
- Local-first pairing, trusted-peer, transfer, chunking, hash verification, clipboard-policy, and history foundations across active platform targets.
- Production-readiness audit, MVP scope, release blockers, manual QA, E2E QA, and release checklist documentation.
- CI workflow scaffolding for Android, iOS, macOS, Windows, and Rust core.
- Local build scripts for Android, iOS, macOS, and Windows.

### Security

- Documented that public release remains blocked until security release gates are complete.
- Documented unknown-peer rejection, revoked-peer rejection, SHA-256 verification, and safe receive-file handling as release gates.

### Known Limitations

- Current status is private QA only, not public beta or production release.
- Real-device cross-platform QA signoff is pending.
- Platform signing, store packaging, and release validation are pending.
- Generated Rust bindings are planned but not currently release dependencies.
