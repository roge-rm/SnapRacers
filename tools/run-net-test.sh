#!/usr/bin/env bash
# Races two copies of the game against each other over the network on this
# machine: one hosts and the other joins (see tests/net_test.gd). It runs in
# real time, since the two copies have to keep pace with each other. It takes
# about five minutes, because even a one lap race on a kart sized course
# takes a minute and a half.
set -uo pipefail
cd "$(dirname "$0")/.."
GODOT="tools/godot/Godot_v4.7.2-stable_linux.x86_64"
"$GODOT" --headless --path . res://tests/net_test.tscn -- host > /tmp/snapracers-net-host.log 2>&1 &
HOST=$!
sleep 2
timeout 600 "$GODOT" --headless --path . res://tests/net_test.tscn -- join > /tmp/snapracers-net-join.log 2>&1
JOIN=$?
wait $HOST
HOSTED=$?
grep -hE "^  (ok|FAIL)|order:|passed|failed|SCRIPT ERROR" /tmp/snapracers-net-host.log /tmp/snapracers-net-join.log
[ $HOSTED -eq 0 ] && [ $JOIN -eq 0 ]
