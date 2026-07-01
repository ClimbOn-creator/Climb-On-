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
    attribution: "Terrain © Mapterhorn and source-data contributors",
  };
  const glyphs =
    "https://protomaps.github.io/basemaps-assets/fonts/{fontstack}/{range}.pbf";
  const sprite = "https://protomaps.github.io/basemaps-assets/sprites/v4/light";

  const baseLayers = layers("basemap", namedFlavor("light"), { lang: "en" });
  const labelLayers = layers("basemap", namedFlavor("light"), {
    lang: "en",
    labelsOnly: true,
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
        satellite: {
          type: "raster",
          url: `${origin}/bc-satellite.json`,
          tileSize: 256,
          attribution: `Contains modified Copernicus Sentinel-2 data (${sentinelDataYear})`,
        },
      },
      layers: [
        { id: "satellite", type: "raster", source: "satellite" },
        ...labelLayers,
      ],
    };
  }

  if (kind === "topo" || kind === "3d") {
    const firstLabel = baseLayers.findIndex((layer) => layer.type === "symbol");
    const topoLayers = [...baseLayers];
    topoLayers.splice(firstLabel < 0 ? topoLayers.length : firstLabel, 0, hillshade as never);
    return {
      version: 8,
      name: kind === "3d" ? "Climb On 3D Terrain" : "Climb On Topo",
      glyphs,
      sprite,
      sources: { basemap: basemapSource, terrain: terrainSource },
      ...(kind === "3d"
        ? { terrain: { source: "terrain", exaggeration: 1.12 } }
        : {}),
      layers: topoLayers,
    };
  }
  return null;
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
    const styleMatch = url.pathname.match(/^\/styles\/(clean|satellite|topo|3d)\.json$/);
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
    return tileResponse(request, env, ctx);
  },
};
