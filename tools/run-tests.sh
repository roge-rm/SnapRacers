#!/usr/bin/env bash
# Runs every headless test. Exits non-zero if any of them fail or crash.
set -uo pipefail

cd "$(dirname "$0")/.."
GODOT="tools/godot/Godot_v4.7.2-stable_linux.x86_64"
"$GODOT" --headless --path . --import > /dev/null 2>&1

status=0
for test in "-s tests/drive_test.gd" "-s tests/design_test.gd" "-s tests/damage_test.gd" "res://tests/garage_test.tscn"; do
	echo "== $test"
	# shellcheck disable=SC2086
	if ! "$GODOT" --headless --path . $test 2>&1 | grep -E "^  (ok|FAIL)|passed|failed|ERROR"; then
		status=1
	fi
	if [ "${PIPESTATUS[0]}" -ne 0 ]; then
		echo "   that test exited with an error"
		status=1
	fi
done
rm -f core.[0-9]*
exit $status
