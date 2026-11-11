#!/usr/bin/env bash
# Races the AI round every course, each in different weather and at a
# different time of day, a few at a time, and puts what happened in
# build/soak: a log for each course with anything the engine complained
# about, and summary.txt with a line for each.
#   tools/soak/soak.sh                 every course
#   tools/soak/soak.sh peach_pit ...   just these
#   LAYOUTS=reverse,mirrored,both tools/soak/soak.sh runs those layouts.
set -uo pipefail
cd "$(dirname "$0")/../.."
GODOT=tools/godot/Godot_v4.7.2-stable_linux.x86_64
OUT=build/soak
JOBS=${JOBS:-4}
mkdir -p "$OUT"
touch build/.gdignore
WEATHERS=(clear rain snow fog storm dust random)
TIMES=(morning day evening dusk night)
EXTRA=()
COURSE_ARGS=()
for arg in "$@"; do
	case "$arg" in
		reversed=on|reversed=off|mirrored=on|mirrored=off) EXTRA+=("$arg") ;;
		*) COURSE_ARGS+=("$arg") ;;
	esac
done
if [ ${#COURSE_ARGS[@]} -gt 0 ]; then
	COURSES=("${COURSE_ARGS[@]}")
else
	COURSES=($(ls data/tracks | sed -n 's/\.json$//p'))
fi

LAYOUT_ARGS=("")
LAYOUT_NAMES=(default)
if [ -n "${LAYOUTS:-}" ]; then
	LAYOUT_ARGS=()
	LAYOUT_NAMES=()
	IFS=',' read -r -a LAYOUT_LIST <<< "$LAYOUTS"
	for layout in "${LAYOUT_LIST[@]}"; do
		case "$layout" in
			reverse) LAYOUT_ARGS+=("reversed=on"); LAYOUT_NAMES+=(reverse) ;;
			mirrored) LAYOUT_ARGS+=("mirrored=on"); LAYOUT_NAMES+=(mirrored) ;;
			both) LAYOUT_ARGS+=("reversed=on mirrored=on"); LAYOUT_NAMES+=(both) ;;
			*) echo "Unknown layout: $layout" >&2; exit 2 ;;
		esac
	done
fi

race() {
	local i=$1 course=$2 layout=$3 layout_name=$4
	local weather=${WEATHERS[$((i % ${#WEATHERS[@]}))]}
	local time=${TIMES[$((i % ${#TIMES[@]}))]}
	local log="$OUT/$course.log"
	if [ "$layout_name" != default ]; then log="$OUT/$course-$layout_name.log"; fi
	local layout_args=()
	if [ -n "$layout" ]; then read -r -a layout_args <<< "$layout"; fi
	timeout 1200 "$GODOT" --headless --fixed-fps 60 --path . res://tools/soak/soak.tscn -- "$course" weather="$weather" time="$time" seed=$((i + 1)) "${EXTRA[@]}" "${layout_args[@]}" > "$log" 2>&1
	local code=$?
	local result
	result=$(grep '^RESULT' "$log" || echo "RESULT $course $weather $time: no result, exit $code")
	local errors
	errors=$(grep -c '^ERROR\|^SCRIPT ERROR' "$log")
	echo "$result, $errors errors"
}

i=0
{
for course in "${COURSES[@]}"; do
	for layout_index in "${!LAYOUT_ARGS[@]}"; do
		race $i "$course" "${LAYOUT_ARGS[$layout_index]}" "${LAYOUT_NAMES[$layout_index]}" &
		i=$((i + 1))
		while [ "$(jobs -r | wc -l)" -ge "$JOBS" ]; do
			wait -n
		done
	done
done
wait
} | tee "$OUT/summary.txt"
