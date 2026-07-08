# BeamDrop MVP Scope

## MVP Definition

BeamDrop MVP is a **local-first trusted-device transfer app**. It must work without cloud login, without cloud file upload, and without relay/signaling dependency.

## In Scope For Internal MVP

- Protocol `1.0` transfer envelope and QR pairing payload.
- Local network discovery or QR/manual endpoint fallback.
- Device identity on Android, iOS, macOS, and Windows.
- Trusted peer records and revocation.
- Unknown-peer rejection.
- Text transfer.
- File transfer with 4 MB default chunks.
- SHA-256 verification before completion.
- Transfer history with success, failed, cancelled, rejected, corrupted, and incomplete statuses.
- User-controlled clipboard text sending.
- Clear permission, privacy, and diagnostics UI.
- Android-Windows local MVP as the first hard E2E gate.

## Android-Windows MVP Gate

The MVP is not releasable unless these are manually verified:

1. Android pairs with Windows.
2. Windows pairs with Android.
3. Android sends text to Windows.
4. Windows sends text to Android.
5. Android sends a small file to Windows.
6. Windows sends a small file to Android.
7. Android sends a large chunked file to Windows.
8. Windows sends a large chunked file to Android.
9. Transfer cancellation works.
10. Failed transfer appears in history.
11. Revoked device cannot transfer.
12. Unknown device requires approval or is rejected before content is accepted.

## macOS MVP Gate

1. SwiftPM app builds.
2. Menu bar and main window open reliably.
3. QR pairing/import works with Android or Windows.
4. Text and file send work.
5. File receive writes to Downloads or safe selected folder.
6. Clipboard send is user-controlled and pausable.
7. Keychain strategy is implemented and validated in a signed app.

## iOS MVP Gate

1. Xcode project/workspace builds.
2. Local Network permission and `_beamdrop._tcp` Bonjour service are configured.
3. QR/manual pairing works.
4. Foreground receive limitations are documented and validated.
5. Send text/file through explicit user action or Share Sheet.
6. Manual Paste flow exists for clipboard text.
7. No silent clipboard monitoring.
8. Keychain storage is used for secrets.

## Windows MVP Gate

1. Active Windows target is `apps/windows/src` unless explicitly changed.
2. Active app builds.
3. Pair/send/receive text and files with Android.
4. Chunked transfer and SHA-256 verification work.
5. Unknown/revoked peers are rejected.
6. Secure storage uses platform-supported protected storage.
7. Clipboard send is user-controlled and pausable.
8. Firewall/network troubleshooting exists.
9. MSIX/installer path is documented.

## Explicitly Post-MVP

- Cloud account system.
- Server-required transfer.
- Plaintext relay file storage.
- Team/workspace sharing.
- Folder archive transfer.
- Image/screenshot as first-class transfer types.
- Clipboard image sync.
- Silent mobile clipboard monitoring.
- Generated Rust native bindings.
