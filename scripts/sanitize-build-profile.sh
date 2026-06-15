#!/bin/bash
# sanitize-build-profile.sh - Sanitize/restore build-profile.json5 for safe GitHub push
# Usage:
#   bash scripts/sanitize-build-profile.sh sanitize  - Replace sensitive fields with placeholders
#   bash scripts/sanitize-build-profile.sh restore   - Restore original file from backup

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_PROFILE="apps/app_ohos/ohos/build-profile.json5"
FULL_PATH="$PROJECT_ROOT/$BUILD_PROFILE"
BACKUP_FILE="${FULL_PATH}.local.bak"

sanitize() {
  if [ ! -f "$FULL_PATH" ]; then
    echo "[sanitize] ERROR: $FULL_PATH not found" >&2
    exit 1
  fi

  cp "$FULL_PATH" "$BACKUP_FILE"
  echo "[sanitize] Backup created: ${BACKUP_FILE}"

  # Replace sensitive fields with placeholders
  # certpath - contains Windows user path and cert hash
  sed -i 's|"certpath": *"[^"]*"|"certpath": "~/.ohos/config/your_cert.cer"|g' "$FULL_PATH"
  # keyAlias
  sed -i 's|"keyAlias": *"[^"]*"|"keyAlias": "your_key_alias"|g' "$FULL_PATH"
  # keyPassword - encrypted hex string
  sed -i 's|"keyPassword": *"[^"]*"|"keyPassword": ""|g' "$FULL_PATH"
  # profile - contains Windows user path and profile hash
  sed -i 's|"profile": *"[^"]*"|"profile": "~/.ohos/config/your_profile.p7b"|g' "$FULL_PATH"
  # storeFile - contains Windows user path and keystore hash
  sed -i 's|"storeFile": *"[^"]*"|"storeFile": "~/.ohos/config/your_store.p12"|g' "$FULL_PATH"
  # storePassword - encrypted hex string
  sed -i 's|"storePassword": *"[^"]*"|"storePassword": ""|g' "$FULL_PATH"

  echo "[sanitize] Done - sensitive fields replaced with placeholders"
}

restore() {
  if [ -f "$BACKUP_FILE" ]; then
    cp "$BACKUP_FILE" "$FULL_PATH"
    rm -f "$BACKUP_FILE"
    echo "[restore] Restored from backup, backup removed"
  else
    echo "[restore] No backup file found at ${BACKUP_FILE}, skipping"
  fi
}

case "${1:-}" in
  sanitize)
    sanitize
    ;;
  restore)
    restore
    ;;
  *)
    echo "Usage: bash scripts/sanitize-build-profile.sh [sanitize|restore]" >&2
    exit 1
    ;;
esac
