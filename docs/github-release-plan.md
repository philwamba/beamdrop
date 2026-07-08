# GitHub Release Plan

This plan packages BeamDrop Android and macOS artifacts for an internal GitHub
Release. It does not replace production signing, notarization, Play Console
submission, or App Store review.

## Current Artifact Scope

- Android: `BeamDrop-Android-<version>-internal.apk`.
- macOS: `BeamDrop-macOS-<version>-internal.dmg`.
- Checksums: SHA-256 sidecar files for each artifact.

Artifacts are written to `dist/release/`.

## Local Build Commands

```bash
scripts/build-android-apk.sh
scripts/build-macos-dmg.sh
```

The Android script runs unit tests and `assembleRelease`, then copies the release
APK into `dist/release/`. It refuses to build a release artifact unless Android
release signing variables are configured. Debug-signed APKs must not be uploaded
to GitHub Releases because Play Protect flags unknown/debug-signed sideloaded
apps more aggressively.

For local internal signing, run:

```bash
scripts/create-android-internal-keystore.sh
source dist/signing/android-release-signing.env
scripts/build-android-apk.sh
```

The generated keystore and environment file are written under ignored
`dist/signing/` paths and must not be committed. Public Android distribution
still requires Play/App Signing credentials outside the repository.

The macOS script runs `swift test`, builds the release executable, wraps it in a
minimal `.app` bundle, signs the app bundle ad-hoc by default, and creates a DMG.
Set `CODESIGN_IDENTITY`, `CODESIGN_DMG_IDENTITY`, and `NOTARYTOOL_PROFILE` on a
release machine to produce Developer ID signed and notarized artifacts. Without
Developer ID signing and notarization, macOS Gatekeeper will warn that Apple
cannot verify the app.

## GitHub Release Workflow

Workflow: `.github/workflows/release.yml`.

Recommended internal release flow:

```bash
VERSION="$(cat VERSION)"
git tag "v$VERSION"
git push origin "v$VERSION"
```

The workflow also supports manual dispatch with an existing tag. It verifies the
tag before publishing so a mistyped release cannot silently create a new tag.

Tag pushes create a visible prerelease by default. Manual dispatch can still
create or update a draft release when the `draft` input is enabled. If the
release already exists, the workflow uploads the rebuilt assets with
`--clobber`.

## Required GitHub Permissions

The release job grants `contents: write` only for publishing release assets.
Other jobs use repository read access.

## Production Gates Before Public Release

- Configure Android release signing outside the repo; do not commit keystores or
  signing passwords.
- Configure GitHub secrets `ANDROID_RELEASE_KEYSTORE_BASE64`,
  `ANDROID_RELEASE_STORE_PASSWORD`, `ANDROID_RELEASE_KEY_ALIAS`, and
  `ANDROID_RELEASE_KEY_PASSWORD` before running the release workflow.
- Configure a production macOS app-bundle export path with Developer ID signing,
  hardened runtime, notarization, and stapling.
- Expect Google Play Protect reputation warnings for new sideload-only
  certificates until the app is distributed through Google Play or the signing
  certificate has sufficient install reputation.
- Verify the APK installs on physical Android devices.
- Verify the DMG opens on a clean macOS machine without Gatekeeper warnings.
- Confirm checksums match downloaded GitHub Release assets.
- Use manual draft mode only when a release must remain hidden during QA.
