#!/usr/bin/env bash
set -euo pipefail

binary="dist/x265-linux-x86_64-musl-static"

file "$binary"
"$binary" --version

if file "$binary" | grep -q "dynamically linked"; then
  echo "The x265 binary is dynamically linked"
  exit 1
fi

(
  cd dist
  sha256sum --check x265-linux-x86_64-musl-static.sha256
)

tar -tzf dist/x265-linux-x86_64-musl-static.tar.gz
