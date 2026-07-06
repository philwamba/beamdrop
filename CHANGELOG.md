# Changelog

All notable BeamDrop changes are tracked here.

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
