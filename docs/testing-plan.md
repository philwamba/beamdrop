# BeamDrop Testing Plan

## Testing Goals

BeamDrop testing must prove that local-first transfer works without login,
unknown devices cannot send without approval, large transfers are reliable, and
platform privacy restrictions are respected.

## Test Categories

### Release Command Matrix

Run these commands before tagging a release candidate:

| Area | Command | Current gate |
| --- | --- | --- |
| Android | `scripts/build-android.sh` | Required on a configured Android build host. |
| iPhone | `scripts/build-ios.sh` | Swift package gate; Xcode archive still required for App Store/TestFlight. |
| macOS | `scripts/build-macos.sh` | Swift package gate; notarized app packaging still required. |
| Windows | `pwsh scripts/build-windows.ps1` | Required on Windows runner with Windows App SDK support. |
| Rust core | `cd core/beamdrop-core && cargo test --workspace` | Required. |
| Protocol JSON | `find protocol/beamdrop-protocol -name '*.json' -print0 \| xargs -0 -n1 python3 -m json.tool > /dev/null` | Syntax gate; semantic JSON Schema validation still needs an offline validator. |
| Signaling server | `cd server/beamdrop-signaling && pnpm test && pnpm build` | Required for optional server scaffolding. |
| Relay server | `cd server/beamdrop-relay && pnpm test && pnpm build` | Required for optional server scaffolding. |

### Unit Tests

Required coverage:

- Protocol message parsing and validation.
- Transfer manifest validation.
- Chunk indexing.
- Hash calculation.
- Resume metadata validation.
- Trust state transitions.
- Revocation behavior.

### Integration Tests

Required coverage:

- QR pairing handshake.
- Trusted device connection.
- Unknown device receive approval.
- Manual IP fallback.
- File transfer manifest exchange.
- Chunked transfer.
- Hash verification.
- Resume after interruption.
- Revocation blocking resume.

Android-Windows MVP coverage:

- Android QR pairs on Windows.
- Windows QR pairs on Android.
- Android sends text to Windows.
- Windows sends text to Android.
- Android sends a small file to Windows.
- Windows sends a small file to Android.
- Android sends a file larger than 4 MB to Windows using chunks.
- Windows sends a file larger than 4 MB to Android using chunks.
- Transfer cancellation records `Cancelled`.
- Transfer failure records `Failed`.
- Final SHA-256 mismatch records `Corrupted`.
- Unknown devices are rejected.
- Revoked devices are rejected.

Current automated coverage verifies the shared QR JSON shape, shared transfer
envelope shape, 4 MB chunk metadata, final SHA-256 behavior, cancellation/failure
history states, unknown-peer rejection, and revoked-peer rejection in platform
core tests. Full device-to-device UI execution must still be verified with the
manual local-network checklist below on a Windows PC and Android device.

### Platform Tests

Android:

- Command: `gradle --no-daemon --max-workers=1 testDebugUnitTest`.
- Share intent send.
- User-triggered clipboard send.
- Foreground transfer behavior.
- Scoped storage.
- Permission denial and recovery.
- Release blocker if command cannot initialize Gradle or release assemble cannot
  be produced on the signing machine.

iPhone:

- Command: `swift test`.
- Share Sheet send.
- Shortcuts or Paste-based clipboard send.
- Local network permission.
- Camera QR pairing.
- App background interruption and resume.
- Release blocker if Xcode archive/TestFlight validation fails even when Swift
  package tests pass.

macOS:

- Command: `swift test` and `swift build`.
- File and folder send.
- Optional clipboard permission workflow.
- Firewall/network diagnostics.
- Reveal received file in Finder.
- Release blocker if signing, hardened runtime, notarization, or stapling fails.

Windows:

- Command: `dotnet run --project Tests/BeamDrop.Windows.Tests/BeamDrop.Windows.Tests.csproj` and `dotnet run --project Tests/Tests.csproj`.
- File and folder send.
- Optional clipboard permission workflow.
- Windows Firewall diagnostics.
- Reveal received file in Explorer.
- Release blocker if MSIX/installer signing or Windows App SDK packaging fails.

## Large File Requirements

Production tests must include:

- 100 MB file.
- 1 GB file.
- Multi-file folder transfer.
- Interruption at 10%, 50%, and 90%.
- Resume after app restart where platform allows.
- Hash mismatch simulation.
- Insufficient disk space behavior.

All large file transfers must be chunked. Transfer success must require file hash
verification.

## Network Environment Tests

Test BeamDrop on:

- Home Wi-Fi.
- Phone hotspot.
- Public Wi-Fi with client isolation.
- Corporate Wi-Fi with blocked multicast.
- Different subnets.
- Firewall enabled on macOS and Windows.

Manual IP and QR fallback must be tested when discovery fails.

Use [Android-Windows Local MVP Checklist](android-windows-local-mvp-checklist.md)
for manual local-network verification.

## Security Tests

Required scenarios:

- Unknown device attempts to send file.
- Revoked device attempts to send file.
- Revoked device attempts to resume old transfer.
- Device name spoofing.
- Expired QR pairing code.
- Tampered manifest.
- Tampered chunk.
- Hash verification failure.
- Replay of old pairing payload.

## UX Tests

Validate:

- Onboarding explains local-first transfer.
- Permission prompts are preceded by clear explanations.
- Receive approval dialog is understandable.
- Clipboard limitations are not misleading.
- Network diagnostics provide useful next steps.
- Empty, loading, error, and permission states are complete.

## Accessibility Tests

Required checks:

- Screen reader navigation.
- Dynamic type/text scaling.
- Keyboard navigation on desktop.
- Color contrast.
- Reduced motion.
- Focus order.
- Dialog announcement.
- Progress announcement without relying only on color.

## Store Compliance Tests

Before submission:

- Verify iPhone app does not silently monitor clipboard.
- Verify Android app does not rely on restricted background clipboard access.
- Verify permission purpose strings are accurate.
- Verify no hidden cloud upload is implied or performed for local transfer.
- Verify optional relay language is truthful if relay exists.

## Release Gates

A BeamDrop release cannot ship unless:

- QR pairing passes on all target platforms included in the release.
- Local transfer works without login.
- Unknown sender approval is enforced.
- Trusted device revocation works.
- Large files are chunked, resumable, and hash verified.
- Manual IP or QR fallback works when discovery is blocked.
- Clipboard workflows comply with platform limits.
