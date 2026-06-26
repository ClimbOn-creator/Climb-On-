#!/usr/bin/env sh
set -eu

flutter build web --release \
  --pwa-strategy=none \
  --dart-define-from-file=.env.local.json

cp web/cache_reset_service_worker.js build/web/flutter_service_worker.js
