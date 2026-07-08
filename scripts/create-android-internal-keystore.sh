#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SIGNING_DIR="$ROOT_DIR/dist/signing"
KEYSTORE_PATH="${ANDROID_RELEASE_STORE_FILE:-$SIGNING_DIR/beamdrop-internal-release.jks}"
ENV_FILE="$SIGNING_DIR/android-release-signing.env"
KEY_ALIAS="${ANDROID_RELEASE_KEY_ALIAS:-beamdrop-internal}"

if [[ -f "$KEYSTORE_PATH" && "${FORCE:-}" != "1" ]]; then
  echo "Keystore already exists: $KEYSTORE_PATH" >&2
  echo "Use FORCE=1 $0 to replace it." >&2
  exit 1
fi

if ! command -v keytool >/dev/null 2>&1; then
  echo "keytool is required and was not found." >&2
  exit 1
fi

if ! command -v openssl >/dev/null 2>&1; then
  echo "openssl is required and was not found." >&2
  exit 1
fi

mkdir -p "$SIGNING_DIR"
if [[ -f "$KEYSTORE_PATH" && "${FORCE:-}" == "1" ]]; then
  rm -f "$KEYSTORE_PATH"
fi

STORE_PASSWORD="$(openssl rand -base64 36 | tr -d '\n')"
KEY_PASSWORD="$STORE_PASSWORD"

keytool -genkeypair \
  -v \
  -keystore "$KEYSTORE_PATH" \
  -storetype PKCS12 \
  -storepass "$STORE_PASSWORD" \
  -alias "$KEY_ALIAS" \
  -keypass "$KEY_PASSWORD" \
  -keyalg RSA \
  -keysize 4096 \
  -validity 10000 \
  -dname "CN=BeamDrop Internal Release, OU=BeamDrop, O=BeamDrop, L=Internal, ST=Internal, C=US"

chmod 600 "$KEYSTORE_PATH"

cat > "$ENV_FILE" <<ENV
export ANDROID_RELEASE_STORE_FILE="$KEYSTORE_PATH"
export ANDROID_RELEASE_STORE_PASSWORD="$STORE_PASSWORD"
export ANDROID_RELEASE_KEY_ALIAS="$KEY_ALIAS"
export ANDROID_RELEASE_KEY_PASSWORD="$KEY_PASSWORD"
ENV

chmod 600 "$ENV_FILE"

echo "Created Android internal release keystore:"
echo "  $KEYSTORE_PATH"
echo
echo "Signing environment written to:"
echo "  $ENV_FILE"
echo
echo "Load it before building:"
echo "  source $ENV_FILE"
