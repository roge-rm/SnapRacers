class_name DriverBuilder
extends Node3D

## Where you build your driver.
##
## They stand on a turntable in the middle, slowly turning (drag to spin them
## yourself). Down the left are the five pieces: pick one, then a style and a
## colour for it. On the right are their name and how heavy they've come out,
## which is what decides their class. Everything saves as you go.

const SPIN := 0.35 # radians a second when nobody's touching it
const TABS := [["head", "Head"], ["headgear", "Headgear"], ["torso", "Torso"], ["arms", "Arms"], ["legs", "Legs"]]

var design: CharacterDesign
var _rig: CharacterRig
var _turntable: Node3D
var _camera: Camera3D
var _slot := "head"
var _dragging := false
var _last_touch := 0.0

var _styles: VBoxContainer
var _swatches: GridContainer
var _tab_buttons: Array[Button] = []
var _name_edit: LineEdit
var _weight: Label
var _panels: Array[Control] = []
## Showing them sat in a seat steering, instead of standing.
var _driving := false
var _pose_button: Button
var _wheel: SteeringVisual
var _time := 0.0


func _ready() -> void:
	design = Game.character.duplicate_design()
	SkyAndSun.add_to(self, 20.0, MenuStyle.BOTTOM)
	for child in get_children():
		if child is WorldEnvironment:
			child.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
			child.environment.ambient_light_color = Color("#e8e4f0")
			child.environment.ambient_light_energy = 0.4
			child.environment.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
		elif child is DirectionalLight3D:
			child.light_energy = 0.85
			# Close up, the hips' shadow on the legs came out as a sawtooth.
			child.shadow_bias = 0.08
			child.shadow_normal_bias = 2.5

	_turntable = Node3D.new()
	# Drivers face -Z; turn them round to face the camera to start with.
	_turntable.rotation.y = PI
	add_child(_turntable)
	var stand := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.55
	disc.bottom_radius = 0.6
	disc.height = 0.08
	disc.radial_segments = 40
	stand.mesh = disc
	stand.material_override = PartVisuals.material(Color("#3c3550"))
	stand.position = Vector3(0.0, -0.04, 0.0)
	_turntable.add_child(stand)
	var studs := PartVisuals.make_studs(Vector3(0.75, 0.0, 0.75), Color("#3c3550"))
	studs.position = Vector3(0.0, -0.03, 0.0)
	_turntable.add_child(studs)

	_camera = Camera3D.new()
	_camera.fov = 36.0
	add_child(_camera)
	_camera.position = Vector3(0.0, 0.7, 2.5)
	_camera.look_at(Vector3(0.0, 0.52, 0.0), Vector3.UP)
	_camera.make_current()
	# Shift the view so the driver sits in the gap between the panels.
	_camera.h_offset = 0.18

	_build_ui()
	_rebuild()


func _rebuild() -> void:
	for node in [_rig, _wheel, _turntable.get_node_or_null("Seat")]:
		if node != null:
			node.queue_free()
	_wheel = null
	_rig = CharacterRig.new(design, not _driving)
	_rig.seated = _driving
	if _driving:
		# A seat and a steering wheel, spaced just as they are in a kart.
		var seat_def := PartCatalog.get_part("seat")
		var seat_extent := Grid.to_metres(Vector3(Grid.rotated_size(seat_def.size, 0)))
		var seat := PartVisuals.make(seat_def, seat_extent)
		seat.name = "Seat"
		seat.position = Vector3(0.0, seat_extent.y * 0.5, 0.0)
		_turntable.add_child(seat)
		_rig.position = Vector3(0.0, seat_extent.y, 0.0)
		var wheel_def := PartCatalog.get_part("steering_wheel")
		var wheel_extent := Grid.to_metres(Vector3(Grid.rotated_size(wheel_def.size, 0)))
		_wheel = SteeringVisual.new(wheel_def, wheel_extent)
		# In a kart the wheel's part sits one stud in front of the seat's, and
		# half a plate lower than the top of the seat.
		_wheel.position = _rig.position + Vector3(0.0, -0.05, -0.375)
		_turntable.add_child(_wheel)
	else:
		_rig.position = Vector3(0.0, CharacterRig.FEET_BELOW, 0.0)
	_turntable.add_child(_rig)
	_weight.text = "%s\n%.0f kg" % [design.weight_class(), design.mass()]
	Game.keep_character(design)


func _process(delta: float) -> void:
	_last_touch += delta
	_time += delta
	if _wheel != null and _rig != null and _rig.is_inside_tree():
		# Steer gently one way and the other, to show them driving.
		var amount := sin(_time * 1.3) * 0.8
		_wheel.steer(amount)
		var grips := _wheel.grips(amount)
		var to_rig := _rig.transform.affine_inverse() * _wheel.transform
		_rig.grip(to_rig * grips[0], to_rig * grips[1], to_rig.basis * grips[2], to_rig.basis * grips[3])
		_rig.look(amount)
	if not _dragging and _last_touch > 1.5:
		_turntable.rotation.y += SPIN * delta


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var over := _panels.any(func(p): return p.is_visible_in_tree() and p.get_global_rect().has_point(event.position))
		_dragging = event.pressed and not over
		_last_touch = 0.0
	elif event is InputEventScreenDrag and _dragging:
		_turntable.rotation.y += event.relative.x * 0.01
		_last_touch = 0.0


func go_back() -> void:
	Game.keep_character(design)
	Game.show_menu()


# The panels.

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.theme = MenuStyle.theme()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var title := Label.new()
	title.text = "Driver"
	title.add_theme_font_size_override("font_size", 44)
	root.add_child(title)
	title.position = Vector2(40, 18)
	var back := MenuStyle.link("Back", go_back)
	root.add_child(back)
	back.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	back.offset_left = -140.0
	back.offset_top = 24.0
	_panels.append(back)

	# Left: the pieces, their styles and colours.
	var left := PanelContainer.new()
	left.add_theme_stylebox_override("panel", _panel_style())
	root.add_child(left)
	left.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	left.offset_left = 24.0
	left.offset_right = 470.0
	left.offset_top = 90.0
	left.offset_bottom = -20.0
	_panels.append(left)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	left.add_child(box)
	var tabs := HFlowContainer.new()
	box.add_child(tabs)
	for tab in TABS:
		var button := Button.new()
		button.text = tab[1]
		button.flat = true
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(_show_slot.bind(tab[0]))
		tabs.add_child(button)
		_tab_buttons.append(button)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
	box.add_child(scroll)
	_styles = VBoxContainer.new()
	_styles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_styles)
	_swatches = GridContainer.new()
	_swatches.columns = 7
	_swatches.add_theme_constant_override("h_separation", 8)
	_swatches.add_theme_constant_override("v_separation", 8)
	box.add_child(_swatches)

	# Right: name and weight.
	var right := PanelContainer.new()
	right.add_theme_stylebox_override("panel", _panel_style())
	root.add_child(right)
	right.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	right.offset_left = -330.0
	right.offset_right = -24.0
	right.offset_top = 90.0
	right.offset_bottom = -20.0
	_panels.append(right)
	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", 14)
	right.add_child(side)
	side.add_child(MenuStyle.heading("Name"))
	_name_edit = LineEdit.new()
	_name_edit.max_length = 20
	_name_edit.text = design.name
	_name_edit.text_changed.connect(func(text: String) -> void:
		design.name = text.strip_edges() if text.strip_edges() != "" else "Driver"
		Game.keep_character(design))
	side.add_child(_name_edit)
	side.add_child(MenuStyle.heading("Weight", "Heavier drivers make a steadier kart that's harder to knock about. Lighter ones make it quicker and twitchier."))
	_weight = Label.new()
	_weight.add_theme_font_size_override("font_size", 30)
	_weight.add_theme_color_override("font_color", MenuStyle.ACCENT)
	side.add_child(_weight)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side.add_child(spacer)
	_pose_button = MenuStyle.button("Show driving", func() -> void:
		_driving = not _driving
		_pose_button.text = "Show standing" if _driving else "Show driving"
		_rebuild())
	side.add_child(_pose_button)
	side.add_child(MenuStyle.button("Random", _randomise))

	_show_slot("head")


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(MenuStyle.TOP, 0.82)
	style.set_corner_radius_all(18)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	return style


func _show_slot(slot: String) -> void:
	_slot = slot
	for i in TABS.size():
		var on: bool = TABS[i][0] == slot
		var colour := MenuStyle.ACCENT if on else Color(1.0, 1.0, 1.0, 0.8)
		_tab_buttons[i].add_theme_color_override("font_color", colour)
		_tab_buttons[i].add_theme_color_override("font_hover_color", colour)
	for child in _styles.get_children():
		child.queue_free()
	for style in CharacterDesign.styles(slot):
		var info := CharacterDesign.piece(slot, style)
		var weight := float(info.get("mass", 0.0))
		var label := "%s   %s kg" % [info.get("name", style), str(snappedf(weight, 0.1)).trim_suffix(".0")]
		var button := MenuStyle.button(label, func() -> void:
			design.set_piece(slot, style)
			_show_slot(slot)
			_rebuild())
		button.custom_minimum_size.y = 50.0
		if design.style_of(slot) == style:
			button.add_theme_color_override("font_color", MenuStyle.ACCENT)
		_styles.add_child(button)
	for child in _swatches.get_children():
		child.queue_free()
	var colours := CharacterDesign.palette(slot == "head")
	if slot == "headgear" and design.style_of("headgear") == "none":
		colours = []
	for colour in colours:
		var swatch := Button.new()
		swatch.custom_minimum_size = Vector2(48, 48)
		swatch.focus_mode = Control.FOCUS_NONE
		var style := StyleBoxFlat.new()
		style.bg_color = colour
		style.set_corner_radius_all(24)
		if colour.is_equal_approx(design.color_of(slot)):
			style.border_color = Color.WHITE
			style.set_border_width_all(4)
		for state in ["normal", "hover", "pressed"]:
			swatch.add_theme_stylebox_override(state, style)
		swatch.pressed.connect(func() -> void:
			design.set_piece(slot, "", colour)
			_show_slot(slot)
			_rebuild())
		_swatches.add_child(swatch)


func _randomise() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var name := design.name
	design = CharacterDesign.random(rng)
	design.name = name
	_show_slot(_slot)
	_rebuild()
