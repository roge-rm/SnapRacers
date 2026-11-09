extends Node

## Checks the editor's offered shapes, paired rows, landmark filters and focus.
##   tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --path . res://tests/palette_test.tscn

var failures := 0
var ui: TrackEditorUI
var chosen: Dictionary = {}
var landmark := ""


func check(ok: bool, what: String) -> void:
	print(("  ok    " if ok else "  FAIL  ") + what)
	if not ok:
		failures += 1


func frames(n := 2) -> void:
	for i in n:
		await get_tree().process_frame


func _ready() -> void:
	_shapes()
	ui = TrackEditorUI.new()
	add_child(ui)
	ui.piece_chosen.connect(func(spec: Dictionary) -> void: chosen = spec)
	ui.landmark_chosen.connect(func(prop: String) -> void: landmark = prop)
	await frames()
	_tiles()
	await _focus()
	await _landmarks()
	ui.queue_free()
	await frames()
	print("All palette checks passed." if failures == 0 else "%d palette checks failed." % failures)
	get_tree().quit(1 if failures > 0 else 0)


func _category(name: String) -> int:
	for i in TrackCatalogue.CATEGORIES.size():
		if TrackCatalogue.CATEGORIES[i][0] == name:
			return i
	return -1


func _specs(index: int) -> Array:
	var specs: Array = []
	for row in TrackEditorUI.CATEGORIES[index][2]:
		for entry in row:
			specs.append(entry[1])
	return specs


func _shapes() -> void:
	var all: Array = []
	var paired := true
	for category in TrackEditorUI.CATEGORIES:
		for row in category[2]:
			paired = paired and (row.size() == 2 or (category[0] == "Straights" and row.size() == 1))
			var left: Dictionary = row[0][1]
			var right: Dictionary = row[-1][1]
			var side := "turn" if left.has("turn") else "side"
			if left.has(side):
				var mirrored := left.duplicate()
				mirrored[side] = "right"
				paired = paired and left[side] == "left" and mirrored == right
			for entry in row:
				all.append(entry[1])
	check(paired, "each mirrored pair has a complete left/right row")
	check(all.size() == 98, "98 useful parts are offered (%d)" % all.size())
	var unique: Array = []
	var finite := true
	var round_trip := true
	for spec in all:
		if not unique.has(spec):
			unique.append(spec)
		var piece := TrackPiece.from_spec(spec)
		var back := TrackPiece.from_spec(piece.to_spec())
		for step in 17:
			var at := float(step) / 16.0
			finite = finite and piece.point(at).is_finite()
			round_trip = round_trip and piece.point(at).is_equal_approx(back.point(at))
		round_trip = round_trip and piece.exit().is_equal_approx(back.exit())
	check(unique.size() == all.size(), "every preset has a distinct spec")
	var choice_order := PackedStringArray(TrackCatalogue.closer_choices().map(func(spec): return TrackCatalogue._spec_key(spec)))
	check(choice_order.size() == 55 and "\n".join(choice_order.slice(0, 54)).sha256_text() == "bffdefaf9a8703dd0d121f2aa393bd3c3eff140006d08eacb3b3493ef52e33d7", "reorganising the drawer preserves the existing closer order before the quarter straight")
	check(finite and round_trip, "every offered shape samples and round-trips through the existing parser")
	check(TrackCatalogue.dimensions({"type": "straight", "length": 2.5}) == "64 m long" and TrackCatalogue.dimensions({"type": "slant", "length": 2.5, "across": 1.5}) == "64 m along · 32 m across", "legacy fractional straight and offset captions match their built integer geometry")
	var fractional_bend := {"type": "curve", "size": 2.5, "angle": 45, "rise": 0.5}
	check(TrackCatalogue.dimensions(fractional_bend) == "90° · radius 48 m · up 1.5 m" and TrackCatalogue.piece_name(fractional_bend).begins_with("90° climb"), "legacy bend inspection uses its actual angle and radius while retaining fractional rise")
	var bends := _specs(_category("Bends"))
	check(bends.has({"type": "curve", "turn": "left", "size": 4}) and bends.has({"type": "curve", "turn": "right", "size": 4}), "extra wide bends are offered")
	var banked := _specs(_category("Banked"))
	check(banked.size() == 8 and banked.all(func(spec): return spec.has("bank")) and bends.all(func(spec): return not spec.has("bank") and not spec.has("cut")), "Banked has all eight banking and wall ride parts, Bends has plain bends")
	var offsets := _specs(_category("Offsets"))
	var diagonal := true
	var gentle := true
	var rising := true
	for side in ["left", "right"]:
		for length in [3, 4]:
			var spec := {"type": "slant", "turn": side, "length": length, "across": length - 1}
			diagonal = diagonal and offsets.has(spec)
			var piece := TrackPiece.from_spec(spec)
			var middle := piece.point(0.501) - piece.point(0.499)
			diagonal = diagonal and absf(absf(middle.x / middle.z) - 1.0) < 0.001
			diagonal = diagonal and piece.exit().basis.is_equal_approx(Basis.IDENTITY)
		gentle = gentle and offsets.has({"type": "slant", "turn": side, "length": 4, "across": 1})
		for rise in [-1, 1]:
			rising = rising and offsets.has({"type": "slant", "turn": side, "length": 3, "across": 1, "rise": rise})
	check(diagonal, "both 45-degree middles are offered with forward-facing endpoints")
	check(gentle and rising, "gentle long offsets and rising/falling offsets are offered both ways")
	var hills := _specs(_category("Hills"))
	var bridges := true
	for rise in [-2, 2]:
		for length in [2, 3]:
			var spec := {"type": "ramp", "length": length, "rise": rise}
			bridges = bridges and hills.has(spec) and is_equal_approx(absf(TrackPiece.from_spec(spec).exit().origin.y), 6.0)
	check(bridges, "6 m bridge ramps have short and gentle approaches in both directions")
	check(hills[0].type == "ramp" and hills[-1].type == "crest", "Hills starts with ramps and ends with humps")
	var specials := _specs(_category("Specials"))
	check(specials.has({"type": "crossing"}) and not _specs(0).has({"type": "crossing"}), "the level crossing is with Specials")
	check(specials.has({"type": "loop", "side": "left"}) and specials.has({"type": "corkscrew", "side": "left"}), "loops and corkscrews have their left mirrors")
	check(TrackEditorUI.SURFACES.has(["Concrete", "concrete"]), "concrete is offered as a surface")
	check(specials.size() == 8 and specials.has({"type": "curve", "turn": "right", "size": 2, "cut": true}), "shortcuts sit with the eight Specials")
	check(TrackCatalogue.CATEGORIES.map(func(c): return c[0]) == ["Straights", "Bends", "Offsets", "Hills", "Banked", "Specials"], "six road tabs keep the agreed family order")
	check(TrackCatalogue.CATEGORIES.map(func(c): return _specs(_category(c[0])).size()) == [6, 32, 16, 28, 8, 8], "every family has its complete directly pickable parts")
	var straight_lengths := _specs(_category("Straights")).map(func(spec): return TrackPiece.from_spec(spec).run_length())
	check(straight_lengths == [8.0, 16.0, 32.0, 64.0, 96.0, 128.0], "straights run from the quarter tile through four tiles")
	var ramp_order := hills.filter(func(spec): return spec.type == "ramp").map(func(spec): return [spec.length, spec.rise])
	check(ramp_order == [[1, 1], [1, -1], [2, 1], [2, -1], [3, 1], [3, -1], [2, 2], [2, -2], [3, 2], [3, -2]], "ramps run by 3 then 6 m rise, short to gentle, up/down together")
	var modified := {"type": "arc", "angle": 45, "turn": "left", "size": 2, "bank": 22, "surface": "dirt", "edges": "open"}
	check(TrackCatalogue.piece_name(modified) == "45° bank 22° · Normal left" and TrackCatalogue.dimensions(modified) == "45° · radius 48 m · bank 22°", "surface and edges keep preset identity and actual dimensions")
	var imported := {"type": "arc", "angle": 30, "turn": "right", "size": 4, "rise": 0.5}
	check(TrackCatalogue.piece_name(imported) == "30° climb right" and TrackCatalogue.dimensions(imported) == "30° · radius 112 m · up 1.5 m", "an imported non-preset shows its own angle, radius and rise")
	var profile := PieceIcon.new({"type": "ramp"})
	check(profile.profile_height(PackedFloat32Array([0, 1.5])) == 6 and profile.profile_height(PackedFloat32Array([0, 3])) == 6 and profile.profile_height(PackedFloat32Array([0, -6])) == 6, "ordinary humps and both ramp heights share the 6 m side-view scale")
	profile.free()
	profile = PieceIcon.new({"type": "loop"})
	check(profile.profile_height(PackedFloat32Array([0, 29])) >= 29, "a tall stunt has enough side-view scale for its captioned height")
	profile.free()


func _tiles() -> void:
	var all_match := true
	for index in TrackEditorUI.CATEGORIES.size():
		ui._show_category(index)
		var specs := _specs(index)
		var tiles := ui._tiles.get_children()
		all_match = all_match and tiles.size() == specs.size()
		for i in mini(tiles.size(), specs.size()):
			chosen = {}
			tiles[i].pressed.emit()
			all_match = all_match and chosen == specs[i]
	check(all_match, "switching tabs immediately leaves only current tiles, each choosing its own spec")
	ui._show_category(0)
	check(not ui._landmark_filter.visible, "the landmark filter stays out of road tabs")


func _focus() -> void:
	ui._show_category(1)
	ui._tiles.get_child(5).grab_focus()
	ui._show_category(2)
	ui.focus_palette()
	ui._tiles.get_child(8).grab_focus()
	ui._show_category(1)
	await frames()
	check(get_viewport().gui_get_focus_owner() == ui._tiles.get_child(5), "returning to Bends remembers its tile")
	ui._show_category(2)
	await frames()
	check(get_viewport().gui_get_focus_owner() == ui._tiles.get_child(8), "each road tab remembers its own tile")
	ui._show_category(2)
	await frames()
	check(get_viewport().gui_get_focus_owner() == ui._tiles.get_child(8), "refreshing a tab restores focus to a current tile")


func _landmarks() -> void:
	ui._show_category(1)
	await frames(3)
	var parts_width := ui._drawer.size.x
	var all: Array = TrackEditorUI.LANDMARKS.map(func(entry): return entry[1])
	var grouped: Array = []
	for group in TrackEditorUI.LANDMARK_GROUPS:
		grouped.append_array(group[1])
	var complete := grouped.size() == all.size()
	for prop in all:
		complete = complete and grouped.count(prop) == 1
	check(complete, "every landmark belongs to exactly one named group (%d)" % all.size())
	ui._show_category(TrackEditorUI.CATEGORIES.size())
	check(ui._landmark_filter.visible and ui._landmark_filter.item_count == TrackEditorUI.LANDMARK_GROUPS.size() + 1, "Landmarks offers All and its named groups")
	var shown := _shown_props()
	check(shown.size() == all.size() - Props.BELOW_ROAD.size() and not shown.any(func(prop): return prop in Props.BELOW_ROAD), "All keeps below-road scenery out of ground courses")
	var groups_match := true
	var width_matches := true
	for i in TrackEditorUI.LANDMARK_GROUPS.size():
		ui._landmark_filter.item_selected.emit(i + 1)
		await frames(3)
		width_matches = width_matches and ui._drawer.size.x <= parts_width and is_equal_approx(ui._landmark_filter.size.x, ui._tiles.size.x)
		shown = _shown_props()
		var expected: Array = TrackEditorUI.LANDMARK_GROUPS[i][1].filter(func(prop): return not prop in Props.BELOW_ROAD)
		groups_match = groups_match and shown.size() == expected.size()
		for prop in shown:
			groups_match = groups_match and prop in expected
		if ui._tiles.get_child_count() > 0:
			landmark = ""
			ui._tiles.get_child(0).pressed.emit()
			groups_match = groups_match and landmark == shown[0]
	check(groups_match, "each filter offers only its available landmarks and chooses the shown prop")
	check(width_matches, "every landmark group keeps the filter and drawer aligned with the two-column parts grid")
	ui._choose_landmark_group(1)
	ui._tiles.get_child(3).grab_focus()
	ui._choose_landmark_group(2)
	ui.focus_palette()
	ui._choose_landmark_group(1)
	await frames()
	check(get_viewport().gui_get_focus_owner() == ui._tiles.get_child(3), "each landmark group remembers its own tile")
	var sky_course := CourseDesign.starter()
	sky_course.theme = "sky"
	ui.show_course(sky_course, 0.0, [], false)
	ui._choose_landmark_group(0)
	check(_shown_props().size() == all.size(), "All includes every landmark in sky courses")
	var sky_group := TrackEditorUI.LANDMARK_GROUPS.size()
	ui._choose_landmark_group(sky_group)
	var below := ui._tiles.get_children().filter(func(tile): return tile.get_meta("prop") in Props.BELOW_ROAD)
	below[0].grab_focus()
	sky_course.theme = "orchard"
	ui.show_course(sky_course, 0.0, [], false)
	await frames()
	var focused := get_viewport().gui_get_focus_owner()
	check(_shown_props().size() == 2 and focused != null and ui._tiles.is_ancestor_of(focused), "changing from sky to ground removes excluded landmarks and safely restores tile focus")


func _shown_props() -> Array:
	return ui._tiles.get_children().map(func(tile): return tile.get_meta("prop", ""))
