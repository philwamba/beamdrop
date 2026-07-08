#!/usr/bin/env bash
set -euo pipefail

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "macOS DMG packaging requires macOS." >&2
  exit 1
fi

if ! command -v hdiutil >/dev/null 2>&1; then
  echo "hdiutil is required to create a DMG." >&2
  exit 1
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="${DIST_DIR:-$ROOT_DIR/dist/release}"
WORK_DIR="${WORK_DIR:-$ROOT_DIR/dist/macos-work}"
VERSION="$(tr -d '[:space:]' < "$ROOT_DIR/VERSION")"
APP_NAME="BeamDrop"
EXECUTABLE_NAME="BeamDropMacApp"
ARTIFACT_NAME="BeamDrop-macOS-${VERSION}-internal.dmg"
APP_BUNDLE="$WORK_DIR/$APP_NAME.app"
DMG_STAGING="$WORK_DIR/dmg"
DMG_PATH="$DIST_DIR/$ARTIFACT_NAME"

cd "$ROOT_DIR/apps/macos"
swift test
swift build -c release
BIN_DIR="$(swift build -c release --show-bin-path)"
EXECUTABLE_PATH="$BIN_DIR/$EXECUTABLE_NAME"
RESOURCE_BUNDLE="$BIN_DIR/BeamDropMac_BeamDropMacApp.bundle"

if [[ ! -x "$EXECUTABLE_PATH" ]]; then
  echo "Release executable not found at $EXECUTABLE_PATH" >&2
  exit 1
fi

rm -rf "$APP_BUNDLE" "$DMG_STAGING" "$DMG_PATH"
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources" "$DMG_STAGING" "$DIST_DIR"

cp "$EXECUTABLE_PATH" "$APP_BUNDLE/Contents/MacOS/$EXECUTABLE_NAME"

cat > "$APP_BUNDLE/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>$EXECUTABLE_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>com.beamdrop.macos</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>$VERSION</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
PLIST

echo "APPL????" > "$APP_BUNDLE/Contents/PkgInfo"

if [[ -n "${CODESIGN_IDENTITY:-}" ]]; then
  codesign --force --options runtime --timestamp --sign "$CODESIGN_IDENTITY" "$APP_BUNDLE/Contents/MacOS/$EXECUTABLE_NAME"
else
  codesign --force --sign - "$APP_BUNDLE/Contents/MacOS/$EXECUTABLE_NAME"
  echo "WARNING: app executable uses ad-hoc signing; the DMG is only suitable for internal testing." >&2
fi

if [[ -d "$RESOURCE_BUNDLE" ]]; then
  cp -R "$RESOURCE_BUNDLE" "$APP_BUNDLE/"
fi

cp -R "$APP_BUNDLE" "$DMG_STAGING/"
ln -s /Applications "$DMG_STAGING/Applications"
hdiutil create -volname "$APP_NAME" -srcfolder "$DMG_STAGING" -ov -format UDZO "$DMG_PATH"

if [[ -n "${CODESIGN_DMG_IDENTITY:-}" ]]; then
  codesign --force --timestamp --sign "$CODESIGN_DMG_IDENTITY" "$DMG_PATH"
fi

(
  cd "$DIST_DIR"
  shasum -a 256 "$ARTIFACT_NAME" > "$ARTIFACT_NAME.sha256"
)

echo "$DMG_PATH"
