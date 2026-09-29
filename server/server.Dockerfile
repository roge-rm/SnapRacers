# The SnapRacers dedicated server.
#
# It's the game itself, run with no screen: the same scripts the phones run,
# packed up by the "Linux server" export and run by the official Godot. It's
# built straight from the repo, so there's nothing to build first. The build
# context is the repo's top folder (see docker-compose.yml).

FROM debian:trixie-slim AS build

ARG GODOT_VERSION=4.7.2

RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl unzip \
 && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL -o /tmp/godot.zip \
        "https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-stable/Godot_v${GODOT_VERSION}-stable_linux.x86_64.zip" \
 && unzip -q /tmp/godot.zip -d /tmp \
 && mv "/tmp/Godot_v${GODOT_VERSION}-stable_linux.x86_64" /usr/local/bin/godot \
 && rm /tmp/godot.zip

WORKDIR /src
COPY . /src

# The import makes the .godot folder a checkout doesn't have, and the export
# packs everything the server needs into one file.
RUN godot --headless --path /src --import > /tmp/import.log 2>&1 || (tail -30 /tmp/import.log; exit 1)
RUN mkdir -p /out \
 && godot --headless --path /src --export-pack "Linux server" /out/snapracers.pck > /tmp/export.log 2>&1 \
 && test -s /out/snapracers.pck || (tail -30 /tmp/export.log; exit 1)


FROM debian:trixie-slim

# The same id as the web admin's, though they share nothing but the network.
RUN groupadd --gid 10001 snapracers \
 && useradd --uid 10001 --gid 10001 --home-dir /config --no-create-home --shell /usr/sbin/nologin snapracers

COPY --from=build /usr/local/bin/godot /opt/snapracers/godot
COPY --from=build /out/snapracers.pck /opt/snapracers/snapracers.pck

# Owned here, so the volume Docker makes from it is ours to write in.
RUN mkdir -p /config/courses /config/cups /config/game \
 && chown -R snapracers:snapracers /config

# server.json holds its settings, and courses/ and cups/ any of your own to
# put on. The game's own saves go in /config/game.
ENV SNAPRACERS_CONFIG=/config/server.json \
    XDG_DATA_HOME=/config/game \
    XDG_CONFIG_HOME=/config/game \
    XDG_CACHE_HOME=/tmp

VOLUME ["/config"]
# 27280 for phones (ENet, which is UDP), 27281 for finding games on the local
# network, 27282 for web players (a WebSocket).
EXPOSE 27280/udp 27281/udp 27282/tcp

USER snapracers
WORKDIR /opt/snapracers

HEALTHCHECK --interval=30s --timeout=3s --start-period=30s \
    CMD bash -c 'exec 3<>/dev/tcp/127.0.0.1/27289 && printf "ping\n" >&3 && head -c 20 <&3 | grep -q ok'

ENTRYPOINT ["/opt/snapracers/godot", "--headless", "--main-pack", "/opt/snapracers/snapracers.pck"]
