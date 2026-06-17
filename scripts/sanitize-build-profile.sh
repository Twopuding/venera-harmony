#!/bin/bash
# sanitize-build-profile.sh - Sanitize/restore build-profile.json5 for safe GitHub push
#
# Usage:
#   bash scripts/sanitize-build-profile.sh status   - Show current file/backup state
#   bash scripts/sanitize-build-profile.sh sanitize - Backup and replace sensitive fields
#   bash scripts/sanitize-build-profile.sh restore    - Restore original from backup
#   bash scripts/sanitize-build-profile.sh verify   - Confirm restore succeeded
#   bash scripts/sanitize-build-profile.sh cleanup  - Remove backup after successful verify

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_PROFILE="apps/app_ohos/ohos/build-profile.json5"
FULL_PATH="$PROJECT_ROOT/$BUILD_PROFILE"
BACKUP_FILE="${FULL_PATH}.local.bak"
CHECKSUM_FILE="${BACKUP_FILE}.sha256"

sha256() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}

write_checksum() {
  sha256 "$1" > "$CHECKSUM_FILE"
}

verify_checksum() {
  local file="$1"
  local expected
  expected="$(cat "$CHECKSUM_FILE")"
  local actual
  actual="$(sha256 "$file")"
  if [ "$expected" != "$actual" ]; then
    echo "[verify] ERROR: checksum mismatch for $file" >&2
    echo "[verify]   expected: $expected" >&2
    echo "[verify]   actual:   $actual" >&2
    return 1
  fi
}

looks_sanitized() {
  grep -q '~/.ohos/config/your_' "$FULL_PATH" 2>/dev/null
}

looks_real_signing() {
  grep -qE '"certpath"[[:space:]]*:[[:space:]]*"[^"]*\\\.ohos\\' "$FULL_PATH" 2>/dev/null \
    || grep -qE '"certpath"[[:space:]]*:[[:space:]]*"[^"]*/\.ohos/' "$FULL_PATH" 2>/dev/null \
    || grep -qE '"keyPassword"[[:space:]]*:[[:space:]]*"[0-9A-F]{32,}"' "$FULL_PATH" 2>/dev/null
}

status() {
  echo "build-profile: $FULL_PATH"
  if [ -f "$FULL_PATH" ]; then
    if looks_sanitized; then
      echo "  state: SANITIZED (placeholders present)"
    elif looks_real_signing; then
      echo "  state: REAL (local signing paths/passwords present)"
    else
      echo "  state: UNKNOWN (review file manually)"
    fi
  else
    echo "  state: MISSING"
  fi

  if [ -f "$BACKUP_FILE" ]; then
    echo "  backup: present ($BACKUP_FILE)"
    if [ -f "$CHECKSUM_FILE" ]; then
      echo "  backup checksum: $(cat "$CHECKSUM_FILE")"
    else
      echo "  backup checksum: missing (run verify or re-sanitize with --force)"
    fi
  else
    echo "  backup: none"
  fi
}

sanitize() {
  local force="${1:-}"

  if [ ! -f "$FULL_PATH" ]; then
    echo "[sanitize] ERROR: $FULL_PATH not found" >&2
    exit 1
  fi

  if [ -f "$BACKUP_FILE" ] && [ "$force" != "--force" ]; then
    echo "[sanitize] ERROR: backup already exists at $BACKUP_FILE" >&2
    echo "[sanitize] Run 'restore' first, or 'sanitize --force' to overwrite backup." >&2
    exit 1
  fi

  if looks_sanitized && [ "$force" != "--force" ]; then
    echo "[sanitize] ERROR: file already looks sanitized" >&2
    echo "[sanitize] Run 'restore' first if you need to re-sanitize." >&2
    exit 1
  fi

  local tmp_backup="${BACKUP_FILE}.tmp"
  cp "$FULL_PATH" "$tmp_backup"
  write_checksum "$tmp_backup"
  mv "$tmp_backup" "$BACKUP_FILE"
  echo "[sanitize] Backup created: $BACKUP_FILE"

  sed -i 's|"certpath": *"[^"]*"|"certpath": "~/.ohos/config/your_cert.cer"|g' "$FULL_PATH"
  sed -i 's|"keyAlias": *"[^"]*"|"keyAlias": "your_key_alias"|g' "$FULL_PATH"
  sed -i 's|"keyPassword": *"[^"]*"|"keyPassword": ""|g' "$FULL_PATH"
  sed -i 's|"profile": *"[^"]*"|"profile": "~/.ohos/config/your_profile.p7b"|g' "$FULL_PATH"
  sed -i 's|"storeFile": *"[^"]*"|"storeFile": "~/.ohos/config/your_store.p12"|g' "$FULL_PATH"
  sed -i 's|"storePassword": *"[^"]*"|"storePassword": ""|g' "$FULL_PATH"

  if ! looks_sanitized; then
    echo "[sanitize] ERROR: sanitization may have failed; restoring from backup" >&2
    cp "$BACKUP_FILE" "$FULL_PATH"
    exit 1
  fi

  echo "[sanitize] Done - sensitive fields replaced with placeholders"
}

restore() {
  if [ ! -f "$BACKUP_FILE" ]; then
    echo "[restore] ERROR: no backup at $BACKUP_FILE" >&2
    echo "[restore] Cannot restore signing config safely." >&2
    exit 1
  fi

  if [ -f "$CHECKSUM_FILE" ]; then
    verify_checksum "$BACKUP_FILE"
  else
    echo "[restore] WARN: checksum file missing; proceeding without verification" >&2
  fi

  if grep -q '~/.ohos/config/your_' "$BACKUP_FILE" 2>/dev/null; then
    echo "[restore] ERROR: backup contains sanitized placeholders, not real signing config" >&2
    echo "[restore] Refusing to restore — would overwrite local credentials with placeholders." >&2
    echo "[restore] Delete the bad backup and reconfigure signing in DevEco if needed." >&2
    exit 1
  fi

  local tmp_restore="${FULL_PATH}.restore.tmp"
  cp "$BACKUP_FILE" "$tmp_restore"

  if ! grep -qE '"certpath"|"storeFile"|"profile"' "$tmp_restore"; then
    echo "[restore] ERROR: backup does not look like a valid build-profile" >&2
    rm -f "$tmp_restore"
    exit 1
  fi

  mv "$tmp_restore" "$FULL_PATH"

  if [ -f "$CHECKSUM_FILE" ]; then
    verify_checksum "$FULL_PATH"
  fi

  echo "[restore] Restored from backup (backup kept at $BACKUP_FILE)"
  echo "[restore] Run 'verify', then 'cleanup' to remove backup files"
}

verify() {
  if [ ! -f "$FULL_PATH" ]; then
    echo "[verify] ERROR: $FULL_PATH not found" >&2
    exit 1
  fi

  if looks_sanitized; then
    echo "[verify] FAIL: file is still sanitized" >&2
    exit 1
  fi

  if ! looks_real_signing; then
    echo "[verify] WARN: file restored but signing fields look unusual; review manually" >&2
    exit 1
  fi

  if [ -f "$BACKUP_FILE" ] && [ -f "$CHECKSUM_FILE" ]; then
    verify_checksum "$FULL_PATH"
    verify_checksum "$BACKUP_FILE"
    echo "[verify] OK: restored file matches backup checksum"
  else
    echo "[verify] OK: file contains real signing config (no checksum to compare)"
  fi
}

cleanup() {
  if [ ! -f "$BACKUP_FILE" ]; then
    echo "[cleanup] No backup to remove"
    return 0
  fi

  if looks_sanitized; then
    echo "[cleanup] ERROR: file is still sanitized; run restore first" >&2
    exit 1
  fi

  if [ -f "$CHECKSUM_FILE" ]; then
    verify_checksum "$FULL_PATH" || {
      echo "[cleanup] ERROR: restored file does not match backup; keeping backup" >&2
      exit 1
    }
  fi

  rm -f "$BACKUP_FILE" "$CHECKSUM_FILE"
  echo "[cleanup] Backup removed"
}

case "${1:-}" in
  status)
    status
    ;;
  sanitize)
    sanitize "${2:-}"
    ;;
  restore)
    restore
    ;;
  verify)
    verify
    ;;
  cleanup)
    cleanup
    ;;
  *)
    echo "Usage: bash scripts/sanitize-build-profile.sh [status|sanitize|restore|verify|cleanup]" >&2
    echo "       bash scripts/sanitize-build-profile.sh sanitize --force" >&2
    exit 1
    ;;
esac
