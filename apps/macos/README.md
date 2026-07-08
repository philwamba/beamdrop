# BeamDrop macOS

Native macOS implementation of BeamDrop built with Swift, SwiftUI, AppKit,
Network.framework, Bonjour, NSPasteboard, Keychain, and local JSON persistence.

## What This App Contains

- Menu bar status item with quick actions.
- Optional SwiftUI main window focused on transfer workflows.
- Bonjour discovery for `_beamdrop._tcp`.
- Pairing QR generation and pairing-code import.
- Trusted-device storage with revoke support.
- Manual text, clipboard, selected-file, and drag-and-drop sending.
- Incoming local TCP receive path for text and files.
- Downloads receive target for files.
- Transfer progress, cancellation, and history.
- Clipboard sharing settings with sensitive-content blocking.
- Start at login setting via `SMAppService`.
- Network diagnostics for blocked Bonjour/local network cases.

## Protocol Compatibility

The macOS app uses the BeamDrop `1.0` MVP wire contract shared by Android and
Windows:

- Pairing JSON uses camelCase fields.
- Local service name is `_beamdrop._tcp`.
- Transfers use `JSON envelope + newline + payload bytes`.
- Default chunk size is 4 MB.
- File transfers require final SHA-256 verification before completion.
- Unknown devices are rejected.
- Revoked devices are blocked before payload content is accepted.

## Build

```sh
swift build
```

## Test

```sh
swift test
```

## Run

```sh
swift run BeamDropMacApp
```

## Current Limitations

- Camera-based QR scanning is planned; paste/import pairing payload is provided
  for QR import fallback.
- Folder transfer is planned; files are supported.
- Persisted cross-restart transfer resume is not complete.
- Production security qualification is pending before public distribution.
