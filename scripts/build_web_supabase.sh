#!/usr/bin/env sh
set -eu

flutter build web --release --dart-define-from-file=.env.local.json
