#!/usr/bin/env python3
"""Convert the NRCan CDEM cloud-optimized GeoTIFF to Terrarium MBTiles."""

from __future__ import annotations

import argparse
import io
import math
import os
import sqlite3
from pathlib import Path

import numpy as np
import rasterio
from PIL import Image
from rasterio.enums import Resampling
from rasterio.transform import from_origin
from rasterio.vrt import WarpedVRT
from rasterio.windows import Window

WEB_MERCATOR_LIMIT = 20037508.342789244
DEFAULT_BOUNDS = (-139.10, 48.20, -113.80, 60.05)


def tile_x(lon: float, zoom: int) -> int:
    count = 1 << zoom
    return max(0, min(count - 1, int((lon + 180.0) / 360.0 * count)))


def tile_y(lat: float, zoom: int) -> int:
    count = 1 << zoom
    latitude = max(-85.05112878, min(85.05112878, lat))
    radians = math.radians(latitude)
    value = (1.0 - math.asinh(math.tan(radians)) / math.pi) / 2.0
    return max(0, min(count - 1, int(value * count)))


def encode_terrarium(elevation: np.ndarray) -> bytes:
    values = np.nan_to_num(elevation, nan=0.0, posinf=0.0, neginf=0.0)
    shifted = np.clip(values + 32768.0, 0.0, 65535.996)
    whole = np.floor(shifted)
    red = np.floor(shifted / 256.0)
    green = np.mod(whole, 256.0)
    blue = np.floor((shifted - whole) * 256.0)
    rgb = np.dstack((red, green, blue)).astype(np.uint8)
    output = io.BytesIO()
    Image.fromarray(rgb).save(output, format="PNG", compress_level=6)
    return output.getvalue()


def decode_terrarium(png: bytes | None) -> np.ndarray:
    if png is None:
        return np.zeros((256, 256), dtype=np.float32)
    rgb = np.asarray(Image.open(io.BytesIO(png)).convert("RGB"), dtype=np.float32)
    return rgb[:, :, 0] * 256.0 + rgb[:, :, 1] + rgb[:, :, 2] / 256.0 - 32768.0


def stored_tile(
    database: sqlite3.Connection,
    zoom: int,
    x: int,
    y: int,
) -> bytes | None:
    tms_y = (1 << zoom) - 1 - y
    row = database.execute(
        "SELECT tile_data FROM tiles WHERE zoom_level=? AND tile_column=? AND tile_row=?",
        (zoom, x, tms_y),
    ).fetchone()
    return None if row is None else row[0]


def insert_tile(
    database: sqlite3.Connection,
    zoom: int,
    x: int,
    y: int,
    png: bytes,
) -> None:
    tms_y = (1 << zoom) - 1 - y
    database.execute(
        "INSERT INTO tiles VALUES (?, ?, ?, ?)",
        (zoom, x, tms_y, png),
    )


def create_database(path: Path, bounds: tuple[float, ...], max_zoom: int) -> sqlite3.Connection:
    if path.exists():
        path.unlink()
    database = sqlite3.connect(path)
    database.executescript(
        """
        PRAGMA journal_mode=WAL;
        PRAGMA synchronous=NORMAL;
        CREATE TABLE metadata (name TEXT, value TEXT);
        CREATE TABLE tiles (
          zoom_level INTEGER,
          tile_column INTEGER,
          tile_row INTEGER,
          tile_data BLOB
        );
        CREATE UNIQUE INDEX tile_index ON tiles
          (zoom_level, tile_column, tile_row);
        """
    )
    metadata = {
        "name": "Climb On Canadian CDEM Terrain",
        "type": "overlay",
        "version": "1",
        "description": "Terrarium terrain generated from Natural Resources Canada CDEM",
        "format": "png",
        "bounds": ",".join(str(value) for value in bounds),
        "minzoom": "0",
        "maxzoom": str(max_zoom),
        "attribution": "Terrain © Natural Resources Canada CDEM; Contains information licensed under the Open Government Licence – Canada",
    }
    database.executemany("INSERT INTO metadata VALUES (?, ?)", metadata.items())
    database.commit()
    return database


def build(source: str, output: Path, bounds: tuple[float, ...], max_zoom: int) -> None:
    west, south, east, north = bounds
    database = create_database(output, bounds, max_zoom)
    os.environ.setdefault("GDAL_CACHEMAX", "768")
    os.environ.setdefault("CPL_VSIL_CURL_CACHE_SIZE", "200000000")
    os.environ.setdefault("GDAL_HTTP_MULTIPLEX", "YES")

    with rasterio.Env(
        GDAL_DISABLE_READDIR_ON_OPEN="EMPTY_DIR",
        CPL_VSIL_CURL_ALLOWED_EXTENSIONS=".tif",
    ):
        with rasterio.open(source) as dataset:
            world_pixels = 256 * (1 << max_zoom)
            resolution = 2 * WEB_MERCATOR_LIMIT / world_pixels
            with WarpedVRT(
                dataset,
                crs="EPSG:3857",
                transform=from_origin(
                    -WEB_MERCATOR_LIMIT,
                    WEB_MERCATOR_LIMIT,
                    resolution,
                    resolution,
                ),
                width=world_pixels,
                height=world_pixels,
                nodata=0,
                resampling=Resampling.bilinear,
            ) as terrain:
                x_start = tile_x(west, max_zoom)
                x_end = tile_x(east, max_zoom)
                y_start = tile_y(north, max_zoom)
                y_end = tile_y(south, max_zoom)
                total = (x_end - x_start + 1) * (y_end - y_start + 1)
                completed = 0
                for x in range(x_start, x_end + 1):
                    for y in range(y_start, y_end + 1):
                        window = Window(x * 256, y * 256, 256, 256)
                        values = terrain.read(
                            1,
                            window=window,
                            out_shape=(256, 256),
                            resampling=Resampling.bilinear,
                        )
                        insert_tile(
                            database,
                            max_zoom,
                            x,
                            y,
                            encode_terrarium(values),
                        )
                        completed += 1
                        if completed % 100 == 0 or completed == total:
                            print(
                                f"zoom {max_zoom}: {completed}/{total} source tiles",
                                flush=True,
                            )
                database.commit()

    for zoom in range(max_zoom - 1, -1, -1):
        x_start, x_end = tile_x(west, zoom), tile_x(east, zoom)
        y_start, y_end = tile_y(north, zoom), tile_y(south, zoom)
        total = (x_end - x_start + 1) * (y_end - y_start + 1)
        completed = 0
        for x in range(x_start, x_end + 1):
            for y in range(y_start, y_end + 1):
                canvas = np.zeros((512, 512), dtype=np.float32)
                for offset_x in range(2):
                    for offset_y in range(2):
                        child = decode_terrarium(
                            stored_tile(
                                database,
                                zoom + 1,
                                x * 2 + offset_x,
                                y * 2 + offset_y,
                            )
                        )
                        row = offset_y * 256
                        column = offset_x * 256
                        canvas[row : row + 256, column : column + 256] = child
                reduced = np.asarray(
                    Image.fromarray(canvas).resize(
                        (256, 256),
                        resample=Image.Resampling.BILINEAR,
                    ),
                    dtype=np.float32,
                )
                insert_tile(database, zoom, x, y, encode_terrarium(reduced))
                completed += 1
        database.commit()
        print(f"zoom {zoom}: {completed}/{total} derived tiles", flush=True)
    database.execute("PRAGMA journal_mode=DELETE")
    database.close()


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", required=True)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--maxzoom", type=int, default=11)
    parser.add_argument(
        "--bounds",
        default=",".join(str(value) for value in DEFAULT_BOUNDS),
        help="west,south,east,north",
    )
    arguments = parser.parse_args()
    bounds = tuple(float(value) for value in arguments.bounds.split(","))
    if len(bounds) != 4:
        raise SystemExit("--bounds must contain west,south,east,north")
    build(arguments.source, arguments.output, bounds, arguments.maxzoom)


if __name__ == "__main__":
    main()
