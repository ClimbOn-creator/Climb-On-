#!/usr/bin/env sh
set -eu

for tool in rclone npm; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "$tool is required but is not installed."
    exit 1
  fi
done

if [ -z "${R2_REMOTE:-}" ]; then
  echo "Set R2_REMOTE to the configured rclone destination, for example r2:climb-on-maps."
  exit 1
fi

ARCHIVE_DIR="${ARCHIVE_DIR:-map_archives}"
MAX_ARCHIVE_BYTES="${MAX_ARCHIVE_BYTES:-8589934592}"
TOTAL_ARCHIVE_BYTES=0
ARCHIVES="bc-basemap.pmtiles bc-terrain.pmtiles"
if [ -f "$ARCHIVE_DIR/bc-satellite.pmtiles" ]; then
  ARCHIVES="$ARCHIVES bc-satellite.pmtiles"
fi
for archive in $ARCHIVES; do
  if [ ! -f "$ARCHIVE_DIR/$archive" ]; then
    echo "Missing $ARCHIVE_DIR/$archive"
    exit 1
  fi
  if stat -f%z "$ARCHIVE_DIR/$archive" >/dev/null 2>&1; then
    archive_bytes=$(stat -f%z "$ARCHIVE_DIR/$archive")
  else
    archive_bytes=$(stat -c%s "$ARCHIVE_DIR/$archive")
  fi
  TOTAL_ARCHIVE_BYTES=$((TOTAL_ARCHIVE_BYTES + archive_bytes))
done

if [ "$TOTAL_ARCHIVE_BYTES" -gt "$MAX_ARCHIVE_BYTES" ]; then
  echo "Archives total $TOTAL_ARCHIVE_BYTES bytes, above the $MAX_ARCHIVE_BYTES-byte safety limit."
  echo "Nothing was uploaded. Reduce archive zoom/detail before deploying."
  exit 1
fi

echo "Archive safety check passed: $TOTAL_ARCHIVE_BYTES of $MAX_ARCHIVE_BYTES bytes."
for archive in $ARCHIVES; do
  rclone copyto "$ARCHIVE_DIR/$archive" "$R2_REMOTE/$archive" \
    --progress \
    --s3-chunk-size=256M \
    --s3-upload-concurrency=2
done

cd map_service
npm install
npm run deploy
