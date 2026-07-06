# BeamDrop App Store Submission Notes

## Purpose

BeamDrop must pass review on mobile and desktop app stores while accurately
describing local-first transfer, permissions, clipboard behavior, and optional
server features.

## Positioning

BeamDrop should be described as a native private device-transfer app. Store copy
must avoid implying that mobile clipboard sync runs silently in the background.
Store copy must also avoid implying that a cloud account is required for local
network transfer.

## iPhone Review Risks

### Clipboard Claims

Risk: Rejection or user mistrust if BeamDrop claims automatic background
clipboard monitoring.

Avoidance:

- State that clipboard sending is manual on iPhone.
- Use Share Sheet, Shortcuts, or Paste workflows.
- Do not read clipboard silently in the background.
- Do not present clipboard sync as always-on.

### Local Network Permission

Risk: Local network permission purpose is unclear.

Avoidance:

- Explain that local network access finds and transfers to nearby trusted
  devices without cloud upload.
- Provide matching purpose string and onboarding copy.

### Camera Permission

Risk: Camera permission appears unrelated.

Avoidance:

- Explain that camera is used to scan QR pairing codes.
- Do not request camera until the user starts Scan QR.

## Android Review Risks

### Background Clipboard Access

Risk: Android restricts background clipboard access and may flag invasive
clipboard behavior.

Avoidance:

- Make clipboard sending user-triggered where required.
- Use share intents, foreground app actions, or platform-approved entry points.
- Do not market hidden clipboard monitoring.

### Background Services

Risk: Long-running transfers may be treated as inappropriate background work.

Avoidance:

- Use user-visible foreground transfer behavior where required.
- Show progress notification for active transfers.
- Stop background work when transfer is canceled or complete.

## macOS Review Risks

### Clipboard Automation

Risk: Clipboard watching may appear invasive.

Avoidance:

- Make watched clipboard mode opt-in.
- Provide visible status and disable controls.
- Explain what is watched and when.

### Network Access

Risk: Network behavior is unclear.

Avoidance:

- Explain local device transfer and optional fallback behavior.
- Do not hide relay use if relay is implemented later.

## Windows Store Risks

### Firewall and Network Behavior

Risk: Users may not understand why BeamDrop listens on the local network.

Avoidance:

- Explain local transfer and trusted device pairing.
- Provide diagnostics and firewall guidance.

### Clipboard Behavior

Risk: Clipboard automation is perceived as privacy-invasive.

Avoidance:

- Make desktop clipboard features opt-in.
- Offer pause and disable controls.
- Avoid storing clipboard content unnecessarily.

## Permission Copy Requirements

Store metadata and in-app copy must align for:

- Camera: QR pairing.
- Local network: nearby trusted device transfer.
- Notifications: incoming transfer requests and completion.
- Files/photos: selected content send and receive.
- Clipboard: platform-specific manual or opt-in workflows.

## Claims to Avoid

Avoid these claims:

- "Automatic iPhone clipboard sync in the background."
- "Always-on mobile clipboard monitoring."
- "Send from anyone nearby without approval."
- "Cloud backup included" unless such a feature exists and is documented.
- "Works on every Wi-Fi network automatically" because public/corporate Wi-Fi
  may block discovery.

## Review Notes to Provide

Submission notes should explain:

- BeamDrop is native-only.
- Local transfer works without login.
- Optional relay is not required for MVP.
- QR pairing establishes trusted devices.
- Unknown devices require approval.
- iPhone clipboard sending is manual.
- Android clipboard sending is user-triggered where required.
- Public/corporate Wi-Fi may require manual IP or QR fallback.
