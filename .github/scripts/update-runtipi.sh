#!/usr/bin/env bash
# Points the Runtipi app at a released image: sets the main service's image tag and the app
# version to the release version, and bumps tipi_version so Runtipi offers the update.
# Usage: update-runtipi.sh <release tag, e.g. v1.2.3>
# Writes "version" and "updated" to $GITHUB_OUTPUT when running in Actions.
set -euo pipefail

tag=${1:?usage: update-runtipi.sh <release tag>}
APP_DIR=${APP_DIR:-apps/tor-socks-proxy}
config="$APP_DIR/config.json"
compose="$APP_DIR/docker-compose.json"

output() {
    echo "$1=$2"
    if [ -n "${GITHUB_OUTPUT:-}" ]; then echo "$1=$2" >> "$GITHUB_OUTPUT"; fi
}

# The publish workflow only pushes an X.Y.Z image tag for vX.Y.Z (non-prerelease) releases
version=${tag#v}
if ! [[ $version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "::warning::Release tag '$tag' is not vX.Y.Z, skipping Runtipi update"
    output updated false
    exit 0
fi
output version "$version"

image=$(jq -r '.services[] | select(.isMain) | .image' "$compose")
if [ "$(jq -r .version "$config")" = "$version" ] && [ "${image##*:}" = "$version" ]; then
    echo "Runtipi app already at $version"
    output updated false
    exit 0
fi

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

jq --indent 2 --arg version "$version" \
    '(.services[] | select(.isMain) | .image) |= sub(":[^:/]+$"; ":" + $version)' \
    "$compose" > "$work/docker-compose.json"
jq --indent 2 --arg version "$version" --argjson now "$(($(date +%s) * 1000))" \
    '.version = $version | .tipi_version += 1 | .updated_at = $now' \
    "$config" > "$work/config.json"
mv "$work/docker-compose.json" "$compose"
mv "$work/config.json" "$config"

echo "Runtipi app updated: image ${image%:*}:$version, version $version"
output updated true
