#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GRADLE_BIN="${GRADLE:-gradle}"

cd "$ROOT_DIR/apps/android"
"$GRADLE_BIN" --no-daemon --max-workers=1 testDebugUnitTest assembleRelease
