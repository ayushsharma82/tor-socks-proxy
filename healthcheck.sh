#!/bin/sh
set -eu

# Queries tor's own state over the local control socket (cookie-authenticated).
# Healthy means tor has built a circuit and considers the network reachable.
socket=/run/tor/control
cookie_file=/run/tor/control.authcookie

[ -S "$socket" ] && [ -r "$cookie_file" ] || { echo "control socket not ready"; exit 1; }

cookie=$(od -An -tx1 -v "$cookie_file" | tr -d ' \n')
response=$(printf 'AUTHENTICATE %s\r\nGETINFO status/circuit-established network-liveness\r\nQUIT\r\n' "$cookie" |
    nc -U -w 5 "$socket" | tr -d '\r')

if printf '%s\n' "$response" | grep -qx '250-status/circuit-established=1' &&
    printf '%s\n' "$response" | grep -qx '250-network-liveness=up'; then
    exit 0
fi

printf '%s\n' "$response" | grep -v '^250 OK$' || true
exit 1
