extends SceneTree

## The graphics setting: lower draws less scenery, no crowd and no studs,
## but everything a kart could hit is exactly where it is at High, so
## everyone races the same whatever they've picked.
##
##   tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --path . -s tests/graphics_test.gd

var failures := 0


func check(ok: bool, what: String) -> void:
	print(("  ok    " if ok else "  FAIL  ") + what)
	if not ok:
		failures += 1


## Builds the scenery of a course at this level, and gives back its kit.
func scenery_at(level: String, holder: Node) -> SceneryKit:
	Graphics.level = level
	var track := TrackPath.load_file("res://data/tracks/peach_pit.json")
	var dressing := Scenery.new(track, track.theme)
	holder.add_child(dressing)
	var kit: SceneryKit = dressing._kit
	dressing.free()
	return kit


func _initialize() -> void:
	# Things only build once they're in the tree, which it isn't yet here.
	var runner := Node.new()
	runner.ready.connect(_checks.bind(runner))
	root.add_child(runner)


func _checks(holder: Node) -> void:
	var high := scenery_at("high", holder)
	var low := scenery_at("low", holder)
	var solids := func(kit: SceneryKit) -> String: return str(kit.solids.map(func(s): return [s[0].origin.snapped(Vector3.ONE * 0.01), s[1]]))
	check(not high.solids.is_empty() and solids.call(high) == solids.call(low), "at Low everything a kart could hit is just where it is at High (%d solid)" % high.solids.size())
	var shapes := func(kit: SceneryKit) -> int: return kit.boxes.size() + kit.cylinders.size() + kit.cones.size()
	check(shapes.call(low) < shapes.call(high), "but it draws less far off scenery (%d shapes against %d)" % [shapes.call(low), shapes.call(high)])
	Graphics.level = "low"
	check(not Graphics.value("crowd") and Graphics.shadows() == 0.0 and Graphics.value("scale") < 1.0, "and no crowd, no shadows and a lower resolution")
	Graphics.level = "high"
	check(Graphics.value("crowd") and Graphics.shadows() == 1.0 and Graphics.value("scale") == 1.0, "while High draws everything")
	print("All graphics checks passed." if failures == 0 else "%d graphics checks failed." % failures)
	quit(1 if failures > 0 else 0)
