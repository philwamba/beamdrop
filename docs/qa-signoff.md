# BeamDrop QA Signoff

Current status: **Not signed off for production**.

## Summary

BeamDrop is eligible for internal engineering validation only. Production or
public beta release is blocked until real-device E2E evidence exists for the
required device matrix and all Critical known issues in `docs/known-issues.md`
are closed or formally waived for a narrower internal build.

## Signoff Matrix

| Area | Owner | Status | Evidence |
| --- | --- | --- | --- |
| Android to Windows | QA | Not run | Required: E2E-P01, E2E-P02 evidence bundle. |
| Android to macOS | QA | Not run | Required: E2E-P03, E2E-P04 evidence bundle. |
| iPhone to Windows | QA | Not run | Required: E2E-P05, E2E-P06 evidence bundle. |
| iPhone to macOS | QA | Not run | Required: E2E-P07, E2E-P08 evidence bundle. |
| Android to iPhone | QA | Not run | Required: E2E-P09, E2E-P10 evidence bundle. |
| Unknown/revoked peer rejection | QA/Security | Unit only | Real-device abuse evidence pending. |
| Text/URL/small file transfer | QA | Not run | Real-device evidence pending. |
| Large file/cancel/resume | QA | Not run | Real-device evidence pending. |
| Hash/corruption handling | QA/Security | Unit only | Real-device corruption evidence pending. |
| Permission/discovery fallback | QA | Not run | Requires OS dialogs and blocked-network test. |
| Clipboard platform behavior | QA/Privacy | Unit/manual pending | Android/iPhone/manual and desktop pause evidence pending. |
| Accessibility | QA | Not run | TalkBack, VoiceOver, Narrator, keyboard pending. |
| Packaging/signing | Release | Not signed off | Android, iOS, macOS, Windows signing evidence pending. |

## Minimum Evidence For Signoff

- Completed `docs/manual-test-cases.md` for every device pair in
  `docs/e2e-qa-plan.md`.
- SHA-256 source/destination proof for every file transfer case.
- Screenshots or recordings for QR pairing, receive prompts, transfer progress,
  history, permission errors, discovery fallback, and clipboard controls.
- Redacted logs showing no clipboard content, file contents, private keys, relay
  tokens, or unsafe local paths.
- Build artifacts signed or explicitly marked internal unsigned.

## Release Recommendation

Current recommendation: **Do not release publicly**.

Internal-only QA builds may continue if release notes clearly state that the
build is for engineering validation, transfer encryption and packaging are not
production-certified, and real-device E2E signoff is incomplete.
