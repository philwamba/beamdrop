# BeamDrop Release Gates

## Current Release Decision

BeamDrop is limited to private engineering validation. It is not approved for a
public beta, store submission, or production release.

## Required Gates Before Public Release

| Gate | Area | Status | Public-safe next step |
| --- | --- | --- | --- |
| Real-device transfer QA | Android, iPhone, macOS, Windows | Pending | Complete the full device matrix in `docs/qa-signoff.md`. |
| Secure transfer certification | Cross-platform security | Pending | Complete security review and release qualification for production transport. |
| Apple platform archive validation | iPhone/macOS release | Pending | Validate signed archives, entitlements, and extension behavior on real devices. |
| Windows packaging validation | Windows release | Pending | Validate signed installer/MSIX package on clean Windows devices. |
| Platform signing | All platforms | Pending | Produce signed artifacts through guarded release workflows. |
| Store privacy review | Mobile/desktop stores | Pending | Finalize permission copy, privacy labels, and store submission notes. |

## Non-Public Internal Validation

Internal builds may continue when they are clearly labeled as internal,
unsigned/non-store artifacts are not redistributed, and release notes do not
claim production security or store readiness.
