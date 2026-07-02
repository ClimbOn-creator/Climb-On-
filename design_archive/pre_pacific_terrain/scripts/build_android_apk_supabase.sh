#!/usr/bin/env sh
set -eu

flutter build apk --release --dart-define-from-file=.env.local.json
