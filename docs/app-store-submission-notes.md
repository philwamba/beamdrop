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

## Platform Submission Checklists

### Android

- Build command: `scripts/build-android.sh`.
- Test command: `gradle --no-daemon --max-workers=1 testDebugUnitTest`.
- Signing requirement: Play release track must use Play App Signing or a
  protected release keystore; debug builds are not submission artifacts.
- Permission review: confirm Nearby Wi-Fi Devices is used only for local device
  discovery/transfer, camera is requested only for QR scan, notifications are
  for transfer prompts/progress, and foreground service is limited to active
  transfer progress.
- Store policy risk: clipboard and foreground-service policy. Copy must state
  that clipboard sending is user-triggered; no background clipboard monitoring.
- Manual QA checklist: install release APK/AAB, first launch, permission denial
  recovery, QR pairing, send/receive text, send/receive small file, large
  transfer progress, cancellation, revoked peer rejection.
- Known limitations: release signing and Play Console review are pending.

### iPhone

- Build command: `scripts/build-ios.sh` for package checks; App Store archive
  must be built in Xcode after signing is configured.
- Test command: `swift test` in `apps/ios/`.
- Signing requirement: Apple Developer account, app and extension provisioning
  profiles, App Group entitlement, TestFlight validation, and App Store privacy
  nutrition labels.
- Permission review: local network and Bonjour copy, camera QR scan purpose,
  Share Extension payload handling, and no broad photo/file permissions outside
  user-selected content.
- Store policy risk: automatic clipboard claims. Submission metadata must say
  manual Paste, Share Sheet, and Shortcuts/App Intents where applicable.
- Manual QA checklist: TestFlight install, onboarding, QR scan, show QR,
  Share Extension for text/link/photo/file, manual Paste send, receive prompt,
  export/save received file, cancel transfer, reject unknown/revoked peer.
- Known limitations: archive/signing, App Group production identifiers, and
  end-to-end device transfer signoff remain pending.

### macOS

- Build command: `scripts/build-macos.sh`.
- Test command: `swift test` in `apps/macos/`.
- Signing requirement: Developer ID signing, hardened runtime, notarization,
  stapling, and Mac App Store sandbox review if applicable.
- Permission review: local network listener/discovery explanation, file access
  through picker/save flows, notifications, and clipboard opt-in status.
- Store policy risk: clipboard watching and local network listener disclosure.
- Manual QA checklist: install notarized build, pair, send/receive text and
  files, reveal received file, firewall diagnostics, cancellation, revoked peer
  rejection.
- Known limitations: notarized distributable and final sandbox entitlements are
  not yet proven.

### Windows

- Build command: `scripts/build-windows.ps1`.
- Test command: `dotnet run --project apps/windows/Tests/BeamDrop.Windows.Tests/BeamDrop.Windows.Tests.csproj`.
- Signing requirement: signed Windows package or installer, trusted publisher
  certificate, Windows App SDK packaging, and production platform secure storage.
- Permission review: firewall/local network diagnostics, notifications/tray
  behavior, file picker/save behavior, and clipboard opt-in/pause controls.
- Store policy risk: clipboard automation and local listener behavior must be
  disclosed; no content logging.
- Manual QA checklist: install on clean Windows 11 machine, tray menu, QR
  pairing, text/file transfer in both directions with Android/iPhone/macOS,
  cancellation, corrupted hash history entry, revoked peer rejection.
- Known limitations: MSIX packaging and Microsoft Store submission package are
  pending.
