#!/usr/bin/env sh
set -eu

if ! command -v pmtiles >/dev/null 2>&1; then
  echo "Install the pmtiles command-line tool first: https://docs.protomaps.com/guide/getting-started"
  exit 1
fi

if [ -z "${PROTOMAPS_SOURCE_URL:-}" ]; then
  echo "Set PROTOMAPS_SOURCE_URL to a current v4 daily build from https://maps.protomaps.com/builds"
  exit 1
fi

OUTPUT_DIR="${OUTPUT_DIR:-map_archives}"
MAPTERHORN_SOURCE_URL="${MAPTERHORN_SOURCE_URL:-https://download.mapterhorn.com/planet.pmtiles}"
BC_BBOX="-139.10,48.20,-113.80,60.05"

mkdir -p "$OUTPUT_DIR"

pmtiles extract "$PROTOMAPS_SOURCE_URL" "$OUTPUT_DIR/bc-basemap.pmtiles" \
  --bbox="$BC_BBOX" \
  --maxzoom=15

pmtiles extract "$MAPTERHORN_SOURCE_URL" "$OUTPUT_DIR/bc-terrain.pmtiles" \
  --bbox="$BC_BBOX"

echo "Basemap and terrain archives are ready in $OUTPUT_DIR."
echo "Build bc-satellite.pmtiles separately with scripts/build_sentinel_archive.sh."
