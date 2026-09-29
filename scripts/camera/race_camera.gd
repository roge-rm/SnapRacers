class_name RaceCamera
extends Camera3D

## One person's camera in a race or a test drive. It has several views, and
## the camera button (or V, M, or a controller's Back button) goes through
## them:
## - Chase and far chase follow from behind, one close and one further back
##   and higher up. They swing around to follow the way the kart is actually
##   moving, so a slide looks like a slide.
## - First person is from the driver's eyes, looking over their hands on the
##   steering wheel. Their own head is left out of this camera's view.
## - Bumper is low down on the nose of the kart.
## - Overhead looks straight down from high above, turned so the kart always
##   points up the screen.
## - TV cameras stand beside the track and cut from one to the next as the
##   kart goes by, like a race on TV.
##
## Holding look back turns the view around. When you cross the line the camera
## circles your kart for a moment, then goes to the TV cameras while the AI
## drives you home.

signal view_changed(view: String)

const VIEWS := ["chase", "far", "driver", "bumper", "overhead", "tv"]
const NAMES := {
	"chase": "Chase",
	"far": "Far chase",
	"driver": "First person",
	"bumper": "Bumper",
	"overhead": "Overhead",
	"tv": "TV cameras",
}
## How far behind and above the kart each chase view sits, in metres.
const CHASE := { "chase": [4.3, 1.8], "far": [8.0, 3.4] }
const FOLLOW := 6.0
const LOOK_HEIGHT := 0.9
const OVERHEAD_HEIGHT := 16.0
## How far apart the TV cameras are along the track, how far out from the
## middle of the road, and how high.
const TV_SPACING := 70.0
const TV_OUT := 14.0
const TV_HEIGHT := 4.5
const ORBIT_TIME := 5.0
const ORBIT_RADIUS := 6.0
## The render layer (counting from 1) the first person's driver's head is on,
## so their own first person camera can leave it out (see Kart.head_layer).
## The next person's is the one after.
const FIRST_HEAD_LAYER := 13

var target: Kart
## The track, for the TV cameras. A test drive has none, so no TV cameras.
var track: TrackPath
## Whose controls to read for looking back and changing view.
var input: LocalPlayerInput
var view := "chase"
## The render layer of this person's own driver's head, or 0 for none.
var head_layer := 0

var _up := Vector3.UP
var _looking_back := false
var _orbit_left := 0.0
var _orbit_angle := 0.0
var _after_orbit := ""
var _tv_spots: Array[Vector3] = []
var _tv_offsets: Array[float] = []
var _tv_at := -1
var _offset := -1.0


static func head_layer_of(person: int) -> int:
	return FIRST_HEAD_LAYER + person


func _ready() -> void:
	top_level = true
	fov = 70.0
	near = 0.05
	if track != null:
		_place_tv_cameras()
	_show_view()


## Moves on to the next view.
func next_view() -> void:
	_orbit_left = 0.0
	var views := _views()
	set_view(views[(views.find(view) + 1) % views.size()])
	view_changed.emit(view)


func set_view(which: String) -> void:
	view = which if _views().has(which) else "chase"
	_show_view()
	snap()


## Circles the kart for a moment, then goes to the TV cameras (or back to the
## view it was on, with no track).
func finish() -> void:
	_orbit_left = ORBIT_TIME
	_orbit_angle = 0.0
	_after_orbit = "tv" if track != null else view


func _views() -> Array:
	return VIEWS if track != null else VIEWS.filter(func(v): return v != "tv")


func _show_view() -> void:
	# Leave out your own head in first person, and nowhere else.
	if head_layer > 0:
		set_cull_mask_value(head_layer, view != "driver" or _orbit_left > 0.0)
	fov = 75.0 if view in ["driver", "bumper"] else 70.0


func _physics_process(delta: float) -> void:
	if target == null:
		return
	if input != null:
		if input.take_view_press():
			next_view()
		var back := input.look_back
		if back != _looking_back:
			_looking_back = back
			snap()
	if _orbit_left > 0.0:
		_orbit_left -= delta
		_orbit(delta)
		if _orbit_left <= 0.0:
			set_view(_after_orbit)
		return
	if not _fixed_to_kart():
		_move(delta)


## First person and bumper are fixed to the kart, so they're placed after the
## physics step has moved it, each time the screen's drawn. Placed before it,
## they'd always be a step behind, and the steering wheel would shake.
func _process(_delta: float) -> void:
	if target != null and _orbit_left <= 0.0 and _fixed_to_kart():
		_move(0.0, true)


func _fixed_to_kart() -> bool:
	return view == "driver" or view == "bumper"


## Puts the camera straight where it should be, without easing into it.
func snap() -> void:
	if target == null:
		return
	_move(0.0, true)


func _move(delta: float, instantly := false) -> void:
	var blend := 1.0 if instantly else 1.0 - exp(-FOLLOW * delta)
	match view:
		"driver", "bumper":
			var at := target.eye_point() if view == "driver" else target.to_global(target.bumper_point())
			var turn := target.global_basis.orthonormalized()
			if _looking_back:
				turn = turn.rotated(turn.y, PI)
			global_transform = Transform3D(turn, at)
		"overhead":
			var heading := _heading(Vector3.UP)
			if _looking_back:
				heading = -heading
			var middle := target.global_position + heading * 3.0
			var wanted := middle + Vector3.UP * OVERHEAD_HEIGHT
			global_position = global_position.lerp(wanted, blend)
			look_at(global_position + Vector3.DOWN, heading)
		"tv":
			_tv()
		_:
			_chase(CHASE[view][0], CHASE[view][1], delta, instantly)


## The way the kart's going, flat across `up`.
func _heading(up: Vector3) -> Vector3:
	var facing := -target.global_basis.z
	if target.linear_velocity.length() > 3.0:
		facing = facing.lerp(target.linear_velocity.normalized(), 0.5)
	facing -= up * facing.dot(up)
	if facing.length() < 0.01:
		return Vector3.FORWARD
	return facing.normalized()


func _chase(distance: float, height: float, delta: float, instantly: bool) -> void:
	var wanted_up := Vector3.UP
	if target.sticking:
		wanted_up = target.global_basis.y.normalized()
	# I lerp this instead of using slerp. Slerp between two almost equal
	# directions works out a rotation axis from almost nothing, and Godot
	# complains that it isn't normalised.
	var blended := _up.lerp(wanted_up, 1.0 if instantly else 1.0 - exp(-4.0 * delta))
	if blended.length_squared() > 0.0001:
		_up = blended.normalized()
	var facing := _heading(_up)
	# Looking back, it sits in front of the kart and looks back over it, down
	# the road behind, to see who's coming.
	var side := -1.0 if not _looking_back else 1.0
	var wanted := target.global_position + facing * distance * side + _up * height
	global_position = wanted if instantly else global_position.lerp(wanted, 1.0 - exp(-FOLLOW * delta))
	var aim := target.global_position + _up * LOOK_HEIGHT
	if _looking_back:
		aim = target.global_position - facing * 12.0 + _up * 0.5
	look_at(aim, _up)


func _orbit(delta: float) -> void:
	_orbit_angle += delta * 0.6
	var around := Vector3(cos(_orbit_angle), 0.0, sin(_orbit_angle)).rotated(Vector3.UP, target.global_rotation.y)
	global_position = target.global_position + around * ORBIT_RADIUS + Vector3.UP * 2.2
	look_at(target.global_position + Vector3.UP * 0.6, Vector3.UP)


## Cameras beside the track, on alternate sides.
func _place_tv_cameras() -> void:
	var count := maxi(int(track.length / TV_SPACING), 4)
	for i in count:
		var at := track.length * i / count
		var side := 1.0 if i % 2 == 0 else -1.0
		var spot := track.point_at(at) + track.right_at(at) * side * (track.width * 0.5 + TV_OUT) + Vector3.UP * TV_HEIGHT
		_tv_spots.append(spot)
		_tv_offsets.append(at)


## Watches from whichever TV camera is just ahead of the kart, zoomed in to
## keep it a good size however far away it is.
func _tv() -> void:
	_offset = track.offset_of(target.global_position, _offset, 40.0)
	var count := _tv_spots.size()
	var which := int(fposmod(_offset + TV_SPACING * 0.4, track.length) / track.length * count) % count
	_tv_at = which
	global_position = _tv_spots[which]
	var to_kart := target.global_position + Vector3.UP * 0.5 - global_position
	if to_kart.length() > 0.5:
		look_at(target.global_position + Vector3.UP * 0.5, Vector3.UP)
		fov = clampf(rad_to_deg(2.0 * atan(5.0 / to_kart.length())), 12.0, 70.0)
