#!/usr/bin/env bash
# Starts the dedicated server on this machine, with a fresh config, and has a
# player joining like a phone (ENet) and one joining like a web page
# (WebSocket) race on it (see tests/server_test.gd). It runs in real time, so
# it takes a couple of minutes.
#
#   tools/run-server-test.sh             on a server it starts itself
#   tools/run-server-test.sh --running   on one that's already up (Docker)
set -uo pipefail
cd "$(dirname "$0")/.."
GODOT="tools/godot/Godot_v4.7.2-stable_linux.x86_64"
CONFIG=/tmp/snapracers-server-test
SERVER=""
# With --running it races on a server that's already up, like the Docker one.
if [ "${1:-}" != "--running" ]; then
	rm -rf "$CONFIG" && mkdir -p "$CONFIG"
	SNAPRACERS_CONFIG="$CONFIG/server.json" "$GODOT" --headless --path . -- --server > /tmp/snapracers-server.log 2>&1 &
	SERVER=$!
	sleep 3
fi
"$GODOT" --headless --path . res://tests/server_test.tscn -- enet > /tmp/snapracers-server-enet.log 2>&1 &
PHONE=$!
timeout 300 "$GODOT" --headless --path . res://tests/server_test.tscn -- ws > /tmp/snapracers-server-ws.log 2>&1
WEB=$?
wait $PHONE
PHONED=$?
sleep 2
[ -n "$SERVER" ] && kill $SERVER 2>/dev/null
grep -hE "^  (ok|FAIL)|order:|passed|failed|SCRIPT ERROR" /tmp/snapracers-server-enet.log /tmp/snapracers-server-ws.log
if [ -n "$SERVER" ]; then
	echo "The server said:"
	grep -v "^Godot\|^$" /tmp/snapracers-server.log | head -20
fi
[ $WEB -eq 0 ] && [ $PHONED -eq 0 ]
