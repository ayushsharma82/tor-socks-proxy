#!/bin/sh
set -eu

# Bridges are read from TOR_BRIDGES, one bridge line per line or separated by ';'.
# When TOR_BRIDGES is unset or empty, tor connects directly without bridges.
if [ "${1:-}" = "/usr/bin/tor" ] || [ "${1:-}" = "tor" ]; then
    count=0
    bridges=$(printf '%s\n' "${TOR_BRIDGES:-}" | tr ';' '\n')
    while IFS= read -r line; do
        line=$(printf '%s' "$line" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
        case "$line" in
            '' | '#'*) continue ;;
            Bridge\ *) line=${line#Bridge } ;;
        esac
        set -- "$@" --Bridge "$line"
        count=$((count + 1))
    done <<EOF
$bridges
EOF

    if [ "$count" -gt 0 ]; then
        echo "docker-entrypoint: using $count bridge(s) from TOR_BRIDGES"
        set -- "$@" \
            --UseBridges 1 \
            --ClientTransportPlugin "meek_lite,obfs2,obfs3,obfs4,scramblesuit,webtunnel exec /usr/bin/lyrebird" \
            --ClientTransportPlugin "snowflake exec /usr/bin/snowflake-client"
    else
        echo "docker-entrypoint: TOR_BRIDGES not set, connecting without bridges"
    fi
fi

exec "$@"
