#!/usr/bin/env bash
# Races two copies of the game against each other over the network on this
# machine: one hosts and the other joins (see tests/net_test.gd). It runs in
# real time, since the two copies have to keep pace with each other. It takes
# about five minutes, because even a one lap race on a kart sized course
# takes a minute and a half.
set -uo pipefail
cd "$(dirname "$0")/.."
GODOT="tools/godot/Godot_v4.7.2-stable_linux.x86_64"
# Each run gets its own empty game data folder, deleted at the end.
mkdir -p build/creations
export XDG_DATA_HOME
XDG_DATA_HOME=$(mktemp -d "$PWD/build/creations/net-profile.XXXXXX")
HOST=""
trap '[ -n "$HOST" ] && kill "$HOST" 2>/dev/null; rm -rf -- "$XDG_DATA_HOME"' EXIT
# The host gives up after 11 minutes, so a joiner that fails early can't leave it hanging.
timeout 660 "$GODOT" --headless --path . res://tests/net_test.tscn -- host > /tmp/snapracers-net-host.log 2>&1 &
HOST=$!
sleep 2
timeout 600 "$GODOT" --headless --path . res://tests/net_test.tscn -- join > /tmp/snapracers-net-join.log 2>&1
JOIN=$?
# A joiner that's given up leaves the host nobody to race.
if [ $JOIN -ne 0 ]; then
	kill "$HOST" 2>/dev/null
fi
wait $HOST
HOSTED=$?
grep -hE "^  (ok|FAIL)|order:|passed|failed|SCRIPT ERROR" /tmp/snapracers-net-host.log /tmp/snapracers-net-join.log
# Both copies have to have had the same puddles at each level of the build-up.
HOST_PUDDLES=$(grep -oE "puddles at [0-9]+%: -?[0-9]+" /tmp/snapracers-net-host.log)
JOIN_PUDDLES=$(grep -oE "puddles at [0-9]+%: -?[0-9]+" /tmp/snapracers-net-join.log)
SAME=1
if [ -n "$HOST_PUDDLES" ] && [ "$HOST_PUDDLES" = "$JOIN_PUDDLES" ]; then
	echo "  ok    host and joiner have the same puddles as they build up ($(echo "$HOST_PUDDLES" | wc -l) levels)"
else
	echo "  FAIL  host and joiner have the same puddles as they build up"
	echo "$HOST_PUDDLES" ; echo "$JOIN_PUDDLES"
	SAME=0
fi
[ $HOSTED -eq 0 ] && [ $JOIN -eq 0 ] && [ $SAME -eq 1 ]
