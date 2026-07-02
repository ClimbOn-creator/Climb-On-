# Climb On open map service

This Cloudflare Worker serves Clean 2D, Satellite, and Satellite 3D MapLibre
styles plus standard Z/X/Y tiles from
PMTiles archives stored in the `climb-on-maps` R2 bucket.

Expected R2 objects:

- `bc-basemap.pmtiles` — Protomaps/OpenStreetMap vector basemap.
- `bc-terrain.pmtiles` — Terrarium terrain tiles generated from Natural
  Resources Canada's Canadian Digital Elevation Model (CDEM).
- `bc-satellite.pmtiles` — a processed Copernicus Sentinel-2 RGB mosaic.

The tile-serving portion follows the official Protomaps Cloudflare Worker
design. PMTiles is BSD-3-Clause; the basemap is an ODbL Produced Work and must
retain OpenStreetMap attribution. The styles keep all required attribution.

Run `npm run build` to verify the Worker or `npm run deploy` after the R2 bucket
and Cloudflare account are configured.
