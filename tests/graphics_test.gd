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
	if level == "high":
		check_cells(dressing, kit)
	dressing.free()
	return kit


func check_cells(dressing: Node, kit: SceneryKit) -> void:
	var damage: WorldDamage = null
	for child in dressing.get_children():
		if child is WorldDamage:
			damage = child
			break
	var cells: Array = []
	if damage != null:
		cells = damage.get_children().filter(func(n): return n is MultiMeshInstance3D and n.get_meta("scenery_cell", false))
	check(cells.size() > 1, "scenery is drawn in cells (%d)" % cells.size())
	var far_end := false
	var stay_end := false
	var shadows_on := true
	for draw in cells:
		if draw.get_meta("far"):
			far_end = far_end or (is_equal_approx(draw.visibility_range_end, WorldDamage.far_range()) and draw.material_override == SceneryKit.far_material(Graphics.far()))
		else:
			stay_end = stay_end or is_equal_approx(draw.visibility_range_end, 0.0)
		if draw.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			shadows_on = false
	check(far_end, "far-off fillers fade out by %.0f m and drop out past %.0f m" % [Graphics.far(), WorldDamage.far_range()])
	check(stay_end, "buildings and trackside stay drawn")
	check(shadows_on, "and they still cast shadows")
	var far_boxes := 0
	var stay_boxes := 0
	for box in kit.boxes:
		if box.size() > 4 and box[4]:
			far_boxes += 1
		else:
			stay_boxes += 1
	check(far_boxes > 0 and stay_boxes > 0, "the kit marks fillers far (%d far, %d stay)" % [far_boxes, stay_boxes])
	var empty_aabb := 0
	var wide := 0
	for draw in cells:
		var aabb: AABB = draw.multimesh.custom_aabb
		if aabb.size == Vector3.ZERO:
			empty_aabb += 1
		if aabb.size.x > WorldDamage.CELL * 2.0 or aabb.size.z > WorldDamage.CELL * 2.0:
			wide += 1
	check(empty_aabb == 0 and wide == 0, "each cell's bounds are the cell (%d empty, %d wide)" % [empty_aabb, wide])


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
	var shapes := func(kit: SceneryKit) -> int: return kit.boxes.size() + kit.cylinders.size() + kit.cones.size() + kit.balls.size()
	check(shapes.call(low) < shapes.call(high), "but it draws less far off scenery (%d shapes against %d)" % [shapes.call(low), shapes.call(high)])
	Graphics.level = "low"
	check(not Graphics.value("crowd") and Graphics.shadows() == 0.0 and Graphics.value("scale") < 1.0 and Graphics.beams() == 0.0, "and no crowd, no shadows, a lower resolution and only your own headlight beams")
	Graphics.level = "high"
	check(Graphics.value("crowd") and Graphics.shadows() == 1.0 and Graphics.value("scale") == 1.0 and Graphics.beams() > 0.0, "while High draws everything")
	var lit := SkyAndSun.add_to(holder)
	check(lit.sun.directional_shadow_mode == DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS, "High uses four shadow splits so close things stay sharp")
	check(lit.sun.directional_shadow_split_1 <= 0.05, "with a tight first split for the kart (%.2f)" % lit.sun.directional_shadow_split_1)
	print("All graphics checks passed." if failures == 0 else "%d graphics checks failed." % failures)
	quit(1 if failures > 0 else 0)
