#!/usr/bin/env bash
set -euo pipefail

### -------- CONFIG --------
export BORG_REPO="/mnt/d/ww40/borg/immich"
export BORG_PASSPHRASE="$(cat "$HOME/.borg-passphrase")"

MAIL_TO="eyezopen@gmail.com"
IMMICH_ROOT="/mnt/d/ww40/Docker/immich-app"
LOGFILE="$HOME/backup-immich.log"

### -------- ERROR EMAIL --------
trap 'echo "❌ Immich backup FAILED on $(date)" | mail -s "Immich Backup FAILED" "$MAIL_TO"' ERR

### -------- LOGGING --------
exec >> "$LOGFILE" 2>&1
echo "===== Backup started: $(date) ====="

cd "$IMMICH_ROOT"

### -------- ALWAYS RESTART IMMICH --------
cleanup() {
  echo "Starting Immich containers (cleanup)..."
  docker compose up -d || true
  echo "===== Backup finished: $(date) ====="
}
trap cleanup EXIT

### -------- STOP IMMICH --------
echo "Stopping Immich containers..."
docker compose down

### -------- PRE-FLIGHT --------
borg break-lock || true

### -------- BACKUP --------
BORG_STATS=$(
  borg create \
    --stats \
    --compression zstd,6 \
    ::immich-{now:%Y-%m-%dT%H:%M:%S} \
    "$IMMICH_ROOT/library" \
    "$IMMICH_ROOT/db-dumps" \
    "$IMMICH_ROOT/docker-compose.yml" \
    "$IMMICH_ROOT/.env" \
  2>&1
)

echo "$BORG_STATS"

### -------- PRUNE --------
echo "Running borg prune..."
set +e
borg prune \
  --list \
  --glob-archives 'immich-*' \
  --keep-daily=7 \
  --keep-weekly=4 \
  --keep-monthly=6
PRUNE_RC=$?
set -e
echo "borg prune exit code: $PRUNE_RC"

### -------- COMPACT --------
echo "Running borg compact..."
set +e
borg compact
COMPACT_RC=$?
set -e
echo "borg compact exit code: $COMPACT_RC"

### -------- SUCCESS EMAIL --------
{
  echo "✅ Immich backup completed successfully"
  echo "Date: $(date)"
  echo
  echo "📦 Backup statistics:"
  echo
  echo "$BORG_STATS"
  echo
  echo "🔔 Reminder: Perform a test restore monthly."
} | mail -s "Immich Backup SUCCESS" "$MAIL_TO" || echo "WARNING: mail failed (exit $?)"
