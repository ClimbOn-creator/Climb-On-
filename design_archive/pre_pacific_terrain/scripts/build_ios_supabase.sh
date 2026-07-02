#!/usr/bin/env sh
set -eu

flutter build ios --release --dart-define-from-file=.env.local.json
