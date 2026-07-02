#!/usr/bin/env sh
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TOOLS_DIR="$ROOT_DIR/.tools"
VENV="$TOOLS_DIR/canadian-terrain-venv"
OUTPUT_DIR="${OUTPUT_DIR:-$ROOT_DIR/map_archives}"
MAX_ZOOM="${MAX_ZOOM:-11}"
BOUNDS="${BOUNDS:--139.10,48.20,-113.80,60.05}"
SOURCE_URL="${CDEM_SOURCE_URL:-https://datacube-prod-data-public.s3.ca-central-1.amazonaws.com/store/elevation/cdem-cdsm/cdem/cdem-canada-dem.tif}"

mkdir -p "$TOOLS_DIR" "$OUTPUT_DIR"
if [ ! -x "$VENV/bin/python" ]; then
  python3 -m venv "$VENV"
  "$VENV/bin/python" -m pip install --upgrade pip
  "$VENV/bin/python" -m pip install "numpy>=2,<3" "Pillow>=11,<13" "rasterio>=1.4,<2"
fi

if command -v pmtiles >/dev/null 2>&1; then
  PMTILES_BIN=$(command -v pmtiles)
else
  PMTILES_BIN=$($ROOT_DIR/scripts/install_pmtiles_tool.sh)
fi

MBTILES="$OUTPUT_DIR/bc-terrain.mbtiles"
"$VENV/bin/python" "$ROOT_DIR/scripts/build_canadian_terrain_archive.py" \
  --source "$SOURCE_URL" \
  --output "$MBTILES" \
  --maxzoom "$MAX_ZOOM" \
  --bounds="$BOUNDS"

rm -f "$OUTPUT_DIR/bc-terrain.pmtiles"
"$PMTILES_BIN" convert "$MBTILES" "$OUTPUT_DIR/bc-terrain.pmtiles"
rm -f "$MBTILES"
echo "Canadian CDEM terrain is ready at $OUTPUT_DIR/bc-terrain.pmtiles."
