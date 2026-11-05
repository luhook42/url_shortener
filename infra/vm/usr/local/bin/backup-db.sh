#!/usr/bin/env bash
set -euo pipefail
umask 077
BACKUP_DIR=/var/backups/url_shortener
BUCKET=gs://luhook42-shortener-backups-e985c781/db
mkdir -p "$BACKUP_DIR"
cd /home/luhook42/url_shortener
STAMP=$(date -u +%Y%m%dT%H%M%SZ)
TMP="$BACKUP_DIR/.tmp-$STAMP"
trap 'rm -f "$TMP"' EXIT
docker compose exec -T db sh -c 'pg_dump -U "${POSTGRES_USER:-postgres}" "$POSTGRES_DB"' | gzip > "$TMP"
FILE="$BACKUP_DIR/url_shortener-$STAMP.sql.gz"
mv "$TMP" "$FILE"
gcloud storage cp "$FILE" "$BUCKET/$(basename "$FILE")"
find "$BACKUP_DIR" -name 'url_shortener-*.sql.gz' -mtime +7 -delete
source /etc/backup-db.env
curl -fsS -m 10 --retry 3 -o /dev/null "$HC_URL" || echo "heartbeat ping failed" >&2
