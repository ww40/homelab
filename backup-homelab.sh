#!/usr/bin/env bash
set -euo pipefail

trap 'echo "❌ BACKUP FAILED at $(date)"' ERR

REPO="/mnt/d/ww40/borg/homelab"
ARCHIVE="homelab-configs-$(date +%F_%H-%M)"
MAIL_TO="eyezopen@gmail.com"

# Environment (cron-safe)
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# Let borg fetch passphrase via sudo
export BORG_PASSCOMMAND="/usr/bin/sudo -n /usr/bin/cat /root/.config/borg/passphrase"

# Temporary log file
LOG_FILE=$(mktemp /tmp/borg-backup-XXXXXX.log)

# Capture all output
exec > >(tee -a "$LOG_FILE") 2>&1

echo "=== $(date) START backup-homelab ==="
echo "=== Borg create: $ARCHIVE ==="

/usr/bin/sudo /usr/bin/borg create --stats --compression zstd,6 \
  --exclude '/mnt/d/ww40/Docker/immich-app/library' \
  --exclude '/mnt/d/ww40/Docker/immich-app/library/**' \
  --exclude '/mnt/d/ww40/Docker/frigate/storage' \
  --exclude '/mnt/d/ww40/Docker/frigate/storage/**' \
  "$REPO::$ARCHIVE" \
  /mnt/d/ww40/Docker/caddy \
  /mnt/d/ww40/Docker/frigate \
  /mnt/d/ww40/Docker/immich-app \
  /mnt/d/ww40/Docker/nextcloud \
  /mnt/d/ww40/Docker/pihole \
  /mnt/d/ww40/Docker/plex \
  /mnt/d/ww40/Docker/vaultwarden \
  /home/ww40/uptime-kuma \
  /home/ww40/homepage

echo "=== Borg prune ==="
/usr/bin/sudo /usr/bin/borg prune -v --list "$REPO" \
  --glob-archives 'homelab-configs-*' \
  --keep-daily=7 \
  --keep-weekly=4 \
  --keep-monthly=6

echo "=== Borg compact ==="
/usr/bin/sudo /usr/bin/borg compact "$REPO"

echo "=== Done ==="
echo "✅ BACKUP SUCCESS at $(date)"

if ! mail -s "Borg Backup Report: $ARCHIVE" "$MAIL_TO" < "$LOG_FILE"; then
  echo "WARNING: Failed to send email"
fi

rm -f "$LOG_FILE"
