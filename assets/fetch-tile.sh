#!/usr/bin/env bash
#
# fetch-tile.sh — download one OpenStreetMap tile into the cache, if it isn't there already.
#
#   fetch-tile.sh CACHE_DIR Z X Y VERSION
#
# Tiles are fetched here rather than straight from an Image because OpenStreetMap's tile usage
# policy requires a User-Agent that identifies the application, and Qt's image loader sends its
# own; without one the server answers 418 and the map comes back as "Access blocked" tiles.
#
# Already-cached tiles exit immediately, so the map can ask for every tile it needs on every pan
# and only the new ones cost anything.

set -euo pipefail

cache=${1:?cache dir}
z=${2:?zoom}
x=${3:?tile x}
y=${4:?tile y}
version=${5:-unknown}

out="$cache/$z/$x/$y.png"

# Non-empty means it downloaded cleanly last time; a truncated file would have been left as the
# temporary below and never moved into place
[[ -s "$out" ]] && exit 0

mkdir -p "$(dirname "$out")"
tmp=$(mktemp "$out.XXXXXX")
trap 'rm -f "$tmp"' EXIT

curl --silent --show-error --fail --location --max-time 20 \
    --user-agent "caelestia-shell/$version (+https://github.com/caelestia-dots/shell)" \
    --output "$tmp" \
    "https://tile.openstreetmap.org/$z/$x/$y.png"

# Into place in one step, so a half-written file is never shown as a tile
mv -f "$tmp" "$out"
trap - EXIT
