class_name PowerupField
extends Node3D

## The power-up boxes along a track. Every EVERY metres there's a row of three
## right across the road, so wherever you drive you can get one, and driving
## through a box with a free gadget button gives you a power-up (see
## Powerups), better the further back you are.
##
## A box someone takes is gone for everyone for BACK_AFTER seconds, so two
## karts right behind each other can't both get it. Online, the kart's own
## device takes it and tells the others (see Kart.took_box and take()).
##
## In split screen each player's set is drawn on its own render layer (see
## layer_of()), and each player's camera leaves out the other one's.

const EVERY := 400.0 # metres between rows
const FIRST := 150.0 # metres from the start line to the first row
const ACROSS := [-4.0, 0.0, 4.0] # where the three boxes in a row sit
const HEIGHT := 0.9
const REACH := 1.9
const BACK_AFTER := 3.0 # seconds a taken box is gone for
const SIZE := 1.1
## The render layer of the first viewer's boxes. The next viewer's is the one
## after it.
const FIRST_LAYER := 11

## What the boxes look like (see PowerupLook).
static var look := "stud"

var track: TrackPath
## The race, for each kart's place when it picks a box up. It isn't named as
## a Race, since that needs the Game autoload and the -s tests don't have one.
var race: Node
var spots: Array[Transform3D] = []
## Whose boxes are shown, which is the karts the cameras follow. The rest
## collect theirs unseen. Set this before it's added to the scene.
var viewers: Array[Kart] = []
## When each box comes back, in _time. 0 or less is there now.
var back_at := PackedFloat32Array()
var _time := 0.0
var _rng := RandomNumberGenerator.new()
## One for each viewer.
var _multis: Array[MultiMesh] = []


func _init(path: TrackPath) -> void:
	track = path


func _ready() -> void:
	var d := FIRST
	while d < track.length - 60.0:
		# Never on a loop or a corkscrew, or where the road's open, like a
		# jump's gap.
		var at := d
		while not _row_fits(at) and at < d + EVERY * 0.5:
			at += 8.0
		if _row_fits(at):
			for across in _row_at(at):
				var frame := track.frame_at(at)
				frame.origin += frame.basis.y * HEIGHT + frame.basis.x * across
				spots.append(frame)
		d += EVERY
	back_at.resize(spots.size())

	var box := PowerupLook.mesh(look)
	for v in viewers.size():
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = box
		multi.instance_count = spots.size()
		var draw := MultiMeshInstance3D.new()
		draw.multimesh = multi
		if viewers.size() > 1:
			draw.layers = 1 << (layer_of(v) - 1)
		add_child(draw)
		_multis.append(multi)


## Whether a row can go here: never on a loop or a corkscrew, over a gap,
## or on a jump split's kicker or landing.
func _row_fits(at: float) -> bool:
	if not track.solid_at(at) or TrackPiece.turns_over(track.piece_type_at(at)):
		return false
	var k := track._index_before(at)
	return not track.has_splits or (track.branch_flat(k, 0) and track.branch_flat(k, 1))


## Where across the road a row's boxes go here: ACROSS, or where a split
## has parted, three on each branch.
func _row_at(at: float) -> Array:
	var lanes := track.lanes_at(at)
	if lanes.size() < 2:
		return ACROSS
	var out := []
	for lane in lanes:
		var middle := (lane.x + lane.y) * 0.5
		var step := minf((lane.y - lane.x) * 0.3, absf(ACROSS[0]))
		out.append_array([middle - step, middle, middle + step])
	return out


## The render layer (counting from 1) that this viewer's boxes are drawn on.
static func layer_of(viewer_index: int) -> int:
	return FIRST_LAYER + viewer_index


## Gives this kart a power-up if it's driving through a box and has a free
## button. Returns the one it got, or "".
func collect(kart: Kart) -> String:
	if kart.full():
		return ""
	var middle := kart.global_position + kart.global_basis.y * 0.5
	for i in spots.size():
		if back_at[i] > _time:
			continue
		if spots[i].origin.distance_squared_to(middle) < REACH * REACH:
			back_at[i] = _time + BACK_AFTER
			var field: int = race.racers.size() if race != null else 1
			var kind := Powerups.pick(_place_of(kart), field, _rng)
			kart.give(kind)
			kart.took_box.emit(i)
			return kind
	return ""


## Another device's kart took box `box`, so it goes here too.
func take(box: int) -> void:
	if box >= 0 and box < back_at.size():
		back_at[box] = _time + BACK_AFTER


## Whether box `box` is there to take.
func there(box: int) -> bool:
	return back_at[box] <= _time


func _place_of(kart: Kart) -> int:
	if race == null:
		return 1
	for racer in race.racers:
		if racer.kart == kart:
			return int(race.place_of(racer))
	return 1


func _physics_process(delta: float) -> void:
	_time += delta


## Turns and bobs each viewer's boxes, and hides the taken ones.
func _process(_delta: float) -> void:
	if _multis.is_empty():
		return
	var spin: float = PowerupLook.SPIN.get(look, 1.0)
	var bob: float = PowerupLook.BOB.get(look, 0.0)
	for v in viewers.size():
		if not is_instance_valid(viewers[v]):
			continue
		var multi := _multis[v]
		for i in spots.size():
			var spot := spots[i]
			var foot := spot.origin - spot.basis.y * HEIGHT
			if back_at[i] > _time:
				multi.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ONE * 0.001), foot))
				continue
			var turn := spot.basis * Basis(Vector3.UP, _time * spin + i * 0.9)
			multi.set_instance_transform(i, Transform3D(turn, foot + spot.basis.y * sin(_time * 2.0 + i) * bob))
