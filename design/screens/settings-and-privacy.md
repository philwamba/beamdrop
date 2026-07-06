# BeamDrop Settings and Privacy

## Settings Structure

Settings must be native to each platform and grouped by user intent.

Groups:

- Device.
- Transfers.
- Clipboard.
- Network.
- Notifications.
- Privacy.
- About.

## Device Settings

Fields:

- Device name.
- Platform display.
- Device ID short display for diagnostics.
- Pair new device.

Device name changes should update local display and future pairing payloads.

## Transfer Settings

Fields:

- Default receive location.
- Ask every time before saving.
- Resume storage limit.
- Clear partial transfers.
- Auto-accept from trusted devices where supported.

Auto-accept must be conservative by default and must never apply to unknown
devices.

## Clipboard Settings

iPhone:

- Explain manual clipboard send only.
- Link to Share Sheet and Shortcuts instructions when implemented.

Android:

- Explain user-triggered clipboard send.
- Configure supported quick actions where platform permits.

macOS/Windows:

- Enable clipboard send.
- Enable watched clipboard mode if implemented.
- Pause watching.
- Clear clipboard history.
- Show visible status.

## Network Settings

Fields:

- Local network permission status.
- Discovery enabled.
- Manual IP.
- Preferred network interface where desktop supports it.
- Relay setting if future relay exists.

Relay must be labeled optional and not required for MVP local transfer.

## Notification Settings

Controls:

- Incoming transfer requests.
- Transfer complete.
- Transfer failed.
- Pairing requests.

Notifications must never reveal sensitive clipboard or text content by default.

## Privacy Screen

Required content:

- Local transfer works without login.
- Local transfer does not require cloud upload.
- Trusted device records are stored locally.
- Unknown devices require approval.
- Trusted devices can be revoked.
- Clipboard behavior follows platform restrictions.
- Transfer history can be cleared.

Actions:

- Clear transfer history.
- Revoke all trusted devices.
- Disable clipboard features.
- View privacy policy.

## Trusted Device Management

Device detail shows:

- Device name.
- Platform.
- Trust state.
- Last seen.
- Last transfer.
- Public key fingerprint short form.
- Revoke trust.
- Re-pair.

Revoke dialog must explain that future sends and resume from that device are
blocked until QR pairing happens again.

## Privacy-Safe Defaults

- Unknown senders require approval.
- Desktop clipboard watching is off by default.
- Mobile clipboard sending is manual/user-triggered.
- Transfer history avoids sensitive content previews.
- Optional relay is off or clearly explained if introduced.
