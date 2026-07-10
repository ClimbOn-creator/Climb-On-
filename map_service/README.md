# Climb On open map service

This Cloudflare Worker serves Clean 2D, Satellite, and Satellite 3D MapLibre
styles plus standard Z/X/Y tiles from
PMTiles archives stored in the `climb-on-maps` R2 bucket.

Expected R2 objects:

- `bc-basemap.pmtiles` — Protomaps/OpenStreetMap vector basemap.
- `bc-terrain.pmtiles` — Terrarium terrain tiles generated from Natural
  Resources Canada's Canadian Digital Elevation Model (CDEM).
- Satellite imagery is streamed from Esri World Imagery and is not stored in R2.

The 3D style combines the same satellite imagery used by the flat satellite
style with the existing terrain archive. It does not require another R2 object.

The tile-serving portion follows the official Protomaps Cloudflare Worker
design. PMTiles is BSD-3-Clause; the basemap is an ODbL Produced Work and must
retain OpenStreetMap attribution. The styles keep all required attribution.

Run `npm run build` to verify the Worker or `npm run deploy` after the R2 bucket
and Cloudflare account are configured.
