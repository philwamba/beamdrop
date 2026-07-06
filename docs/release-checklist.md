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
- Transfer resume works for large files.
- Failed hash verification does not expose completed files.

## Security Readiness

- Device private keys are stored in secure platform storage.
- Pairing QR codes expire.
- Revoked devices are blocked.
- Unknown senders require approval.
- Transfer sessions are encrypted.
- Manifest validation rejects unsafe paths.
- Staged partial files are protected from accidental exposure.
- Logs do not contain file contents or clipboard contents.

## Platform Readiness

Android:

- Kotlin and Jetpack Compose app.
- User-triggered clipboard send where required.
- Foreground transfer behavior for long transfers.
- Scoped storage handled correctly.

iPhone:

- Swift and SwiftUI app.
- No silent background clipboard monitoring.
- Share Sheet, Shortcuts, or Paste clipboard workflows.
- Local network and camera permission copy complete.

macOS:

- SwiftUI/AppKit app.
- Desktop clipboard feature is opt-in if present.
- Finder or native file reveal behavior works.

Windows:

- C#, WinUI 3, Windows App SDK app.
- Desktop clipboard feature is opt-in if present.
- Windows notification and firewall guidance works.

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
- Large transfer resume is missing.
- iPhone clipboard behavior implies silent background monitoring.
- Android clipboard behavior violates OS restrictions.
