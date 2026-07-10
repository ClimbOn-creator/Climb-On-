#!/usr/bin/env sh
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
if command -v pmtiles >/dev/null 2>&1; then
  PMTILES_BIN=$(command -v pmtiles)
else
  PMTILES_BIN=$($ROOT_DIR/scripts/install_pmtiles_tool.sh)
fi

if [ -z "${PROTOMAPS_SOURCE_URL:-}" ]; then
  echo "Finding the latest Protomaps open basemap…"
  PROTOMAPS_SOURCE_URL=$(curl -fsSL \
    https://build-metadata.protomaps.dev/builds.json | \
    python3 -c 'import json,sys; builds=json.load(sys.stdin); print("https://build.protomaps.com/" + max(builds, key=lambda item: item["key"])["key"])')
fi

OUTPUT_DIR="${OUTPUT_DIR:-map_archives}"
BC_BBOX="-139.10,48.20,-113.80,60.05"
MAX_ZOOM="${MAX_ZOOM:-12}"

mkdir -p "$OUTPUT_DIR"

"$PMTILES_BIN" extract "$PROTOMAPS_SOURCE_URL" "$OUTPUT_DIR/bc-basemap.pmtiles" \
  --bbox="$BC_BBOX" \
  --maxzoom="$MAX_ZOOM"

echo "The clean 2D basemap is ready in $OUTPUT_DIR."
echo "Build Canadian terrain with scripts/build_canadian_terrain_archive.sh."
echo "Build bc-satellite.pmtiles separately with scripts/build_sentinel_archive.sh."
