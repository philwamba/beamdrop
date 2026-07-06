# BeamDrop Desktop Screens

## Scope

This document specifies BeamDrop desktop UI for macOS and Windows. BeamDrop
desktop should feel like a polished native utility, not a web dashboard.

- macOS: SwiftUI/AppKit, menu bar utility behavior, native sheets, sidebars,
  Finder integration where practical.
- Windows: WinUI 3, Windows App SDK, native navigation, dialogs, notifications,
  and Explorer integration where practical.

## Desktop App Model

Desktop BeamDrop has two surfaces:

- Quick surface: menu bar/tray for fast send, receive status, and clipboard
  controls.
- Main window: full transfer, pairing, history, trusted device, settings, and
  diagnostics management.

## Tray/Menu Bar Quick Menu

Content:

- BeamDrop status: ready, transferring, local network issue, signed out not
  applicable.
- Quick send file.
- Quick send clipboard if enabled and permitted.
- Nearby trusted devices.
- Recent incoming request if pending.
- Open BeamDrop.
- Pause clipboard watching where desktop feature exists.
- Quit.

macOS should use a menu bar extra. Windows should use system tray behavior with
native context menu and notification entry.

## Main Window

Layout:

- Native sidebar navigation.
- Content area with current destination.
- No nested dashboard cards.
- Device and transfer rows use clean list/card hybrids.

Primary sections:

- Home.
- Nearby devices.
- Transfers.
- Trusted devices.
- Settings.
- Privacy.
- Network diagnostics.

## Drag-and-Drop Send Area

Purpose:

- Let users drop files or folders to prepare a transfer.

Design:

- Subtle outlined region.
- Native drag hover state.
- Clear target text: "Drop files to send".
- Device picker nearby.
- No oversized web upload cloud graphic.

Behavior:

- Validate files after drop.
- Preserve folder structure where platform APIs allow.
- Show transfer manifest preview before send.

## Nearby Devices

Content:

- Trusted nearby devices.
- Unknown nearby devices.
- Manual IP connection.
- Discovery status.
- Diagnostics action.

Desktop affordances:

- Context menus for trusted device actions.
- Keyboard navigation through device list.
- Toolbar action for Pair.

## Transfer History

Content:

- Table or native list, depending on platform.
- Columns or row metadata: direction, item, device, size, status, time.
- Filters for sent, received, failed, resumable.
- Actions: open, reveal, retry, resume, clear.

macOS uses Finder reveal. Windows uses Explorer reveal.

## Pairing Window

Content:

- Show QR code.
- Scan QR if camera is available.
- Manual IP fallback.
- Device confirmation sheet.
- Pairing expiration.

Desktop pairing can appear as a dedicated window or sheet from the main window.
It should remain compact and focused.

## Settings

Settings groups:

- Device identity.
- Receive location.
- Notifications.
- Transfers and resume storage.
- Clipboard policy.
- Network.
- Privacy.
- About.

Use native settings patterns:

- macOS Settings scene or polished preferences window.
- Windows WinUI settings page with grouped rows.

## Trusted Devices

Content:

- Device name.
- Platform.
- Trust state.
- Last seen.
- Last transfer.
- Revoke.
- Re-pair.

Revoke must use a confirmation dialog. Revoked devices cannot resume large
transfers without re-pairing.

## Clipboard Policy

Desktop can support stronger clipboard workflows with user permission.

Required controls:

- Clipboard send disabled/enabled.
- Watched clipboard mode opt-in if implemented.
- Pause watching.
- Clear clipboard transfer history.
- Explain that mobile platforms are more restricted.

Required status:

- Active.
- Paused.
- Disabled.
- Permission needed.

## Network Diagnostics

Content:

- Local IP addresses where permitted.
- Network interface.
- Discovery status.
- Listening port status.
- Firewall guidance.
- Manual IP test.
- QR fallback.
- Public/corporate Wi-Fi warning.

Desktop diagnostics should be more detailed than mobile because desktop users can
often change firewall and network settings.

## Desktop Accessibility

- Full keyboard navigation.
- Visible focus rings.
- Screen reader labels for device, status, and progress.
- Native menu roles.
- No color-only status.
- Reduced motion.
- Text scaling where supported.
