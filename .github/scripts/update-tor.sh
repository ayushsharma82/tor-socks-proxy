#!/usr/bin/env bash
# Updates TOR_VERSION/TOR_SHA256 in the Dockerfile to the latest stable Tor release.
# The release checksum must carry a valid signature from one of the pinned Tor release keys.
# Writes "current", "latest" and "updated" to $GITHUB_OUTPUT when running in Actions.
set -euo pipefail

DIST_URL=https://dist.torproject.org
DOCKERFILE=${DOCKERFILE:-Dockerfile}

# Primary key fingerprints of Tor release signers
# (https://support.torproject.org/little-t-tor/verify-little-t-tor/)
TRUSTED_KEYS=(
    2133BC600AB133E1D826D173FE43009C4607B1FB # Nick Mathewson
    B74417EDDF22AC9F9E90F49142E86A2A11F48D36 # David Goulet
    1C1BC007A9F607AA8152C040BEA7B180B1491921 # Alexander Færøy
)

output() {
    echo "$1=$2"
    if [ -n "${GITHUB_OUTPUT:-}" ]; then echo "$1=$2" >> "$GITHUB_OUTPUT"; fi
}

current=$(sed -n 's/^ARG TOR_VERSION=//p' "$DOCKERFILE" | head -n1)
# Stable releases only have four numeric components (no -alpha / -rc suffix)
latest=$(curl -fsSL "$DIST_URL/" |
    grep -oE 'href="tor-[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+\.tar\.gz"' |
    grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' |
    sort -uV | tail -n1)

[ -n "$current" ] || { echo "TOR_VERSION not found in $DOCKERFILE" >&2; exit 1; }
[ -n "$latest" ] || { echo "Could not determine latest Tor release" >&2; exit 1; }

output current "$current"
output latest "$latest"

if [ "$(printf '%s\n%s\n' "$current" "$latest" | sort -V | tail -n1)" = "$current" ]; then
    echo "Tor $current is up to date"
    output updated false
    exit 0
fi

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
export GNUPGHOME="$work/gnupg"
mkdir -m 700 "$GNUPGHOME"

tarball="tor-$latest.tar.gz"
curl -fsSL -o "$work/$tarball" "$DIST_URL/$tarball"
curl -fsSL -o "$work/$tarball.sha256sum" "$DIST_URL/$tarball.sha256sum"
curl -fsSL -o "$work/$tarball.sha256sum.asc" "$DIST_URL/$tarball.sha256sum.asc"

for key in "${TRUSTED_KEYS[@]}"; do
    gpg --batch --quiet --keyserver hkps://keys.openpgp.org --recv-keys "$key" ||
        gpg --batch --quiet --keyserver hkps://keyserver.ubuntu.com --recv-keys "$key" ||
        echo "warning: could not fetch key $key" >&2
done

# VALIDSIG's last field is the primary key fingerprint; require one from the trusted list
signers=$(gpg --batch --status-fd 1 --verify "$work/$tarball.sha256sum.asc" "$work/$tarball.sha256sum" 2>/dev/null |
    awk '$2 == "VALIDSIG" { print $NF }' || true)
trusted_signer=""
for key in "${TRUSTED_KEYS[@]}"; do
    if grep -qxF "$key" <<< "$signers"; then trusted_signer=$key; break; fi
done
[ -n "$trusted_signer" ] || { echo "No valid signature from a trusted Tor release key" >&2; exit 1; }
echo "Checksum signed by $trusted_signer"

(cd "$work" && sha256sum -c "$tarball.sha256sum")
sha256=$(awk '{ print $1 }' "$work/$tarball.sha256sum")

sed -i.bak \
    -e "s/^ARG TOR_VERSION=.*/ARG TOR_VERSION=$latest/" \
    -e "s/^ARG TOR_SHA256=.*/ARG TOR_SHA256=$sha256/" \
    "$DOCKERFILE"
rm -f "$DOCKERFILE.bak"

echo "Updated Tor $current -> $latest"
output updated true
