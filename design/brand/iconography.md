# BeamDrop Iconography

## Icon Principles

BeamDrop icons should be simple, native, and functional. Icons identify actions,
content types, device types, and trust states. They should not become decorative
illustrations.

Use platform icon systems:

- Android: Material Symbols or Material Icons.
- iOS/macOS: SF Symbols.
- Windows: Segoe Fluent Icons / WinUI SymbolIcon where available.

## Style

- Outline or native default style.
- Consistent optical size within a platform.
- No custom cartoon icons.
- No complex multi-color icons inside tool surfaces.
- No manually drawn icons when a native system icon exists.

## Required Icon Concepts

Actions:

- Send.
- Receive.
- Pair.
- Scan QR.
- Manual IP.
- Retry.
- Resume.
- Pause.
- Cancel.
- Revoke.
- Open.
- Reveal in folder.

Content types:

- File.
- Folder.
- Text.
- Link.
- Screenshot.
- Clipboard.

Device types:

- Android phone.
- iPhone.
- Mac.
- Windows PC.
- Unknown device.

Trust and network:

- Trusted.
- Unknown.
- Revoked.
- Local route.
- Manual route.
- Future relay route.
- Verified.
- Failed verification.

## Icon and Text Pairing

Icon-only buttons are allowed only for familiar controls or compact toolbars, and
must include accessible labels and tooltips on desktop. Destructive actions must
include text in dialogs and menus.

## QR and Pairing Symbols

QR-related icons should be literal: QR code and camera/scan icons. Do not invent
abstract pairing symbols that obscure the task.

## Status Icons

Status icons must never rely on color alone:

- Complete: check icon plus "Verified" or "Complete".
- Failed: warning/error icon plus reason.
- Revoked: blocked icon plus "Revoked".
- Manual route: network/IP icon plus "Manual IP".
