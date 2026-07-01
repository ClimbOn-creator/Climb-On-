# Offline map packs

Climb On divides British Columbia into six downloadable regions. Route, crag,
tour, path, comment, and picture data can be cached without a map-provider key.
GPS uses the phone's receiver and remains available without cell service.

Production satellite, topo, and 3D downloads must use map data that permits
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

The app derives Clean, Satellite, Topo, and 3D style URLs from that address.
Individual style overrides remain available if the service is split later:

```text
--dart-define=OFFLINE_SATELLITE_STYLE_URL=https://maps.example.com/satellite/style.json
--dart-define=OFFLINE_TOPO_STYLE_URL=https://maps.example.com/topo/style.json
--dart-define=OFFLINE_3D_STYLE_URL=https://maps.example.com/terrain/style.json
--dart-define=OFFLINE_CLEAN_STYLE_URL=https://maps.example.com/clean/style.json
```

The native downloader saves each full region through zoom 13, then saves
high-detail tiles through zoom 16 around known crags and ski objectives. The
same style URL is used for display, so MapLibre automatically reads its offline
database when the device loses connectivity.

## Build and deployment

1. Install the `pmtiles` command-line tool.
2. Pick a current Protomaps v4 daily build URL and run:

   ```sh
   PROTOMAPS_SOURCE_URL=https://build.protomaps.com/YYYYMMDD.pmtiles \
     ./scripts/prepare_open_map_archives.sh
   ```

3. Create a cloud-minimized, true-colour Copernicus Sentinel-2 mosaic for BC as
   an RGB GeoTIFF. Keep its acquisition dates and processing notes for the app's
   store/licensing records, then run:

   ```sh
   ./scripts/build_sentinel_archive.sh /path/to/bc-sentinel-rgb-mosaic.tif
   ```

4. Create the `climb-on-maps` R2 bucket. Configure an `rclone` R2 remote, then:

   ```sh
   R2_REMOTE=r2:climb-on-maps ./scripts/deploy_open_map_service.sh
   ```

5. Give the Worker a custom HTTPS domain and set `OFFLINE_MAP_BASE_URL` in the
   app's Cloudflare/mobile build environment.

When the Sentinel mosaic is refreshed, update `SENTINEL_DATA_YEAR` in
`map_service/wrangler.toml` so its legal source notice matches the imagery.

The generated archives are deliberately ignored by Git; they can be many
gigabytes and belong in R2 rather than GitHub.

## Data and attribution

- Basemap: Protomaps v4, derived from OpenStreetMap, distributed as an ODbL
  Produced Work. OpenStreetMap attribution is retained in the app and styles.
- Terrain: Mapterhorn Terrarium PMTiles. Retain Mapterhorn/source attribution.
- Satellite: modified Copernicus Sentinel-2 imagery. Retain the source dates,
  processing record, and the required Copernicus notice.

Sentinel-2 is approximately 10 m resolution. It is suitable for mountain-scale
navigation, snow cover, and terrain context, but is not a replacement for
licensed high-resolution aerial photography.
