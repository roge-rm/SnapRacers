class_name DriverBuilder
extends Node3D

## Where you build your driver. It looks and works like the garage.
##
## They stand on a round baseplate in the middle, slowly turning (drag to spin
## them yourself). The panels are in DriverUI. Pick a piece on the left, then
## a style of it and a colour. Every change can be undone, and everything
## saves as you go.

const SPIN := 0.35 # radians a second when nobody's touching it

var design: CharacterDesign
var ui: DriverUI
var _rig: CharacterRig
var _turntable: Node3D
var _camera: Camera3D
var _dragging := false
var _last_touch := 0.0
var _undo: Array[Dictionary] = []
var _redo: Array[Dictionary] = []
## Whether they're shown sitting in a seat and steering, instead of standing.
var _driving := false
var _wheel: SteeringVisual
var _time := 0.0


func _ready() -> void:
	design = Game.character.duplicate_design()
	SkyAndSun.add_to(self, 20.0, BuilderStyle.BACKGROUND)
	# Lit like a toy on a shelf: softly, with light, soft shadows, a cool
	# light from the other side and a warm one from behind that picks out the
	# edges of the shiny plastic.
	for child in get_children():
		if child is WorldEnvironment:
			child.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
			child.environment.ambient_light_color = Color("#e8e8e8")
			child.environment.ambient_light_energy = 0.38
			child.environment.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
		elif child is DirectionalLight3D:
			child.light_energy = 0.75
			child.shadow_opacity = 0.55
			child.shadow_blur = 2.5
			# Close up, the shadow of the hips on the legs came out as a sawtooth.
			child.shadow_bias = 0.08
			child.shadow_normal_bias = 2.5
	CharacterRig.add_toy_lights(self)

	_turntable = Node3D.new()
	# Drivers face -Z, so turn them around to face the camera to start with.
	_turntable.rotation.y = PI
	add_child(_turntable)
	# A round grey baseplate, the same as the garage's.
	var stand := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.6
	disc.bottom_radius = 0.6
	disc.height = 0.08
	disc.radial_segments = 48
	stand.mesh = disc
	stand.material_override = PartVisuals.material(Color("#5d6873"))
	stand.position = Vector3(0.0, -0.04, 0.0)
	_turntable.add_child(stand)
	var studs := PartVisuals.make_studs(Vector3(0.8, 0.0, 0.8), Color("#5d6873"))
	studs.position = Vector3(0.0, -0.03, 0.0)
	_turntable.add_child(studs)

	_camera = Camera3D.new()
	_camera.fov = 36.0
	add_child(_camera)
	# Far enough back that a top hat clears the toolbar and the feet clear
	# the buttons along the bottom.
	_camera.position = Vector3(0.0, 0.85, 3.1)
	_camera.look_at(Vector3(0.0, 0.42, 0.0), Vector3.UP)
	_camera.make_current()
	# Shift the view so the driver stands in the middle of the space right of
	# the drawer.
	_camera.h_offset = -0.4

	var layer := CanvasLayer.new()
	add_child(layer)
	ui = DriverUI.new()
	layer.add_child(ui)
	ui.style_chosen.connect(func(slot: String, style: String) -> void: _change(slot, style))
	ui.colour_chosen.connect(func(slot: String, colour: Color) -> void: _change(slot, "", colour))
	ui.undo_pressed.connect(undo)
	ui.redo_pressed.connect(redo)
	ui.random_pressed.connect(randomise)
	ui.pose_toggled.connect(func(driving: bool) -> void:
		_driving = driving
		_rebuild())
	ui.done_pressed.connect(go_back)
	ui.name_changed.connect(func(text: String) -> void:
		design.name = text.strip_edges() if text.strip_edges() != "" else "Driver"
		_show())
	_rebuild()


## Changes one piece's style or colour, as one step to undo.
func _change(slot: String, style := "", colour := Color(0, 0, 0, 0)) -> void:
	var before := design.to_dict()
	design.set_piece(slot, style, colour)
	if design.to_dict() == before:
		return
	_undo.append(before)
	_redo.clear()
	_rebuild()


func undo() -> void:
	if not _undo.is_empty():
		_redo.append(design.to_dict())
		_restore(_undo.pop_back())


func redo() -> void:
	if not _redo.is_empty():
		_undo.append(design.to_dict())
		_restore(_redo.pop_back())


## Goes back to an earlier look, keeping the name they've got now.
func _restore(look: Dictionary) -> void:
	var name := design.name
	design = CharacterDesign.from_dict(look)
	design.name = name
	_rebuild()


func randomise() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	_undo.append(design.to_dict())
	_redo.clear()
	var name := design.name
	design = CharacterDesign.random(rng)
	design.name = name
	_rebuild()


func _rebuild() -> void:
	for node in [_rig, _wheel, _turntable.get_node_or_null("Seat")]:
		if node != null:
			node.queue_free()
	_wheel = null
	var first := _rig == null
	_rig = CharacterRig.new(design, _driving)
	_rig.lively = true
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
	# A happy little hop for each new piece they try on.
	if not first:
		_rig.hop()
	_show()


func _show() -> void:
	ui.show_design(design)
	ui.set_history(not _undo.is_empty(), not _redo.is_empty())
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
		_dragging = event.pressed and not ui.is_over_ui(event.position)
		_last_touch = 0.0
	elif event is InputEventScreenDrag and _dragging:
		_turntable.rotation.y += event.relative.x * 0.01
		_last_touch = 0.0


func go_back() -> void:
	Game.keep_character(design)
	Game.show_menu()
