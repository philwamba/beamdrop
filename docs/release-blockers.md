# BeamDrop Release Blockers

## Current Release Decision

BeamDrop is **READY FOR INTERNAL TESTING ONLY** at best. It is **not ready for public beta or production release**.

## Critical Blockers

| Blocker | Affected Area | Current Behavior | Missing Behavior | Risk | Release Decision | Plan |
| --- | --- | --- | --- | --- | --- | --- |
| No recorded real-device Android-Windows MVP signoff | Android, Windows, QA | Code paths exist and builds pass. | Physical device pairing/text/file/large-file/cancel/revoke/failure matrix. | Critical | Blocker | Execute manual checklist and record pass/fail in `docs/qa-signoff.md`. |
| No completed authenticated encrypted transport | Cross-platform security | Trust/public-key checks and SHA-256 exist. | E2E encrypted authenticated session. | Critical | Internal testing only | Design and implement session encryption before public beta. |
| iOS app has no Xcode project/workspace validation | iOS release | Swift package tests pass; SwiftUI app sources exist. | Xcode build, signing, app group, extension integration. | Critical | Blocker | Create Xcode project or generator config and validate on device. |
| iOS transfer UI not fully wired to real foreground transfer transport | iOS | Core validation exists; Send Text/File surfaces still note MVP transport not connected. | Real foreground send/receive and history integration. | Critical | Blocker | Wire SwiftUI app shell to transfer service and local network runtime. |
| Windows production secure storage provider incomplete | Windows security | Interface and AES test protector exist. | DPAPI/Credential Locker-backed implementation. | High | Blocker | Implement provider and tests. |
| Windows release target ambiguity | Windows | `apps/windows/src` builds; older `apps/windows/BeamDrop.Windows.App` exists. | Clear active/deprecated target docs and CI path. | High | Fix before release | Document `apps/windows/src` as active or restore old shell. |
| Signing/package pipelines absent | All platforms | Local builds exist. | Signed Android/iOS/macOS/Windows artifacts. | Critical | Public release blocker | Add platform signing docs and guarded release workflows. |

## High Blockers

| Blocker | Affected Area | Current Behavior | Missing Behavior | Risk | Release Decision | Plan |
| --- | --- | --- | --- | --- | --- | --- |
| macOS Swift concurrency warnings | macOS | Build passes with warnings in receive path. | Swift 6-safe receive state handling. | High | Fix before release | Refactor receive counters/error into actor or serial state object. |
| Persistent cross-restart resume incomplete | Transfer | Chunk planning exists. | Durable chunk state and resume protocol exchange. | High | Fix before release if marketed | Do not market resume until complete. |
| Runtime JSON Schema validation not uniform | Protocol | Strong model validation exists in places. | Same schema/fixture validation across apps. | High | Fix before release | Add protocol fixture tests in CI. |
| Path traversal tests not uniform | Security | iOS validates filenames; Windows/macOS/Android need explicit test coverage. | Cross-platform tests for dangerous names. | High | Fix before release | Add tests for `../`, absolute paths, separators, control chars. |

## Not Public Release Blockers If Documented

| Item | Decision |
| --- | --- |
| Relay/signaling production hardening | POST-MVP because local MVP must not depend on server. |
| Rust native bindings | POST-MVP if platform-native implementations remain canonical. |
| Folder archive/image/screenshot/clipboard image transfer | POST-MVP unless marketed. |
| Camera QR scanning on macOS/Windows | Document manual import fallback for internal MVP. |
