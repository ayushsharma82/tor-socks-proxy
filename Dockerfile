FROM alpine:3.24 AS builder

# Bumped automatically by .github/workflows/tor-version-bump.yml
ARG TOR_VERSION=0.4.9.15
ARG TOR_SHA256=1911f5b216a6814ed143a08bbcff1c6dc96d2ca3b505df9a21876080a92963f3

RUN apk add --no-cache build-base curl libevent-dev openssl-dev zlib-dev xz-dev zstd-dev libcap-dev linux-headers

WORKDIR /src
RUN curl -fsSL -o tor.tar.gz "https://dist.torproject.org/tor-${TOR_VERSION}.tar.gz" && \
    echo "${TOR_SHA256}  tor.tar.gz" | sha256sum -c - && \
    tar -xzf tor.tar.gz --strip-components=1 && \
    rm tor.tar.gz

# The relay module is compiled out, so this tor binary can only ever act as a client.
RUN ./configure \
        --prefix=/usr \
        --sysconfdir=/etc \
        --localstatedir=/var \
        --disable-module-relay \
        --disable-asciidoc \
        --disable-manpage \
        --disable-html-manual \
        --disable-unittests && \
    make -j"$(nproc)" && \
    make install DESTDIR=/out && \
    strip /out/usr/bin/tor

FROM alpine:3.24

ARG TOR_VERSION=0.4.9.15

LABEL maintainer="Peter Dave Hello <hsu@peterdavehello.org>"
LABEL name="tor-socks-proxy"
LABEL version="${TOR_VERSION}"

RUN apk -U upgrade && \
    apk -v add libevent libgcc openssl zlib xz-libs zstd-libs libcap netcat-openbsd lyrebird snowflake && \
    addgroup -S tor && \
    adduser -S -D -H -G tor -h /var/lib/tor -s /sbin/nologin tor && \
    mkdir -p /var/lib/tor /run/tor && \
    chown tor:tor /var/lib/tor /run/tor && \
    chmod 700 /var/lib/tor /run/tor && \
    rm -rf /var/cache/apk/*

COPY --from=builder /out/usr/bin/tor /usr/bin/tor
COPY --from=builder /out/usr/share/tor /usr/share/tor
COPY --chown=tor:root torrc /etc/tor/
COPY docker-entrypoint.sh healthcheck.sh /usr/local/bin/

RUN tor --version

# Asks tor itself over its local control socket whether a circuit is up; no external requests.
HEALTHCHECK --interval=30s --timeout=10s --start-period=120s \
    CMD ["/usr/local/bin/healthcheck.sh"]

USER tor
EXPOSE 8853/udp 9150/tcp

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["/usr/bin/tor", "-f", "/etc/tor/torrc"]
