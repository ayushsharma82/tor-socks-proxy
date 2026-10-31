<p align="center">
  <img width="350px" src=".github/logo.jpeg" alt="Tor SOCKS Proxy">
</p>

# Tor-socks-proxy

![license](https://img.shields.io/badge/license-GPLv3.0-brightgreen.svg?style=flat)
[![Build Status](https://app.travis-ci.com/PeterDaveHello/tor-socks-proxy.svg?branch=master)](https://app.travis-ci.com/PeterDaveHello/tor-socks-proxy)
[![Docker Hub pulls](https://img.shields.io/docker/pulls/peterdavehello/tor-socks-proxy.svg)](https://hub.docker.com/r/peterdavehello/tor-socks-proxy/)

[![Docker Hub badge](http://dockeri.co/image/peterdavehello/tor-socks-proxy)](https://hub.docker.com/r/peterdavehello/tor-socks-proxy/)

The super easy way to set up a [Tor](https://www.torproject.org) [SOCKS5](https://en.wikipedia.org/wiki/SOCKS#SOCKS5) [proxy server](https://en.wikipedia.org/wiki/Proxy_server) inside a [Docker](https://en.wikipedia.org/wiki/Docker_(software)) [container](https://en.wikipedia.org/wiki/Container_(virtualization)), without Tor relay/exit node function enabled.

- **Client only**: Tor is built from the official, checksum-verified source with the relay module compiled out, so the container can never act as a relay, bridge or exit node.
- **Bridges / pluggable transports**: optional `obfs4`, `webtunnel`, `meek_lite` and `snowflake` bridges via the `TOR_BRIDGES` environment variable to get around ISP or network censorship.
- **Self-contained healthcheck**: asks Tor over a local, cookie-authenticated control socket whether a circuit is established. No requests to third-party sites.

## Docker image Repository

We push the built image to Docker Hub and GitHub Container Registry:

- GitHub Container Registry:
  - `ghcr.io/peterdavehello/tor-socks-proxy`
  - <https://github.com/PeterDaveHello/tor-socks-proxy/pkgs/container/tor-socks-proxy>
- Docker Hub:
  - `peterdavehello/tor-socks-proxy`
  - <https://hub.docker.com/r/peterdavehello/tor-socks-proxy/>

Use the prefix `ghcr.io/` if you prefer to use GitHub Container Registry.

## Usage

### First-Time Setup

```sh
docker run -d --restart=always --name tor-socks-proxy -p 127.0.0.1:9150:9150/tcp peterdavehello/tor-socks-proxy:latest
```

- `--restart=always`: This ensures the container automatically restarts whenever the system reboots.
- `-p 127.0.0.1:9150:9150/tcp`: This binds the container to localhost, and you should not change this IP unless you want to expose the proxy to a local network or the Internet.
  - You can change the first `9150` to any available port. Please note that ports `9050`/`9150` may be occupied if you are running another Tor client like TorBrowser.

### Start or stop an existing Instance manually

```sh
docker start tor-socks-proxy
```

```sh
docker stop tor-socks-proxy
```

### Checking the Proxy Status and logs

```sh
docker logs tor-socks-proxy
```

### Configuring a Client to Use the Proxy

```sh
curl --socks5-hostname 127.0.0.1:9150 https://ipinfo.tw/ip
```

### Stopping the Proxy

```sh
docker stop tor-socks-proxy
```

## Bypassing ISP Restrictions with Bridges

If your ISP or network blocks Tor, pass one or more [bridge lines](https://bridges.torproject.org/) in the `TOR_BRIDGES` environment variable. Separate bridges with newlines or `;`. A leading `Bridge ` prefix and lines starting with `#` are ignored. If `TOR_BRIDGES` is unset or empty, Tor connects directly without bridges.

Supported transports: `obfs4`, `webtunnel`, `meek_lite` (via [lyrebird](https://gitlab.torproject.org/tpo/anti-censorship/pluggable-transports/lyrebird)) and `snowflake`.

```sh
docker run -d --restart=always --name tor-socks-proxy -p 127.0.0.1:9150:9150/tcp \
  -e TOR_BRIDGES='obfs4 192.0.2.10:443 FINGERPRINT cert=CERT iat-mode=0; webtunnel [2001:db8::1]:443 FINGERPRINT url=https://example.com/path ver=0.0.1' \
  peterdavehello/tor-socks-proxy:latest
```

With Docker Compose, a YAML block scalar keeps one bridge per line:

```yaml
services:
  tor-socks-proxy:
    image: peterdavehello/tor-socks-proxy:latest
    environment:
      TOR_BRIDGES: |
        obfs4 192.0.2.10:443 FINGERPRINT cert=CERT iat-mode=0
        obfs4 192.0.2.11:443 FINGERPRINT cert=CERT iat-mode=0
```

`docker logs tor-socks-proxy` shows how many bridges were loaded. The bridge lines themselves are not logged.

## Health Status

The image has a built-in `HEALTHCHECK`. It authenticates to Tor's control socket (a Unix socket inside the container, not exposed on any port) and reports healthy once Tor has an established circuit and considers the network reachable:

```sh
docker inspect --format '{{.State.Health.Status}}' tor-socks-proxy
```

## IP Renewal

By default, Tor automatically changes IPs every 10 minutes. You can manually renew the IP by restarting the container:

```sh
docker restart tor-socks-proxy
```

## DNS over Tor

Publish DNS port during setup to query DNS requests over Tor:

```sh
docker run -d --restart=always --name tor-socks-proxy -p 127.0.0.1:9150:9150/tcp -p 127.0.0.1:53:8853/udp peterdavehello/tor-socks-proxy:latest
```
## Runtipi

This repository is also a [Runtipi](https://runtipi.io) app store. In Runtipi, go to **Settings → App stores**, add `https://github.com/ayushsharma82/tor-socks-proxy`, then install **Tor SOCKS Proxy**. Bridges (separated by `;`) and the DNS port can be set in the app's settings. The app definition lives in [`apps/tor-socks-proxy`](apps/tor-socks-proxy).

## Releases and Tor Updates

- `.github/workflows/tor-version-bump.yml` runs every Monday. When a newer stable Tor is released, it verifies the release checksum's GPG signature against the Tor release signing keys and opens a PR that updates `TOR_VERSION` and `TOR_SHA256` in the `Dockerfile`.
- `.github/workflows/docker-publish.yml` builds `linux/amd64`, `linux/arm64` and `linux/arm/v7` images when a GitHub release is published (tag releases as `vX.Y.Z`). It always pushes to GitHub Container Registry, and also to Docker Hub when the `DOCKERHUB_USERNAME` and `DOCKERHUB_TOKEN` repository secrets are set. Tags: `X.Y.Z`, `X.Y`, `tor-<tor version>` and `latest`.

## Sponsor

<a href="https://m.do.co/c/1fdd0a1d695a"><img src="https://opensource.nyc3.cdn.digitaloceanspaces.com/attribution/assets/SVG/DO_Logo_horizontal_blue.svg" width="201px"></a>

This project is now sponsored by DigitalOcean, providing us with a dedicated development and testing environment.

For cloud VPS hosting with $200 in free credit, consider using my DigitalOcean referral link: https://m.do.co/c/1fdd0a1d695a

## Support Tor Project

Support the Tor project by [setting up Tor bridge/exit nodes](https://trac.torproject.org/projects/tor/wiki/TorRelayGuide) and [donating](https://donate.torproject.org/).
