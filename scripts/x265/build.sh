#!/usr/bin/env bash
set -euo pipefail

repo_root="${GITHUB_WORKSPACE}"
src="${repo_root}/x265"
docker_script="${repo_root}/scripts/x265/docker-build.sh"

mkdir -p "$src/dist"

docker run --rm \
  --mount "type=bind,src=${src},dst=/src" \
  --mount "type=bind,src=${docker_script},dst=/usr/local/bin/docker-build.sh,readonly" \
  --workdir /src \
  alpine:3.22 \
  sh /usr/local/bin/docker-build.sh

test -d "$src/dist"
find "$src/dist" -maxdepth 1 -type f -printf "%p\n"
