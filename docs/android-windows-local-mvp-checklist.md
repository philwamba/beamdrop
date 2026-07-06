# Android-Windows Local MVP Checklist

Use this checklist to verify BeamDrop Android and Windows on the same local
network. Do not use hardcoded IP addresses; use QR pairing endpoint hints,
discovery, or manual connection fallback.

## Prerequisites

- Android device and Windows PC are on the same reachable local network.
- Windows Defender Firewall allows BeamDrop on private networks.
- Android local network/Wi-Fi permissions are granted where prompted.
- Public/corporate Wi-Fi client isolation is disabled, or manual connection is
  used on a reachable subnet.
- Both apps use protocol version `1.0`.
- Both apps use transfer port `49320` unless explicitly changed for testing.

## Pairing

1. Android shows pairing QR.
2. Windows imports or scans the Android QR payload.
3. Windows confirms Android device name and fingerprint.
4. Windows approves pairing.
5. Windows shows pairing QR.
6. Android scans or pastes the Windows QR payload.
7. Android confirms Windows device name and fingerprint.
8. Android approves pairing.
9. Both devices appear as trusted.

## Transfer

1. Android sends text to Windows.
2. Windows sends text to Android.
3. Android sends a small file to Windows.
4. Windows sends a small file to Android.
5. Android sends a file larger than 4 MB to Windows.
6. Windows sends a file larger than 4 MB to Android.
7. Each file transfer shows progress and completes only after SHA-256 verification.

## Cancellation and Failure

1. Start a large transfer.
2. Cancel it.
3. Verify history records `Cancelled`.
4. Disconnect one device during transfer.
5. Verify history records `Failed`.
6. Corrupt a debug payload.
7. Verify history records `Corrupted` and the receiver does not commit the file.

## Security

1. Attempt transfer from an unpaired device and verify rejection.
2. Revoke a trusted device and verify future transfers are rejected.
3. Verify auto-accept applies only to trusted peers with that setting enabled.

## Diagnostics

- If discovery fails, use manual connection with the IP/host shown in QR or
  diagnostics.
- If Windows cannot receive, check Windows Defender Firewall private-network
  rules.
- If Android cannot receive, verify both devices are reachable on Wi-Fi and not
  blocked by client isolation.
