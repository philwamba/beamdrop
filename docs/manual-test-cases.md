# BeamDrop Manual Test Cases

Use these cases for every pair in `docs/e2e-qa-plan.md`. Record evidence in the
QA run folder before updating `docs/qa-signoff.md`.

## Setup

- Install the same BeamDrop build/version on both devices.
- Put both devices on the same local network.
- Disable optional relay/signaling services for MVP local transfer validation.
- Prepare the test data listed in `docs/e2e-qa-plan.md`.
- Run `scripts/run-local-network-test.sh --service` from a desktop on the test
  network to capture discovery diagnostics where practical.

## Pairing And Trust

| Case ID | Steps | Expected result |
| --- | --- | --- |
| QA-PAIR-001 | Sender opens Pair New Device; receiver scans QR; receiver approves. | Both devices store trusted peer with device name, platform, fingerprint, endpoint, and trusted status. |
| QA-PAIR-002 | Attempt transfer from an unpaired device. | Receiver rejects unknown peer before accepting bytes; no completed history entry. |
| QA-PAIR-003 | Revoke a trusted peer, then attempt text and file transfer. | Transfer is rejected as revoked on both text and file paths. |
| QA-PAIR-004 | Scan expired, malformed, wrong-service, and missing-public-key QR payloads. | App shows clear invalid/expired/protocol/service error and stores no trust record. |

## Transfers

| Case ID | Steps | Expected result |
| --- | --- | --- |
| QA-TX-001 | Send text payload. | Text arrives exactly; sender and receiver history show completed. |
| QA-TX-002 | Send URL payload. | URL arrives as a link/URL item; history shows completed. |
| QA-TX-003 | Send 512 KB file. | File saves in expected destination; name is safe; SHA-256 matches source. |
| QA-TX-004 | Send 128 MB file. | Transfer uses chunked progress, does not load entire file into memory, and final SHA-256 matches. |
| QA-TX-005 | Cancel a large transfer at 25-50%. | Sender and receiver show cancelled; partial/staging file is removed or hidden. |
| QA-TX-006 | Interrupt and resume a large transfer where resume is implemented. | Missing chunks resume; final file hash matches; history records completed. If resume is not implemented on that pair, record as known issue. |
| QA-TX-007 | Receiver rejects incoming transfer. | Sender/receiver show rejected, not failed or completed. |
| QA-TX-008 | Corrupt payload after manifest hash is generated. | Receiver records corrupted/hash failure and does not expose file as completed. |
| QA-TX-009 | Send unsafe filenames. | Sender or receiver rejects path traversal and does not write outside save directory. |

## History And Diagnostics

| Case ID | Steps | Expected result |
| --- | --- | --- |
| QA-HIST-001 | Complete text, URL, small file, and large file flows. | History shows direction, peer, status, size, type, timestamps, and no content leak. |
| QA-HIST-002 | Run rejected, cancelled, failed, and corrupted flows. | History records correct terminal status and clear error message. |
| QA-NET-001 | Deny local network or nearby-device permission. | App shows local network permission error and recovery guidance. |
| QA-NET-002 | Test on network with mDNS/client isolation blocked. | Discovery failure is clear; QR/manual endpoint fallback is offered and works where possible. |
| QA-NET-003 | Run `scripts/run-local-network-test.sh --host HOST --port 49320`. | Script reports reachability result for the peer endpoint and available discovery tools. |

## Clipboard

| Case ID | Platforms | Steps | Expected result |
| --- | --- | --- | --- |
| QA-CLIP-001 | Android | Copy ordinary text, tap BeamDrop clipboard action. | Send is user-triggered; text transfers only after explicit action. |
| QA-CLIP-002 | Android | Copy password/token-like text, tap BeamDrop clipboard action. | Sensitive-looking content is blocked with a clear message; content is not logged. |
| QA-CLIP-003 | iPhone | Use manual Paste or Share Sheet for text. | No silent background clipboard monitoring; transfer only follows user action. |
| QA-CLIP-004 | Windows/macOS | Enable clipboard sharing, send once, pause, attempt send. | Clipboard sharing is opt-in, pause blocks send, content is not logged. |

## Evidence Template

For each case capture:

- Pair ID and case ID.
- Build version and commit SHA.
- Sender device model/OS and receiver device model/OS.
- Network type and firewall/VPN state.
- Expected result and actual result.
- Screenshots of pairing, prompt, progress, history, and error state.
- SHA-256 source and destination values for file transfers.
- Redacted logs only.
