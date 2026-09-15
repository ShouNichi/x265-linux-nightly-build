#!/usr/bin/env bash
set -euo pipefail

sha="$(git ls-remote "$UPSTREAM" refs/heads/master | awk '{print $1}')"

if [[ -z "$sha" ]]; then
  echo "Could not determine upstream commit"
  exit 1
fi

short="${sha:0:12}"
tag="musl-nightly-$short"

echo "Upstream commit: $sha"
echo "sha=$sha" >> "$GITHUB_OUTPUT"

if [[ "$GITHUB_EVENT_NAME" == "workflow_dispatch" ]]; then
  echo "changed=true" >> "$GITHUB_OUTPUT"
elif gh release view "$tag" \
    --repo "$GITHUB_REPOSITORY" >/dev/null 2>&1; then
  echo "Release $tag already exists"
  echo "changed=false" >> "$GITHUB_OUTPUT"
else
  echo "Release $tag does not exist"
  echo "changed=true" >> "$GITHUB_OUTPUT"
fi
