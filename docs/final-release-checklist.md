# BeamDrop Final Release Checklist

Do not publish public downloads until every blocking item is checked.

## Security Gate

- [ ] Authenticated encrypted transport complete or public release explicitly deferred.
- [ ] Unknown peers rejected before content is accepted.
- [ ] Revoked peers rejected before content is accepted.
- [ ] QR payload validation tested.
- [ ] Transfer envelope validation tested.
- [ ] SHA-256 required for file transfers.
- [ ] Corrupted transfer fails and records history.
- [ ] Path traversal file names rejected or sanitized.
- [ ] Temporary files are deleted after failed/cancelled/corrupted transfer.
- [ ] Private keys are stored only through platform secure storage.
- [ ] Logs do not contain clipboard content, file content, private keys, tokens, or secrets.

## Platform Build Gate

- [ ] Android CI build passes.
- [ ] Android release signing configured.
- [ ] iOS Xcode project/workspace builds.
- [ ] iOS app group, Keychain, Local Network, Bonjour, and Share Extension validated.
- [ ] macOS SwiftPM build passes.
- [ ] macOS signing, sandbox, notarization, and DMG/export path documented.
- [ ] Windows active `apps/windows/src` build passes.
- [ ] Windows platform secure storage provider implemented.
- [ ] Windows MSIX/installer path documented.
- [ ] Rust core tests pass or Rust marked foundation-only for MVP.
- [ ] Server tests pass or server marked post-MVP.

## Android-Windows MVP Gate

- [ ] Android shows pairing QR.
- [ ] Windows pairs with Android.
- [ ] Windows shows pairing QR.
- [ ] Android pairs with Windows.
- [ ] Android sends text to Windows.
- [ ] Windows sends text to Android.
- [ ] Android sends small file to Windows.
- [ ] Windows sends small file to Android.
- [ ] Android sends large chunked file to Windows.
- [ ] Windows sends large chunked file to Android.
- [ ] Cancellation works.
- [ ] Failed transfer appears in history.
- [ ] SHA-256 mismatch is rejected.
- [ ] Unknown device rejected.
- [ ] Revoked device rejected.

## UX/Accessibility Gate

- [ ] All required screens reachable.
- [ ] Empty, loading, error, permission denied, and pairing failure states exist.
- [ ] Receive approval clearly shows sender, file/type, size, and trust.
- [ ] Revoke and cancel are confirmable.
- [ ] Clipboard sharing pause is visible on desktop.
- [ ] Mobile clipboard flows are user-triggered.
- [ ] TalkBack pass complete.
- [ ] VoiceOver pass complete.
- [ ] macOS keyboard navigation pass complete.
- [ ] Windows Narrator/keyboard pass complete.
- [ ] Light and dark mode screenshots reviewed.

## Store/Release Gate

- [ ] Privacy policy finalized.
- [ ] Store submission notes reviewed.
- [ ] Screenshots captured.
- [ ] Changelog updated.
- [ ] Version updated.
- [ ] Checksums generated.
- [ ] Release artifacts signed.
- [ ] Known limitations included in release notes.
