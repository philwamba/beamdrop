# BeamDrop UI and UX Requirements

## Purpose

This document is the implementation-facing UI contract for BeamDrop. The detailed
design system lives in `design/brand/` and `design/screens/`; app teams must use
those documents when building native Android, iPhone, macOS, and Windows UI.

BeamDrop should feel fast, premium, minimal, native, private, and professional.
It must not feel childish, generic, dashboard-like, or web-app-like.

## Native-Only UI Requirement

BeamDrop must be implemented with native platform UI:

- Android: Kotlin, Jetpack Compose, Material 3.
- iPhone: Swift, SwiftUI, iOS sheets, navigation, Share Sheet, and Shortcuts
  where appropriate.
- macOS: Swift, SwiftUI, AppKit where needed, menu bar utility patterns, Finder
  integration where practical.
- Windows: C#, WinUI 3, Windows App SDK, native dialogs, notifications, and
  Explorer integration where practical.

Do not use Electron, Tauri, Flutter, React Native, Ionic, Cordova, browser UI
wrappers, or a web dashboard architecture.

## Design Source Files

Brand:

- `design/brand/brand-guidelines.md`
- `design/brand/color-system.md`
- `design/brand/typography.md`
- `design/brand/iconography.md`

Screens and flows:

- `design/screens/mobile-screens.md`
- `design/screens/desktop-screens.md`
- `design/screens/states-and-dialogs.md`
- `design/screens/onboarding-flow.md`
- `design/screens/transfer-flow-ui.md`
- `design/screens/settings-and-privacy.md`

## Product UX Principles

- Local-first: local transfer works without login.
- Private: unknown devices cannot send files without approval.
- Trustworthy: devices pair with QR code and can be revoked.
- Reliable: large transfers are chunked, resumable, and hash verified.
- Platform-honest: iPhone and Android clipboard restrictions are represented
  accurately.
- Native: each platform follows its own navigation, dialog, permission, and file
  picker conventions.

## Navigation Requirements

Mobile primary destinations:

- Home.
- Devices.
- History.
- Settings.

Mobile secondary screens:

- Onboarding.
- Nearby Devices.
- Pair New Device.
- Scan QR Code.
- Device Detail.
- Send Text.
- Send File.
- Receive Prompt.
- Transfer Progress.
- Trusted Devices.
- Privacy.
- Network Diagnostics.

Desktop primary surfaces:

- Tray/Menu Bar quick menu.
- Main window.
- Drag-and-drop send area.
- Nearby devices.
- Transfer history.
- Pairing window.
- Settings.
- Trusted devices.
- Clipboard policy.
- Network diagnostics.

## Component Requirements

### Buttons

- Primary buttons are reserved for send, pair, accept, and resume.
- Secondary buttons are used for scan QR, manual IP, diagnostics, and change
  destination.
- Destructive buttons are used for reject, revoke, cancel, and clear history.
- Icon-only buttons require accessible labels and desktop tooltips.

### Device Cards

Device cards or rows must show:

- Device name.
- Platform icon.
- Trust state.
- Last seen or nearby status.
- Primary action when trusted.
- Pair or ignore action when unknown.

Unknown devices must not look equivalent to trusted send targets.

### Transfer Cards

Transfer cards or rows must show:

- Direction.
- Content type.
- Other device.
- Size.
- Status.
- Verification result where relevant.
- Resume/retry/open/reveal actions where available.

### Empty States

Required empty states:

- No trusted devices.
- No nearby devices.
- No transfer history.
- No receive destination.
- Clipboard unavailable on this platform.

Each empty state must include a concrete next action.

### Error States

Required error states:

- Discovery blocked.
- Pairing expired.
- Pairing failed.
- Transfer interrupted.
- Resume unavailable.
- Hash verification failed.
- Permission denied.
- Insufficient storage.
- Device trust revoked.

Each error must explain what happened and offer a next step.

### Permission Explanations

Before OS prompts, BeamDrop must explain:

- Camera: scan QR codes for trusted pairing.
- Local network: transfer to nearby trusted devices without cloud upload.
- Notifications: show incoming transfer requests and transfer completion.
- Files/photos: send selected content and save received content.
- Clipboard: manual or opt-in behavior depending on platform.

## Required Dialogs

### Receive-File Approval

Required for unknown senders. It must show:

- Sender name and platform.
- Trust state.
- Transfer type.
- Item count.
- Total size.
- Destination.
- Accept and reject actions.

For unknown devices, state that accepting does not trust the device.

### Revoke Trusted Device

Must explain that future trusted sends and large-transfer resume from that device
will be blocked until QR pairing happens again.

### Cancel Transfer

Must explain whether partial data will be removed or can be resumed.

## Pairing UI

The pairing UI must include:

- Pairing QR screen.
- Scan QR screen.
- Expiration and refresh.
- Manual IP fallback.
- Device confirmation.
- Previously revoked warning.
- Camera permission explanation.

Pairing must not create trust silently.

## Transfer UI

Transfer progress must include:

- Sending or receiving state.
- Other device name and platform.
- Route: Local, Manual IP, or future Relay.
- Current item.
- Overall progress.
- Bytes transferred and total size.
- Speed where stable.
- Pause, cancel, retry, or resume where supported.
- Hash verification state.

Transfer complete UI must show verified completion and open/reveal actions.
Transfer failed UI must show a specific reason and recovery action.

## Network Diagnostics UI

Network Diagnostics must show:

- Local network permission status.
- Current network where available.
- Local IP addresses where permitted.
- Discovery status.
- Reachability test.
- Firewall or client-isolation guidance.
- Manual IP and QR fallback.

It must explicitly explain that public or corporate Wi-Fi may block local
discovery.

## Clipboard UI Requirements

iPhone:

- No silent background clipboard monitoring.
- Use Share Sheet, Shortcuts, or Paste.
- UI copy must not imply always-on sync.

Android:

- Clipboard sending must be user-triggered where required by OS restrictions.
- UI copy must not imply unrestricted background access.

macOS and Windows:

- Stronger clipboard workflows may exist with explicit user permission.
- Watched clipboard mode must be opt-in, visible, pausable, and easy to disable.

## Accessibility Requirements

All BeamDrop UI must support:

- WCAG AA contrast.
- Screen reader labels.
- Dynamic text or platform text scaling.
- Keyboard navigation on desktop.
- Visible focus states.
- Reduced motion.
- Non-color-only status indicators.
- Accessible dialogs and sheets.
- Progress announcements for long transfers.
- Touch targets or pointer targets that meet platform guidance.

## Implementation Checklist

- Use native UI frameworks only.
- Follow `design/brand/` for personality, color, typography, and icons.
- Follow `design/screens/` for mobile, desktop, dialogs, onboarding, transfer,
  settings, and privacy flows.
- Do not build a web dashboard or shared browser-like shell.
- Android feels like Material 3 Compose.
- iPhone feels like SwiftUI and native iOS.
- macOS feels like a polished menu bar utility with a native main window.
- Windows feels like WinUI 3.
- Local transfer works without login in the UI flow.
- Optional relay is never presented as required for MVP.
- QR pairing is the primary trust flow.
- Unknown senders require receive approval.
- Trusted devices can be revoked.
- Large transfer UI shows chunked/resumable/verified behavior without exposing
  unnecessary protocol detail.
- iPhone clipboard copy is manual-only.
- Android clipboard copy is user-triggered where required.
- Desktop clipboard automation is opt-in and visible.
- Public/corporate Wi-Fi discovery failure has manual IP and QR fallback.
- Permission prompts have clear pre-permission explanations.
- Empty, loading, error, permission, success, and failure states are implemented.
- Accessibility is tested before release.
