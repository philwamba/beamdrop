# BeamDrop

BeamDrop is a native, private cross-device transfer app for trusted personal devices.
It is designed for moving files, folders, text, links, screenshots, and clipboard
content between Android, iPhone, Windows, and macOS without treating the cloud as
the default path.

BeamDrop is local-first. The primary product experience should work over nearby
networks and direct device-to-device paths where possible. Optional servers may be
used for relay or signaling, but BeamDrop should not require uploading user
content to a cloud storage service for the local MVP.

## Supported Platforms

- Android: Kotlin and Jetpack Compose
- iPhone: Swift and SwiftUI
- macOS: Swift, SwiftUI, and AppKit where native desktop integration is needed
- Windows: C#, WinUI 3, and Windows App SDK
- Shared core: Rust where it provides clear value for protocol, crypto, device
  discovery, transfer state, and cross-platform correctness

BeamDrop is not an Electron, Tauri, Flutter, React Native, Ionic, Cordova, web
wrapper, or browser-only application.

## Transfer Scope

BeamDrop is intended to support:

- Files and folders
- Text snippets
- Links
- Screenshots
- Clipboard content

Transfers should be explicit, inspectable, and controlled by the user. Trusted
device pairing, transport encryption, transfer integrity checks, and clear
receive/send consent are core product requirements.

## Clipboard Platform Constraints

iPhone clipboard sync cannot rely on silent background clipboard monitoring.
iOS does not allow apps to continuously read the clipboard in the background.
BeamDrop clipboard sending on iPhone must be manual through supported user-driven
entry points such as Share Sheet, Shortcuts, or Paste.

Android clipboard access is also subject to OS restrictions, especially in recent
Android versions. BeamDrop clipboard sending on Android must be user-triggered
where required by the operating system.

These constraints are product requirements, not implementation details. BeamDrop
must expose clipboard workflows that respect each platform's privacy model.

## Repository Layout

```text
beamdrop/
├── README.md
├── LICENSE
├── .gitignore
├── docs/
├── protocol/
│   └── beamdrop-protocol/
├── core/
│   └── beamdrop-core/
├── apps/
│   ├── android/
│   ├── ios/
│   ├── macos/
│   └── windows/
├── server/
│   ├── beamdrop-relay/
│   └── beamdrop-signaling/
├── design/
├── scripts/
└── .github/
    └── workflows/
```

## Development Principles

- Native platform UI and OS integration come first.
- Local transfer should be the default path.
- Servers are optional infrastructure for signaling or relay, not mandatory cloud
  storage.
- Shared Rust code should be used where it reduces duplicated correctness,
  security, or protocol work.
- Platform privacy restrictions must be reflected in the product UX.

## Current Status

This repository currently contains the initial monorepo foundation only. It does
not yet contain app code, server code, protocol code, or web UI.
