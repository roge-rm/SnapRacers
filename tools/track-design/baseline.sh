#!/usr/bin/env bash
# Races eight Expert AI karts round each course in clear weather by day, one
# course at a time, and writes a table of the best lap, resets and finishers
# to tools/track-design/baseline.md. Logs go in build/soak-baseline.
#   tools/track-design/baseline.sh                 every course, in cup order
#   tools/track-design/baseline.sh peach_pit ...   just these
# The table keeps rows for courses not raced this time.
set -uo pipefail
cd "$(dirname "$0")/../.."
GODOT=tools/godot/Godot_v4.7.2-stable_linux.x86_64
OUT=build/soak-baseline
mkdir -p "$OUT" build/creations
if [ $# -gt 0 ]; then
	COURSES=("$@")
else
	COURSES=($(python3 -c 'import json; print(" ".join(t for c in json.load(open("data/grand_prix.json"))["cups"] for t in c["tracks"]))'))
fi
for course in "${COURSES[@]}"; do
	profile=$(mktemp -d "$PWD/build/creations/profile.XXXXXX")
	XDG_DATA_HOME=$profile timeout 1500 heavy build "$GODOT" --headless --fixed-fps 60 --path . res://tools/soak/soak.tscn -- \
		"$course" weather=clear time=day difficulty=expert seed=1 > "$OUT/$course.log" 2>&1
	rm -rf "$profile"
	grep '^RESULT' "$OUT/$course.log" || echo "RESULT $course: no result"
done
python3 tools/track-design/baseline_table.py
