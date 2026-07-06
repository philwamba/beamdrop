# BeamDrop iPhone

Native iPhone implementation foundation built with Swift and SwiftUI.

Implemented:

- Swift package `BeamDropIOSCore` for protocol, pairing, trust, transfer
  verification, local persistence, Keychain abstraction, Bonjour/local network
  abstractions, ViewModels, and Share Extension payload parsing.
- SwiftUI app source with onboarding, home, nearby devices, pair/show QR,
  scan QR, trusted devices, send text, manual Paste, send file, receive prompt,
  transfer progress/cancel, history, settings, privacy, diagnostics, and about
  screens.
- Share Extension source for files, photos, text, and links.
- App Intent for manual clipboard send entry.
- Required plist/entitlement files for local network, Bonjour, camera, and App
  Group configuration.

Clipboard policy:

BeamDrop for iPhone does not implement silent background clipboard monitoring.
Clipboard send paths are manual through Paste, Share Sheet, or Shortcuts/App
Intents.

Test:

```sh
swift test
```

Current limitation:

This directory contains buildable core Swift package sources and iOS app /
extension source files. An `.xcodeproj` or `.xcworkspace` target graph still
needs to be generated or created in Xcode to build the app and Share Extension
as installable iOS targets.
