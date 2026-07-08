# Changelog

All notable BeamDrop changes are tracked here.

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

- Internal testing only. Do not ship as production until Android release build,
  iOS archive/TestFlight, macOS notarization, Windows MSIX/installer packaging,
  authenticated transfer encryption, and real-device cross-platform QA are
  completed.

## 0.1.0-internal.0 - 2026-07-06

### Added

- Native app foundations for Android, iOS, macOS, and Windows.
- Shared protocol schema package and Rust core foundation.
- Local-first pairing, trusted-peer, transfer, chunking, hash verification, clipboard-policy, and history foundations across active platform targets.
- Production-readiness audit, MVP scope, release blockers, manual QA, E2E QA, and release checklist documentation.
- CI workflow scaffolding for Android, iOS, macOS, Windows, and Rust core.
- Local build scripts for Android, iOS, macOS, and Windows.

### Security

- Documented that public release remains blocked until authenticated encrypted transfer sessions are implemented and verified.
- Documented unknown-peer rejection, revoked-peer rejection, SHA-256 verification, and safe receive-file handling as release gates.

### Known Limitations

- Current status is internal testing only, not public beta or production release.
- Real-device Android-Windows MVP signoff is pending.
- iOS requires Xcode project/workspace validation and complete foreground transfer wiring.
- Windows requires a production DPAPI or Credential Locker storage provider and packaging path.
- macOS requires signing, sandbox, notarization, and packaged-app validation.
- Generated Rust bindings are planned but not currently release dependencies.
