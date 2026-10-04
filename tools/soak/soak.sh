#!/usr/bin/env bash
# Races the AI round every course, each in different weather and at a
# different time of day, a few at a time, and puts what happened in
# build/soak: a log for each course with anything the engine complained
# about, and summary.txt with a line for each.
#   tools/soak/soak.sh                 every course
#   tools/soak/soak.sh peach_pit ...   just these
set -uo pipefail
cd "$(dirname "$0")/../.."
GODOT=tools/godot/Godot_v4.7.2-stable_linux.x86_64
OUT=build/soak
JOBS=${JOBS:-4}
mkdir -p "$OUT"
touch build/.gdignore
WEATHERS=(clear rain snow fog storm dust random)
TIMES=(morning day evening dusk night)
if [ $# -gt 0 ]; then
	COURSES=("$@")
else
	COURSES=($(ls data/tracks | sed -n 's/\.json$//p'))
fi

race() {
	local i=$1 course=$2
	local weather=${WEATHERS[$((i % ${#WEATHERS[@]}))]}
	local time=${TIMES[$((i % ${#TIMES[@]}))]}
	timeout 1200 "$GODOT" --headless --fixed-fps 60 --path . res://tools/soak/soak.tscn -- "$course" weather="$weather" time="$time" seed=$((i + 1)) > "$OUT/$course.log" 2>&1
	local code=$?
	local result
	result=$(grep '^RESULT' "$OUT/$course.log" || echo "RESULT $course $weather $time: no result, exit $code")
	local errors
	errors=$(grep -c '^ERROR\|^SCRIPT ERROR' "$OUT/$course.log")
	echo "$result, $errors errors"
}

i=0
{
for course in "${COURSES[@]}"; do
	race $i "$course" &
	i=$((i + 1))
	while [ "$(jobs -r | wc -l)" -ge "$JOBS" ]; do
		wait -n
	done
done
wait
} | tee "$OUT/summary.txt"
