# BeamDrop Release Checklist

## Release Scope

Every release must state which platforms are included:

- Android.
- iPhone.
- macOS.
- Windows.
- Shared core.
- Protocol.
- Optional relay or signaling.

The MVP release must not depend on remote relay or cloud upload for local
network transfer.

## GitHub Release Artifacts

- Android APK artifact command: `scripts/build-android-apk.sh`.
- macOS DMG artifact command: `scripts/build-macos-dmg.sh`.
- GitHub workflow: `.github/workflows/release.yml`.
- Release tag format: `v<VERSION>`, for example `v0.1.0-internal.2`.
- Release publication mode: draft prerelease until production signing,
  notarization, and manual QA are complete.
- Artifact integrity: attach SHA-256 sidecar files with every APK and DMG.
- Token scope: GitHub Actions release publishing must use least privilege; only
  the publish job should request `contents: write`.
- Safety gate: the workflow must verify an existing tag before creating or
  updating a GitHub Release.
- Internal limitation: Android release artifacts now require external release
  signing and must fail closed when signing credentials are missing; current
  macOS DMG artifacts are ad-hoc signed unless Developer ID signing and
  notarization environment variables are configured.

## Product Readiness

- BeamDrop name and app icons are final for the release.
- Onboarding explains local-first transfer.
- Local network transfer works without login.
- QR pairing is implemented.
- Unknown devices cannot send files without approval.
- Trusted devices can be revoked.
- Manual IP and QR fallback are available.
- Network diagnostics explain public/corporate Wi-Fi limitations.

## Transfer Readiness

- Files transfer successfully.
- Folders transfer successfully.
- Text transfers successfully.
- Links transfer successfully.
- Screenshots transfer through native flows.
- Clipboard workflows match platform restrictions.
- All large file transfers are chunked.
- File hash verification is required.
- Transfers cannot be marked complete before hash verification succeeds.
- Missing or malformed transfer hashes are rejected.
- Transfer resume works for large files.
- Failed hash verification does not expose completed files.

## Security Readiness

- Device private keys are stored in secure platform storage.
- Pairing QR codes expire.
- Revoked devices are blocked.
- Unknown senders require approval.
- Transfer sessions are encrypted.
- Manifest validation rejects unsafe paths, traversal filenames, malformed
  hashes, negative sizes, and inconsistent chunk metadata.
- Staged partial files are protected from accidental exposure.
- Logs do not contain file contents or clipboard contents.
- Clipboard auto/tray send blocks sensitive-looking content by default.
- Crash reports exclude clipboard text, file contents, local file paths where
  practical, private keys, relay tokens, and decrypted metadata.

Optional server release gates:

- Local transfer still works with signaling and relay services offline.
- Signaling service does not transport plaintext files or clipboard contents.
- Relay service accepts encrypted blobs only and does not inspect plaintext.
- Relay tokens expire.
- Relay max file size is enforced.
- Relay cleanup deletes expired blobs.
- Rate limiting is enabled for signaling and relay endpoints.
- Server logs exclude file contents, clipboard contents, encryption keys, and
  decrypted metadata.

## Platform Readiness

### Android Release Checklist

- Build command: `scripts/build-android.sh`.
- APK artifact command: `scripts/build-android-apk.sh`.
- Test command: `gradle --no-daemon --max-workers=1 testDebugUnitTest`.
- Signing requirement: Play App Signing or release keystore configured outside
  the repo; no debug signing for release artifacts.
- GitHub release signing secrets required: `ANDROID_RELEASE_KEYSTORE_BASE64`,
  `ANDROID_RELEASE_STORE_PASSWORD`, `ANDROID_RELEASE_KEY_ALIAS`, and
  `ANDROID_RELEASE_KEY_PASSWORD`.
- Sideload warning risk: Google Play Protect may still warn that it has not seen
  this developer before when installing APKs outside Google Play. This is a
  reputation/distribution limitation, not a code permission issue. Production
  mitigation is Google Play distribution with Play App Signing.
- Permission review: `INTERNET`, network state, Wi-Fi state/multicast, Nearby
  Wi-Fi Devices with `neverForLocation`, camera for QR scan, Android 13+
  notifications, and foreground service only for active transfer progress.
- Store policy risk: background clipboard behavior and foreground service
  claims. Clipboard send must remain user-triggered and privacy copy must match
  actual behavior.
- Manual QA checklist: QR show/scan, local discovery denial/recovery,
  Android-Windows text transfer, small file transfer, large chunked file
  transfer, cancellation, corrupted hash failure, revoked peer rejection,
  notification prompt/progress, scoped storage save/reopen.
- Known limitations: release builds must be signed with a stable non-debug key.
  Users who installed older debug-signed APKs must uninstall before installing a
  differently signed APK with the same package name.

### iPhone Release Checklist

- Build command: `scripts/build-ios.sh` for Swift package validation; archive
  must be produced from the Xcode project/workspace once signing is configured.
- Test command: `swift test` in `apps/ios/`.
- Signing requirement: Apple Developer Team, App ID, App Group for the Share
  Extension, provisioning profiles for app and extension, and TestFlight archive
  validation.
- Permission review: local network usage description, Bonjour `_beamdrop._tcp`,
  camera only for QR scan, file/photo access only through picker/share flows.
- Store policy risk: iPhone clipboard must not be described as silent background
  sync. Use manual Paste, Share Sheet, and App Intents/Shortcuts language.
- Manual QA checklist: onboarding, local network permission prompt, camera QR
  scan, show QR, approve pairing, Share Extension send text/link/photo/file,
  manual Paste send, receive prompt, save/export received file, cancellation,
  history failure entry, revoked peer rejection.
- Known limitations: Swift package tests pass, but App Store archive, device
  signing, Share Extension entitlements, and full foreground transfer UI still
  require Xcode/TestFlight validation.

### macOS Release Checklist

- Build command: `scripts/build-macos.sh`.
- DMG artifact command: `scripts/build-macos-dmg.sh`.
- Test command: `swift test` in `apps/macos/`.
- Signing requirement: Developer ID Application certificate, hardened runtime,
  notarization, stapling, and sandbox/entitlement review if distributed through
  the Mac App Store.
- Permission review: local network/Bonjour behavior, file picker/save location,
  notification prompts, and clipboard monitoring only if explicitly enabled.
- Store policy risk: clipboard watching and local listener behavior must be
  opt-in, visible, and documented.
- Manual QA checklist: pair with Android/iPhone/Windows, send text/file/folder,
  receive prompt, large file cancellation/resume where supported, reveal in
  Finder, firewall/blocked Bonjour diagnostics, revoked peer rejection.
- Known limitations: Developer ID signing, notarization, stapling, and final
  entitlements are not proven for public distribution; unsigned or ad-hoc signed
  DMGs will trigger macOS Gatekeeper verification warnings.

### Windows Release Checklist

- Build command: `scripts/build-windows.ps1`.
- Test command: `dotnet run --project apps/windows/Tests/BeamDrop.Windows.Tests/BeamDrop.Windows.Tests.csproj`.
- Signing requirement: signed Windows package or installer, Windows App SDK
  packaging configuration, and production platform secure storage provider.
- Permission review: Windows Firewall/local network prompt copy,
  notification/tray behavior, file picker/save location, and clipboard policy.
- Store policy risk: local listener and clipboard tray action must be disclosed;
  clipboard sharing must be opt-in/pausable and must not log clipboard content.
- Manual QA checklist: install on clean Windows machine, tray menu actions,
  QR pair with Android/iPhone/macOS, send/receive text and files, large chunked
  transfer, cancellation, corrupted hash failure, revoked peer rejection,
  network diagnostics, settings persistence, uninstall cleanup.
- Known limitations: WinUI packaging/MSIX publishing and store submission assets
  are not proven; the active tested shell lives under `apps/windows/src/` while
  top-level WinUI scaffold projects are still release-incomplete.

### Shared Core, Protocol, and Server Checklist

- Rust build/test command: `cargo test --workspace` in `core/beamdrop-core/`.
- Protocol validation command: `find protocol/beamdrop-protocol -name '*.json' -print0 | xargs -0 -n1 python3 -m json.tool > /dev/null`.
- Server test commands: `pnpm test` and `pnpm build` in both
  `server/beamdrop-signaling/` and `server/beamdrop-relay/`.
- Signing requirement: server container images must be built from tagged commits
  and published with provenance; client release artifacts must include checksums.
- Permission review: protocol and server docs must not imply the optional relay
  is required for local transfer.
- Store policy risk: relay/signaling must be described as optional future remote
  infrastructure, not as required cloud storage for the MVP.
- Manual QA checklist: schema examples parse, Rust protocol tests pass, relay
  health/token expiry/max-size/cleanup tests pass, signaling health tests pass,
  local transfers work with server offline.
- Known limitations: JSON syntax validation is automated; full JSON Schema
  semantic validation still needs an offline validator in CI.

## Testing Readiness

- Unit tests pass.
- Integration tests pass.
- Large file tests pass.
- Resume tests pass.
- Hash failure tests pass.
- Revocation tests pass.
- Network blocked-discovery tests pass.
- Accessibility tests pass.
- Store compliance review complete.

## Documentation Readiness

- README is accurate.
- Product requirements are current.
- Technical architecture is current.
- Protocol spec is current.
- Security model is current.
- Platform limitations are current.
- Privacy policy notes are current.
- Store submission notes are current.

## Release Decision

Do not release if:

- Local transfer requires login.
- Optional relay is required for MVP transfer.
- Unknown devices can send without approval.
- Large files are not chunked.
- File hash verification can be skipped.
- Transfer sessions are not encrypted.
- Large transfer resume is missing.
- Receive filenames can escape the selected save directory.
- iPhone clipboard behavior implies silent background monitoring.
- Android clipboard behavior violates OS restrictions.
- Relay or signaling is required for same-network local transfer.
- Relay stores plaintext user content.
