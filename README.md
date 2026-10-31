<p align="center">
  <img width="350px" src=".github/logo.jpeg" alt="Tor SOCKS Proxy">
</p>

<p align="center">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-GPLv3.0-brightgreen.svg?style=flat" alt="License: GPLv3"></a>
  <a href="https://github.com/ayushsharma82/tor-socks-proxy/actions/workflows/docker-publish.yml"><img src="https://github.com/ayushsharma82/tor-socks-proxy/actions/workflows/docker-publish.yml/badge.svg" alt="Publish Docker image"></a>
</p>

# Tor SOCKS Proxy

A lightweight Docker image that runs [Tor](https://www.torproject.org) as a [SOCKS5](https://en.wikipedia.org/wiki/SOCKS#SOCKS5) proxy. Point any SOCKS5-capable application at it and its traffic is routed through the Tor network.

## Table of Contents

- [Features](#features)
- [Quick Start](#quick-start)
- [Using the Proxy](#using-the-proxy)
- [Bypassing Censorship with Bridges](#bypassing-censorship-with-bridges)
- [DNS over Tor](#dns-over-tor)
- [Docker Compose](#docker-compose)
- [Runtipi](#runtipi)
- [Configuration Reference](#configuration-reference)
- [Health Check](#health-check)
- [Managing the Container](#managing-the-container)
- [Security Notes](#security-notes)
- [Releases and Automatic Updates](#releases-and-automatic-updates)
- [Credits](#credits)
- [License](#license)

## Features

- **Client only.** Tor is compiled from the official source with relay support removed. The container cannot act as a relay, bridge or exit node, whatever the configuration.
- **Verified builds.** The Tor source is pinned to a specific version and SHA-256 checksum. New versions are accepted only after their release signature is verified against the Tor Project's signing keys.
- **Censorship circumvention.** Optional bridge support through `obfs4`, `webtunnel`, `meek_lite` and `snowflake`, configured with a single environment variable.
- **Private health check.** Container health is read directly from Tor over a local, authenticated control socket. No requests are sent to third-party websites.
- **Multi-architecture.** Images are published for `linux/amd64`, `linux/arm64` and `linux/arm/v7`.
- **Runtipi ready.** The repository doubles as a [Runtipi](https://runtipi.io) app store for one-click installation.

## Quick Start

Run the proxy and bind it to your local machine only:

```sh
docker run -d --restart=always --name tor-socks-proxy \
  -p 127.0.0.1:9150:9150/tcp \
  ghcr.io/ayushsharma82/tor-socks-proxy:latest
```

| Option | Purpose |
| --- | --- |
| `--restart=always` | Restarts the container automatically, including after a reboot. |
| `-p 127.0.0.1:9150:9150/tcp` | Publishes the SOCKS5 port on `localhost` only. Change the first `9150` to use a different host port. |

Tor usually needs 10–60 seconds to connect. Follow its progress with `docker logs -f tor-socks-proxy` until you see `Bootstrapped 100% (done)`.

> [!NOTE]
> Ports `9050` and `9150` may already be in use if you run another Tor client, such as Tor Browser.

## Using the Proxy

Configure your application to use the SOCKS5 proxy at `127.0.0.1:9150`. Use remote DNS resolution (often called `socks5h` or "proxy DNS") so that hostnames are resolved by Tor rather than by your local network.

To confirm that traffic is going through Tor:

```sh
curl --socks5-hostname 127.0.0.1:9150 https://check.torproject.org/api/ip
```

A response containing `"IsTor":true` means the proxy is working.

## Bypassing Censorship with Bridges

If your ISP or network blocks Tor, use bridges: unlisted entry points to the Tor network that are harder to block.

1. Get bridge lines from [bridges.torproject.org](https://bridges.torproject.org/).
2. Pass them in the `TOR_BRIDGES` environment variable.

```sh
docker run -d --restart=always --name tor-socks-proxy \
  -p 127.0.0.1:9150:9150/tcp \
  -e TOR_BRIDGES='obfs4 192.0.2.10:443 FINGERPRINT cert=CERT iat-mode=0; webtunnel [2001:db8::1]:443 FINGERPRINT url=https://example.com/path ver=0.0.1' \
  ghcr.io/ayushsharma82/tor-socks-proxy:latest
```

How `TOR_BRIDGES` is read:

- Separate multiple bridges with a newline or a semicolon (`;`).
- A leading `Bridge ` prefix, as shown on the Tor bridges site, is accepted.
- Lines starting with `#` are ignored.
- If the variable is unset or empty, Tor connects directly without bridges.

Supported transports:

| Transport | Provided by |
| --- | --- |
| `obfs4`, `webtunnel`, `meek_lite` | [lyrebird](https://gitlab.torproject.org/tpo/anti-censorship/pluggable-transports/lyrebird) |
| `snowflake` | [snowflake](https://gitlab.torproject.org/tpo/anti-censorship/pluggable-transports/snowflake) |

On startup, the container logs how many bridges it loaded. The bridge lines themselves are never logged.

## DNS over Tor

Tor can also resolve DNS queries. Publish the container's UDP port `8853` to use it:

```sh
docker run -d --restart=always --name tor-socks-proxy \
  -p 127.0.0.1:9150:9150/tcp \
  -p 127.0.0.1:53:8853/udp \
  ghcr.io/ayushsharma82/tor-socks-proxy:latest
```

Tor's DNS resolver supports `A`, `AAAA` and `PTR` lookups.

## Docker Compose

A ready-to-use [`docker-compose.yml`](docker-compose.yml) is included. To add bridges, use a YAML block so that each bridge sits on its own line:

```yaml
services:
  tor-socks-proxy:
    image: ghcr.io/ayushsharma82/tor-socks-proxy:latest
    container_name: tor-socks-proxy
    restart: unless-stopped
    ports:
      - "127.0.0.1:9150:9150/tcp"
      - "127.0.0.1:8853:8853/udp"
    environment:
      TOR_BRIDGES: |
        obfs4 192.0.2.10:443 FINGERPRINT cert=CERT iat-mode=0
        obfs4 192.0.2.11:443 FINGERPRINT cert=CERT iat-mode=0
```

```sh
docker compose up -d
```

## Runtipi

This repository is also a [Runtipi](https://runtipi.io) app store.

1. In Runtipi, open **Settings → App stores**.
2. Add `https://github.com/ayushsharma82/tor-socks-proxy`.
3. Install **Tor SOCKS Proxy** from the app store.

You can set bridges (separated by `;`) and the DNS port in the app's settings. The SOCKS5 proxy is available on the app's port (default `9150`). The app definition lives in [`apps/tor-socks-proxy`](apps/tor-socks-proxy).

## Configuration Reference

| Setting | Default | Description |
| --- | --- | --- |
| `TOR_BRIDGES` | *(empty)* | Bridge lines separated by newlines or `;`. Leave empty to connect without bridges. |
| `9150/tcp` | — | SOCKS5 proxy port. |
| `8853/udp` | — | DNS over Tor port. |

## Health Check

The image includes a built-in Docker `HEALTHCHECK`. It connects to Tor's control socket, a Unix socket inside the container that is not exposed on any port and requires cookie authentication. The container is reported healthy once Tor has an established circuit and considers the network reachable.

```sh
docker inspect --format '{{.State.Health.Status}}' tor-socks-proxy
```

## Managing the Container

| Task | Command |
| --- | --- |
| View logs | `docker logs tor-socks-proxy` |
| Stop | `docker stop tor-socks-proxy` |
| Start | `docker start tor-socks-proxy` |
| Get a new exit IP | `docker restart tor-socks-proxy` |
| Update to the latest image | `docker pull ghcr.io/ayushsharma82/tor-socks-proxy:latest`, then recreate the container |

Tor rotates circuits for new connections roughly every 10 minutes. Restarting the container forces a fresh set of circuits immediately.

## Security Notes

- **The proxy has no authentication.** Anyone who can reach port `9150` can use it. Keep it bound to `127.0.0.1`, or to a trusted private network, and never expose it to the internet.
- **Use remote DNS.** Clients that resolve hostnames locally leak the sites you visit to your DNS provider. Use `socks5h` or `--socks5-hostname`.
- **This is not Tor Browser.** The proxy routes traffic through Tor but does not protect against browser fingerprinting or application-level leaks. For anonymous browsing, use [Tor Browser](https://www.torproject.org/download/).

## Releases and Automatic Updates

Three GitHub Actions workflows keep the image current:

| Workflow | Trigger | What it does |
| --- | --- | --- |
| [Tor version bump](.github/workflows/tor-version-bump.yml) | Every Monday, or manually | Checks for a new stable Tor release, verifies its GPG signature against the Tor Project's release keys, and opens a PR updating `TOR_VERSION` and `TOR_SHA256` in the `Dockerfile`. |
| [Publish Docker image](.github/workflows/docker-publish.yml) | A GitHub release is published | Builds multi-architecture images and pushes them to GitHub Container Registry (and to Docker Hub when the `DOCKERHUB_USERNAME` and `DOCKERHUB_TOKEN` secrets are configured). |
| [Update Runtipi app](.github/workflows/runtipi-update.yml) | After a release image is published, or manually | Opens a PR that points the Runtipi app at the new image tag and bumps its version. |

**Image tags.** Name releases `vX.Y.Z`. Each release produces the tags `X.Y.Z`, `X.Y`, `tor-<tor version>` and, except for prereleases, `latest`.

**Typical release flow:** merge the weekly Tor bump PR → publish a release → merge the Runtipi update PR.

## Credits

Based on [PeterDaveHello/tor-socks-proxy](https://github.com/PeterDaveHello/tor-socks-proxy). Tor is developed by [The Tor Project](https://www.torproject.org). Consider supporting it by [running a relay](https://community.torproject.org/relay/) or [donating](https://donate.torproject.org/).

## License

Released under the [GNU General Public License v3.0](LICENSE).
