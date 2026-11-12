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
echo "== -s tests/layout_test.gd"
if ! timeout 600 "$GODOT" --headless --fixed-fps 60 --path . -s tests/layout_test.gd 2>&1 | grep -E "^  (ok|FAIL)|passed|failed|ERROR"; then
	status=1
fi
for test in "res://tests/layout_settings_test.tscn" "-s tests/cut_bend_layout_test.gd" "-s tests/drive_test.gd" "res://tests/drift_test.tscn" "-s tests/wheels_test.gd" "-s tests/suspension_test.gd" "-s tests/kart_collision_test.gd" "-s tests/ai_drive_test.gd" "res://tests/ai_gadget_test.tscn" "res://tests/ai_traffic_test.tscn" "-s tests/ai_wall_test.gd" "-s tests/ai_stuck_test.gd" "-s tests/ai_weather_test.gd" "-s tests/weather_test.gd" "-s tests/puddle_feel_test.gd" "-s tests/drift_feel_test.gd" "-s tests/snow_bank_test.gd" "-s tests/graphics_test.gd" "-s tests/bike_test.gd" "-s tests/bindings_test.gd" "-s tests/trophy_test.gd" "res://tests/race_window_test.tscn" "-s tests/design_test.gd" "-s tests/parts_test.gd" "res://tests/engine_tradeoff_test.tscn" "-s tests/wheel_fit_test.gd" "-s tests/damage_test.gd" "-s tests/track_test.gd" "res://tests/garage_test.tscn" "res://tests/damage_world_test.tscn" "-s tests/loop_test.gd" "-s tests/corkscrew_test.gd" "-s tests/gadget_test.gd" "-s tests/shock_ring_test.gd" "-s tests/trap_test.gd" "res://tests/marbles_test.tscn" "-s tests/brick_pile_test.gd" "-s tests/character_test.gd" "res://tests/sound_test.tscn" "res://tests/menu_test.tscn" "res://tests/scroll_tap_test.tscn" "res://tests/split_test.tscn" "res://tests/finish_driving_test.tscn" "res://tests/pause_test.tscn" "res://tests/focus_test.tscn" "res://tests/pad_tour_test.tscn" "res://tests/racer_names_test.tscn" "res://tests/modes_test.tscn" "res://tests/podium_test.tscn" "res://tests/stock_test.tscn" "res://tests/kart_picker_layout_test.tscn" "res://tests/results_layout_test.tscn" "res://tests/difficulty_test.tscn" "res://tests/camera_test.tscn" "res://tests/rear_view_mirror_test.tscn" "res://tests/race_test.tscn -- peach_pit" "res://tests/race_test.tscn -- launchpad_loop" "res://tests/race_test.tscn -- built" "res://tests/race_test.tscn -- crossing" "res://tests/race_test.tscn -- res://tests/data/sky_test.json" "res://tests/race_test.tscn -- peach_pit rain" "res://tests/race_test.tscn -- frostbite_forest snow" "-s tests/course_test.gd" "-s tests/angled_track_test.gd" "res://tests/track_parts_upgrade_test.tscn" "res://tests/half_grid_test.tscn" "res://tests/quarter_straight_test.tscn" "res://tests/adjustable_road_test.tscn" "res://tests/adjustable_editor_test.tscn" "res://tests/map_rotation_test.tscn" "res://tests/track_closing_upgrade_test.tscn" "res://tests/figure_eight_test.tscn" "res://tests/banked_clearance_test.tscn" "-s tests/advanced_closer_test.gd" "-s tests/sharing_test.gd" "res://tests/angled_sharing_test.tscn" "-s tests/creation_library_test.gd" "res://tests/creations_menu_test.tscn" "res://tests/sharing_ui_test.tscn" "res://tests/editor_test.tscn" "res://tests/editor_first_scene_test.tscn" "res://tests/palette_test.tscn" "res://tests/rail_test.tscn" "res://tests/angled_editor_test.tscn" "res://tests/bluetooth_test.tscn" "-s tests/runoff_test.gd" "-s tests/edges_test.gd" "-s tests/crossing_test.gd" "-s tests/sky_test.gd"; do
	echo "== $test"
	mkdir -p build/creations
	profile=$(mktemp -d "$PWD/build/creations/profile.XXXXXX")
	profile_env=(env "XDG_DATA_HOME=$profile")
	# shellcheck disable=SC2086
	"${profile_env[@]}" timeout 600 "$GODOT" --headless --fixed-fps 60 --path . $test 2>&1 | grep -E "^  (ok|FAIL)|passed|failed|ERROR"
	codes=("${PIPESTATUS[@]}")
	if [ -n "${profile:-}" ]; then
		rm -rf -- "$profile"
	fi
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
