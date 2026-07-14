#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT="$ROOT/examples/javascript-helloworld"
OUT_DIR="$PROJECT/build/npl"
OUT="$OUT_DIR/dev.hmclnex.example.javascript.helloworld-v1.0.0.npl"
mkdir -p "$OUT_DIR"
rm -f "$OUT"
cd "$PROJECT"
zip -r "$OUT" plugin.json main.js
echo "Created $OUT"
