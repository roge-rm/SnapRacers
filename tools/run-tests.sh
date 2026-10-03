#!/usr/bin/env bash
# Runs every headless test, and exits with an error if any of them fail or
# crash. --fixed-fps lets them run as fast as they can instead of in real
# time, with physics still stepping 1/60 s at a time. Each one gets ten
# minutes, so a test that hangs fails instead of holding everything up.
set -uo pipefail

cd "$(dirname "$0")/.."
GODOT="tools/godot/Godot_v4.7.2-stable_linux.x86_64"
"$GODOT" --headless --path . --import > /dev/null 2>&1

status=0
for test in "-s tests/drive_test.gd" "-s tests/drift_test.gd" "-s tests/wheels_test.gd" "-s tests/bike_test.gd" "-s tests/bindings_test.gd" "-s tests/trophy_test.gd" "-s tests/design_test.gd" "-s tests/parts_test.gd" "-s tests/damage_test.gd" "-s tests/track_test.gd" "res://tests/garage_test.tscn" "res://tests/damage_world_test.tscn" "-s tests/loop_test.gd" "-s tests/corkscrew_test.gd" "-s tests/gadget_test.gd" "-s tests/character_test.gd" "-s tests/sound_test.gd" "res://tests/menu_test.tscn" "res://tests/split_test.tscn" "res://tests/pause_test.tscn" "res://tests/focus_test.tscn" "res://tests/modes_test.tscn" "res://tests/stock_test.tscn" "res://tests/difficulty_test.tscn" "res://tests/camera_test.tscn" "res://tests/race_test.tscn -- peach_pit" "res://tests/race_test.tscn -- launchpad_loop" "res://tests/race_test.tscn -- built" "-s tests/course_test.gd" "-s tests/sharing_test.gd" "res://tests/editor_test.tscn" "res://tests/bluetooth_test.tscn" "-s tests/runoff_test.gd"; do
	echo "== $test"
	# shellcheck disable=SC2086
	timeout 600 "$GODOT" --headless --fixed-fps 60 --path . $test 2>&1 | grep -E "^  (ok|FAIL)|passed|failed|ERROR"
	codes=("${PIPESTATUS[@]}")
	if [ "${codes[1]}" -ne 0 ]; then
		status=1
	fi
	if [ "${codes[0]}" -ne 0 ]; then
		echo "   that test exited with an error"
		status=1
	fi
done

# The network tests run in real time, as separate copies of the game talking
# to each other, so they have their own scripts.
for test in tools/run-net-test.sh tools/run-server-test.sh; do
	echo "== $test"
	"$test" | grep -E "^  (ok|FAIL)|passed|failed|ERROR"
	codes=("${PIPESTATUS[@]}")
	if [ "${codes[1]}" -ne 0 ]; then
		status=1
	fi
	if [ "${codes[0]}" -ne 0 ]; then
		echo "   that test exited with an error"
		status=1
	fi
done
rm -f core.[0-9]*
exit $status
