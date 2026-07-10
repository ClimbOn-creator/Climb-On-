#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
RUN_DIR="${TMPDIR:-/tmp}/climb_on_macos_run"

mkdir -p "$RUN_DIR"
rsync -a --delete \
  --exclude='.git' \
  --exclude='.dart_tool' \
  --exclude='build' \
  "$ROOT_DIR/" "$RUN_DIR/"

cd "$RUN_DIR"
flutter pub get
exec flutter run -d macos --dart-define-from-file=.env.local.json "$@"
