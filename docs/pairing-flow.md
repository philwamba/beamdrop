# BeamDrop Pairing Flow

## Purpose

Pairing creates a trusted relationship between two BeamDrop devices. BeamDrop
pairs devices using QR code so trust is deliberate, visible, and resistant to
nearby device spoofing.

## Entry Points

- Home screen: Pair a new device.
- Nearby devices screen: Pair unknown device.
- Trusted devices screen: Add trusted device.
- Network diagnostics screen: Pair by QR fallback when discovery fails.

## Primary QR Pairing Flow

1. User opens BeamDrop on both devices.
2. On device A, user selects "Pair device".
3. Device A shows a short-lived QR code.
4. On device B, user selects "Scan QR".
5. Device B requests camera permission with a BeamDrop-specific explanation.
6. Device B scans the QR code.
7. Devices establish an authenticated pairing session.
8. Both devices show confirmation details:
   - Device name.
   - Platform.
   - Trust action.
   - Local or manual endpoint status.
9. User confirms pairing.
10. Both devices store trusted device records.

## QR Payload Requirements

The QR code should include:

- Pairing session ID.
- Device ID.
- Display name.
- Platform.
- Public key or pairing key material.
- Local endpoint hint if available.
- Protocol version.
- Expiration timestamp.

The QR code must not contain a reusable permanent secret.

## Approval Requirements

Pairing must never silently create trust. At least one visible confirmation is
required, and both apps should show the resulting trusted device when pairing
completes.

Unknown devices cannot send files without approval before pairing. A device that
has not completed pairing remains unknown even if it appears in nearby discovery.

## Manual IP and QR Fallback

Public and corporate Wi-Fi may block local discovery. BeamDrop must support
fallback pairing by:

- Scanning a QR code with endpoint hints.
- Entering a manual IP address or hostname.
- Showing diagnostics when discovery is unavailable.

Fallback pairing must use the same authentication and trust confirmation as
regular QR pairing.

## Pairing Error States

- QR expired: show a refresh action.
- Camera denied: show manual code or IP alternatives where possible.
- Device unreachable: offer network diagnostics.
- Protocol mismatch: explain that one app must be updated.
- Already trusted: show the trusted device record.
- Previously revoked: require deliberate re-pairing and warn the user.
- Wrong device: allow cancel before trust is saved.

## Revocation Flow

1. User opens Trusted Devices.
2. User selects a device.
3. User chooses Revoke Trust.
4. BeamDrop explains that future sends and resumes from that device will be
   blocked until it is paired again.
5. User confirms.
6. Device moves to revoked trust state locally.

Revocation must be available on Android, iPhone, macOS, and Windows.

## Pairing Acceptance Criteria

- QR pairing works without login.
- Pairing works on local network.
- Pairing can proceed with manual IP fallback when discovery fails.
- Trust cannot be created silently.
- Revoked devices cannot resume trusted status without re-pairing.
