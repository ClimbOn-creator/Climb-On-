import { layers, namedFlavor } from "@protomaps/basemaps";
import {
  Compression,
  EtagMismatch,
  PMTiles,
  RangeResponse,
  ResolvedValueCache,
  Source,
  TileType,
  tileTypeExt,
} from "pmtiles";

interface Env {
  ALLOWED_ORIGINS?: string;
  BUCKET: R2Bucket;
  CACHE_CONTROL?: string;
  PUBLIC_HOSTNAME?: string;
  SENTINEL_DATA_YEAR?: string;
}

class KeyNotFoundError extends Error {}

async function decompress(
  buffer: ArrayBuffer,
  compression: Compression,
): Promise<ArrayBuffer> {
  if (compression === Compression.None || compression === Compression.Unknown) {
    return buffer;
  }
  if (compression === Compression.Gzip) {
    const result = new Response(buffer).body?.pipeThrough(
      new DecompressionStream("gzip"),
    );
    return new Response(result).arrayBuffer();
  }
  throw new Error("Unsupported PMTiles compression");
}

const headerCache = new ResolvedValueCache(25, undefined, decompress);

class R2Source implements Source {
  constructor(
    private readonly env: Env,
    private readonly archiveName: string,
  ) {}

  getKey(): string {
    return this.archiveName;
  }

  async getBytes(
    offset: number,
    length: number,
    _signal?: AbortSignal,
    etag?: string,
  ): Promise<RangeResponse> {
    const response = await this.env.BUCKET.get(`${this.archiveName}.pmtiles`, {
      range: { offset, length },
      onlyIf: { etagMatches: etag },
    });
    if (!response) throw new KeyNotFoundError("Archive not found");
    if (!response.body) throw new EtagMismatch();
    return {
      data: await response.arrayBuffer(),
      etag: response.etag,
      cacheControl: response.httpMetadata?.cacheControl,
      expires: response.httpMetadata?.cacheExpiry?.toISOString(),
    };
  }
}

const tilePattern =
  /^\/(?<name>[a-zA-Z0-9._/-]+)\/(?<z>\d+)\/(?<x>\d+)\/(?<y>\d+)\.(?<ext>[a-z]+)$/;
const tileJsonPattern = /^\/(?<name>[a-zA-Z0-9._/-]+)\.json$/;

function corsHeaders(request: Request, env: Env): Headers {
  const headers = new Headers({ Vary: "Origin" });
  const origin = request.headers.get("Origin") ?? "";
  const allowed = (env.ALLOWED_ORIGINS ?? "").split(",");
  if (allowed.includes("*")) headers.set("Access-Control-Allow-Origin", "*");
  else if (allowed.includes(origin)) headers.set("Access-Control-Allow-Origin", origin);
  return headers;
}

function style(
  origin: string,
  kind: string,
  sentinelDataYear: string,
): Record<string, unknown> | null {
  const attribution =
    "<a href='https://protomaps.com'>Protomaps</a> © " +
    "<a href='https://openstreetmap.org/copyright'>OpenStreetMap contributors</a>";
  const basemapSource = {
    type: "vector",
    url: `${origin}/bc-basemap.json`,
    attribution,
  };
  const terrainSource = {
    type: "raster-dem",
    url: `${origin}/bc-terrain.json`,
    tileSize: 512,
    encoding: "terrarium",
    attribution:
      "Terrain © Natural Resources Canada CDEM; Contains information licensed under the <a href='https://open.canada.ca/en/open-government-licence-canada'>Open Government Licence – Canada</a>",
  };
  const satelliteSource = {
    type: "raster",
    url: `${origin}/bc-satellite.json`,
    tileSize: 256,
    attribution: `Contains modified Copernicus Sentinel-2 data (${sentinelDataYear})`,
  };
  const contourSource = {
    type: "raster",
    tiles: [`${origin}/contours/{z}/{x}/{y}.png`],
    tileSize: 256,
    minzoom: 8,
    maxzoom: 16,
    attribution:
      "Contours © Natural Resources Canada CanVec; Contains information licensed under the Open Government Licence – Canada",
  };
  const glyphs =
    "https://protomaps.github.io/basemaps-assets/fonts/{fontstack}/{range}.pbf";
  const sprite = "https://protomaps.github.io/basemaps-assets/sprites/v4/light";

  const baseLayers = layers("basemap", namedFlavor("light"), { lang: "en" });
  const labelLayers = layers("basemap", namedFlavor("light"), {
    lang: "en",
    labelsOnly: true,
  });
  const satelliteLabelLayers = labelLayers.map((layer) => {
    if (layer.type !== "symbol") return layer;
    return {
      ...layer,
      layout: {
        ...layer.layout,
        "text-rotation-alignment": "map",
        "text-pitch-alignment": "map",
        "icon-rotation-alignment": "map",
        "icon-pitch-alignment": "map",
      },
      paint: {
        ...layer.paint,
        "text-color": "#263238",
        "text-halo-color": "rgba(255, 255, 255, 0.94)",
        "text-halo-width": 1.5,
        "text-halo-blur": 0.15,
      },
    };
  });
  const hillshade = {
    id: "terrain-hillshade",
    type: "hillshade",
    source: "terrain",
    paint: {
      "hillshade-exaggeration": 0.38,
      "hillshade-shadow-color": "#31433a",
      "hillshade-highlight-color": "#ffffff",
      "hillshade-accent-color": "#73826f",
    },
  };

  if (kind === "clean") {
    return {
      version: 8,
      name: "Climb On Clean",
      glyphs,
      sprite,
      sources: { basemap: basemapSource },
      layers: baseLayers,
    };
  }

  if (kind === "satellite") {
    return {
      version: 8,
      name: "Climb On Sentinel-2 Satellite",
      glyphs,
      sprite,
      sources: {
        basemap: basemapSource,
        satellite: satelliteSource,
      },
      layers: [
        { id: "satellite", type: "raster", source: "satellite" },
        ...satelliteLabelLayers,
      ],
    };
  }

  if (kind === "3d") {
    return {
      version: 8,
      name: "Climb On Satellite 3D + Topo",
      glyphs,
      sprite,
      sources: {
        basemap: basemapSource,
        satellite: satelliteSource,
        terrain: terrainSource,
        contours: contourSource,
      },
      terrain: { source: "terrain", exaggeration: 1.12 },
      layers: [
        {
          id: "satellite",
          type: "raster",
          source: "satellite",
          paint: { "raster-saturation": -0.05, "raster-contrast": 0.08 },
        },
        hillshade,
        {
          id: "topographic-contours",
          type: "raster",
          source: "contours",
          minzoom: 8,
          paint: { "raster-opacity": 0.72 },
        },
        ...satelliteLabelLayers,
      ],
    };
  }
  return null;
}

function tileLongitude(x: number, z: number): number {
  return (x / 2 ** z) * 360 - 180;
}

function tileLatitude(y: number, z: number): number {
  const radians = Math.atan(Math.sinh(Math.PI * (1 - (2 * y) / 2 ** z)));
  return (radians * 180) / Math.PI;
}

async function contourResponse(request: Request, env: Env): Promise<Response> {
  const url = new URL(request.url);
  const match = url.pathname.match(/^\/contours\/(\d+)\/(\d+)\/(\d+)\.png$/);
  if (!match) return new Response("Not found", { status: 404 });

  const z = Number(match[1]);
  const x = Number(match[2]);
  const y = Number(match[3]);
  if (z < 8 || z > 16 || x < 0 || y < 0 || x >= 2 ** z || y >= 2 ** z) {
    return new Response(null, { status: 204, headers: corsHeaders(request, env) });
  }

  const west = tileLongitude(x, z);
  const east = tileLongitude(x + 1, z);
  const north = tileLatitude(y, z);
  const south = tileLatitude(y + 1, z);
  const upstream = new URL("https://maps.geogratis.gc.ca/wms/canvec_en");
  upstream.search = new URLSearchParams({
    service: "WMS",
    version: "1.1.1",
    request: "GetMap",
    layers: "contour_elevation_50k,contour_approximative_50k,contour_depression_50k",
    styles: "",
    format: "image/png",
    transparent: "true",
    srs: "EPSG:4326",
    bbox: `${west},${south},${east},${north}`,
    width: "256",
    height: "256",
  }).toString();

  const cached = await caches.default.match(request);
  if (cached) return cached;
  const response = await fetch(upstream, {
    headers: { "User-Agent": "Climb On map service (contour tile proxy)" },
  });
  if (!response.ok) return new Response("Contour service unavailable", { status: 502 });

  const headers = corsHeaders(request, env);
  headers.set("Content-Type", response.headers.get("Content-Type") ?? "image/png");
  headers.set("Cache-Control", "public, max-age=604800");
  const result = new Response(response.body, { headers });
  await caches.default.put(request, result.clone());
  return result;
}

async function tileResponse(
  request: Request,
  env: Env,
  ctx: ExecutionContext,
): Promise<Response> {
  const url = new URL(request.url);
  const tileMatch = url.pathname.match(tilePattern);
  const jsonMatch = url.pathname.match(tileJsonPattern);
  const groups = tileMatch?.groups ?? jsonMatch?.groups;
  if (!groups) return new Response("Not found", { status: 404 });

  const name = groups.name;
  const archive = new PMTiles(new R2Source(env, name), headerCache, decompress);
  const headers = corsHeaders(request, env);
  headers.set("Cache-Control", env.CACHE_CONTROL ?? "public, max-age=86400");

  try {
    if (jsonMatch) {
      headers.set("Content-Type", "application/json");
      const hostname = env.PUBLIC_HOSTNAME ?? url.host;
      const data = await archive.getTileJson(`https://${hostname}/${name}`);
      return new Response(JSON.stringify(data), { headers });
    }

    const z = Number(groups.z);
    const x = Number(groups.x);
    const y = Number(groups.y);
    const extension = groups.ext;
    const header = await archive.getHeader();
    const expected: Record<string, TileType> = {
      mvt: TileType.Mvt,
      pbf: TileType.Mvt,
      png: TileType.Png,
      jpg: TileType.Jpeg,
      jpeg: TileType.Jpeg,
      webp: TileType.Webp,
      avif: TileType.Avif,
    };
    if (expected[extension] !== header.tileType && tileTypeExt(header.tileType)) {
      return new Response("Tile extension does not match archive", {
        status: 400,
        headers,
      });
    }
    const cached = await caches.default.match(request);
    if (cached) return cached;
    const tile = await archive.getZxy(z, x, y);
    if (!tile) return new Response(null, { status: 204, headers });
    const contentTypes: Partial<Record<TileType, string>> = {
      [TileType.Mvt]: "application/x-protobuf",
      [TileType.Png]: "image/png",
      [TileType.Jpeg]: "image/jpeg",
      [TileType.Webp]: "image/webp",
      [TileType.Avif]: "image/avif",
    };
    headers.set("Content-Type", contentTypes[header.tileType] ?? "application/octet-stream");
    const response = new Response(tile.data, { headers });
    ctx.waitUntil(caches.default.put(request, response.clone()));
    return response;
  } catch (error) {
    if (error instanceof KeyNotFoundError) {
      return new Response("Map archive not installed", { status: 404, headers });
    }
    throw error;
  }
}

export default {
  async fetch(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
    if (request.method === "OPTIONS") {
      return new Response(null, { status: 204, headers: corsHeaders(request, env) });
    }
    if (request.method !== "GET" && request.method !== "HEAD") {
      return new Response("Method not allowed", { status: 405 });
    }
    const url = new URL(request.url);
    if (url.pathname === "/health") {
      return Response.json({ ok: true, service: "climb-on-open-maps" });
    }
    const styleMatch = url.pathname.match(/^\/styles\/(clean|satellite|3d)\.json$/);
    if (styleMatch) {
      const value = style(
        url.origin,
        styleMatch[1],
        env.SENTINEL_DATA_YEAR ?? "2026",
      );
      const headers = corsHeaders(request, env);
      headers.set("Content-Type", "application/json");
      headers.set("Cache-Control", "public, max-age=3600");
      return new Response(JSON.stringify(value), { headers });
    }
    if (url.pathname.startsWith("/contours/")) {
      return contourResponse(request, env);
    }
    return tileResponse(request, env, ctx);
  },
};
