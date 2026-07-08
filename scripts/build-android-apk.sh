#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GRADLE_BIN="${GRADLE:-gradle}"
DIST_DIR="${DIST_DIR:-$ROOT_DIR/dist/release}"
VERSION="$(tr -d '[:space:]' < "$ROOT_DIR/VERSION")"
ARTIFACT_NAME="BeamDrop-Android-${VERSION}-internal.apk"
LOCAL_SIGNING_ENV="$ROOT_DIR/dist/signing/android-release-signing.env"

has_release_signing() {
  [[ -n "${ANDROID_RELEASE_STORE_FILE:-}" ]] &&
    [[ -n "${ANDROID_RELEASE_STORE_PASSWORD:-}" ]] &&
    [[ -n "${ANDROID_RELEASE_KEY_ALIAS:-}" ]] &&
    [[ -n "${ANDROID_RELEASE_KEY_PASSWORD:-}" ]]
}

if ! has_release_signing && [[ -f "$LOCAL_SIGNING_ENV" ]]; then
  # shellcheck disable=SC1090
  source "$LOCAL_SIGNING_ENV"
fi

if ! has_release_signing; then
  cat >&2 <<MSG
Android release signing is not configured.

Refusing to build a release APK with the Android debug certificate because
Play Protect flags unknown/debug-signed sideloaded apps more aggressively.

Create a local internal signing key:
  scripts/create-android-internal-keystore.sh
  source dist/signing/android-release-signing.env

For GitHub releases, configure these repository secrets instead:
  ANDROID_RELEASE_KEYSTORE_BASE64
  ANDROID_RELEASE_STORE_PASSWORD
  ANDROID_RELEASE_KEY_ALIAS
  ANDROID_RELEASE_KEY_PASSWORD
MSG
  exit 1
fi

cd "$ROOT_DIR/apps/android"
"$GRADLE_BIN" --no-daemon --max-workers=1 testDebugUnitTest assembleRelease

APK_PATH="$(find app/build/outputs/apk/release -maxdepth 1 -type f -name '*.apk' | sort | tail -n 1)"
if [[ -z "$APK_PATH" ]]; then
  echo "No release APK found under apps/android/app/build/outputs/apk/release" >&2
  exit 1
fi

if [[ "$APK_PATH" == *unsigned* ]]; then
  echo "Release APK is unsigned. Configure release signing before publishing." >&2
  exit 1
fi

mkdir -p "$DIST_DIR"
cp "$APK_PATH" "$DIST_DIR/$ARTIFACT_NAME"

if command -v apksigner >/dev/null 2>&1; then
  CERTS="$(apksigner verify --print-certs --verbose "$DIST_DIR/$ARTIFACT_NAME")"
elif [[ -n "${ANDROID_HOME:-}" && -x "$ANDROID_HOME/build-tools/36.0.0/apksigner" ]]; then
  CERTS="$("$ANDROID_HOME/build-tools/36.0.0/apksigner" verify --print-certs --verbose "$DIST_DIR/$ARTIFACT_NAME")"
else
  CERTS=""
  echo "WARNING: apksigner not found; skipping signing certificate inspection." >&2
fi

if [[ "$CERTS" == *"CN=Android Debug"* ]]; then
  echo "Release APK is signed with the Android debug certificate. Refusing to publish it." >&2
  exit 1
fi

echo "WARNING: Android artifact is not Play/App Signing distributed yet. Sideloaded APKs may still show Play Protect reputation warnings until distributed through Google Play or a certificate with sufficient reputation." >&2

(
  cd "$DIST_DIR"
  shasum -a 256 "$ARTIFACT_NAME" > "$ARTIFACT_NAME.sha256"
)

echo "$DIST_DIR/$ARTIFACT_NAME"
