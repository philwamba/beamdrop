# BeamDrop Android

Native Android app built with Kotlin and Jetpack Compose.

Implemented foundations:

- Android Keystore-backed device identity generation.
- User-editable local device name.
- QR pairing payload generation and validation.
- Explicit pairing approval before trust is saved.
- Trusted peer persistence, revocation, and transfer trust checks.
- Android Network Service Discovery service structure for `_beamdrop._tcp`.
- Permission planning and explanation UI for local networking, camera,
  notifications, and foreground transfer progress.
- User-triggered clipboard send entry points only.

Build and test:

```sh
gradle testDebugUnitTest
gradle assembleDebug
```

Current limitations:

- Camera QR decoding is represented by scan-screen logic and manual payload
  entry; the CameraX decoder adapter still needs to be wired.
- NSD registration/discovery structure is present, but transfer listeners and
  authenticated pairing handshakes are not yet connected end to end.
- Bluetooth permissions are intentionally not requested until a Bluetooth
  transport exists.
