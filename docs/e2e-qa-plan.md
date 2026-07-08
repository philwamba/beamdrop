# BeamDrop End-to-End QA Plan

## Objective

Validate BeamDrop local-network pairing and transfer behavior across Android,
Windows, macOS, and iPhone without relying on the optional relay/signaling
server. This plan is release-blocking for any public build.

## Execution Status

Current status: **Not complete**.

This repository environment can run protocol/unit checks and provide a local
network diagnostic helper, but it cannot attach real Android/iPhone devices,
camera QR flows, Windows desktop UI, macOS packaged apps, OS permission dialogs,
or cross-device Wi-Fi environments. Those flows are documented as manual E2E
requirements and remain unsigned until real-device evidence is attached.

## Device Pair Matrix

Run every core flow below for each directional pair.

| Pair ID | Direction | Status | Required evidence |
| --- | --- | --- | --- |
| E2E-P01 | Android to Windows | Not run | QR screenshots, transfer history, SHA-256 result, network notes. |
| E2E-P02 | Windows to Android | Not run | QR screenshots, transfer history, SHA-256 result, network notes. |
| E2E-P03 | Android to macOS | Not run | QR screenshots, transfer history, SHA-256 result, network notes. |
| E2E-P04 | macOS to Android | Not run | QR screenshots, transfer history, SHA-256 result, network notes. |
| E2E-P05 | iPhone to Windows | Not run | QR screenshots, Share Sheet/manual Paste evidence, transfer history. |
| E2E-P06 | Windows to iPhone | Not run | QR screenshots, receive prompt, save/export result, transfer history. |
| E2E-P07 | iPhone to macOS | Not run | QR screenshots, Share Sheet/manual Paste evidence, transfer history. |
| E2E-P08 | macOS to iPhone | Not run | QR screenshots, receive prompt, save/export result, transfer history. |
| E2E-P09 | Android to iPhone | Not run | QR screenshots, receive prompt, save/export result, transfer history. |
| E2E-P10 | iPhone to Android | Not run | QR screenshots, transfer history, SHA-256 result, network notes. |

## Core Flow Matrix

Run each flow for every pair in the device pair matrix unless explicitly marked
platform-specific.

| Flow ID | Flow | Expected result | Current automation |
| --- | --- | --- | --- |
| E2E-F01 | Pair devices with QR code | Both devices show trusted peer, platform, fingerprint, and trusted state. | Unit coverage only; real camera/manual QR not automated. |
| E2E-F02 | Reject unknown device | Receiver rejects before content is accepted; history/audit does not mark complete. | Unit coverage for unknown peer rejection. |
| E2E-F03 | Revoke trusted device | Revoked peer cannot transfer or resume until deliberate re-pair. | Unit coverage for revoked peer rejection. |
| E2E-F04 | Send text | Exact text arrives; history records completed after hash verification. | Core/unit coverage only. |
| E2E-F05 | Send URL | URL arrives as URL/link payload; history records completed. | Manual E2E pending. |
| E2E-F06 | Send small file | File name is safe, size matches, SHA-256 matches. | Core/unit hash coverage only. |
| E2E-F07 | Send large file | Payload is chunked, progress updates, final SHA-256 matches. | Chunk planner/unit coverage only. |
| E2E-F08 | Cancel transfer | Sender and receiver show cancelled state; partial files are discarded. | Core/unit coverage partial. |
| E2E-F09 | Resume transfer | Missing chunks are resumed safely; revoked peers cannot resume. | Resume planner coverage only; full E2E pending. |
| E2E-F10 | Reject transfer | Receiver rejection records rejected, not failed/completed. | Core/unit coverage partial. |
| E2E-F11 | Accept transfer | Receiver approval allows trusted transfer and records completed after hash. | Manual E2E pending. |
| E2E-F12 | Verify transfer history | Completed transfer metadata is correct; content is not logged. | Unit coverage partial. |
| E2E-F13 | Verify failed transfer history | Failed/incomplete/corrupted entries are visible with clear error. | Unit coverage partial. |
| E2E-F14 | Verify file hash | Final SHA-256 verification gates completion. | Unit coverage. |
| E2E-F15 | Verify corrupted transfer fails | Tampered/corrupted payload records corrupted and discards staging file. | Unit coverage. |
| E2E-F16 | Verify local network permission error | User sees actionable local network permission explanation and fallback. | Manual OS permission flow. |
| E2E-F17 | Verify discovery failure fallback | Manual QR/endpoint fallback works when mDNS is blocked. | `scripts/run-local-network-test.sh` can diagnose; full E2E pending. |
| E2E-F18 | Android clipboard send is manual | Clipboard send requires user action and blocks sensitive-looking content. | Unit coverage for policy; manual Android UX pending. |
| E2E-F19 | iPhone clipboard send is manual | Clipboard uses Paste/Share Sheet/Shortcuts; no silent background monitoring. | Manual iOS UX pending. |
| E2E-F20 | Desktop clipboard sharing can be paused | Windows/macOS clipboard sharing is opt-in, pausable, and does not log content. | Windows unit coverage; macOS manual pending. |

## Test Environments

- Home Wi-Fi with multicast/mDNS enabled.
- Phone hotspot.
- Guest/public Wi-Fi with client isolation.
- Corporate-style Wi-Fi with multicast blocked.
- Windows firewall default and restrictive profiles.
- macOS firewall default and restrictive profiles.
- VPN enabled and disabled.

## Test Data

- Text: `BeamDrop E2E text payload`.
- URL: `https://beamdrop.local/e2e`.
- Small file: 512 KB random binary.
- Large file: at least 128 MB random binary.
- Corrupted file: copy of small file with one byte changed after manifest hash.
- Unsafe names: `../blocked.txt`, `..\\blocked.txt`, `folder/name.txt`,
  `folder\\name.txt`, empty name, and control-character name.

## Execution Rules

- Do not mark a flow passed without real sender/receiver evidence.
- Do not use mock discovery as production evidence.
- Do not disable trust, revocation, hash verification, or permission prompts to
  make a flow pass.
- Record app version, commit SHA, OS versions, device model, network type, and
  screenshots/log excerpts with content redacted.
- Logs must not include clipboard content, file contents, private keys, relay
  tokens, or full local file paths unless required for a bug and redacted.
