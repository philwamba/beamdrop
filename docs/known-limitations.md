# BeamDrop Known Limitations

BeamDrop is not public-release ready. These limitations must remain visible in release notes and store submission material until fixed.

## Cross-Platform

- Android-Windows, macOS-Windows, iOS-Windows, Android-iOS, and iOS-macOS flows need real-device LAN QA.
- Authenticated encrypted transfer sessions are not complete.
- Transfer resume is planned but not fully durable across app/device restarts.
- Runtime JSON Schema validation is not uniformly wired into every platform.
- Generated Rust bindings for Kotlin, Swift, and C# are not implemented.

## Android

- Persistence currently uses SharedPreferences-style stores, not Room.
- QR scanner requires production camera-polish validation.
- Local discovery reliability needs real public/corporate Wi-Fi tests.
- Android release signing and Play Store artifacts are not configured.

## iOS

- No Xcode project/workspace build has been validated.
- SwiftUI app transfer shell is not fully wired to real foreground transfer transport.
- Background receive is constrained by iOS policy and must not be promised.
- Clipboard text send remains manual by platform requirement.

## macOS

- App is not signed, sandboxed, packaged, or notarized.
- Camera-based QR scanning is not implemented; paste/import is the fallback.
- Receive path has Swift concurrency warnings under future Swift 6 strictness.
- Login item behavior needs packaged-app validation.

## Windows

- Active release target is `apps/windows/src`; older `apps/windows/BeamDrop.Windows.App` XAML shell exists and must not be treated as the release target unless restored/validated.
- Production DPAPI/Credential Locker storage is not complete.
- MSIX/installer packaging is not configured.
- Tray clipboard workflow needs final runtime wiring.

## Server

- Relay/signaling are optional and post-MVP for local transfer.
- Auth, rate limiting, abuse controls, and observability are not production complete.
- Relay must not be used as plaintext cloud file storage.
