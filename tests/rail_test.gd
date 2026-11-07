extends Node

## Checks category groups and the ordinary SafeArea flow around cutouts.
##   tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --path . res://tests/rail_test.tscn
## Run without --headless and with --fixed-fps 60 to check first drawn frames.

var failures := 0
var _entry_ui: Control
var _drawn: Array = []


func check(ok: bool, what: String) -> void:
	print(("  ok    " if ok else "  FAIL  ") + what)
	if not ok:
		failures += 1


func frames(n := 8) -> void:
	for i in n:
		await get_tree().process_frame


func _ready() -> void:
	await _groups(7)
	await _groups(8)
	await _groups(9)
	await _ordinary_flow(false)
	await _ordinary_flow(true)
	await _layout_lifecycle()
	await _builders()
	if DisplayServer.get_name() != "headless":
		RenderingServer.frame_pre_draw.connect(_capture_entry)
		await _entries()
		RenderingServer.frame_pre_draw.disconnect(_capture_entry)
	SafeArea.pretend = []
	print("All rail checks passed." if failures == 0 else "%d rail checks failed." % failures)
	get_tree().quit(1 if failures > 0 else 0)


## Observe the geometry that will actually be drawn, including the first
## frame and the polls after half a second. Run this scene without --headless.
func _capture_entry() -> void:
	if not is_instance_valid(_entry_ui) or not _entry_ui.is_visible_in_tree():
		return
	var safe: SafeArea = _entry_ui.find_child("SafeArea", false, false)
	var geometry: Array = [_entry_ui._drawer.get_global_rect()]
	for tab in _entry_ui._rail:
		geometry.append(tab.get_global_rect())
	_drawn.append([geometry, safe._fitting, safe._last_sizes.duplicate()])


func _entries() -> void:
	for kind in 3:
		var label: String = ["garage", "driver", "track editor"][kind]
		var height := get_viewport().get_visible_rect().size.y
		var middle := Rect2(0, height * 0.5 - 10.0, 32, 20)
		for entry in ["middle", "top", "bottom", "none"]:
			var hole := middle
			if entry == "top":
				hole = Rect2(0, 0, 64, 40)
			elif entry == "bottom":
				hole = Rect2(0, height - 40.0, 64, 40)
			if entry == "none":
				_holes([])
			else:
				_holes([hole])
			_entry_ui = [GarageUI, DriverUI, TrackEditorUI][kind].new()
			_drawn = []
			add_child(_entry_ui)
			var safe: SafeArea = _entry_ui.find_child("SafeArea", false, false)
			var sorts := [0]
			_entry_ui._rail_box.sort_children.connect(func() -> void: sorts[0] += 1)
			await RenderingServer.frame_post_draw
			var first_sorts: int = sorts[0]
			await frames(70)
			var stable := _drawn.size() >= 60
			for draw in _drawn:
				stable = stable and draw[0] == _drawn[0][0] and not draw[1] and draw[2] == safe._last_sizes
			check(stable and sorts[0] == first_sorts, "%s %s cutout is settled on its first drawn frame and through the 0.5 s polls (%d frames)" % [label, entry, _drawn.size()])
			if entry == "middle":
				_check_groups(_entry_ui._rail_box, _entry_ui._rail, hole, label + " first presentation")
				var window_size := DisplayServer.window_get_size()
				DisplayServer.window_set_size(window_size + Vector2i(80, 80))
				await frames(2)
				var resized_hole := Rect2(0, get_viewport().get_visible_rect().size.y * 0.5 - 10.0, 32, 20)
				_holes([resized_hole])
				await frames(40)
				_check_groups(_entry_ui._rail_box, _entry_ui._rail, resized_hole, label + " after window resize")
				DisplayServer.window_set_size(window_size)
				await frames(2)
				_holes([middle])
				await frames(40)
				_check_groups(_entry_ui._rail_box, _entry_ui._rail, middle, label + " after restoring window size")
				# Turning the phone moves its cutout to the other edge.
				_holes([Rect2(get_viewport().get_visible_rect().size.x - 32.0, middle.position.y, 32, 20)])
				await frames(40)
				var gap: Control = safe._gaps.get(_entry_ui._rail_box)
				check(gap != null and not gap.visible and is_zero_approx(_entry_ui._rail[0].position.y), label + " closes the rail gap when the cutout rotates to the other side")
				_holes([middle])
				await frames(40)
				_check_groups(_entry_ui._rail_box, _entry_ui._rail, middle, label + " rotated back")
				_holes([])
				await frames(40)
				check(not gap.visible and gap.custom_minimum_size == Vector2.ZERO, label + " restores the ordinary rail after the cutout is removed")
			elif entry != "none":
				var drawer: Rect2 = _entry_ui._drawer.get_global_rect()
				check(drawer.position.y >= hole.end.y + SafeArea.CLEAR if entry == "top" else drawer.end.y <= hole.position.y - SafeArea.CLEAR, label + " clears its initial " + entry + " cutout")
			_entry_ui.queue_free()
			_entry_ui = null
			_holes([])
			await frames(2)


func _layout_lifecycle() -> void:
	var safe := SafeArea.new()
	var box := VBoxContainer.new()
	box.position = Vector2(100, 100)
	box.size = Vector2(200, 400)
	box.add_theme_constant_override("separation", 0)
	for i in 4:
		var item := Control.new()
		item.custom_minimum_size = Vector2(48, 52)
		box.add_child(item)
	safe.flow(box)
	safe.refit()
	await frames(2)
	check(not safe._fitting, "configuring SafeArea before attachment does not start a layout wait")
	add_child(box)
	add_child(safe)
	_holes([Rect2(100, 165, 200, 20)])
	safe.refit()
	await frames()
	var gap: Control = safe._gaps.get(box)
	check(gap != null and gap.visible and not safe._fitting, "preconfigured flow settles after SafeArea enters the tree")
	remove_child(box)
	safe.refit()
	await frames()
	check(not safe._fitting, "a detached registered container cannot strand layout")
	add_child(box)
	_holes([])
	safe.refit()
	await frames()
	check(not gap.visible and not safe._fitting, "reattached flow still responds to cutout removal")
	safe.refit()
	box.free()
	await frames()
	check(not safe._fitting, "freeing a container during its pending sort cancels the wait")
	var replacement := HBoxContainer.new()
	replacement.position = Vector2(100, 100)
	replacement.size = Vector2(400, 100)
	replacement.add_theme_constant_override("separation", 0)
	for i in 4:
		var item := Control.new()
		item.custom_minimum_size = Vector2(48, 52)
		replacement.add_child(item)
	add_child(replacement)
	safe.flow(replacement)
	_holes([Rect2(165, 100, 20, 100)])
	safe.refit()
	await frames()
	var next_gap: Control = safe._gaps.get(replacement)
	check(next_gap != null and next_gap.visible and not safe._fitting, "later flow and cutout changes still work after a pending container is freed")
	safe.refit()
	remove_child(safe)
	await frames()
	check(not safe._fitting, "detaching SafeArea during layout releases its pending fit")
	add_child(safe)
	_holes([])
	safe.refit()
	await frames()
	check(next_gap != null and not next_gap.visible and not safe._fitting, "reattaching SafeArea refits without waiting for ready to run again")
	safe.queue_free()
	replacement.queue_free()
	_holes([])
	await frames()


func _holes(rects: Array[Rect2]) -> void:
	SafeArea.pretend = []
	var scale := SafeArea.screen_size(get_viewport()) / get_viewport().get_visible_rect().size
	for rect in rects:
		SafeArea.pretend.append(Rect2(rect.position * scale, rect.size * scale))


func _groups(count: int) -> void:
	var rail := RailBox.new()
	rail.position = Vector2(20, 20)
	rail.size = Vector2(48, 640)
	rail.add_theme_constant_override("separation", 0)
	add_child(rail)
	var tabs: Array[IconButton] = []
	for i in count:
		var tab := BuilderStyle.rail_tab("head", str(i))
		rail.add_child(tab)
		tabs.append(tab)
	var safe := SafeArea.new()
	add_child(safe)
	safe.flow(rail)
	await frames()
	var original := tabs.map(func(tab: IconButton) -> Vector2: return tab.position)
	var hole := Rect2(20, 310, 32, 40)
	_holes([hole])
	safe.refit()
	await frames()
	_check_groups(rail, tabs, hole, "%d tabs" % count)
	var gap: Control = safe._gaps.get(rail)
	check(gap != null and gap.focus_mode == Control.FOCUS_NONE and gap.mouse_filter == Control.MOUSE_FILTER_IGNORE, "the centre gap cannot take focus or taps")
	var ordered := true
	for i in count - 1:
		ordered = ordered and tabs[i].get_index() < tabs[i + 1].get_index()
	check(ordered, "category child order survives the split")
	tabs[ceili(count * 0.5) - 1].grab_focus()
	check(tabs[ceili(count * 0.5) - 1].find_next_valid_focus() == tabs[ceili(count * 0.5)], "focus crosses the centre gap in category order")
	# Enlarging the rail stretches only the gap.
	rail.size.y = 700
	safe.refit()
	await frames()
	_check_groups(rail, tabs, hole, "%d tabs after growing" % count)
	rail.size.y = 540
	safe.refit()
	await frames()
	if count == 9:
		check(gap.size_flags_vertical == Control.SIZE_FILL, "shrinking the rail falls back when a group would meet the cutout")
	rail.size.y = 640
	safe.refit()
	await frames()
	_check_groups(rail, tabs, hole, "%d tabs after shrinking and restoring" % count)
	# This hole cannot fit between equal groups, so normal flow moves only
	# the tabs that would meet it.
	rail.size.y = 640
	hole = Rect2(20, 210, 32, 24)
	_holes([hole])
	safe.refit()
	await frames()
	var clear := true
	for tab in tabs:
		clear = clear and not tab.get_global_rect().intersects(hole.grow(SafeArea.CLEAR))
	check(clear and gap.size_flags_vertical == Control.SIZE_FILL and not is_equal_approx(tabs[-1].get_rect().end.y, rail.size.y), "%d tabs use ordinary flow when equal groups cannot clear the hole" % count)
	_holes([])
	safe.refit()
	await frames()
	check(tabs.map(func(tab: IconButton) -> Vector2: return tab.position) == original and not gap.visible and gap.custom_minimum_size == Vector2.ZERO, "%d tabs restore their original layout without a cutout" % count)
	# A hole elsewhere on the screen does not spread the rail apart.
	_holes([Rect2(800, 310, 32, 40)])
	safe.refit()
	await frames()
	check(tabs.map(func(tab: IconButton) -> Vector2: return tab.position) == original, "%d tabs stay together for a cutout on the other side" % count)
	rail.queue_free()
	safe.queue_free()
	_holes([])
	await frames()


func _check_groups(rail: RailBox, tabs: Array[IconButton], hole: Rect2, label: String) -> void:
	var split := ceili(tabs.size() * 0.5)
	var grouped := is_zero_approx(tabs[0].position.y) and is_equal_approx(tabs[-1].get_rect().end.y, rail.size.y)
	var clear := true
	for i in tabs.size():
		clear = clear and not tabs[i].get_global_rect().intersects(hole.grow(SafeArea.CLEAR))
		if i > 0 and i != split:
			grouped = grouped and is_equal_approx(tabs[i].position.y, tabs[i - 1].get_rect().end.y)
	check(grouped and clear and tabs[split].position.y > tabs[split - 1].get_rect().end.y, "%s split %d/%d, flush with both ends and clear of the cutout" % [label, split, tabs.size() - split])


func _ordinary_flow(horizontal: bool) -> void:
	var box: BoxContainer = HBoxContainer.new() if horizontal else VBoxContainer.new()
	box.position = Vector2(100, 100)
	box.size = Vector2(400, 400)
	box.add_theme_constant_override("separation", 0)
	add_child(box)
	var children: Array[Control] = []
	for i in 4:
		var child := Control.new()
		child.custom_minimum_size = Vector2(48, 52)
		box.add_child(child)
		children.append(child)
	var safe := SafeArea.new()
	add_child(safe)
	safe.flow(box)
	await frames()
	var hole := Rect2(165, 100, 20, 400) if horizontal else Rect2(100, 165, 400, 20)
	_holes([hole])
	safe.refit()
	await frames()
	var gap: Control = safe._gaps.get(box)
	check(gap != null and gap.get_index() == 1 and not children[1].get_global_rect().intersects(hole.grow(SafeArea.CLEAR)), "ordinary %s flow keeps its gap before the first intersecting child" % ("horizontal" if horizontal else "vertical"))
	box.queue_free()
	safe.queue_free()
	_holes([])
	await frames()


func _builders() -> void:
	for ui in [GarageUI.new(), DriverUI.new(), TrackEditorUI.new()]:
		add_child(ui)
		await frames()
		if ui is TrackEditorUI:
			check(ui._rail.size() == 7 and ui._rail[4].picture == "banked", "the track editor has seven native rail tabs including Banked")
		var rail: RailBox = ui._rail_box
		var safe: SafeArea = ui.find_child("SafeArea", false, false)
		var rect := rail.get_global_rect()
		var hole := Rect2(rect.position.x, rect.get_center().y - 10.0, 24, 20)
		_holes([hole])
		safe.refit()
		await frames(16)
		_check_groups(rail, ui._rail, hole, ("garage" if ui is GarageUI else "driver" if ui is DriverUI else "track editor") + " shared rail")
		for bottom in [false, true]:
			var height := get_viewport().get_visible_rect().size.y
			var edge := Rect2(0, height - 40 if bottom else 0.0, 64, 40)
			_holes([edge])
			safe.refit()
			await frames(16)
			var drawer_rect: Rect2 = ui._drawer.get_global_rect()
			var shortens := drawer_rect.end.y <= edge.position.y - SafeArea.CLEAR if bottom else drawer_rect.position.y >= edge.end.y + SafeArea.CLEAR
			var gap: Control = safe._gaps.get(rail)
			check(shortens and gap != null and not gap.visible, "an edge cutout still shortens the drawer at the %s" % ("bottom" if bottom else "top"))
		ui.queue_free()
		_holes([])
		await frames()
