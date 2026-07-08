# BeamDrop Known Limitations

BeamDrop is not public-release ready. These limitations should remain visible in
release notes and store submission material until closed.

## Cross-Platform

- Full real-device transfer QA is pending across Android, iPhone, macOS, and
  Windows.
- Large-transfer interruption/resume behavior requires full matrix validation.
- Runtime protocol validation must stay aligned across platform implementations.

## Android

- Release signing and Play Store artifacts are not finalized.
- Local discovery and permission flows require real network/device QA.

## iPhone

- Store archive, signing, App Group, and Share Extension validation are pending.
- Clipboard send remains manual by platform requirement.

## macOS

- Signed/notarized distribution is pending.
- Packaged-app desktop behavior requires QA.

## Windows

- Signed installer/package validation is pending.
- Desktop tray and clipboard controls require clean-machine QA.

## Server

- Relay/signaling are optional and not required for local MVP.
- Remote-transfer production readiness requires separate server security review.
