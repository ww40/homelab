#!/usr/bin/env bash
set -euo pipefail

REPO="/mnt/d/ww40/borg/homelab"
ARCHIVE="homelab-configs-$(date +%F_%H-%M)"

# Run borg as root so it can read container-owned dirs (e.g. Immich postgres)
SUDO_BORG="sudo -E borg"

# Tell borg how to get the passphrase (no prompts)
export BORG_PASSCOMMAND="cat /root/.config/borg/passphrase"

echo "=== Borg create: $ARCHIVE ==="

$SUDO_BORG create --stats --compression zstd,6 \
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
$SUDO_BORG prune -v --list "$REPO" \
  --glob-archives 'homelab-configs-*' \
  --keep-daily=7 \
  --keep-weekly=4 \
  --keep-monthly=6

echo "=== Borg compact ==="
$SUDO_BORG compact "$REPO"

echo "=== Done ==="
