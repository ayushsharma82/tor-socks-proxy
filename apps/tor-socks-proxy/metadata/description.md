# Tor SOCKS Proxy

A [Tor](https://www.torproject.org) SOCKS5 proxy in a container. Tor is built from the official, checksum-verified source with the relay module compiled out, so it can only run as a client. It never acts as a relay, bridge or exit node.

## Usage

Point any SOCKS5-capable client at `<your-tipi-ip>:<app port>` (default `9150`). Use remote DNS (`socks5h`) so hostnames are resolved through Tor:

```sh
curl --socks5-hostname <your-tipi-ip>:9150 https://check.torproject.org/api/ip
```

DNS over Tor is available over UDP on the configured DNS port (default `8853`).

## Bypassing ISP restrictions

If your network blocks Tor, paste one or more bridge lines from [bridges.torproject.org](https://bridges.torproject.org) into the **Tor bridges** setting, separated by `;`. Supported transports: `obfs4`, `webtunnel`, `meek_lite` and `snowflake`. Leave the field empty to connect without bridges.

## Security

The proxy has no authentication. Anyone who can reach the port can use it, so don't expose it to the internet.
