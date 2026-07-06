# BeamDrop Manual Test Cases

Run these on real devices on the same local network and on at least one network where discovery is blocked.

## Pair Matrix

For each device pair below, test all cases in the next section.

1. Android to Windows
2. Windows to Android
3. Android to macOS
4. macOS to Android
5. iOS to Windows
6. Windows to iOS
7. iOS to macOS
8. macOS to iOS
9. Android to iOS
10. iOS to Android

## Required Cases Per Pair

| Case | Expected Result |
| --- | --- |
| Pair using QR | Both devices show trusted peer with matching fingerprint. |
| Reject unknown device | Receiver rejects before accepting content. |
| Revoke trusted device | Future transfers from revoked device are blocked. |
| Send text | Text arrives intact and history records success. |
| Send small file | File arrives with correct name, size, and SHA-256. |
| Send large file | File transfers in chunks, does not exhaust memory, verifies SHA-256. |
| Cancel transfer | Sender/receiver history records cancelled. |
| Simulate failed transfer | History records failed/incomplete. |
| Corrupt transfer | Receiver rejects as corrupted. |
| Discovery failure fallback | QR/manual endpoint pairing works when mDNS is blocked. |
| Permission denied | User sees actionable explanation and fallback. |

## Evidence Required

- Device models and OS versions.
- App build/version.
- Network type.
- Screenshots of pairing, transfer progress, history, and error states.
- Hash verification result.
- Any logs with secrets/content redacted.
