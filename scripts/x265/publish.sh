#!/usr/bin/env bash
set -euo pipefail

short="${SHA:0:12}"
tag="musl-nightly-$short"

notes="Static x86_64 musl build of x265.

Features:
- 8-bit support
- 10-bit support
- 12-bit support
- HDR10+ support

Upstream commit:
https://github.com/Multicorewareinc/x265/commit/$SHA"

if gh release view "$tag" \
    --repo "$GITHUB_REPOSITORY" >/dev/null 2>&1; then
  gh release upload "$tag" dist/* \
    --repo "$GITHUB_REPOSITORY" \
    --clobber
else
  gh release create "$tag" dist/* \
    --repo "$GITHUB_REPOSITORY" \
    --title "x265 static musl nightly: $short" \
    --notes "$notes"
fi
