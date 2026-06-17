#!/usr/bin/env bash
# Build a slim release HAP for HarmonyOS.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$ROOT/apps/app_ohos"

cd "$APP_DIR"
flutter build hap --release \
  --tree-shake-icons \
  --obfuscate \
  --split-debug-info=build/symbols

HAP="$APP_DIR/build/ohos/hap/entry-default-signed.hap"
if [[ -f "$HAP" ]]; then
  SIZE_MB=$(awk "BEGIN {printf \"%.2f\", $(stat -c%s "$HAP")/1024/1024}")
  echo "Release HAP: $HAP (${SIZE_MB} MB)"
fi
