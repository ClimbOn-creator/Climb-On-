# Offline map packs

Climb On divides British Columbia into six downloadable regions. Route, crag,
tour, path, comment, and picture data can be cached without a map-provider key.
GPS uses the phone's receiver and remains available without cell service.

Production 2D, satellite, and 3D downloads must use map data that permits
bulk offline storage. Do not point downloads at the public OpenStreetMap,
OpenTopoMap, or standard Esri World Imagery endpoints.

The repository now includes a self-hosted Cloudflare R2/Worker implementation
in `map_service/`. It serves open-data MapLibre styles and tiles without using
Google, Esri, OpenStreetMap's public tile server, or OpenTopoMap for offline
downloads.

After deploying the Worker, set one build value:

```text
--dart-define=OFFLINE_MAP_BASE_URL=https://maps.your-domain.ca
```

The app derives Clean 2D, Satellite, and Satellite 3D style URLs from that
address. The 3D choice uses the same satellite imagery with terrain enabled.
Individual style overrides remain available if the service is split later:

```text
--dart-define=OFFLINE_SATELLITE_STYLE_URL=https://maps.example.com/satellite/style.json
--dart-define=OFFLINE_3D_STYLE_URL=https://maps.example.com/terrain/style.json
--dart-define=OFFLINE_CLEAN_STYLE_URL=https://maps.example.com/clean/style.json
```

The native downloader saves each full region through zoom 13, then saves
high-detail tiles through zoom 16 around known crags and ski objectives. The
same style URL is used for display, so MapLibre automatically reads its offline
database when the device loses connectivity.

## Build and deployment

1. Run the archive preparation script. It installs the small `pmtiles` tool
   locally and selects the latest Protomaps v4 build automatically:

   ```sh
   ./scripts/prepare_open_map_archives.sh
   ./scripts/build_canadian_terrain_archive.sh
   ```

2. Create a cloud-minimized, true-colour Copernicus Sentinel-2 mosaic for BC as
   an RGB GeoTIFF. Keep its acquisition dates and processing notes for the app's
   store/licensing records, then run:

   ```sh
   ./scripts/build_sentinel_archive.sh /path/to/bc-sentinel-rgb-mosaic.tif
   ```

3. Create the `climb-on-maps` R2 bucket. Configure an `rclone` R2 remote, then:

   ```sh
   R2_REMOTE=r2:climb-on-maps ./scripts/deploy_open_map_service.sh
   ```

4. Give the Worker a custom HTTPS domain and set `OFFLINE_MAP_BASE_URL` in the
   app's Cloudflare/mobile build environment.

When the Sentinel mosaic is refreshed, update `SENTINEL_DATA_YEAR` in
`map_service/wrangler.toml` so its legal source notice matches the imagery.

The terrain archive is capped at zoom 11 and overzooms on the device. This keeps
optional 3D practical while preserving mountain-scale terrain. The Sentinel
mosaic is resampled to 20 m before tiling for the same reason.

The generated archives are deliberately ignored by Git; they can be many
gigabytes and belong in R2 rather than GitHub.

## Editing download sections

Run `supabase/offline_map_regions.sql` once. An app administrator can then open
Map, enable **Edit map**, choose **Edit download section**, and select any of the
six BC sections. The existing outline opens in the same point editor used for
approach and ski lines. Tap to add points, tap a numbered point and then the map
to move it, or clear the draft and retrace it. Saving publishes the boundary to
all users and caches it for offline use. Regular users have read-only access.
The native map engine accepts rectangular download areas, so the app converts
each saved polygon into narrow adjoining bands. Those bands follow the traced
shape and prevent the original large overlapping rectangles from returning.

The built-in outlines come from the Province of British Columbia's official
`WHSE_LEGAL_ADMIN_BOUNDARIES.ADM_TOURISM_REGIONS_SP` GIS layer. They are
packaged in `assets/data/bc_tourism_regions.geojson` under the Open Government
Licence – British Columbia. A boundary saved by an administrator overrides
only that region, so hand-traced adjustments are preserved while other regions
continue to use the official geometry.

## Data and attribution

- Basemap: Protomaps v4, derived from OpenStreetMap, distributed as an ODbL
  Produced Work. OpenStreetMap attribution is retained in the app and styles.
- Terrain: Natural Resources Canada Canadian Digital Elevation Model (CDEM),
  converted into Terrarium PMTiles. Retain the Open Government Licence –
  Canada and NRCan attribution included by the build script. The source COG is
  read directly from NRCan's public Canadian elevation data store.
- Satellite: modified Copernicus Sentinel-2 imagery. Retain the source dates,
  processing record, and the required Copernicus notice.

Sentinel-2 is approximately 10 m resolution. It is suitable for mountain-scale
navigation, snow cover, and terrain context, but is not a replacement for
licensed high-resolution aerial photography.
