class_name TestDrive
extends Node3D

## Takes the kart from the garage out onto the test course, a short lap of
## jumps, drops, a loop and tight corners built from the same pieces as the
## game's courses. There's no race: you drive round for as long as you like,
## and fall off or wander away and you're put back on the road.

const COURSE := "res://data/test_course.json"
## Which piece the loose bricks stand beyond, and where: metres on from its
## start and to its right. They're on the grass past the hairpin after the
## drop, where you end up if you come off the bridge too fast.
const PILE_PIECE := 6
const PILE_AHEAD := 30.0
const PILE_RIGHT := 16.0

var kart: Kart
var camera: RaceCamera
var speed_label: Label
var track: TrackPath
var builder: TrackBuilder
## How far round the lap the kart is, in metres.
var offset := 0.0
## Frames drawn so far. "Loading" stays up for the first few, while the
## shaders get ready (see Game.show_drive()).
var _frames_drawn := 0


func _ready() -> void:
	track = TrackPath.load_file(COURSE)
	builder = TrackBuilder.new(track)
	add_child(builder)
	var pile_from := track.piece_starts[PILE_PIECE]
	TestTrack.add_brick_pile(self, pile_from.origin - pile_from.basis.z * PILE_AHEAD + pile_from.basis.x * PILE_RIGHT, PI * 0.5)

	var player := LocalPlayerInput.new()
	player.use_keyboard = true
	player.any_joypad = true
	player.both_keys = true
	add_child(player) # before the kart, so its controls are up to date each tick

	kart = Kart.new()
	kart.build(Game.design, Game.character)
	kart.controls = player.controls
	kart.weather_grip = builder.conditions.grip()
	kart.weather_drag = builder.conditions.drag()
	kart.lights_on = builder.conditions.dark()
	kart.beams = builder.conditions.beams()
	kart.transform = track.place_at(0.0)
	kart.reset_to = func(_where: Vector3) -> Transform3D:
		return _reset_spot()
	kart.sound.wind = true
	add_child(kart)

	camera = RaceCamera.new()
	camera.target = kart
	camera.input = player
	camera.head_layer = RaceCamera.head_layer_of(0)
	kart.head_layer = camera.head_layer
	camera.view = Game.camera_view(0)
	camera.view_changed.connect(func(which: String) -> void: Game.set_camera_view(0, which))
	add_child(camera)
	camera.make_current()
	camera.snap()

	var hud := CanvasLayer.new()
	add_child(hud)
	var hud_root := Control.new()
	hud_root.theme = Game.theme
	hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(hud_root)
	hud_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	speed_label = Label.new()
	speed_label.position = Vector2(24, 16)
	speed_label.theme_type_variation = "HudLabel"
	hud_root.add_child(speed_label)

	var garage := Button.new()
	garage.text = "Garage"
	garage.custom_minimum_size = Vector2(150, 56)
	garage.focus_mode = Control.FOCUS_NONE
	hud_root.add_child(garage)
	garage.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	garage.position.y = 12
	garage.pressed.connect(Game.show_garage)

	var view := IconButton.new("camera", "Change the view")
	hud_root.add_child(view)
	view.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	view.offset_left = -190.0
	view.offset_right = -190.0 + IconButton.SIZE
	view.offset_top = 16.0
	view.offset_bottom = 16.0 + IconButton.SIZE
	view.pressed.connect(player.press_view)

	var touch := TouchControls.new()
	touch.visible = TouchControls.shown_at_start()
	touch.steering = Game.steering(0)
	touch.control_size = Game.touch_size()
	touch.height = TouchControls.height_for(Game.touch_height(), false)
	touch.blockers.append(garage)
	touch.blockers.append(view)
	hud_root.add_child(touch)
	player.touch = touch
	# Nothing hides under a camera hole.
	var safe := SafeArea.new()
	hud_root.add_child(safe)
	for control in [speed_label, garage, view]:
		safe.watch(control)

## The controller and keys drive here, so they don't move round the buttons.
func own_controls() -> bool:
	return true


func go_back() -> void:
	Game.show_garage()


func _exit_tree() -> void:
	Game.show_loading(false)


## Back on the road if it's fallen off or wandered a long way from it, the
## same as in a race.
func _physics_process(_delta: float) -> void:
	offset = track.offset_near(kart.global_position, offset, 5.0, 40.0)
	var middle := track.point_at(offset)
	var below := (kart.global_position - middle).dot(track.up_at(offset))
	if kart.slowdown_left <= 0.0 and (below < -Race.FALLEN or kart.global_position.distance_to(middle) > Race.LOST):
		kart.request_reset()


## Where a reset puts the kart: the middle of the road where it is, or well
## before the loop if it came off there, so it has the speed for another go.
func _reset_spot() -> Transform3D:
	var start := offset
	var backed := false
	for step in 80:
		if track.up_at(start).y > 0.95 and not _loop_coming(start):
			break
		start -= 2.0
		backed = true
	if backed:
		start -= Race.RUN_UP
	kart.run_up_reset = backed
	offset = fposmod(start, track.length)
	return track.place_at(start)


func _loop_coming(at: float) -> bool:
	if not TrackPiece.turns_over(track.piece_type_at(at)):
		return false
	var ahead := 0.0
	while ahead <= Race.LOOP_FOOT:
		if track.up_at(at + ahead).y <= 0.95:
			return true
		ahead += 2.0
	return false


func _process(_delta: float) -> void:
	_frames_drawn += 1
	if _frames_drawn == Race.FRAMES_BEFORE_COUNTDOWN:
		Game.show_loading(false)
	var kmh := absf(kart.forward_speed) * 3.6
	var text := "%d km/h" % roundi(kmh)
	if kart.slowdown_left > 0.0:
		text += "   reset slowdown"
	if not kart.lost.is_empty():
		var n := kart.lost.size()
		text += "   %d part%s lost, reset to fix" % [n, "" if n == 1 else "s"]
	if Game.show_fps():
		text += "\n%d fps" % Engine.get_frames_per_second()
	speed_label.text = text
