#!/usr/bin/env sh
set -eu

./scripts/build_web_supabase.sh

cd build/web
zip -qr ../../climb_on_web_upload.zip .
