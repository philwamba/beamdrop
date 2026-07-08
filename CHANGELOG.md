# Changelog

All notable BeamDrop changes are tracked here.

## Unreleased

## 0.1.0-internal.8 - 2026-07-08

### Fixed

- macOS incoming pairing and transfer approval prompts now bring the BeamDrop
  window forward so Android sends do not appear to fail silently while the Mac
  is waiting in the background.
- macOS approval timeouts and explicit rejections now show clear in-app error
  messages.
- macOS DMG packaging now includes local network and Bonjour privacy
  declarations for `_beamdrop._tcp`, improving pairing/discovery/transfer
  behavior on recent macOS releases.

### Release Status

- Private QA only. The macOS DMG is still ad-hoc signed unless Developer ID
  signing and notarization are configured outside the repository.

## 0.1.0-internal.7 - 2026-07-08

### Fixed

- Android release APK builds now fail closed when release signing credentials are
  missing instead of falling back to the Android debug certificate.
- Android APK metadata now uses the repository `VERSION` for `versionName` and a
  monotonically increasing version code derived from the release version.
- Android now sends a reciprocal `PAIRING_REQUEST` after approving a scanned QR
  code, allowing macOS to show an approval prompt and trust the Android device
  before transfers.
- macOS now handles incoming `PAIRING_REQUEST` payloads through an explicit
  trust approval dialog instead of rejecting them as unknown-device transfers.
- Android release APKs now use R8/resource shrinking and exclude unused bundled
  BouncyCastle resources, reducing the internal APK from about 16 MB to about
  2.5 MB.
- Added a local-only helper for generating an ignored internal Android release
  keystore for sideload QA builds.
- GitHub release workflow now requires Android release signing secrets before it
  can publish Android APK artifacts.

### Release Status

- Private QA only. The Android APK can now be signed with a stable non-debug
  internal key, but sideload installs may still show Play Protect reputation
  warnings until distributed through Google Play or a recognized signing
  certificate.

## 0.1.0-internal.6 - 2026-07-08

### Fixed

- Encrypted transfers now use one sealed-chunk wire framing on every platform
  (length-prefixed frames), so Android, iPhone, macOS, and Windows encrypted
  transfers interoperate on all platform pairs. Windows and macOS were updated
  to match the framing already used by Android and iPhone; receivers validate
  each frame length against the manifest before decrypting.
- Android QR scanning is more tolerant of camera frame orientation and luminance
  layout, and the scanner now enters the ready state automatically when camera
  permission was already granted.
- Android top-level navigation is consistent again: Home, Devices, History, and
  Settings use the same four-item bottom bar, while send and receive actions
  live on the Home screen.
- Android theme colors now follow the BeamDrop logo's blue/cyan palette instead
  of the temporary green palette.
- Android back and close actions now use icon buttons instead of text buttons.
- Android device renaming now opens from an edit icon beside the phone name,
  saves from a dialog, and shows a confirmation toast.
- Android Home now exposes receive actions directly with Show QR and Scan QR
  buttons.

### Release Status

- Private QA only. Android artifacts use internal signing for sideload
  installability, not production Play/App Signing credentials.
- macOS artifacts are ad-hoc signed unless Developer ID signing and notarization
  are configured outside the repository.

## 0.1.0-internal.5 - 2026-07-08

### Changed

- Android app structure now follows a professional single-Activity Compose
  architecture with navigation, screens, theme, shared components, and helpers
  split by feature area.
- Android Home now uses a simpler phone-screen-inspired layout with centered
  BeamDrop identity, a short device code, lightweight top actions, and a
  minimal Receive / Send / Settings bottom dock.
- Android colors now align more closely with the teal BeamDrop logo direction.

### Release Status

- Private QA only. Android artifacts use internal signing for sideload
  installability, not production Play/App Signing credentials.

## 0.1.0-internal.4 - 2026-07-08

### Fixed

- Android Pair New Device and Scan QR flows now present camera scanning as a
  clear primary action for nontechnical users.
- Android Scan QR now opens a real CameraX preview and decodes BeamDrop QR codes
  instead of only offering manual payload entry.
- Android home is reorganized around send, pair, devices, history, and settings
  with clearer labels and bottom navigation.

### Release Status

- Private QA only. Android artifacts use internal debug signing unless production
  signing credentials are provided.

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
