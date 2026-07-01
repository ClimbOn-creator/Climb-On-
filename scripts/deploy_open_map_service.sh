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
for archive in bc-basemap.pmtiles bc-terrain.pmtiles bc-satellite.pmtiles; do
  if [ ! -f "$ARCHIVE_DIR/$archive" ]; then
    echo "Missing $ARCHIVE_DIR/$archive"
    exit 1
  fi
  rclone copyto "$ARCHIVE_DIR/$archive" "$R2_REMOTE/$archive" \
    --progress \
    --s3-chunk-size=256M \
    --s3-upload-concurrency=2
done

cd map_service
npm install
npm run deploy
