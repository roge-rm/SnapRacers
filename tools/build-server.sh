#!/usr/bin/env bash
# Builds the dedicated server to run on a Linux PC without Docker: the game
# packed up the way the "Linux server" export does it, and the Godot we
# already have to run it with. It goes in /tmp like the other builds.
#
#   tools/build-server.sh          the server, in /tmp/snapracers-build/server
#   tools/build-server.sh --run    and start it, with its settings and any
#                                  courses and cups of its own in ~/.snapracers-server
#
# For a server that stays up, with its web admin page, use Docker instead
# (see server/README.md).
set -euo pipefail

cd "$(dirname "$0")/.."
VERSION=4.7.2
GODOT="tools/godot/Godot_v${VERSION}-stable_linux.x86_64"
OUT=/tmp/snapracers-build/server

mkdir -p "$OUT"
"$GODOT" --headless --path . --export-pack "Linux server" "$OUT/snapracers.pck" > "$OUT/export.log" 2>&1 \
	|| { tail -20 "$OUT/export.log"; exit 1; }
cp "$GODOT" "$OUT/godot"
cat > "$OUT/snapracers-server" <<'RUN'
#!/usr/bin/env bash
# Runs the SnapRacers dedicated server. Its settings are in
# $SNAPRACERS_CONFIG (~/.snapracers-server/server.json unless you say).
cd "$(dirname "$0")"
export SNAPRACERS_CONFIG="${SNAPRACERS_CONFIG:-$HOME/.snapracers-server/server.json}"
mkdir -p "$(dirname "$SNAPRACERS_CONFIG")"
exec ./godot --headless --main-pack snapracers.pck "$@"
RUN
chmod +x "$OUT/snapracers-server"
echo "The server's in $OUT ($(du -sh "$OUT" | cut -f1))"

if [ "${1:-}" = "--run" ]; then
	exec "$OUT/snapracers-server"
fi
