#!/usr/bin/env bash
# Times the stock karts, bikes and trikes like balance.tscn, but several at
# once, each copy of the game doing a few of them, then puts the times
# together with the last full run's and shows how each compares with the
# middle of the field. Name vehicles or courses to only do those, and the
# others keep their last times:
#   tools/stock-karts/balance.sh
#   tools/stock-karts/balance.sh superbike chopper launchpad_loop
# JOBS sets how many copies run at once (8 to start with).
set -euo pipefail

cd "$(dirname "$0")/../.."
GODOT="tools/godot/Godot_v4.7.2-stable_linux.x86_64"
JOBS="${JOBS:-8}"
OUT="$PWD/build/balance"
mkdir -p "$OUT"
rm -f "$OUT"/part_*.json "$OUT"/log_*.txt

vehicles=()
courses=()
for name in "$@"; do
	if [ -f "data/karts/stock/$name.json" ]; then
		vehicles+=("$name")
	else
		courses+=("$name")
	fi
done
if [ ${#vehicles[@]} -eq 0 ]; then
	for file in data/karts/stock/*.json; do
		vehicles+=("$(basename "$file" .json)")
	done
fi

# Dealt out in turn, so each copy gets a mix of slow and quick ones.
for ((i = 0; i < JOBS; i++)); do
	group=()
	for ((j = i; j < ${#vehicles[@]}; j += JOBS)); do
		group+=("${vehicles[j]}")
	done
	[ ${#group[@]} -gt 0 ] || continue
	BALANCE_OUT="$OUT/part_$i.json" timeout 3600 "$GODOT" --headless --fixed-fps 60 --path . res://tools/stock-karts/balance.tscn -- "${group[@]}" "${courses[@]}" > "$OUT/log_$i.txt" 2>&1 &
done
wait
grep -h "reset\. \|gave up" "$OUT"/log_*.txt || true
python3 tools/stock-karts/balance_table.py "$OUT"/part_*.json
