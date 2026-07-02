#!/usr/bin/env sh
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
INSTALL_DIR="$ROOT_DIR/.tools"
TARGET="$INSTALL_DIR/pmtiles"

if [ -x "$TARGET" ]; then
  echo "$TARGET"
  exit 0
fi

for tool in curl python3; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "$tool is required to install pmtiles." >&2
    exit 1
  fi
done

case "$(uname -s)" in
  Darwin) PLATFORM=Darwin ;;
  Linux) PLATFORM=Linux ;;
  *) echo "Automatic pmtiles install supports macOS and Linux." >&2; exit 1 ;;
esac

case "$(uname -m)" in
  arm64|aarch64) ARCH=arm64 ;;
  x86_64|amd64) ARCH=x86_64 ;;
  *) echo "Unsupported processor for automatic pmtiles install." >&2; exit 1 ;;
esac

mkdir -p "$INSTALL_DIR"
METADATA="$INSTALL_DIR/pmtiles-release.json"
curl -fsSL https://api.github.com/repos/protomaps/go-pmtiles/releases/latest \
  -o "$METADATA"
DOWNLOAD_URL=$(python3 - "$METADATA" "$PLATFORM" "$ARCH" <<'PY'
import json, sys
release, platform, arch = sys.argv[1:]
with open(release, encoding="utf-8") as source:
    assets = json.load(source)["assets"]
needle = f"_{platform}_{arch}"
for asset in assets:
    if needle in asset["name"]:
        print(asset["browser_download_url"])
        break
else:
    raise SystemExit(f"No pmtiles release found for {platform} {arch}")
PY
)

ARCHIVE="$INSTALL_DIR/pmtiles-download"
curl -fL "$DOWNLOAD_URL" -o "$ARCHIVE"
TEMP_DIR="$INSTALL_DIR/pmtiles-unpack"
rm -rf "$TEMP_DIR"
mkdir -p "$TEMP_DIR"
case "$DOWNLOAD_URL" in
  *.zip) unzip -q "$ARCHIVE" -d "$TEMP_DIR" ;;
  *.tar.gz) tar -xzf "$ARCHIVE" -C "$TEMP_DIR" ;;
  *) echo "Unknown pmtiles archive format." >&2; exit 1 ;;
esac

FOUND=$(find "$TEMP_DIR" -type f -name pmtiles -print -quit)
if [ -z "$FOUND" ]; then
  echo "The pmtiles binary was not found in the release." >&2
  exit 1
fi
mv "$FOUND" "$TARGET"
chmod +x "$TARGET"
rm -rf "$ARCHIVE" "$TEMP_DIR" "$METADATA"
echo "$TARGET"
