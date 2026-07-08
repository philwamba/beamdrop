#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GRADLE_BIN="${GRADLE:-gradle}"
DIST_DIR="${DIST_DIR:-$ROOT_DIR/dist/release}"
VERSION="$(tr -d '[:space:]' < "$ROOT_DIR/VERSION")"
ARTIFACT_NAME="BeamDrop-Android-${VERSION}-internal.apk"

cd "$ROOT_DIR/apps/android"
"$GRADLE_BIN" --no-daemon --max-workers=1 testDebugUnitTest assembleRelease

APK_PATH="$(find app/build/outputs/apk/release -maxdepth 1 -type f -name '*.apk' | sort | tail -n 1)"
if [[ -z "$APK_PATH" ]]; then
  echo "No release APK found under apps/android/app/build/outputs/apk/release" >&2
  exit 1
fi

if [[ "$APK_PATH" == *unsigned* ]]; then
  echo "Release APK is unsigned. Configure internal debug fallback or release signing before publishing." >&2
  exit 1
fi

mkdir -p "$DIST_DIR"
cp "$APK_PATH" "$DIST_DIR/$ARTIFACT_NAME"

echo "WARNING: Android artifact is signed for installability, but production releases still require Play/App Signing credentials." >&2

(
  cd "$DIST_DIR"
  shasum -a 256 "$ARTIFACT_NAME" > "$ARTIFACT_NAME.sha256"
)

echo "$DIST_DIR/$ARTIFACT_NAME"
