# BeamDrop Production Readiness Audit

Date: 2026-07-06  
Target: Local-first MVP release candidate  
Decision standard: Code and build verified, not document-claimed.

## Status Legend

- `COMPLETE`: Implemented and locally build/test verified where possible.
- `PARTIAL`: Real implementation exists but coverage, wiring, or platform validation is incomplete.
- `SCAFFOLDED ONLY`: API/UI/project structure exists but is not production-wired.
- `NOT IMPLEMENTED`: No meaningful implementation found.
- `BLOCKED BY PLATFORM LIMITATION`: Platform policy prevents requested behavior.
- `POST-MVP`: Deliberately outside the local-first MVP.
- `NEEDS REAL DEVICE QA`: Code exists but requires device/LAN/store/runtime validation.

## Cross-Platform

| Item | Status | Evidence | Risk | Release Decision | Implementation Plan |
| --- | --- | --- | --- | --- | --- |
| Protocol 1.0 field alignment | PARTIAL | Android `TransferEnvelopeCodec.kt`, iOS `TransferModels.swift`, macOS `ProtocolModels.swift`, Windows `TransferEnvelopeCodec.cs` use `protocolVersion`, `transferId`, `transferType`, `senderDeviceId`, `senderPublicKey`, `receiverDeviceId`, `createdAt`, `payloadMetadata`. | High | Fix before release | Run schema/example validation in CI and add interop fixture tests for every platform. |
| Local-first without server dependency | COMPLETE | App transfer paths use local TCP/Bonjour/manual endpoint concepts; server docs/code are separate. | Medium | Document only | Keep relay/signaling disabled for MVP release notes. |
| Real Android-Windows LAN flows | NEEDS REAL DEVICE QA | Android and Windows code paths exist; no automated or recorded real-device run in repo. | Critical | Blocker for public release | Execute `docs/android-windows-local-mvp-checklist.md` on physical devices and attach results to QA signoff. |
| Authenticated encrypted transfer session | NOT IMPLEMENTED | Trust/public-key checks and SHA-256 exist, but no completed E2E encrypted session transport is wired across apps. | Critical | Internal testing only | Design and implement Noise/TLS-style session establishment before public beta. |
| Persistent cross-restart resume | PARTIAL | Chunk/resume planning exists in Rust and platform transfer models, but durable resume state is not complete. | High | Fix before release for large-file promise | Persist chunk manifests, verified chunk hashes, and resumed offsets per platform. |
| Transfer history statuses | PARTIAL | Android/Windows/iOS/macOS have history/status models; full UI and receive-state coverage needs device QA. | High | Fix before release | Add E2E tests for success, failed, cancelled, rejected, corrupted, incomplete. |

## Protocol/Core

| Item | Status | Evidence | Risk | Release Decision | Implementation Plan |
| --- | --- | --- | --- | --- | --- |
| Runtime envelope validation | PARTIAL | iOS validates SHA-256/file names/chunks; Android/Windows/macOS validate core fields; JSON Schema validation is not runtime-wired everywhere. | High | Fix before release | Add shared fixture tests and reject unsupported transfer types uniformly. |
| Rust core tests | NEEDS REAL DEVICE QA | Rust crates exist under `core/beamdrop-core`; native apps do not consume generated bindings. | Medium | Fix before release | Run `cargo test`; decide whether Rust is release dependency or foundation-only. |
| Native bindings | POST-MVP | `beamdrop-bindings/src/lib.rs` says Kotlin/Swift/C# generation is planned. | Medium | Post-MVP | Do not block local MVP if native platform code remains canonical. |
| Unimplemented transfer types | POST-MVP | Compatibility matrix marks `FOLDER_ARCHIVE`, `IMAGE`, `SCREENSHOT`, `CLIPBOARD_IMAGE` future/post-MVP. | Low | Document only | Keep out of release marketing until implemented. |

## Android

| Item | Status | Evidence | Risk | Release Decision | Implementation Plan |
| --- | --- | --- | --- | --- | --- |
| Native app build | COMPLETE | Gradle app under `apps/android`; recent build command passes. | Medium | Fix before release | Keep CI green on Linux runner. |
| QR display/manual import | PARTIAL | Compose pairing and manual payload flow exists in `MainActivity.kt`; production camera scanner still needs polish. | Medium | Fix before release | Add scanner implementation or mark manual import as MVP fallback. |
| Transfer streaming/hash | PARTIAL | `TransferManager`, `AndroidFileTransferSource`, `Hashing`, `SocketTransferTransport`; needs real-device LAN QA. | Critical | Blocker for public release | Run Android-Windows/macOS device matrix. |
| Room persistence | NOT IMPLEMENTED | Current stores are SharedPreferences-based. | Medium | Post-MVP or fix before release | Decide if SharedPreferences is acceptable for MVP; otherwise add Room DAOs. |
| Clipboard policy | COMPLETE | Manual clipboard sender exists; no hidden background monitoring. | Medium | Document only | Keep QS tile user-triggered. |
| Deprecated send icon warnings | COMPLETE | Replaced with auto-mirrored Material send icon. | Low | Fixed | None. |

## iOS

| Item | Status | Evidence | Risk | Release Decision | Implementation Plan |
| --- | --- | --- | --- | --- | --- |
| Xcode project/workspace | NOT IMPLEMENTED | Swift package and app source exist; no `.xcodeproj`/workspace found. | Critical | Blocker | Create Xcode project/workspace or Tuist/XcodeGen config before TestFlight. |
| Local network plist | COMPLETE | `NSLocalNetworkUsageDescription`, `NSBonjourServices` include `_beamdrop._tcp`. | Medium | Document only | Validate on device. |
| QR/manual pairing | PARTIAL | SwiftUI scanner/manual import views exist. | High | Needs device QA | Validate camera permission and QR decode on iPhone. |
| Transfer app shell wiring | PARTIAL | Core `TransferService` validates payloads; SwiftUI send views still show transport-not-connected MVP errors. | Critical | Blocker | Wire foreground send/receive transport and history persistence. |
| Clipboard behavior | COMPLETE | Manual paste/share/shortcut only; no silent monitoring. | Medium | Document only | Keep store notes explicit. |
| Keychain | PARTIAL | Keychain abstraction exists; device-app integration needs Xcode validation. | High | Fix before release | Validate real Keychain access group and app group on device. |

## macOS

| Item | Status | Evidence | Risk | Release Decision | Implementation Plan |
| --- | --- | --- | --- | --- | --- |
| Native build | COMPLETE | SwiftPM app builds/tests under `apps/macos`. | Medium | Fix before release | Add CI and signed app packaging. |
| Menu bar/main window | PARTIAL | SwiftUI/AppKit menu bar implemented; no packaged-app validation. | Medium | Needs real device QA | Run as packaged app and validate menu bar/login item behavior. |
| Pairing/import | PARTIAL | QR generation and paste import exist; camera scanning absent. | Medium | Document fallback | Keep manual import MVP or add camera scanner. |
| Transfer send/receive | PARTIAL | TCP transfer service exists; no cross-device verification. | Critical | Blocker for public release | Execute LAN matrix. |
| Keychain | PARTIAL | `KeychainSecretStore` exists; app signing/sandbox entitlements not validated. | High | Fix before release | Validate signed app and sandbox strategy. |
| Swift concurrency warnings | PARTIAL | Build passes but receive path warns about captured mutable vars under Swift 6 mode. | Medium | Fix before release | Refactor receive state into actor/serial object. |

## Windows

| Item | Status | Evidence | Risk | Release Decision | Implementation Plan |
| --- | --- | --- | --- | --- | --- |
| Active build target clarity | PARTIAL | `apps/windows/src` builds; older `apps/windows/BeamDrop.Windows.App` XAML project also exists. | High | Fix before release | Mark old XAML shell legacy or restore/build it fully. |
| Core send/receive | PARTIAL | `src/BeamDrop.Windows.Core` transfer manager validates trust/hash/chunks. | Critical | Needs real device QA | Run Android-Windows and macOS-Windows tests. |
| Secret storage | SCAFFOLDED ONLY | `ISecretStore`, AES protector, and DPAPI/Credential Locker plan exist; not a real DPAPI/Credential Locker implementation. | High | Blocker | Implement production Windows protector backed by DPAPI/Credential Locker. |
| Clipboard policy | PARTIAL | Clipboard service and policy exist; tray production wiring incomplete. | Medium | Fix before release | Wire tray action and pause status to active runtime. |
| Packaging | NOT IMPLEMENTED | No MSIX/installer workflow verified. | High | Blocker for public release | Add MSIX/installer path and signing cert docs. |

## Server/Relay/Signaling

| Item | Status | Evidence | Risk | Release Decision | Implementation Plan |
| --- | --- | --- | --- | --- | --- |
| Optional for MVP | COMPLETE | Server code is under `server/`; local app flows do not require it. | Medium | Document only | Keep disabled in MVP release. |
| Relay plaintext storage policy | PARTIAL | Relay code exists; production crypto/auth posture not final. | High | Post-MVP | Relay must accept only encrypted payloads and short-lived tokens. |
| Auth/rate limiting/observability | PARTIAL | Health/tests exist; production abuse controls incomplete. | High | Post-MVP | Add auth, rate limits, metrics, structured logs. |

## Security

| Item | Status | Evidence | Risk | Release Decision | Implementation Plan |
| --- | --- | --- | --- | --- | --- |
| Unknown peer rejection | PARTIAL | Implemented in platform trust policies; needs E2E QA. | Critical | Blocker until tested | Add malicious/unpaired sender tests. |
| Revoked peer rejection | PARTIAL | Implemented in stores/policies; needs E2E QA. | Critical | Blocker until tested | Add device-matrix revoke tests. |
| SHA-256 verification | PARTIAL | Android/Windows/iOS/macOS helpers exist; not all E2E verified. | Critical | Blocker until tested | Corrupt payload on wire and verify rejection/history. |
| Path traversal protection | PARTIAL | iOS validates file names; Windows/macOS sanitize/target; Android app-private target needs explicit audit. | High | Fix before release | Add cross-platform file name tests. |
| Logs and secrets | PARTIAL | No obvious content logging in core paths; server/app logs need review. | High | Fix before release | Add logging policy and grep CI check for secrets only if practical. |

## Privacy

| Item | Status | Evidence | Risk | Release Decision | Implementation Plan |
| --- | --- | --- | --- | --- | --- |
| Mobile clipboard manual only | COMPLETE | iOS/Android flows are explicit user action. | Medium | Document only | Keep app-store copy accurate. |
| Desktop clipboard pause | PARTIAL | macOS/Windows settings exist; production tray/menu state not fully verified. | Medium | Fix before release | Validate pause setting and last status. |
| Privacy policy notes | PARTIAL | `docs/privacy-policy-notes.md` exists; final policy not published. | Medium | Fix before release | Convert notes to final store-ready policy. |

## UI/UX

| Item | Status | Evidence | Risk | Release Decision | Implementation Plan |
| --- | --- | --- | --- | --- | --- |
| Required screens reachable | PARTIAL | Android/iOS/macOS/Windows shell screens exist; full navigation not device-verified. | Medium | Needs QA | Run screen-by-screen QA. |
| Loading/error/empty states | PARTIAL | Many empty/error states exist; real network loading/failure states incomplete. | Medium | Fix before release | Add explicit loading for discovery/listeners/transfers. |
| Destructive confirmation | PARTIAL | Implemented in several shells; legacy Windows XAML has copy but not behavior. | Medium | Fix before release | Wire dialogs to real commands. |

## Accessibility

| Item | Status | Evidence | Risk | Release Decision | Implementation Plan |
| --- | --- | --- | --- | --- | --- |
| Screen reader labels | PARTIAL | Important logo/QR labels exist; full TalkBack/VoiceOver/Narrator pass absent. | Medium | Needs real device QA | Run platform accessibility matrix. |
| Keyboard navigation desktop | PARTIAL | Native controls support basics; custom flows not audited. | Medium | Fix before release | Validate macOS/Windows keyboard-only flows. |
| Dynamic type/high contrast | NEEDS REAL DEVICE QA | No screenshot/accessibility test artifacts. | Medium | Fix before release | Capture and review. |

## CI/Build/Release

| Item | Status | Evidence | Risk | Release Decision | Implementation Plan |
| --- | --- | --- | --- | --- | --- |
| Local build commands | COMPLETE | README/docs list commands; scripts added in this pass. | Medium | Document only | Keep commands current. |
| GitHub Actions | SCAFFOLDED ONLY | Workflow README existed; actual workflow YAMLs added in this pass. | Medium | Fix before release | Validate in GitHub Actions. |
| Signing/notarization | NOT IMPLEMENTED | No cert/provisioning/notary/MSIX config. | Critical | Public release blocker | Add signing secrets and release jobs only after internal QA. |

## Store/Package Readiness

| Item | Status | Evidence | Risk | Release Decision | Implementation Plan |
| --- | --- | --- | --- | --- | --- |
| Android Play release | NOT IMPLEMENTED | Release APK builds; signing/store assets incomplete. | High | Blocker | Add signing config, privacy labels, screenshots. |
| iOS TestFlight/App Store | NOT IMPLEMENTED | No Xcode project/provisioning. | Critical | Blocker | Create Xcode project and signing setup. |
| macOS notarized DMG | NOT IMPLEMENTED | SwiftPM app builds; no notarization. | High | Blocker | Add archive/sign/notarize/dmg docs. |
| Windows installer/MSIX | NOT IMPLEMENTED | Core app builds; no installer path. | High | Blocker | Add MSIX/installer project and signing docs. |

## End-to-End QA

| Item | Status | Evidence | Risk | Release Decision | Implementation Plan |
| --- | --- | --- | --- | --- | --- |
| Android-Windows matrix | NEEDS REAL DEVICE QA | Manual checklist exists; no signoff. | Critical | Blocker for public release | Execute full matrix and record results in `docs/qa-signoff.md`. |
| Full platform pair matrix | NEEDS REAL DEVICE QA | New manual/e2e docs added. | Critical | Blocker | Test every pair over same LAN and blocked-discovery fallback. |
