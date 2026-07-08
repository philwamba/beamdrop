# BeamDrop Android UX Plan

Status: active Android UX direction for the MVP.

## Research Basis

This plan follows current Android guidance in these areas:

- Runtime permissions should be requested in context, with clear value and graceful fallback when denied.
- Navigation should separate top-level destinations from task/detail flows so system Back is predictable.
- Dialogs should interrupt only for decisions that need immediate user action, such as trust approval, destructive changes, and receive/cancel decisions.
- Accessibility requires clear labels, sufficient touch targets, readable text, and workflows that do not depend on technical language.

Reference docs:

- Android runtime permissions: https://developer.android.com/training/permissions/requesting
- Android navigation and back stack: https://developer.android.com/guide/navigation
- Compose dialog component guidance: https://developer.android.com/develop/ui/compose/components/dialog
- Android accessibility foundations: https://developer.android.com/design/ui/mobile/guides/foundations/accessibility

## Product Language

BeamDrop should explain itself as "send to your devices" rather than as protocols, ports, keys, or local discovery. Technical details can appear in diagnostics and advanced trust details, but primary actions should be plain:

- Pair a device
- Scan QR
- Send text
- Send file
- View transfer history
- Manage trusted devices

Errors should say what happened and what to do next. Examples:

- "Camera permission is needed to scan. You can paste the pairing code instead."
- "This QR is not a BeamDrop pairing code."
- "This device was revoked. Pair it again before sending."
- "No nearby devices found. Use QR pairing if discovery is blocked."

## App Structure

Top-level destinations:

- Home
- Trusted Devices
- Transfer History
- Settings

These destinations use bottom navigation and do not show an app-bar Back button. Android system Back returns to Home from any top-level destination except Home.

Task/detail destinations:

- Onboarding
- Pair New Device
- Scan QR Code
- Device Detail
- Permission Help
- Send Text
- Send File
- Privacy
- Network Diagnostics
- About

These screens show a visible Back or Close action and return to the screen that makes sense for the task.

Implementation structure:

- Keep one `MainActivity` as the Android lifecycle and dependency setup entry point.
- Put route state and back behavior in `navigation/BeamDropApp.kt`.
- Put route names in `navigation/BeamDropDestination.kt`.
- Put screens in product-area packages under `ui/`: `home`, `onboarding`, `pairing`, `devices`, `transfer`, `settings`, and `nearby`.
- Put shared visual primitives in `ui/components`.
- Put formatting and local UI helpers in `ui/util`.
- Do not add one Activity per screen unless Android platform integration requires a distinct task, exported component, or external entry point.

## Onboarding Flow

Purpose: explain BeamDrop in one screen without a generic marketing dashboard.

Recommended layout:

- App logo and "BeamDrop"
- Three short benefits:
  - Send on your local network
  - Pair with QR approval
  - Revoke devices any time
- Primary action: Continue
- Secondary text: no account required for local transfer

Back behavior:

- First app launch: system Back can exit.
- After onboarding is complete: do not show onboarding again unless reset from settings.

## Home

Purpose: show that the phone is ready and expose the most common actions.

Layout:

- Top app bar with Settings icon.
- Status card: "Ready to send" plus trusted-device count.
- Action grid:
  - Send text
  - Send file
  - Paste clipboard text
  - Activity
  - Show my QR
  - Scan QR
  - Nearby
  - Settings
- Trusted devices preview with a clear empty state.
- Help actions:
  - Permissions and connection help
  - How it works
  - About

Back behavior:

- System Back exits/minimizes according to Android default activity behavior.

## Pair New Device

Purpose: let this phone be scanned.

Layout:

- Title: "Show this QR to your other device"
- QR code
- Local device name
- Fingerprint
- Endpoint/status chip
- Plain copy: "The other device will still ask before trusting this phone."
- Secondary action: Scan another BeamDrop QR

Back behavior:

- Back returns to Home or the previous task source.

## Scan QR Code

Purpose: scan another BeamDrop device and approve trust.

Layout:

- Camera permission explanation card.
- Camera preview when permission is granted.
- Manual paste fallback.
- Inline state message for ready/error/trusted.
- Error state includes "Scan again".

Dialog:

- Pairing approval dialog must show device name, platform, fingerprint, service name, and trust status.
- Approval is required. Do not auto-trust.

Back behavior:

- Close returns to the previous screen and refreshes trusted devices.

## Trusted Devices

Purpose: manage devices that can send or receive.

Layout:

- Device cards with name, platform, fingerprint, trust status.
- Empty state with Scan QR and Show my QR.
- Device detail action.
- Revoke trust action.

Dialog:

- Revoke trust must be confirmed.

Back behavior:

- Top-level bottom-nav screen. System Back returns to Home.

## Device Detail

Purpose: inspect trust before acting.

Layout:

- Device name
- Platform
- Device ID
- Fingerprint
- Trust status
- Last seen or paired timestamp when available
- Revoke action for trusted devices

Dialog:

- Revoke trust must be confirmed.

Back behavior:

- Back returns to Trusted Devices.

## Send Text

Purpose: send short text or URL manually.

Layout:

- Recipient picker
- Text input
- Send as text
- Send URL when URL-like content is present
- Inline validation if no trusted recipient exists

Back behavior:

- Back returns to Home.

## Send File

Purpose: choose a local file and send it to a trusted device.

Layout:

- Recipient picker
- File picker button
- Selected file summary
- Send selected file
- Progress moves to History after send starts/completes

Back behavior:

- Back returns to Home.

## Transfer History

Purpose: show current and previous transfer outcomes.

Layout:

- Active progress card if a transfer is running.
- History list with sent, received, failed, rejected, cancelled, corrupted, and verified statuses.
- Empty state: "No transfers yet."

Dialog:

- Active transfer cancellation must be confirmed.

Back behavior:

- Top-level bottom-nav screen. System Back returns to Home.

## Settings

Purpose: organize policy, permissions, diagnostics, and app information.

Layout:

- Transfer defaults summary
- Privacy
- Permissions
- Network diagnostics
- About

Back behavior:

- Top-level bottom-nav screen. System Back returns to Home.

## Privacy

Purpose: explain security behavior in plain language.

Content:

- Local-first transfers
- Manual clipboard send on Android
- Unknown devices rejected
- Revoked devices blocked

Back behavior:

- Back returns to Settings.

## Permission Help

Purpose: explain required permissions before Android prompts or when troubleshooting.

Content:

- Internet/network state
- Nearby Wi-Fi devices when Android requires it
- Camera for QR scanning
- Notification permission on Android 13+
- Foreground service only for active transfer progress if later needed

Back behavior:

- Back returns to Home or Settings depending on entry point.

## Network Diagnostics

Purpose: help when discovery fails.

Content:

- Local address
- BeamDrop service name: `_beamdrop._tcp`
- Common blockers: guest Wi-Fi, VPN, public networks, corporate isolation
- Manual QR fallback

Back behavior:

- Back returns to Settings.

## About

Purpose: show version and native stack without distracting from product use.

Content:

- Logo
- Version
- Release status
- Native Android stack note

Back behavior:

- Back returns to Settings.
