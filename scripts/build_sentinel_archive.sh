#!/usr/bin/env sh
set -eu

if [ "$#" -ne 1 ]; then
  echo "Usage: $0 /path/to/bc-sentinel-rgb-mosaic.tif"
  exit 1
fi

for tool in gdalwarp gdal_translate gdaladdo pmtiles; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "$tool is required but is not installed."
    exit 1
  fi
done

INPUT="$1"
OUTPUT_DIR="${OUTPUT_DIR:-map_archives}"
WORK_DIR="$OUTPUT_DIR/.sentinel-work"
mkdir -p "$WORK_DIR"

gdalwarp \
  -t_srs EPSG:3857 \
  -te_srs EPSG:4326 \
  -te -139.10 48.20 -113.80 60.05 \
  -r cubic \
  -co TILED=YES \
  -co COMPRESS=DEFLATE \
  "$INPUT" "$WORK_DIR/bc-sentinel-3857.tif"

gdal_translate \
  -of MBTILES \
  -co TILE_FORMAT=JPEG \
  -co QUALITY=85 \
  -co ZOOM_LEVEL_STRATEGY=UPPER \
  "$WORK_DIR/bc-sentinel-3857.tif" "$WORK_DIR/bc-satellite.mbtiles"

gdaladdo -r average "$WORK_DIR/bc-satellite.mbtiles" 2 4 8 16 32 64 128 256
pmtiles convert "$WORK_DIR/bc-satellite.mbtiles" "$OUTPUT_DIR/bc-satellite.pmtiles"

echo "Sentinel-2 satellite archive is ready at $OUTPUT_DIR/bc-satellite.pmtiles."
