extends Node

## The main menu's course window picks a still at random from every course
## that comes with the game.
##
##   tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --fixed-fps 60 --path . res://tests/race_window_test.tscn

var failures := 0


func check(ok: bool, what: String) -> void:
	print(("  ok    " if ok else "  FAIL  ") + what)
	if not ok:
		failures += 1


func _ready() -> void:
	var ids: Array = Tracks.all()
	check(ids.size() >= 2, "the game ships more than one course (%d)" % ids.size())
	var unique := {}
	var stills := 0
	for id in ids:
		unique[id] = true
		if FileAccess.file_exists(RaceWindow.still_path(id)):
			stills += 1
	check(unique.size() == ids.size(), "each shipped course is in the cups once")
	check(stills == ids.size(), "each shipped course has a menu still (%d of %d)" % [stills, ids.size()])

	RaceWindow._bag.clear()
	RaceWindow._last_id = ""
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var first := RaceWindow.pick_id(rng)
	check(ids.has(first), "a pick is one of the shipped courses (%s)" % first)

	rng.seed = 12345
	RaceWindow._bag.clear()
	RaceWindow._last_id = ""
	check(RaceWindow.pick_id(rng) == first, "the same seed repeats the same pick")

	RaceWindow._bag.clear()
	RaceWindow._last_id = ""
	rng.seed = 7
	var seen := {}
	var prev := ""
	var repeats := 0
	for _n in ids.size():
		var id := RaceWindow.pick_id(rng)
		if id == prev:
			repeats += 1
		seen[id] = true
		prev = id
	check(repeats == 0, "one pass never shows the same course twice in a row")
	check(seen.size() == ids.size(), "one pass shows every shipped course (%d of %d)" % [seen.size(), ids.size()])
	var again := RaceWindow.pick_id(rng)
	check(ids.has(again) and again != prev, "the next pass starts on a different course (%s after %s)" % [again, prev])

	RaceWindow.forced_id = "peach_pit"
	var window := RaceWindow.new()
	add_child(window)
	window.size = Vector2(800, 500)
	await get_tree().process_frame
	check(window.course_id == "peach_pit" and window.course_name == "PEACH PIT", "a forced course shows that course's name")
	check(window._picture != null and window._picture.get_size().x > 0, "and its still")
	window.free()

	RaceWindow.forced_id = ""
	RaceWindow._bag.clear()
	RaceWindow._last_id = ""
	var live := RaceWindow.new()
	add_child(live)
	live.size = Vector2(800, 500)
	await get_tree().process_frame
	check(ids.has(live.course_id), "_ready picks a shipped course (%s)" % live.course_id)
	check(live.course_name != "" and live._picture != null, "and shows that course's still")
	live.free()
	RaceWindow._bag.clear()
	RaceWindow._last_id = ""

	print("All race window checks passed." if failures == 0 else "%d race window checks failed." % failures)
	get_tree().quit(1 if failures > 0 else 0)
