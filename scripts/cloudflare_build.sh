#!/usr/bin/env sh
set -eu

if ! command -v flutter >/dev/null 2>&1; then
  mkdir -p .cloudflare
  git clone --depth 1 --branch stable https://github.com/flutter/flutter.git .cloudflare/flutter
  export PATH="$PWD/.cloudflare/flutter/bin:$PATH"
fi

flutter --version
flutter config --enable-web
flutter pub get

flutter build web --release \
  --dart-define=SUPABASE_URL="${SUPABASE_URL:-}" \
  --dart-define=SUPABASE_PUBLISHABLE_KEY="${SUPABASE_PUBLISHABLE_KEY:-}" \
  --dart-define=SUPABASE_AUTH_REDIRECT_URL="${SUPABASE_AUTH_REDIRECT_URL:-}"
