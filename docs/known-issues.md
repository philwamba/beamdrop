# BeamDrop Known Issues

## Current Status

BeamDrop remains in private QA. The items below are public-safe release gates;
detailed engineering notes should stay in the issue tracker, not public
Markdown.

| ID | Area | Status | Public-safe summary |
| --- | --- | --- | --- |
| KI-001 | E2E matrix | Open | Full real-device cross-platform QA evidence is pending. |
| KI-002 | Security qualification | Open | Production transport security review and conformance signoff are pending. |
| KI-003 | Large-transfer continuity | Open | Interrupted large-transfer behavior requires full device-matrix validation. |
| KI-004 | Android release | Open | Signed release build validation is pending on a configured release host. |
| KI-005 | iPhone release | Open | Signed archive, extension, and TestFlight validation are pending. |
| KI-006 | macOS release | Open | Signed and notarized package validation is pending. |
| KI-007 | Windows release | Open | Signed package/installer validation is pending. |
| KI-008 | Protocol validation | Mitigated | Semantic schema validation of all protocol examples now runs in CI; fixture coverage can continue to expand. |
| KI-009 | Discovery fallback | Open | Blocked-network fallback needs real-network QA evidence. |
| KI-010 | Clipboard UX | Open | Manual/opt-in clipboard behavior needs platform UI QA evidence. |

## Fixed During QA Preparation

| ID | Area | Fix |
| --- | --- | --- |
| FIX-001 | QA planning | Expanded E2E matrix and manual cases for required platform pairs and flows. |
| FIX-002 | Local diagnostics | Added a local network diagnostic script for discovery and reachability checks. |
| FIX-003 | Release evidence | Added signoff and known-issue tracking so unrun flows are visible. |
| FIX-004 | Transfer security | Implemented authenticated session encryption across core and all four apps, verified by shared conformance vectors in every platform test suite. |
| FIX-005 | Encrypted framing | Unified the sealed-chunk wire framing across Android, iPhone, macOS, and Windows so encrypted transfers interoperate on every platform pair. |
| FIX-006 | Resume durability | Added a validated, crash-safe transfer checkpoint format driving missing-chunk retransmission. |
| FIX-007 | Protocol validation | Automated semantic JSON Schema validation of protocol examples in CI with a pinned offline validator. |
| FIX-008 | Server hardening | Signaling now requires token-bound device sessions; rate limiting is enforced; relay cleanup runs on a schedule; relay upload/download paths are covered by tests. |
| FIX-009 | Windows secret storage | Added a DPAPI-backed production secret protector with a cross-platform test fallback. |
