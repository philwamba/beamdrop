# BeamDrop Product Requirements

## Product Summary

BeamDrop is a native private cross-device transfer app for Android, iPhone,
Windows, and macOS. It lets a person move files, folders, text, links,
screenshots, and clipboard content between trusted devices without requiring a
login, cloud drive, or mandatory remote account.

The MVP is local-first. Devices on the same usable local network must be able to
discover, pair, and transfer without signing in. Optional relay or signaling
services may be added later to improve reachability, but they must not be
required for the local MVP.

## Product Goals

- Send content quickly between a user's trusted devices.
- Make local network transfer work without login or cloud upload.
- Preserve user control over who can send to a device.
- Provide clear security and permission explanations before asking for access.
- Handle large files reliably with chunking, hash verification, and resume.
- Respect native platform limits, especially mobile clipboard restrictions.

## Non-Goals

- BeamDrop is not a cloud storage product.
- BeamDrop is not a public file drop box for anonymous senders.
- BeamDrop is not a web-only app and must not be implemented with Electron,
  Tauri, Flutter, React Native, Ionic, Cordova, or browser UI wrappers.
- The MVP does not require remote relay, identity accounts, or cloud upload.

## Supported Platforms

- Android: native Kotlin and Jetpack Compose.
- iPhone: native Swift and SwiftUI.
- macOS: native Swift, SwiftUI, and AppKit where desktop integration requires it.
- Windows: native C#, WinUI 3, and Windows App SDK.
- Shared core: Rust where it improves correctness for protocol, cryptography,
  transfer state, and validation.

## Personas

### Personal Multi-Device User

Owns a phone, laptop, and desktop. Wants to move photos, screenshots, links, and
documents without emailing themselves or using a cloud drive.

Required outcomes:

- Pair once with QR code.
- See trusted devices on the home screen.
- Send a file or link in a few taps or clicks.
- Revoke an old device immediately.

### Privacy-Sensitive User

Does not want files uploaded to third-party cloud storage. Expects explicit
approval before unknown devices can send files.

Required outcomes:

- Understand whether a transfer is local or relayed.
- Reject an incoming request from an unknown device.
- View and clear transfer history.
- Disable clipboard features.

### Corporate or Campus Network User

Uses public or managed Wi-Fi where multicast discovery may be blocked.

Required outcomes:

- Use manual IP entry or QR fallback when nearby discovery fails.
- Run network diagnostics to identify discovery, firewall, or subnet issues.
- Transfer locally when direct connectivity is still possible.

## Core MVP Requirements

### Pairing

- Devices pair using QR code.
- A pairing QR code must encode enough information to establish a secure
  authenticated session, not a reusable permanent secret.
- Pairing must show both device names and platform types before trust is saved.
- Unknown devices cannot send files without approval.
- Trusted devices can be revoked from every platform.
- Revocation must prevent future automatic trust for that device.

### Local Transfer

- Local network transfer must work without login.
- Local transfer must not require cloud upload.
- Discovery should prefer local mechanisms, but manual IP and QR fallback are
  required because public and corporate Wi-Fi may block discovery.
- The app must clearly identify when a device is discovered locally, manually
  entered, or reached through a future relay.

### Transfer Types

- Files: send one or more files with names, sizes, hashes, and MIME/type hints.
- Folders: preserve relative folder structure and empty directories where the
  platform file picker can provide them.
- Text: send plain text snippets with preview and size limit.
- Links: send URL text with parsed host display and safety warning for unusual
  schemes.
- Screenshots: support native share targets and desktop capture workflows.
- Clipboard: support only platform-permitted, user-driven clipboard workflows.

### Reliability

- All large file transfers must be chunked.
- File hash verification is required after transfer.
- Transfer resume is required for large files.
- Partial transfers must not appear as complete files until verification passes.
- Interrupted transfers must retain enough metadata to resume or cleanly fail.

### Security

- Device trust must be explicit.
- Unknown devices cannot push content silently.
- Incoming transfers from untrusted devices require user approval.
- Pairing keys and trusted device records must be stored in platform secure
  storage where available.
- Transfer sessions must use authenticated encryption.
- File hashes must be verified before a received item is marked complete.

## Clipboard Requirements

### iPhone

iPhone cannot silently monitor the clipboard in the background. BeamDrop must not
promise automatic background clipboard sync on iOS. Clipboard sending must be
manual through Share Sheet, Shortcuts, or Paste.

### Android

Android background clipboard access is restricted. BeamDrop clipboard sending
must be user-triggered where required by OS restrictions, using visible app
actions, share targets, Quick Settings, or foreground flows.

### Desktop

Desktop apps can support stronger clipboard workflows with user permission.
macOS and Windows may offer watched clipboard modes, but they must be opt-in,
clearly explained, revocable, and visible in settings.

## Success Metrics

- Pair two devices by QR code in under 60 seconds.
- Start a local transfer without login.
- Complete a 1 GB local transfer with chunking and hash verification.
- Resume a large transfer after network interruption.
- Reject an unknown incoming transfer before content is accepted.
- Revoke a trusted device and block subsequent trusted sends from it.
- Provide a working manual IP or QR fallback when discovery fails.

## MVP Acceptance Criteria

- Android, iPhone, macOS, and Windows have native app foundations.
- Local network pairing and transfer do not require login.
- QR pairing is the primary pairing flow.
- Unknown senders require approval before transfer.
- Trusted device revocation is implemented.
- Large files are chunked, resumable, and hash verified.
- Clipboard UX follows iOS, Android, macOS, and Windows platform limits.
- Network diagnostics explain discovery failures and fallback options.
