# BeamDrop End-to-End QA Plan

## Objective

Prove the local-first MVP works without cloud login, server dependency, or relay.

## Environments

- Home Wi-Fi with mDNS allowed.
- Public/guest Wi-Fi or router setting with client isolation enabled.
- VPN enabled and disabled.
- Windows firewall default and restrictive profiles.
- macOS firewall default and restrictive profiles.

## Test Data

- Text snippet under 1 KB.
- URL.
- Small file under 1 MB.
- Large file larger than 20 MB.
- File names containing spaces, unicode, long names, and blocked traversal strings.
- Corrupted payload fixture.

## Automation Candidates

- Protocol fixture tests across Android/iOS/macOS/Windows.
- Hash mismatch tests.
- Revoked/unknown peer tests.
- Chunk/resume planner tests.
- Clipboard policy tests.

## Manual-Only Until Harness Exists

- QR camera scanning.
- OS permission dialogs.
- Bonjour discovery on real networks.
- Mobile background/foreground receive behavior.
- Desktop tray/menu bar interactions.
- Store packaging/signing/notarization.
